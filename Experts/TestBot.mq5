//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <zone_detector.mqh>
#include <signal_engine.mqh>
#include <trade_executor.mqh>
#include <Controls\Dialog.mqh>

Zone demandZone;
Zone supplyZone;

CAppDialog AppWindow;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   DetectDemandZone(demandZone);
   DetectSupplyZone(supplyZone);

//--- create application dialog
   if(!AppWindow.Create(0,"AppWindow",0,20,20,360,324))
      return(INIT_FAILED);
//--- run application
   AppWindow.Run();
//--- succeed

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy dialog
   AppWindow.Destroy(reason);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(CheckBuySignal(price, demandZone))
     {
      Print("Entered BUY");
      OpenBuy(demandZone);
      demandZone.isFresh = false;
     }

   if(CheckSellSignal(price, supplyZone))
     {
      Print("Entered SELL");
      OpenSell(supplyZone);
      supplyZone.isFresh = false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {

   AppWindow.ChartEvent(id,lparam,dparam,sparam);
//Print(ChartGetInteger(chart_ID,CHART_VISIBLE_BARS,0,result));
   if(id == CHARTEVENT_KEYUP)
     {
      int visibleBars = ChartVisibleBars();
      Print("Visible Bars ", visibleBars);

      Print(_Period);

      MqlRates rates[];
      CopyRates(_Symbol, _Period, 0, 100, rates);
      Print("");
     }
  }

//+----------------------------------------------------------------------+
//| Gets the number of bars that are displayed (visible) in chart window |
//+----------------------------------------------------------------------+
int ChartVisibleBars(const long chart_ID=0)
  {
//--- prepare the variable to get the property value
   long result=-1;
//--- reset the error value
   ResetLastError();
//--- receive the property value
   if(!ChartGetInteger(chart_ID,CHART_VISIBLE_BARS,0,result))
     {
      //--- display the error message in Experts journal
      Print(__FUNCTION__+", Error Code = ",GetLastError());
     }
//--- return the value of the chart property
   return((int)result);
  }
//+------------------------------------------------------------------+
