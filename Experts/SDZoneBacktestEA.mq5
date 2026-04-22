//+------------------------------------------------------------------+
//|                                              SDZoneBacktestEA.mq5 |
//|                                        Example EA for backtesting |
//+------------------------------------------------------------------+
#property copyright "Example"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input string InpIndicatorName = "BasicS&D";
input int    InpZoneSizePoints = 100;
input int    InpExtendBars = 10;
input int    InpMergeDistancePoints = 150;
input bool   InpDedupeNearbyZones = false;
input bool   InpMergeOverlappingZones = true;
input int    InpLimit = 250;

input int    InpLookbackBars = 500;
input double InpLot = 0.10;
input int    InpSLPoints = 500;
input bool   InpUseRiskReward = true;
input double InpRiskReward = 2.0;
input int    InpTPPoints = 1000;
input bool   InpUseTrendFilter = true;
input int    InpMAPeriod = 200;
input ENUM_MA_METHOD InpMAMethod = MODE_EMA;
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE;
input bool   InpOnlyFirstTouch = true;
input long   InpMagic = 26042026;
input bool   InpOnePositionOnly = true;
input bool   InpReverseOnOppositeZone = true;
input string InpTestTag = "A_BASE";
input bool   InpPrintDebugStats = true;

CTrade trade;
int    indicatorHandle = INVALID_HANDLE;
int    maHandle = INVALID_HANDLE;

datetime lastBarTime = 0;
double   lastDemandLow = EMPTY_VALUE;
double   lastSupplyHigh = EMPTY_VALUE;
long     lastTradedDemandKey = LONG_MIN;
long     lastTradedSupplyKey = LONG_MIN;
int      statBars = 0;
int      statRawBuySignals = 0;
int      statRawSellSignals = 0;
int      statBlockedByTrendBuy = 0;
int      statBlockedByTrendSell = 0;
int      statBlockedByFirstTouchBuy = 0;
int      statBlockedByFirstTouchSell = 0;
int      statBlockedByPosition = 0;
int      statBuyOrders = 0;
int      statSellOrders = 0;
int      statReversals = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   indicatorHandle = iCustom(_Symbol, _Period, InpIndicatorName,
                             InpZoneSizePoints,
                             InpExtendBars,
                             InpMergeDistancePoints,
                             InpDedupeNearbyZones,
                             InpMergeOverlappingZones,
                             InpLimit);
   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("Indikator handle olusturulamadi: ", InpIndicatorName);
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagic);

   if(InpUseTrendFilter)
   {
      maHandle = iMA(_Symbol, _Period, InpMAPeriod, 0, InpMAMethod, InpMAPrice);
      if(maHandle == INVALID_HANDLE)
      {
         Print("MA handle olusturulamadi.");
         return INIT_FAILED;
      }
   }

   if(InpPrintDebugStats)
   {
      Print("TEST START [", InpTestTag, "] Symbol=", _Symbol, " TF=", EnumToString(_Period),
            " TrendFilter=", (InpUseTrendFilter ? "ON" : "OFF"),
            " FirstTouch=", (InpOnlyFirstTouch ? "ON" : "OFF"),
            " RR=", (InpUseRiskReward ? "ON" : "OFF"),
            " RRValue=", DoubleToString(InpRiskReward, 2),
            " SLPoints=", InpSLPoints,
            " TPPoints=", InpTPPoints);
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpPrintDebugStats)
      PrintStats();

   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);

   if(maHandle != INVALID_HANDLE)
      IndicatorRelease(maHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar())
      return;

   statBars++;

   double demandLow = EMPTY_VALUE;
   double supplyHigh = EMPTY_VALUE;

   if(!ReadLatestZones(demandLow, supplyHigh))
      return;

   lastDemandLow = demandLow;
   lastSupplyHigh = supplyHigh;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   const bool inDemand = (demandLow != EMPTY_VALUE &&
                          ask >= demandLow &&
                          ask <= demandLow + InpZoneSizePoints * _Point);

   const bool inSupply = (supplyHigh != EMPTY_VALUE &&
                          bid <= supplyHigh &&
                          bid >= supplyHigh - InpZoneSizePoints * _Point);

   if(inDemand && !inSupply)
      statRawBuySignals++;
   else if(inSupply && !inDemand)
      statRawSellSignals++;

   ManageEntries(inDemand, inSupply, ask, bid, demandLow, supplyHigh);
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t == 0)
      return false;

   if(t == lastBarTime)
      return false;

   lastBarTime = t;
   return true;
}

//+------------------------------------------------------------------+
bool ReadLatestZones(double &demandLow, double &supplyHigh)
{
   demandLow = EMPTY_VALUE;
   supplyHigh = EMPTY_VALUE;

   // shift=0 acik bar oldugu icin backtest tarafinda look-ahead riskini azaltmak adina
   // kapanmis barlardan (>=1) veri okunur.
   for(int shift = 1; shift <= InpLookbackBars; shift++)
   {
      double demandArr[1];
      if(CopyBuffer(indicatorHandle, 0, shift, 1, demandArr) == 1)
      {
         if(demandArr[0] != EMPTY_VALUE)
         {
            demandLow = demandArr[0];
            break;
         }
      }
   }

   for(int shift = 1; shift <= InpLookbackBars; shift++)
   {
      double supplyArr[1];
      if(CopyBuffer(indicatorHandle, 1, shift, 1, supplyArr) == 1)
      {
         if(supplyArr[0] != EMPTY_VALUE)
         {
            supplyHigh = supplyArr[0];
            break;
         }
      }
   }

   return (demandLow != EMPTY_VALUE || supplyHigh != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
void ManageEntries(const bool inDemand, const bool inSupply, const double ask, const double bid, const double demandLow, const double supplyHigh)
{
   bool allowBuy = inDemand && !inSupply;
   bool allowSell = inSupply && !inDemand;

   if(allowBuy && !TrendAllows(true))
   {
      statBlockedByTrendBuy++;
      allowBuy = false;
   }
   if(allowSell && !TrendAllows(false))
   {
      statBlockedByTrendSell++;
      allowSell = false;
   }

   if(InpOnlyFirstTouch)
   {
      if(allowBuy && ZoneKey(demandLow) == lastTradedDemandKey)
      {
         statBlockedByFirstTouchBuy++;
         allowBuy = false;
      }
      if(allowSell && ZoneKey(supplyHigh) == lastTradedSupplyKey)
      {
         statBlockedByFirstTouchSell++;
         allowSell = false;
      }
   }

   if(InpOnePositionOnly && HasOpenPosition())
   {
      if(!InpReverseOnOppositeZone)
      {
         if(allowBuy || allowSell)
            statBlockedByPosition++;
         return;
      }

      ENUM_POSITION_TYPE posType = CurrentPositionType();
      if(posType == POSITION_TYPE_BUY && allowSell)
      {
         if(CloseCurrentPosition())
         {
            if(OpenSell(bid))
            {
               lastTradedSupplyKey = ZoneKey(supplyHigh);
               statReversals++;
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL && allowBuy)
      {
         if(CloseCurrentPosition())
         {
            if(OpenBuy(ask))
            {
               lastTradedDemandKey = ZoneKey(demandLow);
               statReversals++;
            }
         }
      }
      return;
   }

   if(allowBuy)
   {
      if(OpenBuy(ask))
      {
         lastTradedDemandKey = ZoneKey(demandLow);
         statBuyOrders++;
      }
   }
   else if(allowSell)
   {
      if(OpenSell(bid))
      {
         lastTradedSupplyKey = ZoneKey(supplyHigh);
         statSellOrders++;
      }
   }
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
ENUM_POSITION_TYPE CurrentPositionType()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   }
   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
bool CloseCurrentPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      if(!trade.PositionClose(ticket))
      {
         Print("Pozisyon kapanis hatasi. Ticket=", ticket, " Err=", _LastError);
         return false;
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool OpenBuy(const double ask)
{
   double sl = 0.0;
   double tp = 0.0;
   const double slDistance = InpSLPoints * _Point;

   if(slDistance > 0.0)
      sl = ask - slDistance;

   if(InpUseRiskReward && slDistance > 0.0)
      tp = ask + (slDistance * InpRiskReward);
   else if(InpTPPoints > 0)
      tp = ask + InpTPPoints * _Point;

   if(!trade.Buy(InpLot, _Symbol, 0.0, sl, tp, "SD buy zone touch"))
   {
      Print("Buy hatasi: ", _LastError);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool OpenSell(const double bid)
{
   double sl = 0.0;
   double tp = 0.0;
   const double slDistance = InpSLPoints * _Point;

   if(slDistance > 0.0)
      sl = bid + slDistance;

   if(InpUseRiskReward && slDistance > 0.0)
      tp = bid - (slDistance * InpRiskReward);
   else if(InpTPPoints > 0)
      tp = bid - InpTPPoints * _Point;

   if(!trade.Sell(InpLot, _Symbol, 0.0, sl, tp, "SD sell zone touch"))
   {
      Print("Sell hatasi: ", _LastError);
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+

bool TrendAllows(const bool isBuy)
{
   if(!InpUseTrendFilter)
      return true;

   if(maHandle == INVALID_HANDLE)
      return false;

   double maArr[1];
   if(CopyBuffer(maHandle, 0, 1, 1, maArr) != 1)
      return false;

   double ma = maArr[0];
   double close1 = iClose(_Symbol, _Period, 1);

   if(ma == 0.0 || close1 == 0.0)
      return false;

   if(isBuy)
      return close1 > ma;

   return close1 < ma;
}

long ZoneKey(const double zonePrice)
{
   if(zonePrice == EMPTY_VALUE)
      return LONG_MIN;

   return (long)MathRound(zonePrice / _Point);
}

void PrintStats()
{
   Print("TEST END [", InpTestTag, "]",
         " Bars=", statBars,
         " RawBuy=", statRawBuySignals,
         " RawSell=", statRawSellSignals,
         " TrendBlockBuy=", statBlockedByTrendBuy,
         " TrendBlockSell=", statBlockedByTrendSell,
         " FirstTouchBlockBuy=", statBlockedByFirstTouchBuy,
         " FirstTouchBlockSell=", statBlockedByFirstTouchSell,
         " PositionBlocked=", statBlockedByPosition,
         " BuyOrders=", statBuyOrders,
         " SellOrders=", statSellOrders,
         " Reversals=", statReversals);
}
