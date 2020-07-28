//+------------------------------------------------------------------+
//|                                                I_PriceAction.mq5 |
//|                                             Camilo Dias da Silva |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Camilo Dias da Silva"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   Comment(close[0]);
   return(rates_total);
  }
//+------------------------------------------------------------------+
