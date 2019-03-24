<#
.SYNOPSIS
Output statistics from a thinkorswim strategy file exported as csv.

.PARAMETER File
Name or of csv file to process.

.PARAMETER ShowFileContents
If true, will output the contents of the csv file and calculated properties.

.NOTES
Author Kory Gill, @korygill

.LINK
https://github.com/korygill/technical-analysis
#>

[CmdletBinding()]
param (
    [string]
    $File = '..\FGMR\FGMR-StrategyReports-SPX.csv',

    [switch]
    $ShowFileContents
)

#
# functions
#
function Convert-CurrencyStringToDecimal ([string]$input)
{
    ((($input -replace '\$') -replace '[)]') -replace '\(', '-') -replace '[^-0-9.]'
}

function Add-Statistic ([string]$statistic, [double]$data)
{
    $dbl = [math]::Round($data, 2)
    $dblStr = "{0:N2}" -f $dbl

    #Write-Information "$statistic $dblStr"

    $null = $outData.Add(
        [PSCustomObject]@{
            'Statistic'=$statistic
            'DblData'=$dbl
            'Data'=$dblStr
            }
        )
}

function Write-Header
{
    Write-Output "$("="*78)"
}


#
# start of main script
#

# Makes debugging from ISE easier.
if ($PSScriptRoot -eq "")
{
    $root = Split-Path -Parent $psISE.CurrentFile.FullPath
}
else
{
    $root = $PSScriptRoot
}

Set-Location $root

if (-not (Test-Path $File))
{
    throw "Cannot open file '$File'."
}

# read csv file
$outData = [System.Collections.ArrayList]::new()
$content = Get-Content -Path $File
$csvdata = $content | ? {$_ -match ";.*;"} | ConvertFrom-Csv -Delimiter ';'

# convert currency strings to decimal
# calculate properties
foreach ($item in $csvdata)
{
    $item.Amount = [double]($item.Amount | Convert-CurrencyStringToDecimal)
    $item.Price = $item.Price | Convert-CurrencyStringToDecimal
    $tpl = [double]($item.'Trade P/L' | Convert-CurrencyStringToDecimal)
    $item.'Trade P/L' = if ($tpl -eq 0) {""} else {$tpl}
    $pl = [double]($item.'P/L' | Convert-CurrencyStringToDecimal)
    $item.'P/L' = if ($pl -eq 0) {""} else {$pl}

    if ($tpl -eq 0)
    {
        $item | Add-Member -MemberType NoteProperty -Name "Points" -Value 0
    }
    else
    {
        $apl = [math]::Abs($item.Amount)
        $item | Add-Member -MemberType NoteProperty -Name "Points" -Value ($tpl/$apl*($apl/50))
    }
}

if ($ShowFileContents)
{
    $csvdata | ft -AutoSize
}

#
# stats!
#
Add-Statistic "Total trades:" $($csvdata.Count)

# get only lines that have Trade P/L
$tradepl = $csvdata | ? {$_.'Trade P/L'}
Add-Statistic "Total orders:" $($tradepl.Count)

$n = $tradepl.'Trade P/L' | Measure-Object -Maximum -Minimum -Sum -Average
Add-Statistic "Total P/L:" $($n.Sum)
Add-Statistic "Min Trade P/L:" $($n.Minimum)
Add-Statistic "Max Trade P/L:" $($n.Maximum)

$winners = $tradepl | ? {$_.'Trade P/L' -ge 0}
Add-Statistic "Winners:" $($winners.Count)

$losers = $tradepl | ? {$_.'Trade P/L' -lt 0}
Add-Statistic "Losers:" $($losers.Count)

$n = $winners.'Trade P/L' | Measure-Object -Maximum -Minimum -Sum -Average
Add-Statistic "Winner Total P/L:" $($n.Sum)
Add-Statistic "Winner Min Trade P/L:" $($n.Minimum)
Add-Statistic "Winner Max P/L:" $($n.Maximum)

$n = $losers.'Trade P/L' | Measure-Object -Maximum -Minimum -Sum -Average
Add-Statistic "Loser Total P/L:" $($n.Sum)
Add-Statistic "Loser Min Trade P/L:" $($n.Minimum)
Add-Statistic "Loser Max P/L:" $($n.Maximum)

<#
$max = ($tradepl.'P/L' | Measure-Object -Maximum).Maximum
$maxTrade = $tradepl | ? {$_.'P/L' -eq $max}

$min = ($tradepl.'P/L' | Measure-Object -Minimum).Minimum
$minTrade = $tradepl | ? {$_.'P/L' -eq $min}
#>

$points = $tradepl.Points | Measure-Object -Sum -Average -Maximum -Minimum
Add-Statistic "Average Points:" $points.Average
Add-Statistic "Maximum Points:" $points.Maximum
Add-Statistic "Minimum Points:" $points.Minimum

$shortTrades = $tradepl | ? {$_.Amount -gt 0}
$longTrades = $tradepl | ? {$_.Amount -lt 0}

Add-Statistic "Short Trades:" $shortTrades.Count
Add-Statistic "Long Trades:" $longTrades.Count

$points = $shortTrades.Points | Measure-Object -Sum -Average -Maximum -Minimum
Add-Statistic "Short Average Points:" $points.Average
Add-Statistic "Short Maximum Points:" $points.Maximum
Add-Statistic "Short Minimum Points:" $points.Minimum

$points = $longTrades.Points | Measure-Object -Sum -Average -Maximum -Minimum
Add-Statistic "Long Average Points:" $points.Average
Add-Statistic "Long Maximum Points:" $points.Maximum
Add-Statistic "Long Minimum Points:" $points.Minimum

Write-Header
Write-Output "Statistics for '$($tradepl[0].Strategy)' from '$File'."
Write-Output "From: $($tradepl[0].'Date/Time')"
Write-Output "  To: $($tradepl[-1].'Date/Time')"
$outData | Select Statistic, Data | ft

Write-Header
Write-Output "Trade distribution by trade size (1 ES == 50 units)"
$tradepl | Group Amount | Sort {[int]$_.Name} | Select @{n='Trades'; e={$_.Count}}, @{n='TradeSize';e={[int]$_.Name*-1}} | ft

# calc trade length stats
$openCloseTrade = [System.Collections.ArrayList]::new()
$firstOpen = $false
$openTrade = $null
$closeTrade = $null

foreach ($item in $csvdata)
{
    if ($item.Side -match "to Open" -and $firstOpen -eq $false)
    {
        $firstOpen = $true
        $openTrade = $item
    }
    elseif ($item.Side -match "to Close")
    {
        $firstOpen = $false
        $closeTrade = $item

        $null = $openCloseTrade.Add(
            [PSCustomObject]@{
                'FirstOpenTrade'=$openTrade
                'CloseTrade'=$closeTrade
                }
            )
    }
}

# all trades
$tradeDuration = [System.Collections.ArrayList]::new()

foreach ($trade in $openCloseTrade)
{
    $openDate = [datetime]::Parse($trade.FirstOpenTrade.'Date/Time')
    $closeDate = [datetime]::Parse($trade.CloseTrade.'Date/Time')
    $numDays = $closeDate - $openDate
    $null = $tradeDuration.Add($numDays)
}

Write-Header
Write-Output "Trade Size by Duration"
$tradeDuration.TotalDays | group | sort {[int]$_.Count}, {[int]$_.Name} | Select @{n='TradeSize'; e={$_.Count}}, @{n='Days';e={$_.Name}} | ft

# buys only
$buys = $openCloseTrade | ? {$_.FirstOpenTrade.Side -match "Buy to Open"}
$tradeDuration = [System.Collections.ArrayList]::new()

foreach ($trade in $buys)
{
    $openDate = [datetime]::Parse($trade.FirstOpenTrade.'Date/Time')
    $closeDate = [datetime]::Parse($trade.CloseTrade.'Date/Time')
    $numDays = $closeDate - $openDate
    $null = $tradeDuration.Add($numDays)
}

Write-Header
Write-Output "Long Trade Size by Duration"
$tradeDuration.TotalDays | group | sort {[int]$_.Count}, {[int]$_.Name} | Select @{n='TradeSize'; e={$_.Count}}, @{n='Days';e={$_.Name}} | ft

# sells only
$sells = $openCloseTrade | ? {$_.FirstOpenTrade.Side -match "Sell to Open"}
$tradeDuration = [System.Collections.ArrayList]::new()

foreach ($trade in $sells)
{
    $openDate = [datetime]::Parse($trade.FirstOpenTrade.'Date/Time')
    $closeDate = [datetime]::Parse($trade.CloseTrade.'Date/Time')
    $numDays = $closeDate - $openDate
    $null = $tradeDuration.Add($numDays)
}

Write-Header
Write-Output "Short Trade Size by Duration"
$tradeDuration.TotalDays | group | sort {[int]$_.Count}, {[int]$_.Name} | Select @{n='TradeSize'; e={$_.Count}}, @{n='Days';e={$_.Name}} | ft



