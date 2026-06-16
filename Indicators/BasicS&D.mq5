//+------------------------------------------------------------------+
//|                                                     BasicS&D.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#define LIVELOG_REDIRECT
#include <LiveLog.mqh>
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 2

#property indicator_type1 DRAW_NONE // sadece EA için
#property indicator_type2 DRAW_NONE

input int zoneSizePoints = 10;           // zone kalınlığı
input int extendBars = 10;               // sağa uzatma
input int mergeDistancePoints = 150;     // dedupeNearbyZones=true iken kullanılır
input bool dedupeNearbyZones = false;    // true: yakın fiyatta ikinci zone çizilmez
input bool mergeOverlappingZones = true; // true: MergeZones — üst üste bineni birleştirir/siler
input int limit = 200;

// Beklenti (Expectancy) = (Kazanma Oranı X Ortalama Kar) - (Kaybetme Oranı X Ortalama Zarar)

double demandBuffer[];
double supplyBuffer[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
    ObjectsDeleteAll(0);
    SetIndexBuffer(0, demandBuffer);
    SetIndexBuffer(1, supplyBuffer);

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    ObjectsDeleteAll(0);
    LiveLogClose();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    if (rates_total < 5)
        return (0);

    if (rates_total < limit)
        Print("Yeterli Bar Yok.");

    CalculateZones(rates_total, prev_calculated, low, high, close, time);

    if (mergeOverlappingZones)
        MergeZones();
    
    return (rates_total);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateZones(const int rates_total, const int prev_calculated,
                    const double& low[], const double& high[], const double& close[],
                    const datetime& time[]) {
    int start = prev_calculated == 0 ? MathMax(2, rates_total - limit)
                                     : prev_calculated - 1;

    if (start < 2)
        start = 2;

    for (int i = start; i < rates_total - 1; i++) {
        demandBuffer[i] = EMPTY_VALUE;
        supplyBuffer[i] = EMPTY_VALUE;

        // --- SWING LOW → DEMAND ---
        if (low[i] < low[i - 1] && low[i] < low[i + 1]) {
            double lowPrice = low[i];
            double top = lowPrice + zoneSizePoints * _Point;

            string name = "Demand_" + IntegerToString(i);

            if (ObjectFind(0, name) == -1) {
                datetime t1 = time[i];
                datetime t2 = time[i] + PeriodSeconds() * extendBars;

                if (!dedupeNearbyZones || !ZoneExistsNearby(lowPrice, true)) {
                    if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, top, t2, lowPrice)) {
                        // ColorToARGB(AARRGGBB) OBJPROP_COLOR (MQL5 color) ile uyumsuz; renkler kayar.
                        ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
                        ObjectSetInteger(0, name, OBJPROP_FILL, true);
                        ObjectSetInteger(0, name, OBJPROP_BACK, true);
                        // SUNKEN/RAISED üst üste binince gölgeler birikir, çakışma simsiyah görünür.
                        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
                    }
                }
            }

            demandBuffer[i] = lowPrice;
        }
        // --- SWING HIGH → SUPPLY ---
        if (high[i] > high[i - 1] && high[i] > high[i + 1]) {
            double highPrice = high[i];
            double bottom = highPrice - zoneSizePoints * _Point;

            string name = "Supply_" + IntegerToString(i);

            if (ObjectFind(0, name) == -1) {
                datetime t1 = time[i];
                datetime t2 = time[i] + PeriodSeconds() * extendBars;

                if (!dedupeNearbyZones || !ZoneExistsNearby(highPrice, false)) {
                    if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, highPrice, t2, bottom)) {
                        ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
                        ObjectSetInteger(0, name, OBJPROP_FILL, true);
                        ObjectSetInteger(0, name, OBJPROP_BACK, true);
                        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
                    }
                }
            }

            supplyBuffer[i] = highPrice;
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ZoneExistsNearby(double price, bool isDemand) {
    int total = ObjectsTotal(0);
    string name = isDemand ? "Demand_" : "Supply_";

    for (int i = 0; i < total; i++) {
        string name = ObjectName(0, i);

        if (isDemand && StringFind(name, "Demand_") == -1)
            continue;

        if (!isDemand && StringFind(name, "Supply_") == -1)
            continue;

        double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
        double p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

        double top = MathMax(p1, p2);
        double bottom = MathMin(p1, p2);

        double mid = (top + bottom) / 2.0;

        if (MathAbs(mid - price) <= mergeDistancePoints * _Point)
            return true;
    }

    return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOverlap(double a_top, double a_bottom, double b_top, double b_bottom) {
    return !(a_bottom > b_top || a_top < b_bottom);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNear(double a_top, double a_bottom, double b_top, double b_bottom) {
    double threshold = 10 * _Point;

    return (MathAbs(a_top - b_bottom) < threshold ||
            MathAbs(a_bottom - b_top) < threshold);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MergeZones() {
    int total = ObjectsTotal(0);

    for (int i = 0; i < total; i++) {
        string nameA = ObjectName(0, i);

        if (ObjectGetInteger(0, nameA, OBJPROP_TYPE) != OBJ_RECTANGLE)
            continue;

        if (StringFind(nameA, "Demand_") != 0 && StringFind(nameA, "Supply_") != 0)
            continue;

        double a1 = ObjectGetDouble(0, nameA, OBJPROP_PRICE, 0);
        double a2 = ObjectGetDouble(0, nameA, OBJPROP_PRICE, 1);

        double a_top = MathMax(a1, a2);
        double a_bottom = MathMin(a1, a2);

        for (int j = i + 1; j < total; j++) {
            string nameB = ObjectName(0, j);

            if (ObjectGetInteger(0, nameB, OBJPROP_TYPE) != OBJ_RECTANGLE)
                continue;

            if (StringFind(nameB, "Demand_") != 0 && StringFind(nameB, "Supply_") != 0)
                continue;

            double b1 = ObjectGetDouble(0, nameB, OBJPROP_PRICE, 0);
            double b2 = ObjectGetDouble(0, nameB, OBJPROP_PRICE, 1);

            double b_top = MathMax(b1, b2);
            double b_bottom = MathMin(b1, b2);

            if (IsOverlap(a_top, a_bottom, b_top, b_bottom) ||
                IsNear(a_top, a_bottom, b_top, b_bottom)) {
                double newTop = MathMax(a_top, b_top);
                double newBottom = MathMin(a_bottom, b_bottom);

                // A'yı güncelle
                ObjectSetDouble(0, nameA, OBJPROP_PRICE, 0, newTop);
                ObjectSetDouble(0, nameA, OBJPROP_PRICE, 1, newBottom);

                // B'yi sil
                ObjectDelete(0, nameB);

                total = ObjectsTotal(0);
                j--;
            }
        }
    }
}
//+------------------------------------------------------------------+

void ClearOldZones() {
    int total = ObjectsTotal(0);
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i);

        if (StringFind(name, "Demand_") == 0 || StringFind(name, "Supply_") == 0)
            ObjectDelete(0, name);
    }
}