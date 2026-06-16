//+------------------------------------------------------------------+
//|                                                       engulf.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window

#property indicator_buffers 1
#property indicator_plots 1

#property indicator_label1 "Engulf"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrLime
#property indicator_width1 1

input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_H4; // Analiz yapılacak timeframe
input int MaxBaseCandles = 1000;                     // Max hesaplanacak bar sayısı
input bool UseCandleBodyForZone = true;              // Zone'u gövde bazlı çiz
input int ExtendZoneBars = 200;                      // Zone'un sağa doğru uzayacağı bar sayısı

const string ZoneObjectPrefix = "ENGULF_ZONE_";
double EngulfBuffer[];

enum CandleType {
    NEUTRAL = 0,
    BEARISH = 1,
    BULLISH = 2
};

int OnInit() {
    SetIndexBuffer(0, EngulfBuffer, INDICATOR_DATA);

    PlotIndexSetInteger(0, PLOT_ARROW, 233);

    // Varsayilan bos deger 0 oldugu icin buffer'daki EMPTY_VALUE ok cizilmesin diye tanimlanir
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    ArraySetAsSeries(EngulfBuffer, false);

    IndicatorSetString(INDICATOR_SHORTNAME,
                       "Engulf(" + EnumToString(AnalysisTimeframe) + ")");

    Print("Engulf indicator initialized on ", EnumToString(AnalysisTimeframe));

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    ClearZoneObjects();
}

bool CopyAnalysisRates(const int count,
                       double& htf_open[],
                       double& htf_high[],
                       double& htf_low[],
                       double& htf_close[],
                       datetime& htf_time[]) {
    ArraySetAsSeries(htf_open, true);
    ArraySetAsSeries(htf_high, true);
    ArraySetAsSeries(htf_low, true);
    ArraySetAsSeries(htf_close, true);
    ArraySetAsSeries(htf_time, true);

    if (CopyOpen(_Symbol, AnalysisTimeframe, 0, count, htf_open) < count)
        return false;
    if (CopyHigh(_Symbol, AnalysisTimeframe, 0, count, htf_high) < count)
        return false;
    if (CopyLow(_Symbol, AnalysisTimeframe, 0, count, htf_low) < count)
        return false;
    if (CopyClose(_Symbol, AnalysisTimeframe, 0, count, htf_close) < count)
        return false;
    if (CopyTime(_Symbol, AnalysisTimeframe, 0, count, htf_time) < count)
        return false;

    return true;
}

int HtfBarToChartIndex(const datetime bar_time, const int rates_total) {
    int shift = iBarShift(_Symbol, Period(), bar_time, false);
    if (shift < 0 || shift >= rates_total)
        return -1;

    return rates_total - 1 - shift;
}

string ZoneNameFromTime(const datetime bar_time) {
    return ZoneObjectPrefix + IntegerToString((long)bar_time);
}

bool ProcessHtfBar(const int i,
                   const int rates_total,
                   const double& htf_open[],
                   const double& htf_high[],
                   const double& htf_low[],
                   const double& htf_close[],
                   const datetime& htf_time[]) {
    int chart_idx = HtfBarToChartIndex(htf_time[i], rates_total);
    if (chart_idx < 0)
        return false;

    EngulfBuffer[chart_idx] = EMPTY_VALUE;

    string zoneName = ZoneNameFromTime(htf_time[i]);

    CandleType currentType = BearOrBull(htf_open[i], htf_close[i]);
    CandleType previousType = BearOrBull(htf_open[i + 1], htf_close[i + 1]);
    if (currentType == BULLISH) {
        ObjectDelete(ChartID(), zoneName);
        return false;
    }

    if (previousType == BEARISH) {
        ObjectDelete(ChartID(), zoneName);
        return false;
    }

    double currentHigh = htf_high[i];
    double currentOpen = htf_open[i];
    double currentClose = htf_close[i];

    double previousHigh = htf_high[i + 1];
    double previousClose = htf_close[i + 1];
    double previousLow = htf_low[i + 1];

    if (currentOpen >= previousClose && currentClose < previousLow && currentHigh > previousHigh) {
        double markerOffset = (htf_high[i] - htf_low[i]) * 0.20;
        EngulfBuffer[chart_idx] = htf_low[i] - markerOffset;

        double zoneHigh = UseCandleBodyForZone ? MathMax(htf_open[i], htf_close[i]) : htf_high[i];
        double zoneLow = UseCandleBodyForZone ? MathMin(htf_open[i], htf_close[i]) : htf_low[i];
        BuildZone(htf_time[i], zoneHigh, zoneLow);

        return true;
    }

    ObjectDelete(ChartID(), zoneName);

    return false;
}

int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int32_t& spread[]) {
    int htf_count = MaxBaseCandles + 2;

    double htf_open[];
    double htf_high[];
    double htf_low[];
    double htf_close[];
    datetime htf_time[];

    if (!CopyAnalysisRates(htf_count, htf_open, htf_high, htf_low, htf_close, htf_time))
        return prev_calculated;

    if (prev_calculated == 0) {
        ArrayInitialize(EngulfBuffer, EMPTY_VALUE);
        ClearZoneObjects();
    }

    int htf_start = 1;
    int htf_end = htf_count - 2;

    if (prev_calculated > 0) {
        htf_end = MathMin(2, htf_end);
    }

    for (int i = htf_start; i <= htf_end; i++)
        ProcessHtfBar(i, rates_total, htf_open, htf_high, htf_low, htf_close, htf_time);

    return rates_total;
}

void ClearZoneObjects() {
    long chart_id = ChartID();

    while (ObjectsDeleteAll(chart_id, ZoneObjectPrefix, 0, OBJ_RECTANGLE) > 0) {}

    int total = ObjectsTotal(chart_id, 0, OBJ_RECTANGLE);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(chart_id, i, 0, OBJ_RECTANGLE);
        if (StringFind(name, ZoneObjectPrefix) == 0)
            ObjectDelete(chart_id, name);
    }

    ChartRedraw(chart_id);
}

CandleType BearOrBull(const double open, const double close) {
    if (close > open)
        return BULLISH;

    return BEARISH;
}

void BuildZone(const datetime bar_time, const double zone_high, const double zone_low) {
    long chart_id = ChartID();
    string zoneName = ZoneNameFromTime(bar_time);
    datetime t1 = bar_time;
    datetime t2 = bar_time + (datetime)(PeriodSeconds(AnalysisTimeframe) * ExtendZoneBars);

    if (ObjectFind(chart_id, zoneName) >= 0)
        ObjectDelete(chart_id, zoneName);

    if (ObjectCreate(chart_id, zoneName, OBJ_RECTANGLE, 0, t1, zone_high, t2, zone_low)) {
        ObjectSetInteger(chart_id, zoneName, OBJPROP_COLOR, clrSilver);
        ObjectSetInteger(chart_id, zoneName, OBJPROP_FILL, true);
        ObjectSetInteger(chart_id, zoneName, OBJPROP_BACK, true);
        ObjectSetInteger(chart_id, zoneName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }
}
