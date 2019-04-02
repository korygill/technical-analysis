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

$tradeUnitSize = 0;
if ($csvdata.Count)
{
    $tradeUnitSize = [math]::Abs($csvdata[0].Amount)
}

Write-Header
Write-Output "Trade Unite Size is '$tradeUnitSize' (FYI: 1 ES == 50 SPX units)`r`n"

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
        $item | Add-Member -MemberType NoteProperty -Name "Points" -Value ($tpl/$apl*($apl/$tradeUnitSize))
    }
}

if ($ShowFileContents)
{
    $csvdata | ft -AutoSize
}

#
# get only lines that have Trade P/L
#
$tradepl = $csvdata | ? {$_.'Trade P/L'}
#$tradepl = $csvdata | ? {$_.'Trade P/L' -and ($_.'Date/Time' -lt [datetime]::Parse('12/15/2018') -or $_.'Date/Time' -gt [datetime]::Parse('12/31/2018'))}

Write-Header
Write-Output "Trade distribution by trade size (1 ES == 50 SPX units)"
$tradepl | Group Amount | Sort {[int]$_.Name} | Select @{n='Trades'; e={$_.Count}}, @{n='TradeSize';e={[int]$_.Name*-1}} | ft

#
# calc trade length stats
#
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

#
# all trades
#
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

#
# buys only
#
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
if ($tradeDuration.Count)
{
    $tradeDuration.TotalDays | group | sort {[int]$_.Count}, {[int]$_.Name} | Select @{n='TradeSize'; e={$_.Count}}, @{n='Days';e={$_.Name}} | ft
}
else
{
    Write-Output "NONE"
}

#
# sells only
#
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
if ($tradeDuration.Count)
{
    $tradeDuration.TotalDays | group | sort {[int]$_.Count}, {[int]$_.Name} | Select @{n='TradeSize'; e={$_.Count}}, @{n='Days';e={$_.Name}} | ft
}
else
{
    Write-Output "NONE"
}

#
# stats!
#
Add-Statistic "Total trades:" $($csvdata.Count)

# get only lines that have Trade P/L
# $tradepl = $csvdata | ? {$_.'Trade P/L'}
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

$shortTrades = [System.Collections.ArrayList]::new()
$tplShort = $tradepl | ? {$_.Amount -gt 0}
if ($tplShort) {$shortTrades.AddRange($tplShort)}

$longTrades = [System.Collections.ArrayList]::new()
$tplLong = $tradepl | ? {$_.Amount -lt 0}
if ($tplLong) {$longTrades.AddRange($tplLong)}

Add-Statistic "Short Trades:" $shortTrades.Count
Add-Statistic "Long Trades:" $longTrades.Count

$shortPoints = if ($shortTrades.Count) {$shortTrades.Points} else {0}
$points = $shortPoints | Measure-Object -Sum -Average -Maximum -Minimum
Add-Statistic "Short Average Points:" $points.Average
Add-Statistic "Short Maximum Points:" $points.Maximum
Add-Statistic "Short Minimum Points:" $points.Minimum

$longPoints = if ($longTrades.Count) {$longTrades.Points} else {0}
$points = $longPoints | Measure-Object -Sum -Average -Maximum -Minimum
Add-Statistic "Long Average Points:" $points.Average
Add-Statistic "Long Maximum Points:" $points.Maximum
Add-Statistic "Long Minimum Points:" $points.Minimum

$exitType = ($tradepl | ? Strategy -Match 'StopLossLX')
$exit = if ($exitType) {$exitType.Count} else {0}
Add-Statistic "Exit StopLossLX:" $exit

$exitType = ($tradepl | ? Strategy -NotMatch 'StopLossLX')
$exit = if ($exitType) {$exitType.Count} else {0}
Add-Statistic "Exit NOT StopLossLX:" $exit


#
# Output Statistics
#
Write-Header
Write-Output "Statistics for '$($tradepl[0].Strategy)' from '$File'."
Write-Output "From: $($tradepl[0].'Date/Time')"
Write-Output "  To: $($tradepl[-1].'Date/Time')"
$outData | Select Statistic, Data | ft

# Just a line that does nothing so you can set a breakpoint if needed before script exits.
Start-Sleep -Milliseconds 100
