#include <Library/Candle.mqh>
#include <Library/Swing/models/Swing.mqh>
#include <Library/Swing/models/SwingResult.mqh>

input int FurtherCandlesCount = 3; // Dönüşleri tespit etmek için ileriye bakılacak bar sayısı
input color SwingBullishColor = clrLime; // Bullish swing rengi
input color SwingBearishColor = clrRed; // Bearish swing rengi
input color SwingRangeColor = clrGray; // Range swing rengi
input int SwingLineWidth = 5; // Swing çizgi kalınlığı

enum SwingState {
    INITIAL,
    CANDIDATE,
    PROBABLE,
    CONFIRMED,
};

class SwingEngine {
  private:
    bool isSessionStarted;
    SwingState swingState;
    SwingResult swingResult;

    Candle candidateCandles[];
    Swing swingCache;

    color bullishColor;
    color bearishColor;
    color rangeColor;
    int lineWidth;

    static const string SwingLinePrefix;

  public:
    SwingEngine() {
        swingCache = Swing();
        swingState = INITIAL;
        ApplyVisualInputs();
    }

    void ApplyVisualInputs() {
        bullishColor = SwingBullishColor;
        bearishColor = SwingBearishColor;
        rangeColor = SwingRangeColor;
        lineWidth = SwingLineWidth;
        if (lineWidth < 1)
            lineWidth = 1;
    }

    SwingResult Solve(const Candle& candles[]);

    Swing getLastSwing();

    void DrawSwingLines(const long chartId);

    void ClearSwingLines(const long chartId);

  private:
    void _addCandidateCandle(const Candle& candle) {
        int size = ArraySize(candidateCandles);
        ArrayResize(candidateCandles, size + 1);
        candidateCandles[size] = candle;
    }

    void _addConfirmedSwing() {
        swingCache.startCandle = candidateCandles[0];
        swingCache.endCandle = candidateCandles[ArraySize(candidateCandles) - 1];

        int size = ArraySize(swingResult.swingList);
        ArrayResize(swingResult.swingList, size + 1);
        swingResult.swingList[size] = swingCache;

        swingCache = Swing();
    }

    void _clearCandidateCandles() {
        ArrayResize(candidateCandles, 0);
    }

    color _swingColor(const SwingType type) {
        if (type == BULLISH)
            return bullishColor;

        if (type == BEARISH)
            return bearishColor;

        return rangeColor;
    }

    // TODO: threshold koyup range aralığı belirlenebilir. Şu anda hiç range'e düşmüyor.
    SwingType _compareCandlesAndGetSwingType(Candle& currentCandle, Candle& previousCandle) {
        if (currentCandle.Center() > previousCandle.Center()) {
            return BULLISH;
        } else if (currentCandle.Center() < previousCandle.Center()) {
            return BEARISH;
        }

        return RANGE;
    }

    void _compareSwingType(Candle& currentCandle, Candle& previousCandle) {
        SwingType currentSwingType = _compareCandlesAndGetSwingType(currentCandle, previousCandle);
        if (swingCache.type == currentSwingType) {
            swingState = CANDIDATE;
            return;
        }

        swingState = PROBABLE;
    }
};

const string SwingEngine::SwingLinePrefix = "SWING_LINE_";

SwingResult SwingEngine::Solve(const Candle& candles[]) {
    swingState = INITIAL;
    swingCache = Swing();
    ArrayResize(candidateCandles, 0);
    ArrayResize(swingResult.swingList, 0);

    for (int i = 1; i < ArraySize(candles); i++) {
        Candle previousCandle = candles[i - 1];
        Candle currentCandle = candles[i];

        if (swingState == INITIAL) {
            swingState = CANDIDATE;
            swingCache.type = _compareCandlesAndGetSwingType(currentCandle, previousCandle);
        }

        _compareSwingType(currentCandle, previousCandle);

        if (swingState == CANDIDATE) {
            _addCandidateCandle(currentCandle);
            continue; 
        }

        int candlesCount = ArraySize(candles);
        int furtherCandlesIndex = 1;
        while (furtherCandlesIndex <= FurtherCandlesCount) {
            int lookIndex = i + furtherCandlesIndex;
            if (lookIndex >= candlesCount)
                break;

            Candle furtherCandle = candles[lookIndex];
            _compareSwingType(furtherCandle, currentCandle);

            if (swingState == CANDIDATE)
                break;

            furtherCandlesIndex++;
        }

        if (swingState == PROBABLE) {
            if (ArraySize(candidateCandles) > 0)
                _addConfirmedSwing();
            _clearCandidateCandles();
            // swingState = INITIAL;

            swingState = CANDIDATE;
            swingCache.type = _compareCandlesAndGetSwingType(currentCandle, previousCandle);
            _addCandidateCandle(currentCandle);
        }
    }

    return swingResult;
}

Swing SwingEngine::getLastSwing() {
    return swingResult.swingList[ArraySize(swingResult.swingList) - 1];
}

void SwingEngine::DrawSwingLines(const long chartId) {
    ClearSwingLines(chartId);

    for (int i = 0; i < ArraySize(swingResult.swingList); i++) {
        Swing swing = swingResult.swingList[i];
        datetime timeStart = swing.startCandle.time;
        datetime timeEnd = swing.endCandle.time;

        if (timeStart == 0 || timeEnd == 0 || timeStart == timeEnd)
            continue;

        string name = SwingLinePrefix + IntegerToString(i);
        double priceStart = swing.startCandle.Center();
        double priceEnd = swing.endCandle.Center();

        if (!ObjectCreate(chartId, name, OBJ_ARROWED_LINE, 0, timeStart, priceStart, timeEnd, priceEnd))
            continue;

        ObjectSetInteger(chartId, name, OBJPROP_COLOR, _swingColor(swing.type));
        ObjectSetInteger(chartId, name, OBJPROP_WIDTH, lineWidth);
        ObjectSetInteger(chartId, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(chartId, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(chartId, name, OBJPROP_BACK, false);
        ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
    }

    ChartRedraw(chartId);
}

void SwingEngine::ClearSwingLines(const long chartId) {
    ObjectsDeleteAll(chartId, SwingLinePrefix);
}
