//+------------------------------------------------------------------+
//|                                       MarketStructureExample.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#include <Library/Swing/SwingEngine.mqh>
#include <Library/MarketStructure/MarketStructureEngine.mqh>

#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int MaxLookbackBars = 55;

SwingEngine swingEngine = SwingEngine();
MarketStructureEngine marketStructureEngine = MarketStructureEngine();

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

    Candle candles[];
    if (!BuildCandles(rates_total, time, open, high, low, close, candles))
        return prev_calculated;

    SwingResult swingResult = swingEngine.Solve(candles);
    swingEngine.DrawSwingLines(ChartID());

    marketStructureEngine = MarketStructureEngine(swingResult.swingList);

    Candle lastTopCandle = marketStructureEngine.GetLastTop();
    Candle lastDeepCandle = marketStructureEngine.GetLastDeep();
    double testClose = lastTopCandle.close;

    if (prev_calculated == 0 || rates_total > prev_calculated) {
        if (lastTopCandle.time == 0)
            Print("LastTop: bulunamadi");
        else
            PrintFormat("LastTop: time=%s high=%.5f close=%.5f",
                        TimeToString(lastTopCandle.time),
                        lastTopCandle.high,
                        lastTopCandle.close);

        PrintFormat("Test Close: %.5f", lastTopCandle.close);

        if (lastDeepCandle.time == 0)
            Print("LastDeep: bulunamadi");
        else
            PrintFormat("LastDeep: time=%s low=%.5f close=%.5f",
                        TimeToString(lastDeepCandle.time),
                        lastDeepCandle.low,
                        lastDeepCandle.close);
    }

    return (rates_total);
}

bool BuildCandles(const int rates_total,
                  const datetime& time[],
                  const double& open[],
                  const double& high[],
                  const double& low[],
                  const double& close[],
                  Candle& candles[]) {
    int lookbackStart = rates_total - MaxLookbackBars;
    if (lookbackStart < 0)
        lookbackStart = 0;

    ArrayResize(candles, 0);

    for (int i = lookbackStart; i < rates_total; i++) {
        Candle candle = Candle(time[i], open[i], high[i], low[i], close[i]);
        candle.AddCandleList(candles);
    }

    return ArraySize(candles) > 1;
}
