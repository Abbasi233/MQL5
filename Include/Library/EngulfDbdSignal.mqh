#ifndef ENGULF_DBD_SIGNAL_MQH
#define ENGULF_DBD_SIGNAL_MQH

#include <Library/Candle.mqh>

struct FormationSettings {
    int lookbackPeriod;
    int minLookbackSamples;
    double rangePercentile;
    double bodyRatioPercentile;
    double baseMaxBodyRatio;
    int maxBaseCandles;
};

FormationSettings MakeFormationSettings(const int lookbackPeriod,
                                        const int minLookbackSamples,
                                        const double rangePercentile,
                                        const double bodyRatioPercentile,
                                        const double baseMaxBodyRatio,
                                        const int maxBaseCandles) {
    FormationSettings settings;
    settings.lookbackPeriod = lookbackPeriod;
    settings.minLookbackSamples = minLookbackSamples;
    settings.rangePercentile = rangePercentile;
    settings.bodyRatioPercentile = bodyRatioPercentile;
    settings.baseMaxBodyRatio = baseMaxBodyRatio;
    settings.maxBaseCandles = maxBaseCandles;
    return settings;
}

enum FormationCandleType {
    FORMATION_BASE = 0,
    FORMATION_RALLY = 1,
    FORMATION_DROP = -1
};

struct DbdSignal {
    ENUM_TIMEFRAMES analysisTimeframe;
    ENUM_TIMEFRAMES dbdTimeframe;
    datetime baseStartTime;
    datetime baseEndTime;
    double baseHigh;
    double baseLow;
};

struct EngulfInfo {
    bool found;
    int chartIndex;
    datetime barTime;
    datetime leftBarTime;
    datetime rightBarTime;
    double zoneHigh;
    double zoneLow;
    DbdSignal dbdSignal;
};

struct InnerCandlesSearchResult {
    bool found;
    ENUM_TIMEFRAMES timeframe;
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
    signal.analysisTimeframe = PERIOD_CURRENT;
    signal.dbdTimeframe = PERIOD_CURRENT;
    signal.baseStartTime = 0;
    signal.baseEndTime = 0;
    signal.baseHigh = 0;
    signal.baseLow = 0;
    return signal;
}

void AppendEngulfToListEnd(EngulfInfo& engulfs[], const EngulfInfo& info) {
    int size = ArraySize(engulfs);
    ArrayResize(engulfs, size + 1);
    engulfs[size] = info;
}

int FindEngulfIndexByBarTime(const EngulfInfo& engulfs[], const datetime barTime) {
    for (int i = 0; i < ArraySize(engulfs); i++) {
        if (engulfs[i].barTime == barTime)
            return i;
    }
    return -1;
}

void AppendEngulfIntoList(EngulfInfo& engulfs[], const EngulfInfo& info, const int maxEngulfCount) {
    if (!info.found)
        return;

    int existing = FindEngulfIndexByBarTime(engulfs, info.barTime);
    if (existing >= 0) {
        engulfs[existing] = info;
        return;
    }

    AppendEngulfToListEnd(engulfs, info);

    if (maxEngulfCount > 0 && ArraySize(engulfs) > maxEngulfCount)
        ArrayResize(engulfs, maxEngulfCount);
}

bool CopyCandles(const string symbol,
                 const ENUM_TIMEFRAMES timeframe,
                 const int count,
                 Candle& candles[]) {
    double opens[];
    double highs[];
    double lows[];
    double closes[];
    datetime times[];

    ArraySetAsSeries(opens, true);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    ArraySetAsSeries(times, true);

    if (CopyOpen(symbol, timeframe, 0, count, opens) < count)
        return false;
    if (CopyHigh(symbol, timeframe, 0, count, highs) < count)
        return false;
    if (CopyLow(symbol, timeframe, 0, count, lows) < count)
        return false;
    if (CopyClose(symbol, timeframe, 0, count, closes) < count)
        return false;
    if (CopyTime(symbol, timeframe, 0, count, times) < count)
        return false;

    ArrayResize(candles, count);
    ArraySetAsSeries(candles, true);
    for (int i = 0; i < count; i++)
        candles[i] = Candle(times[i], opens[i], highs[i], lows[i], closes[i]);

    return true;
}

EngulfInfo DetectBearishEngulfAt(const Candle& current,
                                 const Candle& previous,
                                 const Candle& next) {
    if (current.type == UP)
        return EmptyHtfEngulfInfo();

    if (previous.type == DOWN)
        return EmptyHtfEngulfInfo();

        current.IsDoji();

    if (current.open >= previous.close && current.close < previous.low && current.high > previous.high) {
        EngulfInfo info;
        info.found = true;
        info.barTime = current.time;
        info.leftBarTime = previous.time;
        info.rightBarTime = next.time;
        info.zoneHigh = MathMax(current.open, current.close);
        info.zoneLow = MathMin(current.open, current.close);
        return info;
    }

    return EmptyHtfEngulfInfo();
}

bool ScanEngulfsInTimeframeRange(const string symbol,
                         const ENUM_TIMEFRAMES analysisTimeframe,
                         const int maxBaseCandles,
                         const int iStart,
                         const int iEnd,
                         EngulfInfo& engulfs[],
                         const int maxEngulfCount,
                         const bool stopWhenFull) {

    Candle candles[];
    int htf_count = maxBaseCandles + 2;

    if (!CopyCandles(symbol, analysisTimeframe, htf_count, candles))
        return false;

    int htf_end = htf_count - 2;
    int scanEnd = MathMin(iEnd, htf_end);
    if (iStart > scanEnd)
        return true;

    for (int i = iStart; i <= scanEnd; i++) {
        EngulfInfo info = DetectBearishEngulfAt(candles[i], candles[i + 1], candles[i - 1]);
        if (info.found)
            AppendEngulfIntoList(engulfs, info, maxEngulfCount);

        if (stopWhenFull && maxEngulfCount > 0 && ArraySize(engulfs) >= maxEngulfCount)
            break;
    }

    return true;
}

int CountCandlesInRange(const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const datetime bar_time_start,
                        const datetime bar_time_end) {
    int shiftStart = iBarShift(symbol, timeframe, bar_time_start, false);
    int shiftEnd = iBarShift(symbol, timeframe, bar_time_end, false);
    return shiftEnd - shiftStart + 1;
}

int CountCandlesInZone(const string symbol,
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
        int count = CountCandlesInZone(symbol, timeframe, bar_time_start, bar_time_end, zone_high, zone_low);

        if (count <= 0)
            continue;

        InnerCandlesSearchResult result;
        result.found = true;
        result.timeframe = timeframe;
        return result;
    }

    return EmptyInnerCandlesSearchResult();
}

double FormationCandleBodyRatio(const int i, const MqlRates& rates[]) {
    double range = rates[i].high - rates[i].low;
    if (range <= 0.0)
        return 0.0;
    return MathAbs(rates[i].close - rates[i].open) / range;
}

bool FormationCandleQualifiesAsBaseBody(const int i,
                                        const MqlRates& rates[],
                                        const double maxBodyRatio) {
    return FormationCandleBodyRatio(i, rates) < maxBodyRatio;
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
        double hi = MathMax(rates[k].high, rates[k].high);
        double lo = MathMin(rates[k].low, rates[k].low);
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

bool ResolveFirstDbdFromInnerTimeframes(const string symbol,
                                        const ENUM_TIMEFRAMES analysisTimeframe,
                                        const ENUM_TIMEFRAMES& timeframesToSearch[],
                                        const FormationSettings& settings,
                                        const EngulfInfo& engulfs[],
                                        DbdSignal& signal) {
    signal = EmptyDbdSignal();

    for (int e = 0; e < ArraySize(engulfs); e++) {
        EngulfInfo engulf = engulfs[e];

        DbdSignal candidate;
        if (!ResolveDbdZone(symbol, engulf, analysisTimeframe, timeframesToSearch, settings, candidate))
            continue;

        // candidate.valid = true;
        // candidate.symbol = symbol;
        candidate.analysisTimeframe = analysisTimeframe;
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
    for (int i = 0; i < ArraySize(timeframesToSearch); i++) {
        DbdSignal candidate;
        if (!TryFindDbdOnTimeframe(symbol, engulf, analysisTimeframe, timeframesToSearch[i], settings, candidate))
            continue;

        signal = candidate;
        return true;
    }

    return false;
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
        if (!FormationCandleQualifiesAsBaseBody(baseStart, rates, settings.baseMaxBodyRatio))
            continue;

        int baseCount = 0;
        while (baseStart + baseCount < ratesTotal - 1 && baseCount < settings.maxBaseCandles) {
            int baseIndex = baseStart + baseCount;
            if (ClassifyFormationCandle(baseIndex, ratesTotal, rates, settings) != FORMATION_BASE)
                break;
            if (!FormationCandleQualifiesAsBaseBody(baseIndex, rates, settings.baseMaxBodyRatio))
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

        int baseEnd = baseStart + baseCount - 1;
        double baseHigh = 0;
        double baseLow = 0;
        CalcBaseZoneBounds(rates, baseStart, baseEnd, baseHigh, baseLow);

        if (!ZonesOverlap(engulf.zoneLow, engulf.zoneHigh, baseLow, baseHigh))
            continue;

        if (!RightDropAlignsWithEngulf(rates[rightIndex].time, engulf.barTime, analysisTimeframe))
            continue;

        best.analysisTimeframe = analysisTimeframe;
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

#endif
