//+------------------------------------------------------------------+
//|                                                 StructEngine.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#include <Library/Swing/SwingEngine.mqh>

#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int MaxLookbackBars = 125;

SwingEngine swingEngine = SwingEngine();
datetime lastCandleTime = 0;

int OnInit() {
    swingEngine.ApplyVisualInputs();
    swingEngine.ClearSwingLines(ChartID());
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    swingEngine.ClearSwingLines(ChartID());
    LiveLogClose();
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    if (rates_total < 2)
        return 0;

    if (lastCandleTime == time[rates_total - 1])
        return prev_calculated;

    lastCandleTime = time[rates_total - 1];

    Candle candles[];
    if (!BuildCandles(rates_total, MaxLookbackBars, time, open, high, low, close, candles))
        return prev_calculated;

    if (!swingEngine.IsInitialized()) {
        swingEngine.Initialize(candles);
        swingEngine.DrawSwingLines(ChartID());
    } 
    // else {
    //     swingEngine.Update(candles);
    //     swingEngine.DrawLastSwingLine(ChartID());
    // }

    return rates_total;
}
