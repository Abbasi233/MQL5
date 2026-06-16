//+------------------------------------------------------------------+
//|                                           BacktestDbLogger.mqh    |
//|                    Reusable SQLite logger for MT5 backtests       |
//+------------------------------------------------------------------+
#property strict

class CBacktestDbLogger
{
private:
   int    m_db;
   string m_dbName;
   string m_lastError;

   string Escape(const string value)
   {
      string out = value;
      StringReplace(out, "'", "''");
      return out;
   }

   bool Exec(const string sql)
   {
      if(m_db == INVALID_HANDLE)
      {
         m_lastError = "DB handle invalid";
         return false;
      }

      if(!DatabaseExecute(m_db, sql))
      {
         m_lastError = "SQL failed. Err=" + IntegerToString(GetLastError());
         return false;
      }

      return true;
   }

public:
   CBacktestDbLogger() : m_db(INVALID_HANDLE), m_dbName(""), m_lastError("") {}

   string LastError() const { return m_lastError; }

   bool Init(const string dbName)
   {
      m_dbName = dbName;
      m_db = DatabaseOpen(dbName, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
      if(m_db == INVALID_HANDLE)
      {
         m_lastError = "DatabaseOpen failed. Err=" + IntegerToString(GetLastError());
         return false;
      }

      return EnsureSchema();
   }

   bool EnsureSchema()
   {
      string runsSql =
         "CREATE TABLE IF NOT EXISTS runs ("
         " run_uid TEXT PRIMARY KEY,"
         " created_at TEXT NOT NULL,"
         " test_tag TEXT,"
         " ea_name TEXT,"
         " symbol TEXT,"
         " timeframe INTEGER,"
         " magic INTEGER,"
         " use_trend_filter INTEGER,"
         " use_first_touch INTEGER,"
         " use_rr INTEGER,"
         " rr_value REAL,"
         " sl_points INTEGER,"
         " tp_points INTEGER,"
         " net_profit REAL,"
         " gross_profit REAL,"
         " gross_loss REAL,"
         " profit_factor REAL,"
         " expected_payoff REAL,"
         " recovery_factor REAL,"
         " total_trades INTEGER,"
         " equity_dd_abs REAL,"
         " equity_dd_rel REAL,"
         " balance_dd_abs REAL,"
         " balance_dd_rel REAL"
         ");";

      if(!Exec(runsSql))
         return false;

      string tradesSql =
         "CREATE TABLE IF NOT EXISTS trades ("
         " id INTEGER PRIMARY KEY AUTOINCREMENT,"
         " run_uid TEXT NOT NULL,"
         " deal_ticket INTEGER,"
         " position_id INTEGER,"
         " symbol TEXT,"
         " side TEXT,"
         " entry_type INTEGER,"
         " volume REAL,"
         " price REAL,"
         " profit REAL,"
         " swap REAL,"
         " commission REAL,"
         " deal_time TEXT,"
         " FOREIGN KEY(run_uid) REFERENCES runs(run_uid)"
         ");";

      return Exec(tradesSql);
   }

   bool BeginRun(const string pRunUid,
                 const string createdAt,
                 const string testTag,
                 const string eaName,
                 const string symbol,
                 const int timeframe,
                 const long magic,
                 const bool useTrendFilter,
                 const bool useFirstTouch,
                 const bool useRR,
                 const double rrValue,
                 const int slPoints,
                 const int tpPoints)
   {
      string sql = StringFormat(
         "INSERT OR REPLACE INTO runs (run_uid,created_at,test_tag,ea_name,symbol,timeframe,magic,use_trend_filter,use_first_touch,use_rr,rr_value,sl_points,tp_points)"
         " VALUES ('%s','%s','%s','%s','%s',%d,%I64d,%d,%d,%d,%.8f,%d,%d);",
         Escape(pRunUid),
         Escape(createdAt),
         Escape(testTag),
         Escape(eaName),
         Escape(symbol),
         timeframe,
         magic,
         useTrendFilter ? 1 : 0,
         useFirstTouch ? 1 : 0,
         useRR ? 1 : 0,
         rrValue,
         slPoints,
         tpPoints
      );

      return Exec(sql);
   }

   bool UpdateRunSummary(const string pRunUid,
                         const double netProfit,
                         const double grossProfit,
                         const double grossLoss,
                         const double profitFactor,
                         const double expectedPayoff,
                         const double recoveryFactor,
                         const int totalTrades,
                         const double equityDdAbs,
                         const double equityDdRel,
                         const double balanceDdAbs,
                         const double balanceDdRel)
   {
      string sql = StringFormat(
         "UPDATE runs SET net_profit=%.8f,gross_profit=%.8f,gross_loss=%.8f,profit_factor=%.8f,expected_payoff=%.8f,recovery_factor=%.8f,total_trades=%d,equity_dd_abs=%.8f,equity_dd_rel=%.8f,balance_dd_abs=%.8f,balance_dd_rel=%.8f"
         " WHERE run_uid='%s';",
         netProfit,
         grossProfit,
         grossLoss,
         profitFactor,
         expectedPayoff,
         recoveryFactor,
         totalTrades,
         equityDdAbs,
         equityDdRel,
         balanceDdAbs,
         balanceDdRel,
         Escape(pRunUid)
      );

      return Exec(sql);
   }

   bool LogDeal(const string pRunUid,
                const ulong dealTicket,
                const long positionId,
                const string symbol,
                const string side,
                const int entryType,
                const double volume,
                const double price,
                const double profit,
                const double swap,
                const double commission,
                const datetime dealTime)
   {
      string dealTimeStr = TimeToString(dealTime, TIME_DATE | TIME_SECONDS);
      string sql = StringFormat(
         "INSERT INTO trades (run_uid,deal_ticket,position_id,symbol,side,entry_type,volume,price,profit,swap,commission,deal_time)"
         " VALUES ('%s',%I64u,%I64d,'%s','%s',%d,%.8f,%.8f,%.8f,%.8f,%.8f,'%s');",
         Escape(pRunUid),
         dealTicket,
         positionId,
         Escape(symbol),
         Escape(side),
         entryType,
         volume,
         price,
         profit,
         swap,
         commission,
         Escape(dealTimeStr)
      );

      return Exec(sql);
   }

   void Close()
   {
      if(m_db != INVALID_HANDLE)
      {
         DatabaseClose(m_db);
         m_db = INVALID_HANDLE;
      }
   }
};
