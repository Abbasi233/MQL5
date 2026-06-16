//+------------------------------------------------------------------+
//|                                        2_FormationDetection.mq5   |
//+------------------------------------------------------------------+
#property copyright "Checklist Indicator 2"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "RBR"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime

#property indicator_label2  "DBR"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen

#property indicator_label3  "DBD"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrTomato

#property indicator_label4  "RBD"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed

input int    AvgRangePeriod    = 14;
input double ImpulseMultiplier = 1.20;
input double MinBodyRatio      = 0.60;
input int    MaxBaseCandles    = 4;
input int    MaxLookbackBars   = 1000;

double RBRBuffer[];
double DBRBuffer[];
double DBDBuffer[];
double RBDBuffer[];

enum CandleType
{
   CANDLE_BASE = 0,
   CANDLE_RALLY = 1,
   CANDLE_DROP = -1
};

double GetAverageRange(const int i, const int rates_total, const double &high[], const double &low[])
{
   int from = i;
   int to   = MathMin(rates_total - 1, i + AvgRangePeriod - 1);
   int count = to - from + 1;
   if(count <= 0)
      return 0.0;

   double sum = 0.0;
   for(int k = from; k <= to; k++)
      sum += (high[k] - low[k]);
   return sum / count;
}

CandleType ClassifyCandle(const int i, const int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
{
   double range = high[i] - low[i];
   if(range <= 0.0)
      return CANDLE_BASE;

   double body      = MathAbs(close[i] - open[i]);
   double bodyRatio = body / range;
   double avgRange  = GetAverageRange(i, rates_total, high, low);

   bool isImpulse = (range >= avgRange * ImpulseMultiplier && bodyRatio >= MinBodyRatio);
   if(isImpulse && close[i] > open[i])
      return CANDLE_RALLY;
   if(isImpulse && close[i] < open[i])
      return CANDLE_DROP;
   return CANDLE_BASE;
}

int OnInit()
{
   SetIndexBuffer(0, RBRBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DBRBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, DBDBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, RBDBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 241);
   PlotIndexSetInteger(1, PLOT_ARROW, 242);
   PlotIndexSetInteger(2, PLOT_ARROW, 243);
   PlotIndexSetInteger(3, PLOT_ARROW, 244);

   ArraySetAsSeries(RBRBuffer, true);
   ArraySetAsSeries(DBRBuffer, true);
   ArraySetAsSeries(DBDBuffer, true);
   ArraySetAsSeries(RBDBuffer, true);

   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < AvgRangePeriod + MaxBaseCandles + 4)
      return 0;

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 1;
   int maxBars = MathMin(rates_total, MaxLookbackBars);
   int oldestToProcess = rates_total - maxBars;
   if(start < oldestToProcess + 1)
      start = oldestToProcess + 1;

   for(int i = start; i < rates_total; i++)
   {
      RBRBuffer[i] = EMPTY_VALUE;
      DBRBuffer[i] = EMPTY_VALUE;
      DBDBuffer[i] = EMPTY_VALUE;
      RBDBuffer[i] = EMPTY_VALUE;
   }

   for(int i = start; i < rates_total - 2; i++)
   {
      CandleType left = ClassifyCandle(i, rates_total, open, high, low, close);
      if(left == CANDLE_BASE)
         continue;

      int baseStart = i + 1;
      int baseCount = 0;
      while(baseStart + baseCount < rates_total - 1 && baseCount < MaxBaseCandles)
      {
         if(ClassifyCandle(baseStart + baseCount, rates_total, open, high, low, close) != CANDLE_BASE)
            break;
         baseCount++;
      }

      if(baseCount <= 0 || baseStart + baseCount >= rates_total)
         continue;

      int rightIndex = baseStart + baseCount;
      CandleType right = ClassifyCandle(rightIndex, rates_total, open, high, low, close);
      if(right == CANDLE_BASE)
         continue;

      int markIndex = baseStart + baseCount - 1;
      if(left == CANDLE_RALLY && right == CANDLE_RALLY)
         RBRBuffer[markIndex] = low[markIndex] - (6 * _Point);
      else if(left == CANDLE_DROP && right == CANDLE_RALLY)
         DBRBuffer[markIndex] = low[markIndex] - (9 * _Point);
      else if(left == CANDLE_DROP && right == CANDLE_DROP)
         DBDBuffer[markIndex] = high[markIndex] + (6 * _Point);
      else if(left == CANDLE_RALLY && right == CANDLE_DROP)
         RBDBuffer[markIndex] = high[markIndex] + (9 * _Point);
   }

   return rates_total;
}
