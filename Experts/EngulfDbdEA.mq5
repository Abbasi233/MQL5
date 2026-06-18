#property copyright "Copyright 2026, MetaQuotes Ltd."
#property version "1.00"

#include <Trade/Trade.mqh>
#include <EngulfDbdSignal.mqh>

input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_H4; // Analiz yapılacak timeframe
input int MaxBaseCandles = 1000;                     // Max hesaplanacak mum sayısı
input bool UseCandleBodyForZone = true;              // Zone'u gövde bazlı çiz
input int ExtendZoneBars = 200;                      // Zone'un sağa doğru uzayacağı mum sayısı
input bool DrawDebugZones = false;                   // Debug zone ve ok çizimi

input double InpLot = 0.10;                          // İşlem lotu
input int InpSLPoints = 500;                         // Stop loss (point)
input int InpTPPoints = 1000;                        // Take profit (point)
input long InpMagic = 20260616;                      // Magic number
input bool InpOnePositionOnly = true;                // Aynı anda tek pozisyon
input bool InpTradeOnNewAnalysisBar = true;          // Sadece yeni analiz mumunda işlem aç

const ENUM_TIMEFRAMES TimeframesToSearch[] = {PERIOD_H1, PERIOD_M30, PERIOD_M15};
const string DbgEngulfZonePrefix = "EA_ENGULF_ZONE_";
const string DbgDbdZonePrefix = "EA_ENGULF_DBD_";
const string DbgArrowPrefix = "EA_ENGULF_ARROW_";

CTrade g_trade;
DbdSignal g_lastSignal;
datetime g_lastAnalysisBarTime = 0;
datetime g_lastTradedEngulfTime = 0;

int OnInit() {
    g_trade.SetExpertMagicNumber(InpMagic);
    g_lastSignal = EmptyDbdSignal();
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    ClearDebugObjects();
    g_lastSignal = EmptyDbdSignal();
}

void OnTick() {
    DbdSignal signal;
    bool hasDbd = FindLatestDbdSignal(_Symbol, AnalysisTimeframe, MaxBaseCandles, UseCandleBodyForZone,
                                      TimeframesToSearch, signal);

    if (hasDbd && signal.valid)
        g_lastSignal = signal;

    if (DrawDebugZones)
        UpdateDebugDraw(hasDbd && signal.valid);

    if (InpTradeOnNewAnalysisBar && !IsNewAnalysisBar())
        return;

    if (!hasDbd || !signal.valid)
        return;

    if (InpOnePositionOnly && HasOpenPosition())
        return;

    if (signal.engulfBarTime == g_lastTradedEngulfTime)
        return;

    if (!OpenSell(signal))
        return;

    g_lastTradedEngulfTime = signal.engulfBarTime;
}

bool IsNewAnalysisBar() {
    datetime currentBarTime = iTime(_Symbol, AnalysisTimeframe, 0);
    if (currentBarTime == 0)
        return false;

    if (currentBarTime == g_lastAnalysisBarTime)
        return false;

    g_lastAnalysisBarTime = currentBarTime;
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

    if (signal.engulfZoneHigh > bid)
        sl = NormalizeDouble(signal.engulfZoneHigh + 10 * point, digits);

    return g_trade.Sell(InpLot, _Symbol, 0, sl, tp, "EngulfDbdEA");
}

void UpdateDebugDraw(const bool hasFullDbdSignal) {
    HtfEngulfInfo engulfs[];
    CollectHtfEngulfs(_Symbol, AnalysisTimeframe, MaxBaseCandles, UseCandleBodyForZone, engulfs);

    if (ArraySize(engulfs) <= 0) {
        ClearDebugObjects();
        return;
    }

    HtfEngulfInfo engulf = engulfs[0];
    DrawEngulfDebugZone(engulf);
    DrawEngulfDebugArrow(engulf);

    if (hasFullDbdSignal && g_lastSignal.valid && g_lastSignal.baseStartTime != 0 && g_lastSignal.baseEndTime != 0)
        DrawDbdDebugZone(g_lastSignal);
}

void ClearDebugObjects() {
    long chart_id = ChartID();

    while (ObjectsDeleteAll(chart_id, DbgEngulfZonePrefix, 0, -1) > 0) {
    }

    while (ObjectsDeleteAll(chart_id, DbgDbdZonePrefix, 0, -1) > 0) {
    }

    while (ObjectsDeleteAll(chart_id, DbgArrowPrefix, 0, -1) > 0) {
    }

    ChartRedraw(chart_id);
}

void DrawEngulfDebugZone(const HtfEngulfInfo& engulf) {
    if (!engulf.found)
        return;

    long chart_id = ChartID();
    string name = DbgEngulfZonePrefix + IntegerToString((long)engulf.barTime);
    datetime t2 = engulf.barTime + (datetime)(PeriodSeconds(AnalysisTimeframe) * ExtendZoneBars);

    if (ObjectFind(chart_id, name) >= 0)
        ObjectDelete(chart_id, name);

    if (ObjectCreate(chart_id, name, OBJ_RECTANGLE, 0, engulf.barTime, engulf.zoneHigh, t2, engulf.zoneLow)) {
        ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clrSilver);
        ObjectSetInteger(chart_id, name, OBJPROP_FILL, true);
        ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
        ObjectSetInteger(chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }
}

void DrawEngulfDebugArrow(const HtfEngulfInfo& engulf) {
    if (!engulf.found)
        return;

    long chart_id = ChartID();
    string name = DbgArrowPrefix + IntegerToString((long)engulf.barTime);
    double price = engulf.zoneLow - (engulf.zoneHigh - engulf.zoneLow) * 0.10;

    if (ObjectFind(chart_id, name) >= 0)
        ObjectDelete(chart_id, name);

    if (ObjectCreate(chart_id, name, OBJ_ARROW, 0, engulf.barTime, price)) {
        ObjectSetInteger(chart_id, name, OBJPROP_ARROWCODE, 234);
        ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
    }
}

void DrawDbdDebugZone(const DbdSignal& signal) {
    long chart_id = ChartID();
    string name = DbgDbdZonePrefix + IntegerToString((long)signal.engulfBarTime);

    if (ObjectFind(chart_id, name) >= 0)
        ObjectDelete(chart_id, name);

    if (ObjectCreate(chart_id, name, OBJ_RECTANGLE, 0, signal.baseStartTime, signal.baseHigh, signal.baseEndTime,
                     signal.baseLow)) {
        ObjectSetInteger(chart_id, name, OBJPROP_COLOR, clrTomato);
        ObjectSetInteger(chart_id, name, OBJPROP_FILL, true);
        ObjectSetInteger(chart_id, name, OBJPROP_BACK, true);
        ObjectSetInteger(chart_id, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }
}
