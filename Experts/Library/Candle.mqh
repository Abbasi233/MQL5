enum CandleType {
    DOWN = -1,
    NEUTRAL = 0,
    UP = 1
};

CandleType UpOrDown(const double open, const double close) {
    if (close > open)
        return UP;

    return DOWN;
}

struct Candle {
    datetime time;
    double open;
    double high;
    double low;
    double close;
    CandleType type;
};