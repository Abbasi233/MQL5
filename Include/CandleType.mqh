enum CandleType {
    NEUTRAL = 0,
    DOWN = 1,
    UP = 2
};

CandleType UpOrDown(const double open, const double close) {
    if (close > open)
        return UP;

    return DOWN;
}