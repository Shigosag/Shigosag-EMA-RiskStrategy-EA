# Shigosag EMA RiskStrategy EA

An experimental MQL4 Expert Advisor for MetaTrader 4 (MT4) that uses EMA crossover signals, trend filters, and configurable trade-management settings.

## Features

- EMA crossover strategy using closed candles
- Current-timeframe and higher-timeframe trend confirmation
- Configurable trading sessions and weekday filters
- Maximum spread filter
- Fixed-lot and equity-based risk sizing
- Fixed or ATR-based stop-loss and take-profit
- Trailing-stop management
- Break-even stop management
- Optional time-based trade exits
- Optional maximum drawdown filter
- Broker-aware lot normalization and stop-distance checks
- Magic number to identify the EA's trades

## Requirements

- MetaTrader 4 (MT4)
- MetaEditor with MQL4 support
- An MT4-compatible broker account

## Installation

1. Download `Shigosag-EMA-RiskStrategy-EA.mq4` from this repository.
2. Open MetaTrader 4 and launch MetaEditor.
3. Place the file in the `MQL4/Experts/` directory.
4. Compile the EA and review any errors or warnings.
5. Run backtests in the MT4 Strategy Tester.
6. Forward-test on a demo account before considering live trading.

## Default Settings

**All default values are for testing and demonstration purposes only.** They are not guaranteed to be profitable or suitable for every trader, broker, symbol, or timeframe.

| Parameter | Default |
|---|---:|
| Short EMA period | 7 |
| Long EMA period | 21 |
| Stop-loss | 50 pips |
| Take-profit | 200 pips |
| Trailing stop | 30 pips |
| Maximum spread | 3 pips |
| Fixed lot size | 0.01 |
| Risk-based sizing | Disabled |
| Risk per trade | 1% when enabled |
| Break-even | Disabled |
| ATR-based SL/TP | Disabled |
| Higher-timeframe confirmation | Enabled |
| Trend filter | Enabled |
| Multiple orders | Disabled |

Review and adjust all settings based on your own testing, broker specifications, and risk tolerance. Pip calculations may differ for non-Forex instruments.

## Testing and Limitations

This project is experimental and has not been established as production-ready. Compile and test it thoroughly, including order execution, stop-loss protection, broker restrictions, and risk-sizing behavior. Broker conditions can affect execution, and protective orders are not guaranteed to succeed.

## Risk Disclaimer

Automated trading involves substantial financial risk, including the possible loss of capital. This EA is provided for educational and experimental purposes only and does not constitute financial advice. Backtest and forward-test on a demo account before considering live trading. Past performance does not guarantee future results.

## Author

**Shigosag (Segun Arulogun Gabriel)**

- GitHub: https://github.com/Shigosag
- Portfolio: https://shigosag.github.io
