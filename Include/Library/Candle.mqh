enum CandleType {
    DOWN = -1,
    NEUTRAL = 0,
    UP = 1
};

struct Candle {
    datetime time;
    double open;
    double high;
    double low;
    double close;
    CandleType type;

    Candle(void) : time(0), open(0), high(0), low(0), close(0), type(NEUTRAL) {
    }
    Candle(const datetime _time,
           const double _open,
           const double _high,
           const double _low,
           const double _close)
        : time(_time),
          open(_open), high(_high), low(_low), close(_close), type(GetType()) {
    }

    CandleType GetType() {
        if (close > open)
            return UP;

        return DOWN;
    }

    double BodyHigh() const {
        return MathMax(open, close);
    }

    double BodyLow() const {
        return MathMin(open, close);
    }

    double Center() const {
        return (high + low) / 2;
    }

    bool IsDoji(const double bodyToRangeRatio = 0.1) const {
        double range = high - low;
        if (range <= 0.0)
            return true;

        double body = MathAbs(close - open);
        return body / range <= bodyToRangeRatio;
    }

    void AddCandleList(Candle& candles[]) {
        int size = ArraySize(candles);
        ArrayResize(candles, size + 1);
        candles[size] = Candle(time, open, high, low, close);
    }
};

bool BuildCandles(const int rates_total,
                  const int maxLookbackBars,
                  const datetime& time[],
                  const double& open[],
                  const double& high[],
                  const double& low[],
                  const double& close[],
                  Candle& candles[]) {
    int lookbackStart = rates_total - maxLookbackBars;
    if (lookbackStart < 0)
        lookbackStart = 0;

    ArrayResize(candles, 0);

    for (int i = lookbackStart; i < rates_total; i++) {
        Candle candle = Candle(time[i], open[i], high[i], low[i], close[i]);
        candle.AddCandleList(candles);
    }

    return ArraySize(candles) > 1;
}
