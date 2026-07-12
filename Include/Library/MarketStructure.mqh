//+------------------------------------------------------------------+
//|                                                      GexData.mqh |
//|                                      MMQ — Muhammad Minhas Qamar |
//|                                   www.mql5.com/en/articles/23410 |
//+------------------------------------------------------------------+
#property copyright "MMQ — Muhammad Minhas Qamar"
#property link "https://www.mql5.com/en/articles/23410"
#property version "1.00"

#ifndef GEX_GEXDATA_MQH
#define GEX_GEXDATA_MQH

#include <GEX/BlackScholes.mqh>

//+------------------------------------------------------------------+
//| One raw option quote, before it is aggregated into the profile.  |
//| It carries everything the gamma math needs: the strike, the      |
//| right, the time to expiry, and the open interest that scales a   |
//| contract's gamma into a real dealer exposure. The iv field is    |
//| filled by the provider (inverted from the price, or read from    |
//| the server) because gamma is a function of volatility.           |
//+------------------------------------------------------------------+
struct OptionQuote {
    ENUM_OPT_RIGHT right;
    double strike;
    datetime expiry;
    double price;         // market mid price
    double spot;          // underlying price
    double rate;          // risk-free rate
    double open_interest; // contracts outstanding at this strike
    double iv;            // filled in by the provider (-1 if invalid)
};

//+------------------------------------------------------------------+
//| The gamma-exposure profile for a single expiry. It reduces a     |
//| flat option chain to one number per strike: the net dealer gamma |
//| exposure (GEX) at that strike, positive where dealers are long   |
//| gamma and negative where they are short. From that profile it    |
//| derives the three levels traders actually read: the call wall    |
//| (largest positive GEX), the put wall (largest negative GEX), and |
//| the zero-gamma "flip" price where total exposure crosses zero.   |
//+------------------------------------------------------------------+
class CGexProfile {
  private:
    double m_strikes[];     // sorted unique strikes for the chosen expiry
    double m_gex[];         // signed dealer GEX per strike (aligned to m_strikes)
    OptionQuote m_quotes[]; // the quotes that survived onto the chosen expiry
    double m_spot;
    double m_multiplier; // contract size (100 for US equity options)
    datetime m_expiry;   // the single expiry this profile represents

    double m_netGex;           // sum of m_gex, the headline regime number
    double m_gexMin, m_gexMax; // most-negative / most-positive per-strike GEX
    double m_callWall;         // strike of the largest positive GEX
    double m_putWall;          // strike of the most-negative GEX
    double m_flip;             // zero-gamma price (<0 if none found)

  public:
    CGexProfile(void) : m_spot(0), m_multiplier(100.0), m_expiry(0),
                        m_netGex(0), m_gexMin(0), m_gexMax(0),
                        m_callWall(0), m_putWall(0), m_flip(-1.0) {
    }

    //--- accessors the renderer reads
    int NStrikes(void) const {
        return (ArraySize(m_strikes));
    }
    double Strike(const int i) const {
        return (m_strikes[i]);
    }
    double Gex(const int i) const {
        return (m_gex[i]);
    }
    double Spot(void) const {
        return (m_spot);
    }
    datetime Expiry(void) const {
        return (m_expiry);
    }
    double NetGex(void) const {
        return (m_netGex);
    }
    double GexMin(void) const {
        return (m_gexMin);
    }
    double GexMax(void) const {
        return (m_gexMax);
    }
    double CallWall(void) const {
        return (m_callWall);
    }
    double PutWall(void) const {
        return (m_putWall);
    }
    double Flip(void) const {
        return (m_flip);
    }

    void Multiplier(const double m) {
        m_multiplier = (m > 0.0) ? m : 100.0;
    }

    //--- build the profile; target is the expiry to use, or 0 for "nearest future"
    bool Build(OptionQuote& quotes[], const datetime target = 0);

  private:
    datetime PickExpiry(OptionQuote& quotes[], const datetime target) const;
    double DealerGammaAtSpot(const double S) const;
    double SolveFlip(void) const;
    int IndexOf(const double& arr[], const double v) const;
};

//+------------------------------------------------------------------+
//| Choose which expiry to profile. A GEX map is always a single     |
//| expiry (near-dated positioning is what pins index price), so we  |
//| either honour the caller's requested expiry or, when none is     |
//| given, take the nearest one still in the future. Expired         |
//| contracts never win here.                                        |
//+------------------------------------------------------------------+
datetime CGexProfile::PickExpiry(OptionQuote& quotes[], const datetime target) const {
    datetime now = TimeCurrent();
    if (now == 0)
        now = TimeLocal();

    datetime best = 0;
    double bestDist = 1e18;
    int n = ArraySize(quotes);
    for (int i = 0; i < n; i++) {
        datetime e = quotes[i].expiry;
        if (e <= now)
            continue; // never profile an expired contract
        //--- distance is "closeness to the requested expiry", or "closeness to now"
        double dist = (target > 0) ? MathAbs((double)(e - target)) : (double)(e - now);
        if (dist < bestDist) {
            bestDist = dist;
            best = e;
        }
    }
    return (best);
}

//+------------------------------------------------------------------+
//| Build the single-expiry profile. Pick the expiry, keep only the  |
//| quotes on it, collect the sorted unique strikes, then sum the    |
//| signed dealer GEX at each strike. The dealer-sign convention is  |
//| the standard one: dealers are assumed short calls and long puts  |
//| against the customer, so a call's gamma adds to exposure and a   |
//| put's subtracts. Per contract the exposure is                    |
//|     gamma * OI * multiplier * spot^2 * 0.01                      |
//| i.e. dollar gamma per 1% move in the underlying.                 |
//+------------------------------------------------------------------+
bool CGexProfile::Build(OptionQuote& quotes[], const datetime target) {
    int n = ArraySize(quotes);
    if (n == 0)
        return (false);

    m_spot = quotes[0].spot;
    m_expiry = PickExpiry(quotes, target);
    if (m_expiry == 0) {
        Print("CGexProfile: no future expiry to profile");
        return (false);
    }

    //--- keep only this expiry's usable quotes (valid IV, positive OI)
    ArrayResize(m_quotes, 0);
    ArrayResize(m_strikes, 0);
    for (int i = 0; i < n; i++) {
        if (quotes[i].expiry != m_expiry)
            continue;
        if (quotes[i].iv <= 0.0 || quotes[i].open_interest <= 0.0)
            continue; // no gamma or no size means no exposure
        int s = ArraySize(m_quotes);
        ArrayResize(m_quotes, s + 1);
        m_quotes[s] = quotes[i];
        if (IndexOf(m_strikes, quotes[i].strike) < 0) {
            int k = ArraySize(m_strikes);
            ArrayResize(m_strikes, k + 1);
            m_strikes[k] = quotes[i].strike;
        }
    }
    ArraySort(m_strikes);
    int nk = ArraySize(m_strikes);
    if (nk < 2) {
        Print("CGexProfile: fewer than 2 usable strikes on the chosen expiry");
        return (false);
    }

    //--- sum signed dealer GEX per strike, evaluated at the live spot
    datetime now = TimeCurrent();
    if (now == 0)
        now = TimeLocal();
    ArrayResize(m_gex, nk);
    ArrayInitialize(m_gex, 0.0);

    int nq = ArraySize(m_quotes);
    for (int i = 0; i < nq; i++) {
        double T = (double)(m_quotes[i].expiry - now) / (365.0 * 24 * 3600);
        if (T <= 0.0)
            continue;
        double g = BSGamma(m_spot, m_quotes[i].strike, m_quotes[i].rate, 0.0, m_quotes[i].iv, T);
        double contractGex = g * m_quotes[i].open_interest * m_multiplier * m_spot * m_spot * 0.01;
        double signed_ = (m_quotes[i].right == OPT_CALL) ? contractGex : -contractGex;
        int k = IndexOf(m_strikes, m_quotes[i].strike);
        if (k >= 0)
            m_gex[k] += signed_;
    }

    //--- derive the headline numbers and the walls from the per-strike profile
    m_netGex = 0.0;
    m_gexMin = 1e18;
    m_gexMax = -1e18;
    m_callWall = m_strikes[0];
    m_putWall = m_strikes[0];
    double maxPos = -1e18, maxNeg = 1e18;
    for (int k = 0; k < nk; k++) {
        m_netGex += m_gex[k];
        if (m_gex[k] < m_gexMin)
            m_gexMin = m_gex[k];
        if (m_gex[k] > m_gexMax)
            m_gexMax = m_gex[k];
        if (m_gex[k] > maxPos) {
            maxPos = m_gex[k];
            m_callWall = m_strikes[k];
        }
        if (m_gex[k] < maxNeg) {
            maxNeg = m_gex[k];
            m_putWall = m_strikes[k];
        }
    }

    //--- the zero-gamma flip: the spot at which total dealer gamma is zero
    m_flip = SolveFlip();
    PrintFormat("CGexProfile: expiry=%s strikes=%d netGEX=%.3g flip=%.2f callWall=%.2f putWall=%.2f",
                TimeToString(m_expiry, TIME_DATE), nk, m_netGex, m_flip, m_callWall, m_putWall);
    return (true);
}

//+------------------------------------------------------------------+
//| Total signed dealer gamma if the underlying were trading at S.   |
//| This is the same aggregation as Build, but with every contract's |
//| gamma re-evaluated at the hypothetical spot S (each keeps its    |
//| own implied volatility). Sweeping S through this function traces |
//| the exposure curve whose zero crossing is the flip level. We     |
//| return raw dealer gamma (not the spot^2-scaled dollar figure),   |
//| because only its sign and zero crossing matter here.             |
//+------------------------------------------------------------------+
double CGexProfile::DealerGammaAtSpot(const double S) const {
    datetime now = TimeCurrent();
    if (now == 0)
        now = TimeLocal();

    double total = 0.0;
    int nq = ArraySize(m_quotes);
    for (int i = 0; i < nq; i++) {
        double T = (double)(m_quotes[i].expiry - now) / (365.0 * 24 * 3600);
        if (T <= 0.0)
            continue;
        double g = BSGamma(S, m_quotes[i].strike, m_quotes[i].rate, 0.0, m_quotes[i].iv, T);
        double contrib = g * m_quotes[i].open_interest * m_multiplier;
        total += (m_quotes[i].right == OPT_CALL) ? contrib : -contrib;
    }
    return (total);
}

//+------------------------------------------------------------------+
//| Find the zero-gamma flip by scanning dealer gamma across a price |
//| band around spot and interpolating the first sign change. The    |
//| band spans the strikes we hold, widened a little so a flip just  |
//| outside the quoted strikes is still caught. If dealer gamma      |
//| never changes sign across the band there is no flip (a wholly    |
//| long- or short-gamma book), and we return a negative sentinel.   |
//+------------------------------------------------------------------+
double CGexProfile::SolveFlip(void) const {
    int nk = ArraySize(m_strikes);
    if (nk < 2)
        return (-1.0);

    double lo = m_strikes[0];
    double hi = m_strikes[nk - 1];
    double pad = 0.15 * (hi - lo); // widen the band by 15% each way
    lo -= pad;
    hi += pad;
    if (lo <= 0.0)
        lo = 0.01 * m_strikes[0];

    int steps = 400;
    double dx = (hi - lo) / steps;
    double prevS = lo;
    double prevG = DealerGammaAtSpot(lo);
    for (int i = 1; i <= steps; i++) {
        double s = lo + i * dx;
        double g = DealerGammaAtSpot(s);
        if ((prevG <= 0.0 && g > 0.0) || (prevG >= 0.0 && g < 0.0)) {
            //--- linear interpolation of the crossing between prevS and s
            double denom = (g - prevG);
            if (MathAbs(denom) < 1e-30)
                return (0.5 * (prevS + s));
            return (prevS - prevG * (s - prevS) / denom);
        }
        prevS = s;
        prevG = g;
    }
    return (-1.0); // no sign change: no flip in this band
}

//+------------------------------------------------------------------+
//| Linear search for a strike in the array. Uses a small tolerance  |
//| so float round-trips still match.                                |
//+------------------------------------------------------------------+
int CGexProfile::IndexOf(const double& arr[], const double v) const {
    int n = ArraySize(arr);
    for (int i = 0; i < n; i++)
        if (MathAbs(arr[i] - v) < 1e-6)
            return (i);
    return (-1);
}

//+------------------------------------------------------------------+
//| CSV provider. Reads a chain file from MQL5\Files with columns:   |
//|   right,strike,expiry,mid,spot,rate,oi                           |
//| where right is C/P and expiry is YYYY.MM.DD. Computes the        |
//| implied volatility for each row via Black-Scholes inversion so   |
//| the gamma aggregation downstream has a sigma to work with.       |
//+------------------------------------------------------------------+
class CGexProviderCSV {
  public:
    bool Load(const string filename, OptionQuote& out[]);
};

//+------------------------------------------------------------------+
//| Parse the CSV chain into a flat quote list, inverting each row's |
//| price to an implied volatility as it is read.                    |
//+------------------------------------------------------------------+
bool CGexProviderCSV::Load(const string filename, OptionQuote& out[]) {
    int h = FileOpen(filename, FILE_READ | FILE_CSV | FILE_ANSI, ',');
    if (h == INVALID_HANDLE) {
        PrintFormat("CGexProviderCSV: cannot open %s (err %d)", filename, GetLastError());
        return (false);
    }
    ArrayResize(out, 0);
    bool header = true;
    while (!FileIsEnding(h)) {
        string sRight = FileReadString(h);
        if (FileIsLineEnding(h) && StringLen(sRight) == 0)
            continue;
        string sStrike = FileReadString(h);
        string sExpiry = FileReadString(h);
        string sMid = FileReadString(h);
        string sSpot = FileReadString(h);
        string sRate = FileReadString(h);
        string sOi = FileReadString(h);
        if (header) {
            header = false; // skip the column titles
            continue;
        }
        if (StringLen(sStrike) == 0)
            continue;

        OptionQuote q;
        string rr = sRight;
        StringToUpper(rr);
        q.right = (StringFind(rr, "P") >= 0) ? OPT_PUT : OPT_CALL;
        q.strike = StringToDouble(sStrike);
        q.expiry = StringToTime(sExpiry);
        q.price = StringToDouble(sMid);
        q.spot = StringToDouble(sSpot);
        q.rate = StringToDouble(sRate);
        q.open_interest = StringToDouble(sOi);

        datetime now = TimeCurrent();
        if (now == 0)
            now = TimeLocal();
        double T = (double)(q.expiry - now) / (365.0 * 24 * 3600);
        q.iv = ImpliedVol(q.right, q.price, q.spot, q.strike, q.rate, 0.0, T);

        int s = ArraySize(out);
        ArrayResize(out, s + 1);
        out[s] = q;
    }
    FileClose(h);
    PrintFormat("CGexProviderCSV: loaded %d rows from %s", ArraySize(out), filename);
    return (ArraySize(out) > 0);
}

#endif // GEX_GEXDATA_MQH
//+------------------------------------------------------------------+
