//+------------------------------------------------------------------+
//|                                                        Tests.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>

CTrade trader;

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
void OnTick()
  {
   GetTradingRange(50);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTrade()
  {

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetTradingRange(int period)
  {
   double trading_range=0;
   int highest_candle, lowest_candle;
   double high[], low[];
   MqlRates price_info[];

   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(price_info,true);

   CopyHigh(_Symbol,_Period,0,period,high);
   CopyLow(_Symbol,_Period,0,period,low);

   highest_candle=ArrayMaximum(high,0,period);
   lowest_candle=ArrayMinimum(low,0,period);

   int data=CopyRates(_Symbol,_Period,0,Bars(_Symbol,_Period),price_info);

   ObjectCreate(_Symbol,"Line1",OBJ_HLINE,0,0,price_info[highest_candle].high);
   ObjectSetInteger(0,"Line1",OBJPROP_COLOR,clrMagenta);
   ObjectSetInteger(0,"Line1",OBJPROP_WIDTH,3);
   ObjectMove(_Symbol,"Line1",0,0,price_info[highest_candle].high);

   ObjectCreate(_Symbol,"Line2",OBJ_HLINE,0,0,price_info[lowest_candle].low);
   ObjectSetInteger(0,"Line2",OBJPROP_COLOR,clrMagenta);
   ObjectSetInteger(0,"Line2",OBJPROP_WIDTH,3);
   ObjectMove(_Symbol,"Line2",0,0,price_info[lowest_candle].low);

   trading_range=price_info[highest_candle].high-price_info[lowest_candle].low;

   Comment("Current trading range is: ",trading_range);

  }
//+------------------------------------------------------------------+
