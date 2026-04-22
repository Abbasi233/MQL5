//+------------------------------------------------------------------+
//|                                                    MySupply2.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1 DRAW_LINE
#property indicator_color1 clrRed
#property indicator_width1 2

#property indicator_type2 DRAW_LINE
#property indicator_color2 clrCyan
#property indicator_width2 3

double CloseBuffer[];
double HighBuffer[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
   {
    SetIndexBuffer(0, CloseBuffer);
    SetIndexBuffer(1, HighBuffer);
    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[])
   {
    int start = prev_calculated > 0 ? prev_calculated - 1 : 0;

    for(int i = start; i < rates_total; i++)
       {
        CloseBuffer[i] = close[i];
        HighBuffer[i] = high[i];
       }

    return(rates_total);
   }
//+------------------------------------------------------------------+
