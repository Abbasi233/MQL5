//+------------------------------------------------------------------+
//|                                      1_CandleClassification.mq5   |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#property copyright "Checklist Indicator 1"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 3

#property indicator_label1 "Rally"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrLime
#property indicator_width1 1

#property indicator_label2 "Drop"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrTomato
#property indicator_width2 1

#property indicator_label3 "Base"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrDodgerBlue
#property indicator_width3 1

input int AvgRangePeriod = 14;         // Ortalama mum araligi periyodu
input double ImpulseMultiplier = 1.20; // Impulsif kabul edilmesi icin range katsayisi
input double MinBodyRatio = 0.60;      // Impulsif mum icin minimum govde/range orani
input int MaxLookbackBars = 250;       // Hesaplanacak maksimum bar
input int atrLookback = 14;            // ATR'nin bakacağı geçmiş mum sayısı

double RallyBuffer[];
double DropBuffer[];
double BaseBuffer[];

int atrHandle; // ATR indikatörünün kimlik numarası
string BaseObjectPrefix = "RBD_BASE_";

enum CANDLE_TYPE {
    CANDLE_BASE,
    CANDLE_RALLY,
    CANDLE_DROP,
    CANDLE_NEUTRAL
};

int OnInit() {
    SetIndexBuffer(0, RallyBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, DropBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, BaseBuffer, INDICATOR_DATA); 

    PlotIndexSetInteger(0, PLOT_ARROW, 233);
    PlotIndexSetInteger(1, PLOT_ARROW, 234);
    PlotIndexSetInteger(2, PLOT_ARROW, 159);

    // OnCalculate'ta time/open/... dizileri varsayilan olarak kronolojik (0 = en eski mum).
    // Buffer ile ayni indekslemenin eslesmesi icin seri modunu kapali tutuyoruz.
    ArraySetAsSeries(RallyBuffer, false);
    ArraySetAsSeries(DropBuffer, false);
    ArraySetAsSeries(BaseBuffer, false);

    // _Symbol: Mevcut parite (örn: EURUSD)
    // _Period: Mevcut zaman dilimi (örn: H1)
    // 14: ATR'nin bakacağı geçmiş mum sayısı
    atrHandle = iATR(_Symbol, _Period, atrLookback);

    if (atrHandle == INVALID_HANDLE) {
        Print("ATR indikatörü yüklenemedi!");
        return (INIT_FAILED);
    }

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    ObjectsDeleteAll(0);
    LiveLogClose();
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
    // 1. ATR verilerini depolamak için dizi
    double atrArray[];
    ArraySetAsSeries(atrArray, true);

    // Tüm ATR verisini kopyalamak yerine gereken kadarını alıyoruz
    if (CopyBuffer(atrHandle, 0, 0, rates_total, atrArray) <= 0)
        return 0;

    int start = prev_calculated == 0 ? MathMax(2, rates_total - MaxLookbackBars)
                                     : prev_calculated - 1;
    if (start < 1)
        start = 1;

    // 3. Ana Döngü: Geçmişten bugüne tüm mumları tarar
    for (int i = start; i < rates_total - 1; i++) {
        RallyBuffer[i] = EMPTY_VALUE;
        DropBuffer[i] = EMPTY_VALUE;
        BaseBuffer[i] = EMPTY_VALUE;

        /*
           ÖNEMLİ NOT: rates_total içindeki diziler (open, close vb.)
           varsayılan olarak AS_SERIES (yani 0 en yeni) DEĞİLDİR.
           Bu yüzden indeksi doğru yönetmeliyiz.
        */

        // Mevcut mumun ATR değerini çekiyoruz.
        // iATR verisi CopyBuffer ile çekildiği için indeks senkronizasyonuna dikkat edilmeli.
        // Genellikle CopyBuffer verisi AsSeries yapıldığı için i değerini terse çevirmek gerekebilir:
        int atrIdx = rates_total - 1 - i;
        double currentATR = atrArray[atrIdx];

        // Sınıflandırma metodunu çağırıyoruz
        CANDLE_TYPE type = ClassifyCandle(open[i], high[i], low[i], close[i], currentATR, 0.50);

        double markerOffset = currentATR * 0.10;
        if (markerOffset <= 0.0)
            markerOffset = (high[i] - low[i]) * 0.20;

        string baseObjectName = BaseObjectPrefix + IntegerToString((int)time[i]);
        if (ObjectFind(0, baseObjectName) != -1)
            ObjectDelete(0, baseObjectName);

            
        if (type == CANDLE_RALLY) {
            RallyBuffer[i] = low[i] - markerOffset;
        } else if (type == CANDLE_DROP) {
            DropBuffer[i] = high[i] + markerOffset;
        } else if (type == CANDLE_BASE) {
            double midPrice = (open[i] + close[i]) * 0.50;
            double halfHeight = MathMax((high[i] - low[i]) * 0.08, _Point * 3);
            // Sag kenar: bir sonraki mumun acilisi (kronolojik time[] ile uyumlu).
            datetime time2 = (i + 1 < rates_total) ? time[i + 1] : (time[i] + PeriodSeconds());
            if (time2 <= time[i])
                time2 = time[i] + PeriodSeconds();

            if (ObjectCreate(0, baseObjectName, OBJ_RECTANGLE, 0, time[i], midPrice + halfHeight, time2, midPrice - halfHeight)) {
                ObjectSetInteger(0, baseObjectName, OBJPROP_COLOR, clrDodgerBlue);
                ObjectSetInteger(0, baseObjectName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, baseObjectName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, baseObjectName, OBJPROP_FILL, true);
                ObjectSetInteger(0, baseObjectName, OBJPROP_BACK, false);
            }
        }

        // Son durumu ekrana yaz
        if (i == rates_total - 2) // Son kapanmış mum
        {
            if (type == CANDLE_RALLY)
                Comment("Şu anki durum: RALLY");
            if (type == CANDLE_BASE)
                Comment("Şu anki durum: BASE");
            if (type == CANDLE_DROP)
                Comment("Şu anki durum: DROP");
        }
    }

    return rates_total;
}

CANDLE_TYPE ClassifyCandle(double open, double high, double low, double close, double currentATR, double bodyThreshold = 0.50) {
    double range = high - low;

    // 1. Sıfıra bölünme hatasını (Divide by Zero) önleme
    if (range == 0.0)
        return CANDLE_BASE;

    double body = MathAbs(open - close);
    double bodyRatio = body / range;

    // 2. BASE MUM KONTROLÜ
    // Gövde, toplam boyun %50'sinden küçükse bu bir Base (Duraksama) mumudur.
    if (bodyRatio < bodyThreshold) {
        return CANDLE_BASE;
    }

    // 3. RALLY VE DROP KONTROLÜ
    // Gövde büyük, peki mumun toplam boyu piyasa ortalamasından (ATR) büyük mü?
    // (ATR çarpanını stratejinize göre 1.0, 1.2, 1.5 olarak esnetebilirsiniz)
    if (bodyRatio >= bodyThreshold && range >= (currentATR * 1.0)) {
        if (close > open) {
            return CANDLE_RALLY; // Sert Yükseliş
        } else if (close < open) {
            return CANDLE_DROP; // Sert Düşüş
        }
    }

    // 4. Şartları sağlamayan ufak ama gövdeli mumlar
    return CANDLE_NEUTRAL;
}

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