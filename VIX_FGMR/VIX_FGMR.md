# $VIX Fear & Greed Mean Reversion Strategy (VIX_FGMR) #

This is a long/short strategy based on the work of [@kerberos007](https://twitter.com/kerberos007). If you look at his feed, you will see lots of work regarding this strategy using Bollinger Bands, Percent B (%B), and some initial parameters that give good back testing results.

As with any strategy, you should understand it, tweak it to your own risk profile, and extend it to incorporate other indicators and strategies.

Alternatively, just buy or sell the glitch!

## Strategy and Study Development ##

This strategy/study is for the VIX.

A *strategy* for this study is still under development... This study can be used independently, or you can find this study in use on the [FGMR](/FGMR/FGMR.md) page. See that page for a lot of info on how to configure studies in thinkorswim.

[VIX_FGMR](/VIX_FGMR/VIX_FGMR.txt)

Per the aformentioned work from [@kerberos007](https://twitter.com/kerberos007)

    Calls
    go long VIX calls when %B(20,1.5) crosses > 0
    cover VIX calls when %B(20,1.5) crosses > 100
    
    Puts
    go long VIX puts when %B(20,1.2) crosses < 100
    cover VIX puts when %B(20,2) crosses < 0

A *Study* will fire many times more than its corresponding *Strategy*. This is also good for developing a new strategy, so you can eyeball when various conditions happen and you get your aha moment.

## post script ##

These studies may or may not work on other symbols. With modifications to the parameters, maybe they work better for Gold than the Euro. Welcome to technical analysis and your journey down the rabbit hole.

## feedback welcome ##

Have a suggestion? Found an issue? Reach out to me on twitter, my DM is open to all. If you are a github user, file an issue or make a suggested change and PR to this repo.


---
back to [README.md](/README.md)