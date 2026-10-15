//+------------------------------------------------------------------+
//|                                     Modified EMA RiskStrategy EA |
//|                                  Copyright 2024-2026, Shigosag.  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2026, Shigosag"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#define MACROSS_MAGIC_NUM 2024290
#define MACROSS_OPEN_BUY_SIGNAL 1
#define MACROSS_OPEN_SELL_SIGNAL -1
#define MACROSS_NO_SIGNAL 0

//--- Input Parameters (Distances in PIPS)
extern int       ShortMaPeriod       = 7;
extern int       LongMaPeriod        = 21;
extern double    StopLoss            = 50.0;   // 50 pips
extern double    TakeProfit          = 200.0;  // 200 pips
extern double    TrailingStop        = 30.0;   // 30 pips
extern double    MaxSpread           = 3.0;    // 3.0 pips
extern double    Lots                = 0.01;
extern int       Slippage            = 3;      // 3 pips
extern bool      AllowMultipleOrders = false;

//--- 6 Separate Hour Filters (Server Hour: 0-23, or -1 to disable)
extern int       StartHour     = 3;
extern int       EndHour       = 6;
extern int       StartHour1    = 11;
extern int       EndHour1      = 14;
extern int       StartHour2    = 19;
extern int       EndHour2      = 21;
extern int       StartHour3    = -1;
extern int       EndHour3      = -1;
extern int       StartHour4    = -1;
extern int       EndHour4      = -1;
extern int       StartHour5    = -1;
extern int       EndHour5      = -1;

//--- Day Filters
extern bool      Monday        = true;
extern bool      Tuesday       = true;
extern bool      Wednesday     = true;
extern bool      Thursday      = true;
extern bool      Friday        = true;

extern string    ExpertName    = "Shigosag_EMA_RiskStrategy_Fixed";

//--- Risk Management Settings
extern bool      RiskManagementEnabled       = false;
extern double    MaxRiskPerTrade             = 1.0;   // 1% of equity
extern bool      UseMaxDrawdown              = false;
extern double    MaxDrawdownPercent          = 10.0;  // Drawdown limit in %

//--- Volatility & ATR
extern bool      VolatilityFilterEnabled     = false;
extern int       ATRPeriod                   = 14;
extern double    MinATR                      = 0.0003;
extern double    MaxATR                      = 0.0050;

//--- Dynamic ATR SL/TP
extern bool      DynamicSLEnabled            = false;
extern bool      DynamicTPEnabled            = false;
extern double    DynamicATRMultiplierSL      = 1.5;
extern double    DynamicATRMultiplierTP      = 3.0;

//--- Break-Even & Time Exits
extern bool      BreakEvenEnabled            = false;
extern double    BreakEvenTriggerPips        = 25.0;  // Profit in pips to trigger BE
extern double    BreakEvenLockPips           = 2.0;   // Pips in profit to lock
extern bool      EnableTimeBasedExit         = false;
extern int       TimeBasedExitMinutes        = 60;

//--- Trend & Higher Timeframe Filters
extern bool      EnableTrendFilter           = true;
extern int       TrendFilterPeriod           = 50;
extern bool      UseMultiTimeframeConfirmation = true;
extern int       HigherTimeframe             = PERIOD_H1;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Universal Pip Size Helper                                        |
//+------------------------------------------------------------------+
double GetPipValue(string sym)
{
   int dig = (int)MarketInfo(sym, MODE_DIGITS);
   double pt = MarketInfo(sym, MODE_POINT);
   if(dig == 3 || dig == 5) return pt * 10.0;
   return pt;
}

int GetPipPoints(string sym)
{
   int dig = (int)MarketInfo(sym, MODE_DIGITS);
   if(dig == 3 || dig == 5) return 10;
   return 1;
}

//+------------------------------------------------------------------+
//| Accurate Broker Lot Normalization                                |
//+------------------------------------------------------------------+
double NormalizeLot(string sym, double lot)
{
   double minLot  = MarketInfo(sym, MODE_MINLOT);
   double maxLot  = MarketInfo(sym, MODE_MAXLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);

   if(minLot <= 0) minLot = 0.01;
   if(maxLot <= 0) maxLot = 100.0;
   if(lotStep <= 0) return minLot;

   int stepDec = (int)MathCeil(MathAbs(MathLog10(lotStep)));
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   return NormalizeDouble(lot, stepDec);
}

//+------------------------------------------------------------------+
//| Accurate Equity % Lot Sizing                                     |
//+------------------------------------------------------------------+
double CalculateRiskLots(string sym, double slPips)
{
   if(!RiskManagementEnabled || slPips <= 0)
      return NormalizeLot(sym, Lots);

   double riskCash   = AccountEquity() * (MaxRiskPerTrade / 100.0);
   double tickValue  = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize   = MarketInfo(sym, MODE_TICKSIZE);
   double pipVal     = GetPipValue(sym);

   if(tickSize <= 0 || tickValue <= 0) 
      return NormalizeLot(sym, Lots);

   double lossPerLot = (slPips * pipVal / tickSize) * tickValue;
   if(lossPerLot <= 0) 
      return NormalizeLot(sym, Lots);

   return NormalizeLot(sym, riskCash / lossPerLot);
}

//+------------------------------------------------------------------+
//| Time & Session Validation                                        |
//+------------------------------------------------------------------+
bool IsHourAllowed(int h, int startH, int endH)
{
   if(startH < 0 || endH < 0) return false;
   if(startH <= endH) return (h >= startH && h <= endH);
   return (h >= startH || h <= endH);
}

bool IsAllowedTime()
{
   switch(DayOfWeek())
   {
      case 1: if(!Monday)    return false; break;
      case 2: if(!Tuesday)   return false; break;
      case 3: if(!Wednesday) return false; break;
      case 4: if(!Thursday)  return false; break;
      case 5: if(!Friday)    return false; break;
      default: return false;
   }

   int h = Hour();
   return (IsHourAllowed(h, StartHour,  EndHour)  ||
           IsHourAllowed(h, StartHour1, EndHour1) ||
           IsHourAllowed(h, StartHour2, EndHour2) ||
           IsHourAllowed(h, StartHour3, EndHour3) ||
           IsHourAllowed(h, StartHour4, EndHour4) ||
           IsHourAllowed(h, StartHour5, EndHour5));
}

bool CheckMaxDrawdown()
{
   if(!UseMaxDrawdown) return false;
   double equity  = AccountEquity();
   double balance = AccountBalance();
   if(balance <= 0) return true;
   double currentDD = ((balance - equity) / balance) * 100.0;
   return (currentDD >= MaxDrawdownPercent);
}

bool IsNewBar()
{
   if(Time[0] != lastBarTime)
   {
      lastBarTime = Time[0];
      return true;
   }
   return false;
}

bool HasOpenOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MACROSS_MAGIC_NUM)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Signal Detection with Higher-Timeframe Confirmation              |
//+------------------------------------------------------------------+
int OpenSignal()
{
   // Volatility Filter
   double atr = iATR(NULL, 0, ATRPeriod, 1);
   if(VolatilityFilterEnabled && (atr < MinATR || atr > MaxATR))
      return MACROSS_NO_SIGNAL;

   // Crossover checks on closed bars 1 and 2
   double shortMa1 = iMA(NULL, 0, ShortMaPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double shortMa2 = iMA(NULL, 0, ShortMaPeriod, 0, MODE_EMA, PRICE_CLOSE, 2);
   double longMa1  = iMA(NULL, 0, LongMaPeriod,  0, MODE_EMA, PRICE_CLOSE, 1);
   double longMa2  = iMA(NULL, 0, LongMaPeriod,  0, MODE_EMA, PRICE_CLOSE, 2);

   int signal = MACROSS_NO_SIGNAL;
   if(shortMa2 <= longMa2 && shortMa1 > longMa1) signal = MACROSS_OPEN_BUY_SIGNAL;
   if(shortMa2 >= longMa2 && shortMa1 < longMa1) signal = MACROSS_OPEN_SELL_SIGNAL;

   if(signal == MACROSS_NO_SIGNAL) return MACROSS_NO_SIGNAL;

   // Trend Filter on Current Chart
   if(EnableTrendFilter)
   {
      double trendMa = iMA(NULL, 0, TrendFilterPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(signal == MACROSS_OPEN_BUY_SIGNAL  && iClose(NULL, 0, 1) < trendMa) return MACROSS_NO_SIGNAL;
      if(signal == MACROSS_OPEN_SELL_SIGNAL && iClose(NULL, 0, 1) > trendMa) return MACROSS_NO_SIGNAL;
   }

   // Trend Filter on Higher Timeframe
   if(UseMultiTimeframeConfirmation)
   {
      double htfMa    = iMA(NULL, HigherTimeframe, TrendFilterPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      double htfClose = iClose(NULL, HigherTimeframe, 1);
      if(signal == MACROSS_OPEN_BUY_SIGNAL  && htfClose < htfMa) return MACROSS_NO_SIGNAL;
      if(signal == MACROSS_OPEN_SELL_SIGNAL && htfClose > htfMa) return MACROSS_NO_SIGNAL;
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Trade Execution                                                  |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal)
{
   RefreshRates();

   string sym = Symbol();
   double pipVal = GetPipValue(sym);
   int pipPts = GetPipPoints(sym);

   double spreadPips = MarketInfo(sym, MODE_SPREAD) / (double)pipPts;
   if(MaxSpread >= 0 && spreadPips > MaxSpread) return;

   // Determine SL and TP
   double actualSlPips = StopLoss;
   double actualTpPips = TakeProfit;

   if(DynamicSLEnabled) actualSlPips = (iATR(sym, 0, ATRPeriod, 1) * DynamicATRMultiplierSL) / pipVal;
   if(DynamicTPEnabled) actualTpPips = (iATR(sym, 0, ATRPeriod, 1) * DynamicATRMultiplierTP) / pipVal;

   double minBrokerDist = MathMax(MarketInfo(sym, MODE_STOPLEVEL), MarketInfo(sym, MODE_FREEZELEVEL)) * MarketInfo(sym, MODE_POINT);
   double slDist = actualSlPips * pipVal;
   double tpDist = actualTpPips * pipVal;

   if((actualSlPips > 0 && slDist < minBrokerDist) || (actualTpPips > 0 && tpDist < minBrokerDist))
   {
      Print("Order aborted: SL/TP too close to broker minimum distance.");
      return;
   }

   double lotSize = CalculateRiskLots(sym, actualSlPips);
   int slip = Slippage * pipPts;
   int cmd = (signal == MACROSS_OPEN_BUY_SIGNAL) ? OP_BUY : OP_SELL;
   double price = (cmd == OP_BUY) ? Ask : Bid;
   double sl = 0, tp = 0;

   if(cmd == OP_BUY)
   {
      if(actualSlPips > 0) sl = NormalizeDouble(price - slDist, Digits);
      if(actualTpPips > 0) tp = NormalizeDouble(price + tpDist, Digits);
   }
   else
   {
      if(actualSlPips > 0) sl = NormalizeDouble(price + slDist, Digits);
      if(actualTpPips > 0) tp = NormalizeDouble(price - tpDist, Digits);
   }

   ResetLastError();
   int ticket = OrderSend(sym, cmd, lotSize, price, slip, sl, tp, ExpertName, MACROSS_MAGIC_NUM, 0, (cmd == OP_BUY ? clrGreen : clrRed));

   // ECN fallback
   if(ticket < 0 && GetLastError() == 130)
   {
      ticket = OrderSend(sym, cmd, lotSize, price, slip, 0, 0, ExpertName, MACROSS_MAGIC_NUM, 0, (cmd == OP_BUY ? clrGreen : clrRed));
      if(ticket > 0 && OrderSelect(ticket, SELECT_BY_TICKET))
      {
         double fillP = OrderOpenPrice();
         double fSl = (cmd == OP_BUY) ? NormalizeDouble(fillP - slDist, Digits) : NormalizeDouble(fillP + slDist, Digits);
         double fTp = (cmd == OP_BUY) ? NormalizeDouble(fillP + tpDist, Digits) : NormalizeDouble(fillP - tpDist, Digits);
         OrderModify(ticket, fillP, fSl, fTp, 0, clrBlue);
      }
   }
}

//+------------------------------------------------------------------+
//| Trade Management: Trailing Stop, Break-Even & Time Exit          |
//+------------------------------------------------------------------+
void ManageTrades()
{
   RefreshRates();
   string sym = Symbol();
   double pipVal = GetPipValue(sym);
   double pt = MarketInfo(sym, MODE_POINT);
   double minDistance = MathMax(MarketInfo(sym, MODE_STOPLEVEL), MarketInfo(sym, MODE_FREEZELEVEL)) * pt;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != sym || OrderMagicNumber() != MACROSS_MAGIC_NUM) continue;

      int ticket = OrderTicket();
      double openP = OrderOpenPrice();
      double currentSl = OrderStopLoss();
      double currentTp = OrderTakeProfit();

      // 1. Time-Based Exit
      if(EnableTimeBasedExit && (TimeCurrent() - OrderOpenTime()) >= TimeBasedExitMinutes * 60)
      {
         double closeP = (OrderType() == OP_BUY) ? Bid : Ask;
         OrderClose(ticket, OrderLots(), closeP, Slippage * GetPipPoints(sym), clrYellow);
         continue;
      }

      // 2. Break-Even
      if(BreakEvenEnabled)
      {
         if(OrderType() == OP_BUY && (Bid - openP) >= (BreakEvenTriggerPips * pipVal))
         {
            double bePrice = NormalizeDouble(openP + (BreakEvenLockPips * pipVal), Digits);
            if(currentSl < bePrice)
               OrderModify(ticket, openP, bePrice, currentTp, 0, clrAqua);
         }
         else if(OrderType() == OP_SELL && (openP - Ask) >= (BreakEvenTriggerPips * pipVal))
         {
            double bePrice = NormalizeDouble(openP - (BreakEvenLockPips * pipVal), Digits);
            if(currentSl == 0 || currentSl > bePrice)
               OrderModify(ticket, openP, bePrice, currentTp, 0, clrAqua);
         }
      }

      // 3. Trailing Stop
      if(TrailingStop > 0)
      {
         if(OrderType() == OP_BUY)
         {
            if((Bid - openP) > (TrailingStop * pipVal))
            {
               double newStop = NormalizeDouble(Bid - (TrailingStop * pipVal), Digits);
               if((Bid - newStop >= minDistance) && (currentSl == 0 || newStop > currentSl + pt))
                  OrderModify(ticket, openP, newStop, currentTp, 0, clrGreen);
            }
         }
         else if(OrderType() == OP_SELL)
         {
            if((openP - Ask) > (TrailingStop * pipVal))
            {
               double newStop = NormalizeDouble(Ask + (TrailingStop * pipVal), Digits);
               if((newStop - Ask >= minDistance) && (currentSl == 0 || newStop < currentSl - pt))
                  OrderModify(ticket, openP, newStop, currentTp, 0, clrRed);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MT4 Event Handlers                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   lastBarTime = Time[0];
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick()
{
   ManageTrades();

   if(IsNewBar())
   {
      if(CheckMaxDrawdown()) return;
      if(!AllowMultipleOrders && HasOpenOrder()) return;

      if(IsAllowedTime())
      {
         int signal = OpenSignal();
         if(signal != MACROSS_NO_SIGNAL)
            ExecuteTrade(signal);
      }
   }
}
