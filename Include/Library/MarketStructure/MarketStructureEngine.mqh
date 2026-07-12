#include <Library/Candle.mqh>
#include <Library/Swing/models/Swing.mqh>

enum MarketStructureType {
    MARKET_BEARISH = -1,
    MARKET_RANGE = 0,
    MARKET_BULLISH = 1,
};

class MarketStructureEngine {
  private:
    Swing swingList[];

  public:
    MarketStructureEngine() {
    }

    MarketStructureEngine(const Swing& newSwingList[]) {
        ArrayCopy(this.swingList, newSwingList);
    }

    Candle GetLastTop() const;
    Candle GetLastDeep() const;

    MarketStructureType DetectMarketStructure() const;
    bool DetectMarketBreak(const Candle& candle) const;

  private:
    Swing _GetLastSwing() const {
        return swingList[ArraySize(swingList) - 1];
    }

    Swing _GetLastSwing(const SwingType& swingType) const {
        for (int i = ArraySize(swingList) - 1; i >= 0; i--) {
            if (swingList[i].type == swingType)
                return swingList[i];
        }

        return Swing();
    }

    Swing _GetLastSwing(const SwingType& swingType, const int count) const {
        int found = 0;
        for (int i = ArraySize(swingList) - 1; i >= 0; i--) {
            if (swingList[i].type == swingType)
                found++;
            if (found == count)
                return swingList[i];
        }

        return Swing();
    }

    Swing _GetLastBullishSwing(const int count = -1) const {
        if (count < 0)
            return _GetLastSwing(SwingType::BULLISH);

        return _GetLastSwing(SwingType::BULLISH, count);
    }

    Swing _GetLastBearishSwing(const int count = -1) const {
        if (count < 0)
            return _GetLastSwing(SwingType::BEARISH);

        return _GetLastSwing(SwingType::BEARISH, count);
    }
};

Candle MarketStructureEngine::GetLastTop() const {
    return _GetLastBullishSwing().endCandle;
}

Candle MarketStructureEngine::GetLastDeep() const {
    return _GetLastBearishSwing().endCandle;
}

MarketStructureType MarketStructureEngine::DetectMarketStructure() const {
    Swing lastTop = _GetLastBullishSwing();
    Swing previousTop = _GetLastBullishSwing(1);
    Swing lastDeep = _GetLastBearishSwing();
    Swing previousDeep = _GetLastBearishSwing(1);

    const double lastTopPrice = lastTop.endCandle.high;
    const double previousTopPrice = previousTop.endCandle.high;
    const double lastDeepPrice = lastDeep.endCandle.low;
    const double previousDeepPrice = previousDeep.endCandle.low;

    const bool higherHigh = lastTopPrice > previousTopPrice;
    const bool higherLow = lastDeepPrice > previousDeepPrice;
    const bool lowerHigh = lastTopPrice < previousTopPrice;
    const bool lowerLow = lastDeepPrice < previousDeepPrice;

    if (higherHigh && higherLow)
        return MARKET_BULLISH;

    if (lowerHigh && lowerLow)
        return MARKET_BEARISH;

    return MARKET_RANGE;
}

bool MarketStructureEngine::DetectMarketBreak(const Candle& candle) const {
    const MarketStructureType structure = DetectMarketStructure();

    if (structure == MARKET_BULLISH) {
        const Swing lastDeep = _GetLastBearishSwing();
        return candle.close < lastDeep.endCandle.low;
    }

    if (structure == MARKET_BEARISH) {
        const Swing lastTop = _GetLastBullishSwing();
        return candle.close > lastTop.endCandle.high;
    }

    return false;
}
