#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#include <Trade/Trade.mqh>

#include <../Experts/Library/Candle.mqh>
#include <../Experts/Library/EngulfDbdSignal.mqh>

#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input bool DrawZones = true;                         // Engulf ve DBD zone çizimi
input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_H4; // Analiz yapılacak timeframe
input int MaxBaseCandles = 100;                      // Max hesaplanacak mum sayısı
input int MaxEngulfCount = 3;                        // Max değerlendirilecek Engulf mum sayısı
input int FormationLookbackPeriod = 50;              // DBD siniflandirma geriye bakis mum sayisi
input int FormationMinLookbackSamples = 10;          // DBD siniflandirma minimum ornek sayisi
input double FormationRangePercentile = 75.0;        // Impuls range percentile esigi
input double FormationBodyRatioPercentile = 60.0;    // Impuls govde orani percentile esigi
input double FormationBaseMaxBodyRatio = 0.5;        // DBD base max govde/range orani
input int FormationMaxBaseCandles = 4;               // DBD base max mum sayisi
input int ExtendZoneBars = 200;                      // Zone'un sağa doğru uzayacağı mum sayısı
input color DbdZoneColor = clrTomato;                // DBD zone rengi

input double InpLot = 0.10;                 // İşlem lotu
input int InpSLPoints = 500;                // Stop loss (point)
input int InpTPPoints = 1000;               // Take profit (point)
input long InpMagic = 20260616;             // Magic number
input bool InpOnePositionOnly = true;       // Aynı anda tek pozisyon
input bool InpTradeOnNewAnalysisBar = true; // Sadece yeni analiz mumunda işlem aç

const ENUM_TIMEFRAMES TimeframesToSearch[] = {PERIOD_H1, PERIOD_M30, PERIOD_M15};
const string ZoneObjectPrefix = "ENGULF_ZONE_";
const string EngulfArrowPrefix = "ENGULF_ARROW_";
const string EngulfArrowHtfScope = "HTF";
const string EngulfArrowLtfScope = "LTF";
const string DbdZoneObjectPrefix = "ENGULF_DBD_BASE_";

CTrade g_trade;

EngulfInfo HtfEngulfInfoList[];
EngulfInfo LtfEngulfInfoList[];
DbdSignal g_lastDbdSignal;

datetime g_lastBarTime;

int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagic);
    g_lastDbdSignal = EmptyDbdSignal();

    ArraySetAsSeries(HtfEngulfInfoList, true);

    ScanEngulfsInTimeframeRange(_Symbol, AnalysisTimeframe, MaxBaseCandles, 1, MaxBaseCandles, HtfEngulfInfoList,
                                MaxEngulfCount, true);

    if (DrawZones)
        FindAndDrawEngulfZones();
    else
        ClearEngulfZoneObjects();

    datetime bar_time_start = iTime(_Symbol, PERIOD_M15, 0);
    datetime bar_time_end = HtfEngulfInfoList[0].barTime;
    int candleCount = CountCandlesInRange(_Symbol, PERIOD_M15, bar_time_start, bar_time_end);
    ScanEngulfsInTimeframeRange(_Symbol, PERIOD_M15, candleCount, 1, candleCount, LtfEngulfInfoList,
                                100, false);

    RemoveOutZoneLtfEngulfs();

    int size = ArraySize(LtfEngulfInfoList);
    for (int i = 0; i < size; i++) {
        DrawEngulfArrow(LtfEngulfInfoList[i], EngulfArrowLtfScope, i);
    }

    ChartRedraw(ChartID());

    Print("Engulf EA initialized on ", EnumToString(AnalysisTimeframe));

    g_lastBarTime = iTime(_Symbol, AnalysisTimeframe, 1);

    return INIT_SUCCEEDED;
}

void RemoveOutZoneLtfEngulfs() {
    double zoneHigh = HtfEngulfInfoList[0].dbdSignal.baseHigh;
    double zoneLow = HtfEngulfInfoList[0].dbdSignal.baseLow;

    EngulfInfo engulfs[];
    int size = ArraySize(LtfEngulfInfoList);
    for (int i = 0; i < size; i++) {
        if (LtfEngulfInfoList[i].zoneLow < zoneHigh && LtfEngulfInfoList[i].zoneHigh > zoneLow)
            AppendEngulfIntoList(engulfs, LtfEngulfInfoList[i], 100);
    }

    ArrayResize(LtfEngulfInfoList, ArraySize(engulfs));
    ArrayCopy(LtfEngulfInfoList, engulfs);
}

void OnDeinit(const int reason) {
    ClearEngulfZoneObjects();
    g_lastDbdSignal = EmptyDbdSignal();
}

void OnTick() {
    DbdSignal signal = HtfEngulfInfoList[0].dbdSignal;

    FormationSettings formationSettings = MakeFormationSettings(
        FormationLookbackPeriod,
        FormationMinLookbackSamples,
        FormationRangePercentile,
        FormationBodyRatioPercentile,
        FormationBaseMaxBodyRatio,
        FormationMaxBaseCandles);

    // bool hasDbd = ResolveFirstDbdFromInnerTimeframes(_Symbol, AnalysisTimeframe, TimeframesToSearch, formationSettings,
    //                                                  HtfEngulfInfoList, signal);

    // if (hasDbd && signal.valid)
    //     g_lastDbdSignal = signal;

    if (InpTradeOnNewAnalysisBar && !IsNewAnalysisBar())
        return;

    // if (!hasDbd || !signal.valid)
    //     return;

    if (InpOnePositionOnly && HasOpenPosition())
        return;

    // if (signal.engulfBarTime == g_lastTradedEngulfTime)
    //     return;

    if (!OpenSell(signal))
        return;

    // g_lastTradedEngulfTime = signal.engulfBarTime;
}

// void InitEngulfList() {
//     int maxCalculateCandles;
//     if (ArraySize(HtfEngulfInfoList) > 0)
//         maxCalculateCandles = MaxBaseCandles;
//     else
//         maxCalculateCandles = 2;

//     ScanHtfEngulfsRange(_Symbol, AnalysisTimeframe, MaxBaseCandles, 1, 2, g_engulfList, MaxEngulfCount, false);
// }

bool IsNewAnalysisBar() {
    datetime currentBarTime = iTime(_Symbol, AnalysisTimeframe, 1);
    if (currentBarTime == 0)
        return false;

    if (currentBarTime == g_lastBarTime)
        return false;

    g_lastBarTime = currentBarTime;
    return true;
}

bool HasOpenPosition() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0)
            continue;
        if (PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
        if (PositionGetInteger(POSITION_MAGIC) != InpMagic)
            continue;
        return true;
    }
    return false;
}

bool OpenSell(const DbdSignal& signal) {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if (bid <= 0)
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    double sl = NormalizeDouble(bid + InpSLPoints * point, digits);
    double tp = NormalizeDouble(bid - InpTPPoints * point, digits);

    // if (signal.engulfZoneHigh > bid)
    //     sl = NormalizeDouble(signal.engulfZoneHigh + 10 * point, digits);

    return g_trade.Sell(InpLot, _Symbol, 0, sl, tp, "EngulfDbdEA");
}

void FindAndDrawEngulfZones() {
    FormationSettings formationSettings = MakeFormationSettings(
        FormationLookbackPeriod,
        FormationMinLookbackSamples,
        FormationRangePercentile,
        FormationBodyRatioPercentile,
        FormationBaseMaxBodyRatio,
        FormationMaxBaseCandles);

    for (int i = 0; i < ArraySize(HtfEngulfInfoList); i++) {
        DbdSignal dbdSignal;
        if (!ResolveDbdZone(_Symbol, HtfEngulfInfoList[i], AnalysisTimeframe, TimeframesToSearch, formationSettings,
                            dbdSignal))
            continue;

        HtfEngulfInfoList[i].dbdSignal = dbdSignal;
        DrawEngulfArrow(HtfEngulfInfoList[i], EngulfArrowHtfScope, i);
        DrawEngulfZone(HtfEngulfInfoList[i]);
        DrawDbdBaseZone(HtfEngulfInfoList[i].barTime, HtfEngulfInfoList[i].dbdSignal);
    }
}

string BuildEngulfArrowName(const string scope, const int index, const datetime barTime) {
    return scope + "_" + EngulfArrowPrefix + "_" + IntegerToString(index) + "_" + IntegerToString((long)barTime);
}

bool DrawEngulfArrow(const EngulfInfo& engulf, const string scope, const int index) {
    if (!engulf.found || engulf.barTime <= 0)
        return false;

    long chart_id = ChartID();
    string name = BuildEngulfArrowName(scope, index, engulf.barTime);
    double zoneHeight = engulf.zoneHigh - engulf.zoneLow;
    if (zoneHeight <= 0.0)
        return false;

    double price = engulf.zoneLow - zoneHeight * 0.10;

    if (ObjectFind(chart_id, name) >= 0)
        ObjectDelete(chart_id, name);

    ResetLastError();
    if (!ObjectCreate(chart_id, name, OBJ_ARROW, 0, engulf.barTime, price)) {
        Print("DrawEngulfArrow failed scope=", scope,
              " index=", index,
              " name=", name,
              " barTime=", TimeToString(engulf.barTime),
              " price=", DoubleToString(price, _Digits),
              " err=", GetLastError());
        return false;
    }

    ObjectSetInteger(chart_id, name, OBJPROP_ARROWCODE, 233);
    ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clrLime);
    ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, false);
    return true;
}

void DrawEngulfZone(const EngulfInfo& engulf) {
    long chart_id = ChartID();
    string zoneName = ZoneObjectPrefix + IntegerToString(engulf.barTime);
    datetime t1 = engulf.barTime;
    datetime t2 = engulf.barTime + (datetime)(PeriodSeconds(AnalysisTimeframe) * ExtendZoneBars);

    if (ObjectFind(chart_id, zoneName) >= 0)
        ObjectDelete(chart_id, zoneName);

    if (ObjectCreate(chart_id, zoneName, OBJ_RECTANGLE, 0, t1, engulf.zoneHigh, t2, engulf.zoneLow)) {
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

void ClearEngulfZoneObjects() {
    long chart_id = ChartID();

    while (ObjectsDeleteAll(chart_id, ZoneObjectPrefix, 0, OBJ_RECTANGLE) > 0) {
    }

    while (ObjectsDeleteAll(chart_id, EngulfArrowHtfScope + "_" + EngulfArrowPrefix, 0, OBJ_ARROW) > 0) {
    }

    while (ObjectsDeleteAll(chart_id, EngulfArrowLtfScope + "_" + EngulfArrowPrefix, 0, OBJ_ARROW) > 0) {
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