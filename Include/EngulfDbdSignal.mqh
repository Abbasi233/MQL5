#ifndef ENGULF_DBD_SIGNAL_MQH
#define ENGULF_DBD_SIGNAL_MQH

#include <CandleType.mqh>

struct HtfEngulfInfo {
    bool found;
    datetime barTime;
    datetime prevBarTime;
    double zoneHigh;
    double zoneLow;
};

struct InnerCandlesSearchResult {
    bool found;
    ENUM_TIMEFRAMES timeframe;
};

struct DbdSignal {
    bool valid;
    string symbol;
    ENUM_TIMEFRAMES analysisTimeframe;
    ENUM_TIMEFRAMES dbdTimeframe;
    datetime engulfBarTime;
    datetime engulfPrevBarTime;
    double engulfZoneHigh;
    double engulfZoneLow;
    datetime baseStartTime;
    datetime baseEndTime;
    double baseHigh;
    double baseLow;
};

HtfEngulfInfo EmptyHtfEngulfInfo() {
    HtfEngulfInfo info;
    info.found = false;
    info.barTime = 0;
    info.prevBarTime = 0;
    info.zoneHigh = 0;
    info.zoneLow = 0;
    return info;
}

InnerCandlesSearchResult EmptyInnerCandlesSearchResult() {
    InnerCandlesSearchResult result;
    result.found = false;
    result.timeframe = PERIOD_CURRENT;
    return result;
}

DbdSignal EmptyDbdSignal() {
    DbdSignal signal;
    signal.valid = false;
    signal.symbol = "";
    signal.analysisTimeframe = PERIOD_CURRENT;
    signal.dbdTimeframe = PERIOD_CURRENT;
    signal.engulfBarTime = 0;
    signal.engulfPrevBarTime = 0;
    signal.engulfZoneHigh = 0;
    signal.engulfZoneLow = 0;
    signal.baseStartTime = 0;
    signal.baseEndTime = 0;
    signal.baseHigh = 0;
    signal.baseLow = 0;
    return signal;
}

void AppendEngulf(HtfEngulfInfo& engulfs[], const HtfEngulfInfo& info) {
    int size = ArraySize(engulfs);
    ArrayResize(engulfs, size + 1);
    engulfs[size] = info;
}

bool CopyHtfRates(const string symbol,
                  const ENUM_TIMEFRAMES timeframe,
                  const int count,
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

    if (CopyOpen(symbol, timeframe, 0, count, htf_open) < count)
        return false;
    if (CopyHigh(symbol, timeframe, 0, count, htf_high) < count)
        return false;
    if (CopyLow(symbol, timeframe, 0, count, htf_low) < count)
        return false;
    if (CopyClose(symbol, timeframe, 0, count, htf_close) < count)
        return false;
    if (CopyTime(symbol, timeframe, 0, count, htf_time) < count)
        return false;

    return true;
}

HtfEngulfInfo DetectBearishEngulfAt(const int i,
                                    const double& htf_open[],
                                    const double& htf_high[],
                                    const double& htf_low[],
                                    const double& htf_close[],
                                    const datetime& htf_time[],
                                    const bool useCandleBodyForZone) {
    CandleType currentType = UpOrDown(htf_open[i], htf_close[i]);
    CandleType previousType = UpOrDown(htf_open[i + 1], htf_close[i + 1]);
    if (currentType == UP)
        return EmptyHtfEngulfInfo();

    if (previousType == DOWN)
        return EmptyHtfEngulfInfo();

    double currentHigh = htf_high[i];
    double currentOpen = htf_open[i];
    double currentClose = htf_close[i];

    double previousHigh = htf_high[i + 1];
    double previousClose = htf_close[i + 1];
    double previousLow = htf_low[i + 1];

    if (currentOpen >= previousClose && currentClose < previousLow && currentHigh > previousHigh) {
        double zoneHigh = useCandleBodyForZone ? MathMax(htf_open[i], htf_close[i]) : htf_high[i];
        double zoneLow = useCandleBodyForZone ? MathMin(htf_open[i], htf_close[i]) : htf_low[i];

        HtfEngulfInfo info;
        info.found = true;
        info.barTime = htf_time[i];
        info.prevBarTime = htf_time[i + 1];
        info.zoneHigh = zoneHigh;
        info.zoneLow = zoneLow;
        return info;
    }

    return EmptyHtfEngulfInfo();
}

void CollectHtfEngulfs(const string symbol,
                       const ENUM_TIMEFRAMES analysisTimeframe,
                       const int maxBaseCandles,
                       const bool useCandleBodyForZone,
                       HtfEngulfInfo& engulfs[]) {
    ArrayResize(engulfs, 0);

    int htf_count = maxBaseCandles + 2;
    double htf_open[];
    double htf_high[];
    double htf_low[];
    double htf_close[];
    datetime htf_time[];

    if (!CopyHtfRates(symbol, analysisTimeframe, htf_count, htf_open, htf_high, htf_low, htf_close, htf_time))
        return;

    int htf_end = htf_count - 2;
    for (int i = 1; i <= htf_end; i++) {
        HtfEngulfInfo info = DetectBearishEngulfAt(i, htf_open, htf_high, htf_low, htf_close, htf_time, useCandleBodyForZone);
        if (info.found)
            AppendEngulf(engulfs, info);
    }
}

int CountInnerCandlesInZone(const string symbol,
                            const ENUM_TIMEFRAMES timeframe,
                            const datetime bar_time_start,
                            const datetime bar_time_end,
                            const double zone_high,
                            const double zone_low) {
    int shiftStart = iBarShift(symbol, timeframe, bar_time_start, false);
    int shiftEnd = iBarShift(symbol, timeframe, bar_time_end, false);

    if (shiftStart < 0 || shiftEnd < 0)
        return 0;

    int count = 0;
    for (int s = shiftEnd; s <= shiftStart; s++) {
        double h = iHigh(symbol, timeframe, s);
        double l = iLow(symbol, timeframe, s);
        if (l <= zone_high && h >= zone_low)
            count++;
    }

    return count;
}

InnerCandlesSearchResult SearchTimeframesUntilFindInnerCandles(const string symbol,
                                                               const ENUM_TIMEFRAMES& timeframesToSearch[],
                                                               const datetime bar_time_start,
                                                               const datetime bar_time_end,
                                                               const double zone_high,
                                                               const double zone_low) {
    for (int i = 0; i < ArraySize(timeframesToSearch); i++) {
        ENUM_TIMEFRAMES timeframe = timeframesToSearch[i];
        int count = CountInnerCandlesInZone(symbol, timeframe, bar_time_start, bar_time_end, zone_high, zone_low);

        if (count <= 0)
            continue;

        InnerCandlesSearchResult result;
        result.found = true;
        result.timeframe = timeframe;
        return result;
    }

    return EmptyInnerCandlesSearchResult();
}

bool ResolveDbdZone(const string symbol,
                    const HtfEngulfInfo& engulf,
                    const ENUM_TIMEFRAMES dbdTimeframe,
                    DbdSignal& signal) {
    signal = EmptyDbdSignal();
    return false;
}

bool FindLatestDbdSignal(const string symbol,
                         const ENUM_TIMEFRAMES analysisTimeframe,
                         const int maxBaseCandles,
                         const bool useCandleBodyForZone,
                         const ENUM_TIMEFRAMES& timeframesToSearch[],
                         DbdSignal& signal) {
    signal = EmptyDbdSignal();

    HtfEngulfInfo engulfs[];
    CollectHtfEngulfs(symbol, analysisTimeframe, maxBaseCandles, useCandleBodyForZone, engulfs);

    for (int e = 0; e < ArraySize(engulfs); e++) {
        HtfEngulfInfo engulf = engulfs[e];

        InnerCandlesSearchResult search = SearchTimeframesUntilFindInnerCandles(
            symbol, timeframesToSearch, engulf.barTime, engulf.prevBarTime, engulf.zoneHigh, engulf.zoneLow);
        if (!search.found)
            continue;

        DbdSignal candidate;
        if (!ResolveDbdZone(symbol, engulf, search.timeframe, candidate))
            continue;

        candidate.valid = true;
        candidate.symbol = symbol;
        candidate.analysisTimeframe = analysisTimeframe;
        candidate.dbdTimeframe = search.timeframe;
        candidate.engulfBarTime = engulf.barTime;
        candidate.engulfPrevBarTime = engulf.prevBarTime;
        candidate.engulfZoneHigh = engulf.zoneHigh;
        candidate.engulfZoneLow = engulf.zoneLow;
        signal = candidate;
        return true;
    }

    return false;
}

#endif
