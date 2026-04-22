bool IsBullishCandle()
{
   return iClose(_Symbol,_Period,0) > iOpen(_Symbol,_Period,0);
}

bool IsBearishCandle()
{
   return iClose(_Symbol,_Period,0) < iOpen(_Symbol,_Period,0);
}

bool IsInZone(double price, Zone &zone)
{
   return price >= zone.low && price <= zone.high;
}

bool CheckBuySignal(double price, Zone &zone)
{
   Print(zone.isDemand);
   if(!zone.isDemand || !zone.isFresh) return false;

   if(IsInZone(price, zone) && IsBullishCandle())
      return true;

   return false;
}

bool CheckSellSignal(double price, Zone &zone)
{
   if(zone.isDemand || !zone.isFresh) return false;

   if(IsInZone(price, zone) && IsBearishCandle())
      return true;

   return false;
}