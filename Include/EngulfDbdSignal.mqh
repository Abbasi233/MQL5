#ifndef ENGULF_DBD_SIGNAL_MQH
#define ENGULF_DBD_SIGNAL_MQH

#include <CandleType.mqh>

struct FormationSettings {
    int lookbackPeriod;
    int minLookbackSamples;
    double rangePercentile;
    double bodyRatioPercentile;
    int maxBaseCandles;
};

FormationSettings DefaultFormationSettings() {
    FormationSettings settings;
    settings.lookbackPeriod = 50;
    settings.minLookbackSamples = 10;
    settings.rangePercentile = 75.0;
    settings.bodyRatioPercentile = 60.0;
    settings.maxBaseCandles = 4;
    return settings;
}

FormationSettings MakeFormationSettings(const int lookbackPeriod,
                                        const int minLookbackSamples,
                                        const double rangePercentile,
                                        const double bodyRatioPercentile,
                                        const int maxBaseCandles) {
    FormationSettings settings;
    settings.lookbackPeriod = lookbackPeriod;
    settings.minLookbackSamples = minLookbackSamples;
    settings.rangePercentile = rangePercentile;
    settings.bodyRatioPercentile = bodyRatioPercentile;
    settings.maxBaseCandles = maxBaseCandles;
    return settings;
}

enum FormationCandleType {
    FORMATION_BASE = 0,
    FORMATION_RALLY = 1,
    FORMATION_DROP = -1
};

struct EngulfInfo {
    bool found;
    int chartIndex;
    datetime barTime;
    datetime leftBarTime;
    datetime rightBarTime;
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
    datetime engulfLeftBarTime;
    double engulfZoneHigh;
    double engulfZoneLow;
    datetime baseStartTime;
    datetime baseEndTime;
    double baseHigh;
    double baseLow;
};

EngulfInfo EmptyHtfEngulfInfo() {
    EngulfInfo info;
    info.found = false;
    info.chartIndex = -1;
    info.barTime = 0;
    info.leftBarTime = 0;
    info.zoneHigh = 0;
    info.zoneLow = 0;
    info.rightBarTime = 0;
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
    signal.engulfLeftBarTime = 0;
    signal.engulfZoneHigh = 0;
    signal.engulfZoneLow = 0;
    signal.baseStartTime = 0;
    signal.baseEndTime = 0;
    signal.baseHigh = 0;
    signal.baseLow = 0;
    return signal;
}

void AppendEngulf(EngulfInfo& engulfs[], const EngulfInfo& info) {
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

EngulfInfo DetectBearishEngulfAt(const int i,
                                    const double& htf_open[],
                                    const double& htf_high[],
                                    const double& htf_low[],
                                    const double& htf_close[],
                                    const datetime& htf_time[]) {
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
        double zoneHigh = MathMax(htf_open[i], htf_close[i]);
        double zoneLow = MathMin(htf_open[i], htf_close[i]);

        EngulfInfo info;
        info.found = true;
        info.barTime = htf_time[i];
        info.leftBarTime = htf_time[i + 1];
        info.rightBarTime = htf_time[i - 1];
        info.zoneHigh = zoneHigh;
        info.zoneLow = zoneLow;
        return info;
    }

    return EmptyHtfEngulfInfo();
}

void CollectHtfEngulfs(const string symbol,
                       const ENUM_TIMEFRAMES analysisTimeframe,
                       const int maxBaseCandles,
                       EngulfInfo& engulfs[]) {
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
        EngulfInfo info = DetectBearishEngulfAt(i, htf_open, htf_high, htf_low, htf_close, htf_time);
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

double FormationPercentile(double& values[], const double pct) {
    int count = ArraySize(values);
    if (count <= 0)
        return 0.0;

    double sorted[];
    ArrayResize(sorted, count);
    ArrayCopy(sorted, values);
    ArraySort(sorted);

    int idx = (int)MathFloor((count - 1) * pct / 100.0);
    if (idx < 0)
        idx = 0;
    if (idx >= count)
        idx = count - 1;
    return sorted[idx];
}

int CollectFormationLookbackSamples(const int i,
                                    const int rates_total,
                                    const MqlRates& rates[],
                                    const FormationSettings& settings,
                                    double& ranges[],
                                    double& bodyRatios[]) {
    ArrayResize(ranges, 0);
    ArrayResize(bodyRatios, 0);

    int from = MathMax(0, i - settings.lookbackPeriod);
    for (int k = from; k < i; k++) {
        double range = rates[k].high - rates[k].low;
        if (range <= 0.0)
            continue;

        int size = ArraySize(ranges);
        ArrayResize(ranges, size + 1);
        ArrayResize(bodyRatios, size + 1);
        ranges[size] = range;
        bodyRatios[size] = MathAbs(rates[k].close - rates[k].open) / range;
    }

    return ArraySize(ranges);
}

FormationCandleType ClassifyFormationCandle(const int i,
                                            const int rates_total,
                                            const MqlRates& rates[],
                                            const FormationSettings& settings) {
    double range = rates[i].high - rates[i].low;
    if (range <= 0.0)
        return FORMATION_BASE;

    double body = MathAbs(rates[i].close - rates[i].open);
    double bodyRatio = body / range;

    double ranges[];
    double bodyRatios[];
    int sampleCount = CollectFormationLookbackSamples(i, rates_total, rates, settings, ranges, bodyRatios);
    if (sampleCount < settings.minLookbackSamples)
        return FORMATION_BASE;

    double rangeThreshold = FormationPercentile(ranges, settings.rangePercentile);
    double bodyThreshold = FormationPercentile(bodyRatios, settings.bodyRatioPercentile);

    bool isImpulse = (range >= rangeThreshold && bodyRatio >= bodyThreshold);
    if (isImpulse && rates[i].close > rates[i].open)
        return FORMATION_RALLY;
    if (isImpulse && rates[i].close < rates[i].open)
        return FORMATION_DROP;
    return FORMATION_BASE;
}

bool ZonesOverlap(const double lowA, const double highA, const double lowB, const double highB) {
    return lowA <= highB && highA >= lowB;
}

bool RightDropAlignsWithEngulf(const datetime rightBarTime,
                               const datetime engulfBarTime,
                               const ENUM_TIMEFRAMES analysisTimeframe) {
    datetime engulfEnd = engulfBarTime + (datetime)PeriodSeconds(analysisTimeframe);
    return rightBarTime >= engulfBarTime && rightBarTime < engulfEnd;
}

void CalcBaseZoneBounds(const MqlRates& rates[],
                        const int baseStart,
                        const int baseEnd,
                        double& zoneHigh,
                        double& zoneLow) {
    zoneHigh = -DBL_MAX;
    zoneLow = DBL_MAX;

    for (int k = baseStart; k <= baseEnd; k++) {
        double hi = MathMax(rates[k].open, rates[k].close);
        double lo = MathMin(rates[k].open, rates[k].close);
        if (hi > zoneHigh)
            zoneHigh = hi;
        if (lo < zoneLow)
            zoneLow = lo;
    }
}

datetime ResolveEngulfWindowEnd(const EngulfInfo& engulf, const ENUM_TIMEFRAMES analysisTimeframe) {
    datetime windowEnd = engulf.barTime + (datetime)PeriodSeconds(analysisTimeframe);
    if (engulf.rightBarTime > 0) {
        datetime rightEnd = engulf.rightBarTime + (datetime)PeriodSeconds(analysisTimeframe);
        if (rightEnd > windowEnd)
            windowEnd = rightEnd;
    }
    return windowEnd;
}

bool CopyRatesInWindow(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const datetime timeStart,
                       const datetime timeEnd,
                       MqlRates& rates[]) {
    ArrayResize(rates, 0);
    ArraySetAsSeries(rates, false);

    if (timeStart <= 0 || timeEnd <= 0 || timeEnd < timeStart)
        return false;

    int copied = CopyRates(symbol, timeframe, timeStart, timeEnd, rates);
    return copied > 0;
}

bool FindFormationSearchBounds(const MqlRates& rates[],
                               const datetime timeStart,
                               const datetime timeEnd,
                               int& searchStart,
                               int& searchEnd) {
    int ratesTotal = ArraySize(rates);
    searchStart = -1;
    searchEnd = -1;

    for (int i = 0; i < ratesTotal; i++) {
        if (rates[i].time >= timeStart) {
            searchStart = i;
            break;
        }
    }

    for (int i = ratesTotal - 1; i >= 0; i--) {
        if (rates[i].time <= timeEnd) {
            searchEnd = i;
            break;
        }
    }

    if (searchStart < 0 || searchEnd < 0 || searchEnd < searchStart)
        return false;

    return true;
}

bool TryFindDbdOnTimeframe(const string symbol,
                           const EngulfInfo& engulf,
                           const ENUM_TIMEFRAMES analysisTimeframe,
                           const ENUM_TIMEFRAMES timeframe,
                           const FormationSettings& settings,
                           DbdSignal& signal) {
    datetime timeStart = engulf.leftBarTime;
    datetime timeEnd = ResolveEngulfWindowEnd(engulf, analysisTimeframe);
     if (timeStart <= 0)
        return false;

    datetime lookbackStart = timeStart - (datetime)(PeriodSeconds(timeframe) * settings.lookbackPeriod);

    MqlRates rates[];
    if (!CopyRatesInWindow(symbol, timeframe, lookbackStart, timeEnd, rates))
        return false;

    int ratesTotal = ArraySize(rates);
    int searchStart = 0;
    int searchEnd = 0;
    if (!FindFormationSearchBounds(rates, timeStart, timeEnd, searchStart, searchEnd))
        return false;

    if (searchEnd - searchStart < settings.maxBaseCandles + 2)
        return false;

    bool found = false;
    DbdSignal best = EmptyDbdSignal();

    for (int i = searchStart; i <= searchEnd - 2; i++) {
        FormationCandleType left = ClassifyFormationCandle(i, ratesTotal, rates, settings);
        if (left != FORMATION_DROP)
            continue;

        int baseStart = i + 1;
        int baseCount = 0;
        while (baseStart + baseCount < ratesTotal - 1 && baseCount < settings.maxBaseCandles) {
            if (ClassifyFormationCandle(baseStart + baseCount, ratesTotal, rates, settings) != FORMATION_BASE)
                break;
            baseCount++;
        }

        if (baseCount <= 0)
            continue;

        int rightIndex = baseStart + baseCount;
        if (rightIndex > searchEnd)
            continue;

        FormationCandleType right = ClassifyFormationCandle(rightIndex, ratesTotal, rates, settings);
        if (right != FORMATION_DROP)
            continue;

        double baseHigh = 0;
        double baseLow = 0;
        int baseEnd = baseStart + baseCount - 1;
        CalcBaseZoneBounds(rates, baseStart, baseEnd, baseHigh, baseLow);

        if (!ZonesOverlap(engulf.zoneLow, engulf.zoneHigh, baseLow, baseHigh))
            continue;

        if (!RightDropAlignsWithEngulf(rates[rightIndex].time, engulf.barTime, analysisTimeframe))
            continue;

        best.baseStartTime = rates[baseStart].time;
        best.baseEndTime = rates[baseEnd].time + (datetime)PeriodSeconds(timeframe);
        best.baseHigh = baseHigh;
        best.baseLow = baseLow;
        best.dbdTimeframe = timeframe;
        found = true;
    }

    if (!found)
        return false;

    signal = best;
    return true;
}

bool FindLatestDbdSignal(const string symbol,
                         const ENUM_TIMEFRAMES analysisTimeframe,
                         const int maxBaseCandles,
                         const ENUM_TIMEFRAMES& timeframesToSearch[],
                         const FormationSettings& settings,
                         DbdSignal& signal) {
    signal = EmptyDbdSignal();

    EngulfInfo engulfs[];
    CollectHtfEngulfs(symbol, analysisTimeframe, maxBaseCandles, engulfs);

    for (int e = 0; e < ArraySize(engulfs); e++) {
        EngulfInfo engulf = engulfs[e];

        DbdSignal candidate;
        if (!ResolveDbdZone(symbol, engulf, analysisTimeframe, timeframesToSearch, settings, candidate))
            continue;

        candidate.valid = true;
        candidate.symbol = symbol;
        candidate.analysisTimeframe = analysisTimeframe;
        candidate.engulfBarTime = engulf.barTime;
        candidate.engulfLeftBarTime = engulf.leftBarTime;
        candidate.engulfZoneHigh = engulf.zoneHigh;
        candidate.engulfZoneLow = engulf.zoneLow;
        signal = candidate;
        return true;
    }

    return false;
}

bool ResolveDbdZone(const string symbol,
                    const EngulfInfo& engulf,
                    const ENUM_TIMEFRAMES analysisTimeframe,
                    const ENUM_TIMEFRAMES& timeframesToSearch[],
                    const FormationSettings& settings,
                    DbdSignal& signal) {
    signal = EmptyDbdSignal();

    for (int i = 0; i < ArraySize(timeframesToSearch); i++) {
        DbdSignal candidate;
        if (!TryFindDbdOnTimeframe(symbol, engulf, analysisTimeframe, timeframesToSearch[i], settings, candidate))
            continue;

        signal = candidate;
        return true;
    }

    return false;
}

#endif
