//+------------------------------------------------------------------+
//|                                                        test2.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

datetime lastBarTime = 0;
int OnInit()
   {
    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
   {  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
   {
    datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 1);
    
    Print(lastBarTime);
    if (lastBarTime != currentBarTime) {
      MqlRates lastBar = GetLastClosedBar();
      lastBarTime = lastBar.time;
      OnNewBarClosed(lastBar);
    }
   }

void OnNewBarClosed(const MqlRates &newBar) {
   Print("New bar closed: ", newBar.close);
}

MqlRates GetLastClosedBar()
{
   MqlRates rates[];
   CopyRates(_Symbol, _Period, 1, 1, rates);
   return rates[0];
}