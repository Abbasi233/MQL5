//+------------------------------------------------------------------+
//|                                                       engulf.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>

#include <EngulfDbdSignal.mqh>

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
input int MaxBaseCandles = 100;                      // Max hesaplanacak bar sayısı
input int ExtendZoneBars = 200;                      // Zone'un sağa doğru uzayacağı bar sayısı
input int MaxEngulfCount = 3;                        // Max bulunacak Engulf mum sayısı
input int FormationLookbackPeriod = 50;              // DBD siniflandirma geriye bakis mum sayisi
input int FormationMinLookbackSamples = 10;          // DBD siniflandirma minimum ornek sayisi
input double FormationRangePercentile = 75.0;        // Impuls range percentile esigi
input double FormationBodyRatioPercentile = 60.0;    // Impuls govde orani percentile esigi
input int FormationMaxBaseCandles = 4;               // DBD base max mum sayisi
input color DbdZoneColor = clrTomato;                // DBD zone rengi

const ENUM_TIMEFRAMES TimeframesToSearch[] = {PERIOD_H1, PERIOD_M30, PERIOD_M15};
const string ZoneObjectPrefix = "ENGULF_ZONE_";
const string DbdZoneObjectPrefix = "ENGULF_DBD_BASE_";

double EngulfBuffer[];
EngulfInfo EngulfInfoList[];
DbdSignal g_lastDbdSignal;

int OnInit() {
    SetIndexBuffer(0, EngulfBuffer, INDICATOR_DATA);

    PlotIndexSetInteger(0, PLOT_ARROW, 233);

    // Varsayilan bos deger 0 oldugu icin buffer'daki EMPTY_VALUE ok cizilmesin diye tanimlanir
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    ArraySetAsSeries(EngulfBuffer, false);
    ArraySetAsSeries(EngulfInfoList, false);

    g_lastDbdSignal = EmptyDbdSignal();

    IndicatorSetString(INDICATOR_SHORTNAME,
                       "Engulf(" + EnumToString(AnalysisTimeframe) + ")");

    Print("Engulf indicator initialized on ", EnumToString(AnalysisTimeframe));

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    ClearZoneObjects();
    g_lastDbdSignal = EmptyDbdSignal();
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

    double htf_open[];
    double htf_high[];
    double htf_low[];
    double htf_close[];
    datetime htf_time[];
    int htf_count = MaxBaseCandles + 2;

    if (!CopyHtfRates(_Symbol, AnalysisTimeframe, htf_count, htf_open, htf_high, htf_low, htf_close, htf_time))
        return prev_calculated;

    if (prev_calculated == 0) {
        ArrayInitialize(EngulfBuffer, EMPTY_VALUE);
        ClearZoneObjects();
        g_lastDbdSignal = EmptyDbdSignal();
    }

    int htf_end = htf_count - 2;
    if (prev_calculated > 0)
        htf_end = MathMin(2, htf_end);

    for (int i = 1; i <= htf_end; i++) {
        EngulfInfo engulf = FindAndDrawEngulfZone(i, rates_total, htf_open, htf_high, htf_low, htf_close, htf_time);

        if (engulf.found)
            AppendEngulf(EngulfInfoList, engulf);

        if (MaxEngulfCount == ArraySize(EngulfInfoList))
            break;
    }

    FormationSettings formationSettings = MakeFormationSettings(
        FormationLookbackPeriod,
        FormationMinLookbackSamples,
        FormationRangePercentile,
        FormationBodyRatioPercentile,
        FormationMaxBaseCandles);

    for (int i = 0; i < ArraySize(EngulfInfoList); i++) {
        DbdSignal dbdSignal;
        if (!ResolveDbdZone(_Symbol, EngulfInfoList[i], AnalysisTimeframe, TimeframesToSearch, formationSettings,
                            dbdSignal))
            continue;

        DrawDbdBaseZone(EngulfInfoList[i].barTime, dbdSignal);
    }

    // DbdSignal signal;
    // if (FindLatestDbdSignal(_Symbol, AnalysisTimeframe, MaxBaseCandles, TimeframesToSearch, signal))
    //     g_lastDbdSignal = signal;

    return rates_total;
}

EngulfInfo FindAndDrawEngulfZone(const int i,
                                 const int rates_total,
                                 const double& htf_open[],
                                 const double& htf_high[],
                                 const double& htf_low[],
                                 const double& htf_close[],
                                 const datetime& htf_time[]) {
    int chart_idx = HtfBarToChartIndex(htf_time[i], rates_total);
    if (chart_idx < 0)
        return EmptyHtfEngulfInfo();

    EngulfBuffer[chart_idx] = EMPTY_VALUE;

    string zoneName = EngulfZoneNameFromTime(htf_time[i]);
    EngulfInfo engulf = DetectBearishEngulfAt(i, htf_open, htf_high, htf_low, htf_close, htf_time);

    if (!engulf.found) {
        ObjectDelete(ChartID(), zoneName);
        return EmptyHtfEngulfInfo();
    }

    double markerOffset = (htf_high[i] - htf_low[i]) * 0.10;
    EngulfBuffer[chart_idx] = htf_low[i] - markerOffset;
    DrawEngulfZone(engulf.barTime, engulf.zoneHigh, engulf.zoneLow);

    return engulf;
}

int HtfBarToChartIndex(const datetime bar_time, const int rates_total) {
    int shift = iBarShift(_Symbol, Period(), bar_time, false);
    if (shift < 0 || shift >= rates_total)
        return -1;

    return rates_total - 1 - shift;
}

void DrawEngulfZone(const datetime bar_time, const double zone_high, const double zone_low) {
    long chart_id = ChartID();
    string zoneName = EngulfZoneNameFromTime(bar_time);
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

void DrawDbdBaseZone(const datetime engulf_bar_time, const DbdSignal& signal) {
    if (signal.baseStartTime == 0 || signal.baseEndTime == 0)
        return;

    if (signal.baseHigh <= signal.baseLow)
        return;

    long chart_id = ChartID();
    string zoneName = DbdZoneObjectPrefix + IntegerToString((long)engulf_bar_time);

    if (ObjectFind(chart_id, zoneName) >= 0)
        ObjectDelete(chart_id, zoneName);

    datetime t1 = signal.baseStartTime;
    datetime t2 = signal.baseStartTime + (datetime)(PeriodSeconds(AnalysisTimeframe) * ExtendZoneBars);

    if (ObjectCreate(chart_id, zoneName, OBJ_RECTANGLE, 0, t1, signal.baseHigh, t2, signal.baseLow)) {
        ObjectSetInteger(chart_id, zoneName, OBJPROP_COLOR, DbdZoneColor);
        ObjectSetInteger(chart_id, zoneName, OBJPROP_FILL, true);
        ObjectSetInteger(chart_id, zoneName, OBJPROP_BACK, true);
        ObjectSetInteger(chart_id, zoneName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }
}

string EngulfZoneNameFromTime(const datetime bar_time) {
    return ZoneObjectPrefix + IntegerToString((long)bar_time);
}

void ClearZoneObjects() {
    long chart_id = ChartID();

    while (ObjectsDeleteAll(chart_id, ZoneObjectPrefix, 0, OBJ_RECTANGLE) > 0) {
    }

    while (ObjectsDeleteAll(chart_id, DbdZoneObjectPrefix, 0, OBJ_RECTANGLE) > 0) {
    }

    int total = ObjectsTotal(chart_id, 0, OBJ_RECTANGLE);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(chart_id, i, 0, OBJ_RECTANGLE);
        if (StringFind(name, ZoneObjectPrefix) == 0 || StringFind(name, DbdZoneObjectPrefix) == 0)
            ObjectDelete(chart_id, name);
    }

    ChartRedraw(chart_id);
}