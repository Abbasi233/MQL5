enum SwingType {
    BEARISH = -1,
    RANGE = 0,
    BULLISH = 1,
};

struct Swing {
    Candle startCandle;
    Candle endCandle;
    SwingType type;

    Swing() : startCandle(), endCandle(), type(RANGE) {
    }
    Swing(const Candle& _startCandle, const Candle& _endCandle, const SwingType& _type) : startCandle(_startCandle), endCandle(_endCandle), type(_type) {
    }
};