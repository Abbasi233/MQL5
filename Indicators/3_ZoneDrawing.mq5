//+------------------------------------------------------------------+
//|                                              3_ZoneDrawing.mq5    |
//+------------------------------------------------------------------+
#property copyright "Checklist Indicator 3"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1
#property indicator_type1 DRAW_NONE

input int AvgRangePeriod = 14;
input double ImpulseMultiplier = 1.20;
input double MinBodyRatio = 0.60;
input int MaxBaseCandles = 4;
input bool UseWicksForZone = true; // false ise govde bazli cizim
input int ExtendBars = 30;         // dikdortgenin saga uzayacagi bar sayisi
input int MaxLookbackBars = 1000;
input string ObjectPrefix = "3_ZONE_";

double DummyBuffer[];

enum CandleType {
    CANDLE_BASE = 0,
    CANDLE_RALLY = 1,
    CANDLE_DROP = -1
};

double GetAverageRange(const int i, const int rates_total, const double& high[], const double& low[]) {
    int from = i;
    int to = MathMin(rates_total - 1, i + AvgRangePeriod - 1);
    int count = to - from + 1;
    if (count <= 0)
        return 0.0;

    double sum = 0.0;
    for (int k = from; k <= to; k++)
        sum += (high[k] - low[k]);
    return sum / count;
}

CandleType ClassifyCandle(const int i, const int rates_total, const double& open[], const double& high[], const double& low[], const double& close[]) {
    double range = high[i] - low[i];
    if (range <= 0.0)
        return CANDLE_BASE;

    double body = MathAbs(close[i] - open[i]);
    double bodyRatio = body / range;
    double avgRange = GetAverageRange(i, rates_total, high, low);

    bool isImpulse = (range >= avgRange * ImpulseMultiplier && bodyRatio >= MinBodyRatio);
    if (isImpulse && close[i] > open[i])
        return CANDLE_RALLY;
    if (isImpulse && close[i] < open[i])
        return CANDLE_DROP;
    return CANDLE_BASE;
}

void ClearZoneObjects() {
    int total = ObjectsTotal(0);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i);
        if (StringFind(name, ObjectPrefix) == 0)
            ObjectDelete(0, name);
    }
}

void BuildZone(const int leftType,
               const int rightType,
               const int baseStart,
               const int baseEnd,
               const datetime& time[],
               const double& open[],
               const double& high[],
               const double& low[],
               const double& close[]) {
    double zoneHigh = -DBL_MAX;
    double zoneLow = DBL_MAX;

    for (int k = baseStart; k <= baseEnd; k++) {
        double hi = UseWicksForZone ? high[k] : MathMax(open[k], close[k]);
        double lo = UseWicksForZone ? low[k] : MathMin(open[k], close[k]);

        if (hi > zoneHigh)
            zoneHigh = hi;
        if (lo < zoneLow)
            zoneLow = lo;
    }

    string pattern = "";
    color zoneColor = clrSilver;

    if ((leftType == CANDLE_RALLY && rightType == CANDLE_DROP) || (leftType == CANDLE_DROP && rightType == CANDLE_DROP)) {
        pattern = (leftType == CANDLE_RALLY) ? "RBD" : "DBD";
        zoneColor = clrTomato; // arz
    } else if ((leftType == CANDLE_RALLY && rightType == CANDLE_RALLY) || (leftType == CANDLE_DROP && rightType == CANDLE_RALLY)) {
        pattern = (leftType == CANDLE_RALLY) ? "RBR" : "DBR";
        zoneColor = clrSeaGreen; // talep
    } else
        return;

    string name = ObjectPrefix + pattern + "_" + IntegerToString((int)time[baseStart]);
    datetime t1 = time[baseStart];
    datetime t2 = time[baseEnd] + (datetime)(PeriodSeconds() * ExtendBars);

    if (ObjectFind(0, name) != -1)
        ObjectDelete(0, name);

    if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, zoneHigh, t2, zoneLow)) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, zoneColor);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }
}

int OnInit() {
    SetIndexBuffer(0, DummyBuffer, INDICATOR_DATA);
    ArraySetAsSeries(DummyBuffer, true);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    ClearZoneObjects();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[]) {
    if (rates_total < AvgRangePeriod + MaxBaseCandles + 4)
        return 0;

    ClearZoneObjects();

    int maxBars = MathMin(rates_total, MaxLookbackBars);
    int iStart = rates_total - maxBars;
    if (iStart < 1)
        iStart = 1;

    for (int i = iStart; i < rates_total - 2; i++) {
        CandleType left = ClassifyCandle(i, rates_total, open, high, low, close);
        if (left == CANDLE_BASE)
            continue;

        int baseStart = i + 1;
        int baseCount = 0;
        while (baseStart + baseCount < rates_total - 1 && baseCount < MaxBaseCandles) {
            if (ClassifyCandle(baseStart + baseCount, rates_total, open, high, low, close) != CANDLE_BASE)
                break;
            baseCount++;
        }

        if (baseCount <= 0 || baseStart + baseCount >= rates_total)
            continue;

        int rightIndex = baseStart + baseCount;
        CandleType right = ClassifyCandle(rightIndex, rates_total, open, high, low, close);
        if (right == CANDLE_BASE)
            continue;

        BuildZone(left, right, baseStart, baseStart + baseCount - 1, time, open, high, low, close);
    }

    return rates_total;
}
