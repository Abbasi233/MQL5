#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#include <Trade/Trade.mqh>
#include <EngulfDbdSignal.mqh>

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
input int FormationMaxBaseCandles = 4;               // DBD base max mum sayisi
input int ExtendZoneBars = 200;                      // Zone'un sağa doğru uzayacağı mum sayısı
input color DbdZoneColor = clrTomato;                // DBD zone rengi

const ENUM_TIMEFRAMES TimeframesToSearch[] = {PERIOD_H1, PERIOD_M30, PERIOD_M15};
const string ZoneObjectPrefix = "ENGULF_ZONE_";
const string EngulfArrowPrefix = "ENGULF_ARROW_";
const string DbdZoneObjectPrefix = "ENGULF_DBD_BASE_";

input double InpLot = 0.10;                 // İşlem lotu
input int InpSLPoints = 500;                // Stop loss (point)
input int InpTPPoints = 1000;               // Take profit (point)
input long InpMagic = 20260616;             // Magic number
input bool InpOnePositionOnly = true;       // Aynı anda tek pozisyon
input bool InpTradeOnNewAnalysisBar = true; // Sadece yeni analiz mumunda işlem aç

CTrade g_trade;

EngulfInfo EngulfInfoList[];
DbdSignal g_lastDbdSignal;

int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagic);

    ArraySetAsSeries(EngulfInfoList, true);

    g_lastDbdSignal = EmptyDbdSignal();

    ScanHtfEngulfsRange(_Symbol, AnalysisTimeframe, MaxBaseCandles, 1, MaxBaseCandles, EngulfInfoList,
                        MaxEngulfCount, true);

    if (DrawZones)
        DrawEngulfZoneObjects();
    else
        ClearEngulfZoneObjects();

    Print("Engulf EA initialized on ", EnumToString(AnalysisTimeframe));

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    ClearEngulfZoneObjects();
    g_lastDbdSignal = EmptyDbdSignal();
}

void OnTick() {
    DbdSignal signal = EngulfInfoList[0].dbdSignal;

    for (int i = 0; i < ArraySize(EngulfInfoList); i++) {
        EngulfInfo engulf = EngulfInfoList[i];
    }

    FormationSettings formationSettings = MakeFormationSettings(
        FormationLookbackPeriod,
        FormationMinLookbackSamples,
        FormationRangePercentile,
        FormationBodyRatioPercentile,
        FormationMaxBaseCandles);

    // bool hasDbd = ResolveFirstDbdFromInnerTimeframes(_Symbol, AnalysisTimeframe, TimeframesToSearch, formationSettings,
    //                                                  EngulfInfoList, signal);

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
//     if (ArraySize(EngulfInfoList) > 0)
//         maxCalculateCandles = MaxBaseCandles;
//     else
//         maxCalculateCandles = 2;

//     ScanHtfEngulfsRange(_Symbol, AnalysisTimeframe, MaxBaseCandles, 1, 2, g_engulfList, MaxEngulfCount, false);
// }

bool IsNewAnalysisBar() {
    datetime currentBarTime = iTime(_Symbol, AnalysisTimeframe, 0);
    if (currentBarTime == 0)
        return false;

    // if (currentBarTime == g_lastAnalysisBarTime)
    //     return false;

    // g_lastAnalysisBarTime = currentBarTime;
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

void DrawEngulfZoneObjects() {
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

        EngulfInfoList[i].dbdSignal = dbdSignal;
        DrawEngulfDebugArrow(EngulfInfoList[i]);
        DrawEngulfZone(EngulfInfoList[i]);
        DrawDbdBaseZone(EngulfInfoList[i].barTime, EngulfInfoList[i].dbdSignal);
    }
}

void DrawEngulfDebugArrow(const EngulfInfo& engulf) {
    long chart_id = ChartID();
    string name = EngulfArrowPrefix + IntegerToString((long)engulf.barTime);
    double price = engulf.zoneLow - (engulf.zoneHigh - engulf.zoneLow) * 0.10;

    if (ObjectFind(chart_id, name) >= 0)
        ObjectDelete(chart_id, name);

    if (ObjectCreate(chart_id, name, OBJ_ARROW, 0, engulf.barTime, price)) {
        ObjectSetInteger(chart_id, name, OBJPROP_ARROWCODE, 233);
        ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
    }
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

    while (ObjectsDeleteAll(chart_id, EngulfArrowPrefix, 0, OBJ_ARROW) > 0) {
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