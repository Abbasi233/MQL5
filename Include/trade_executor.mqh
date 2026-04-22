#include <Trade/Trade.mqh>
CTrade trade;

void OpenBuy(Zone &zone)
{
   double sl = zone.low - 10 * _Point;
   double tp = zone.high + (zone.high - zone.low) * 2;

   trade.Buy(0.01, _Symbol, 0, sl, tp);
}

void OpenSell(Zone &zone)
{
   double sl = zone.high + 10 * _Point;
   double tp = zone.low - (zone.high - zone.low) * 2;

   trade.Sell(0.01, _Symbol, 0, sl, tp);
}