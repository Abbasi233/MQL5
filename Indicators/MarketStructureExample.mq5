//+------------------------------------------------------------------+
//|                                       MarketStructureExample.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#include <Library/EventBus.mqh>
#include <Library/Swing/SwingEngine.mqh>
#include <Library/MarketStructure/MarketStructureEngine.mqh>
#include <Library/MarketStructure/MarketStructureListener.mqh>
#include "MarketStructurePanel.mqh"

#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int MaxLookbackBars = 150;

EventBus eventBus = EventBus();
SwingEngine swingEngine = SwingEngine();
MarketStructureEngine marketStructureEngine = MarketStructureEngine(eventBus);
MarketStructurePanel panel;
BosPrintListener bosListener = BosPrintListener();

int OnInit() {
    eventBus.Subscribe(bosListener);
    panel.SetEventBus(eventBus);
    swingEngine.ApplyVisualInputs();
    swingEngine.ClearSwingLines(ChartID());

    if (!panel.Create(0, "Market Structure", 0))
        return (INIT_FAILED);
    if (!panel.Run())
        return (INIT_FAILED);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    panel.Destroy(reason);
    swingEngine.ClearSwingLines(ChartID());
    LiveLogClose();
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
    panel.ChartEvent(id, lparam, dparam, sparam);
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

    marketStructureEngine.SetSwingList(swingResult.swingList);

    const int candleCount = ArraySize(candles);
    if (candleCount > 0)
        marketStructureEngine.EvaluateBreak(candles[candleCount - 1]);

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
