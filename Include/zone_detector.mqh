struct Zone
{
   double high;
   double low;
   datetime created_at;
   bool isDemand;
   bool isFresh;
};

bool IsImpulseCandle(int i)
{
   double body = MathAbs(iClose(_Symbol,_Period,i) - iOpen(_Symbol,_Period,i));
   double avg = 0;

   for(int j=1; j<=5; j++)
      avg += MathAbs(iClose(_Symbol,_Period,i+j) - iOpen(_Symbol,_Period,i+j));

   avg /= 5;

   return body > avg * 1.5;
}

bool DetectDemandZone(Zone &zone)
{
   for(int i=5; i<50; i++)
   {
      if(IsImpulseCandle(i))
      {
         double baseLow  = iLow(_Symbol,_Period,i+1);
         double baseHigh = iHigh(_Symbol,_Period,i+1);

         zone.low  = baseLow;
         zone.high = baseHigh;
         zone.created_at = TimeCurrent();
         zone.isDemand = true;
         zone.isFresh = true;

         return true;
      }
   }
   return false;
}

bool DetectSupplyZone(Zone &zone)
{
   for(int i=5; i<50; i++)
   {
      if(IsImpulseCandle(i))
      {
         double baseLow  = iLow(_Symbol,_Period,i+1);
         double baseHigh = iHigh(_Symbol,_Period,i+1);

         zone.low  = baseLow;
         zone.high = baseHigh;
         zone.created_at = TimeCurrent();
         zone.isDemand = false;
         zone.isFresh = true;

         return true;
      }
   }
   return false;
}