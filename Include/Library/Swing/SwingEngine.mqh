#include <Library/Candle.mqh>
#include <Library/Swing/models/Swing.mqh>
#include <Library/Swing/models/SwingResult.mqh>

input int FurtherCandlesCount = 3;         // Dönüşleri tespit etmek için ileriye bakılacak bar sayısı
input int SwingLineWidth = 5;              // Swing çizgi kalınlığı
input color SwingBullishColor = clrLime; // Bullish swing rengi
input color SwingBearishColor = clrRed;  // Bearish swing rengi
input color SwingRangeColor = clrGray;   // Range swing rengi

enum SwingState {
    INITIAL,
    CANDIDATE,
    PROBABLE,
    CONFIRMED,
};

class SwingEngine {
  private:
    bool initialized;
    SwingState swingState;
    SwingResult swingResult;

    Candle candidateCandles[];
    Candle probableCandles[];
    Swing swingCache;
    datetime lastProcessedCandleTime;

    color bullishColor;
    color bearishColor;
    color rangeColor;
    int lineWidth;

    static const string SwingLinePrefix;

  public:
    SwingEngine() {
        initialized = false;
        swingCache = Swing();
        swingState = INITIAL;
        lastProcessedCandleTime = 0;
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

    bool IsInitialized() {
        return initialized;
    }

    SwingResult Initialize(const Candle& candles[]);

    SwingResult Update(const Candle& candles[]);

    Swing getLastSwing();

    void DrawSwingLines(const long chartId);

    void DrawLastSwingLine(const long chartId);

    void ClearSwingLines(const long chartId);

  private:
    void _addCandidateCandle(const Candle& candle) {
        int size = ArraySize(candidateCandles);
        ArrayResize(candidateCandles, size + 1);
        candidateCandles[size] = candle;

        if (size == 0)
            swingCache.startCandle = candle;
        swingCache.endCandle = candle;
    }

    void _addProbableCandle(const Candle& candle) {
        int size = ArraySize(probableCandles);
        ArrayResize(probableCandles, size + 1);
        probableCandles[size] = candle;
    }

    void _addConfirmedSwing() {
        swingCache.startCandle = candidateCandles[0];
        swingCache.endCandle = candidateCandles[ArraySize(candidateCandles) - 1];

        int size = ArraySize(swingResult.swingList);
        ArrayResize(swingResult.swingList, size + 1);
        swingResult.swingList[size] = swingCache;
    }

    void _clearCandidateCandles() {
        ArrayResize(candidateCandles, 0);
    }

    void _clearProbableCandles() {
        ArrayResize(probableCandles, 0);
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

    int _findCandleIndexByTime(const Candle& candles[], const datetime time) const {
        for (int i = 0; i < ArraySize(candles); i++) {
            if (candles[i].time == time)
                return i;
        }

        return -1;
    }

    void _startCandidate(const Candle& candle, const SwingType type) {
        swingCache = Swing();
        swingCache.type = type;
        _clearCandidateCandles();
        _addCandidateCandle(candle);
        _clearProbableCandles();
            swingState = CANDIDATE;
        }

    void _startProbable(const Candle& candle, const SwingType type) {
        _clearProbableCandles();
        _addProbableCandle(candle);
        swingState = PROBABLE;
    }

    void _confirmCandidateAndPromoteProbable() {
        if (ArraySize(candidateCandles) > 0)
            _addConfirmedSwing();

        _clearCandidateCandles();
        swingCache = Swing();

        for (int i = 0; i < ArraySize(probableCandles); i++) {
            _addCandidateCandle(probableCandles[i]);

            if (i == 0)
                continue;

            swingCache.type = _compareCandlesAndGetSwingType(probableCandles[i], probableCandles[i - 1]);
        }

        _clearProbableCandles();
        swingState = CANDIDATE;
    }

    void _processFrom(const Candle& candles[], const int startIndex) {
        for (int i = startIndex; i < ArraySize(candles); i++) {
            Candle previousCandle = ArraySize(candidateCandles) > 0 ? candidateCandles[ArraySize(candidateCandles) - 1] : candles[i - 1];
            Candle currentCandle = candles[i];
            SwingType currentSwingType = _compareCandlesAndGetSwingType(currentCandle, previousCandle);

            if (swingState == INITIAL) {
                _startCandidate(currentCandle, currentSwingType);
                lastProcessedCandleTime = currentCandle.time;
                continue;
            }

            if (swingState == CANDIDATE) {
                if (currentSwingType == swingCache.type)
                    _addCandidateCandle(currentCandle);
                else
                    _startProbable(currentCandle, currentSwingType);

                lastProcessedCandleTime = currentCandle.time;
                continue;
            }

            if (currentSwingType == swingCache.type) {
                swingState = CANDIDATE;
                _addCandidateCandle(currentCandle);
                _clearProbableCandles();
            } else {
                _addProbableCandle(currentCandle);
                if (ArraySize(probableCandles) == FurtherCandlesCount)
                    _confirmCandidateAndPromoteProbable();
            }

            lastProcessedCandleTime = currentCandle.time;
        }
    }
};

const string SwingEngine::SwingLinePrefix = "SWING_LINE_";

SwingResult SwingEngine::Initialize(const Candle& candles[]) {
    initialized = false;
    swingState = INITIAL;
    swingCache = Swing();
    ArrayResize(candidateCandles, 0);
    ArrayResize(probableCandles, 0);
    ArrayResize(swingResult.swingList, 0);
    lastProcessedCandleTime = 0;

    if (ArraySize(candles) > 1) {
        _processFrom(candles, 1);
        initialized = true;
    }

    return swingResult;
}

SwingResult SwingEngine::Update(const Candle& candles[]) {
    if (!initialized)
        return Initialize(candles);

    int lastProcessedIndex = _findCandleIndexByTime(candles, lastProcessedCandleTime);
    if (lastProcessedIndex < 0)
        return Initialize(candles);

    int startIndex = lastProcessedIndex + 1;
    if (startIndex >= ArraySize(candles))
        return swingResult;

    _processFrom(candles, startIndex);
    return swingResult;
}

Swing SwingEngine::getLastSwing() {
    return swingResult.swingList[ArraySize(swingResult.swingList) - 1];
}

void SwingEngine::DrawSwingLines(const long chartId) {
    ClearSwingLines(chartId);

    for (int i = 0; i < ArraySize(swingResult.swingList); i++) {
        Swing swing = swingResult.swingList[i];
        datetime startTime = swing.startCandle.time;
        datetime endTime = swing.endCandle.time;

        if (startTime == 0 || endTime == 0 || startTime == endTime)
            continue;

        string name = SwingLinePrefix + IntegerToString(i);
        double priceStart = swing.startCandle.Center();
        double priceEnd = swing.endCandle.Center();

        if (!ObjectCreate(chartId, name, OBJ_ARROWED_LINE, 0, startTime, priceStart, endTime, priceEnd))
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

void SwingEngine::DrawLastSwingLine(const long chartId) {
    Swing lastSwing = getLastSwing();
    datetime startTime = lastSwing.startCandle.time;
    datetime endTime = lastSwing.endCandle.time;

    if (startTime == 0 || endTime == 0 || startTime == endTime)
        return;

    string name = SwingLinePrefix + IntegerToString((long)lastSwing.endCandle.time);
    double priceStart = lastSwing.startCandle.Center();
    double priceEnd = lastSwing.endCandle.Center();

    if (!ObjectCreate(chartId, name, OBJ_ARROWED_LINE, 0, startTime, priceStart, endTime, priceEnd))
        return;

    ObjectSetInteger(chartId, name, OBJPROP_COLOR, _swingColor(lastSwing.type));
    ObjectSetInteger(chartId, name, OBJPROP_WIDTH, lineWidth);
    ObjectSetInteger(chartId, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(chartId, name, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(chartId, name, OBJPROP_BACK, false);
    ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
}

void SwingEngine::ClearSwingLines(const long chartId) {
    ObjectsDeleteAll(chartId, SwingLinePrefix);
}
