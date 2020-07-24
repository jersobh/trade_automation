//+------------------------------------------------------------------+
//|                                                       Kratos.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include "TradeUtils.mq5";

CTrade trader;

// input
enum OPERATION {
   DOLAR,
   INDICE
};
input const OPERATION operation;
input const int gain_rating = 100;
input const int loss_rating = 100;
input const double contracts_number = 1;
input const int max_loss_allowed = 3;

// static and consts
static bool max_loss_reached = false;
static double day_gain = 0.0;
static double day_loss = 0.0;
static datetime last_deal = TimeCurrent();
static string last_position = "";
static const string START_TRADE_TIME = "09:30:00";
static const string END_TRADE_TIME = "17:30:00";
static const string COMMENT = "KRATOS";

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
   BuildDisplay();
   
   if(PositionsTotal() == 0)
     {
      string position = ShouldPlacePosition();

      if(position != "")
        {
         PerformTrade(position);
         last_position = position;
        }
     }
   else
     {
      PlaceLossAtEntracePrice();
      
      bool should_close_position = ShouldClosePosition();

      if(should_close_position)
        {
         ClosePositions(contracts_number, COMMENT);
         last_position = "";
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ShouldPlacePosition()
  {
   MqlRates prices[];
   GetPrices(prices,10);

   if(!IsTradingTime(START_TRADE_TIME, END_TRADE_TIME))
      return "";
      
   if(last_deal > TimeCurrent())
      return "";
      
   max_loss_reached = ShouldStopToTrade() >= max_loss_allowed;
   if(max_loss_reached)
      return "";

   bool sell_condition1 = SellAnalysis(prices, 0);
   bool sell_condition2 = SellAnalysis(prices, 1);
   if(sell_condition1 && !sell_condition2)
      return "sell";

   bool buy_condition1 = BuyAnalysis(prices, 0);
   bool buy_condition2 = BuyAnalysis(prices, 1);
   if(buy_condition1 && !buy_condition2)
      return "buy";

   return "";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellAnalysis(MqlRates &prices[], int index)
  {
   MqlRates price1 = prices[index];
   MqlRates price2 = prices[index+1];
   MqlRates price3 = prices[index+2];

   double ema21[], ema42[];
   GetEmaValues(ema21, 5, 3);
   GetEmaValues(ema42, 21, 3);

   double points = NormalizeDouble(MathAbs(price1.close-price2.low),_Digits);
   double operation_points = operation == INDICE ? (30*_Point) : (3000*_Point);

   bool result = ema21[0] < ema42[0] &&
                 price3.open < ema21[2] &&
                 price3.open < ema42[2] &&
                 price2.close < ema21[1] &&
                 price2.close < ema42[1] &&
                 price2.high > ema21[1] &&
                 price1.close < ema21[0] &&
                 price1.close < ema42[0] &&
                 price1.close < price2.low &&
                 points > operation_points;

   return result;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuyAnalysis(MqlRates &prices[], int index)
  {
   MqlRates price1 = prices[0];
   MqlRates price2 = prices[1];
   MqlRates price3 = prices[2];

   double ema21[], ema42[];
   GetEmaValues(ema21, 5, 3);
   GetEmaValues(ema42, 21, 3);

   double points = NormalizeDouble(MathAbs(price1.close-price2.low)/_Point,_Digits);
   double operation_points = operation == INDICE ? (30*_Point) : (3000*_Point);

   bool result = ema21[0] > ema42[0] &&
                 price3.open > ema21[2] &&
                 price3.open > ema42[2] &&
                 price2.close > ema21[1] &&
                 price2.close > ema42[1] &&
                 price2.low < ema21[1] &&
                 price1.close > ema21[0] &&
                 price1.close > ema42[0] &&
                 price1.close > price2.high &&
                 points > operation_points;

   return result;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PerformTrade(string position)
  {
   const double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   const double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   if(position == "buy")
     {
      const double gain = (ask + gain_rating * _Point);
      const double loss = (ask - loss_rating * _Point);

      trader.Buy(contracts_number, NULL, ask, loss, gain, COMMENT);
     }

   if(position == "sell")
     {
      const double gain = (bid - gain_rating * _Point);
      const double loss = (bid + loss_rating * _Point);

      trader.Sell(contracts_number, NULL, bid, loss, gain, COMMENT);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ShouldClosePosition()
  {
   MqlRates prices[];
   GetPrices(prices,2);

   double ema21[], ema42[];
   GetEmaValues(ema21, 5, 3);
   GetEmaValues(ema42, 21, 3);

   if(last_position == "buy")
      if(prices[1].close < ema21[1] && prices[1].close < ema42[1])
         return true;

   if(last_position == "sell")
     if(prices[1].close > ema21[1] && prices[1].close > ema42[1])
         return true;
         
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BuildDisplay()
  {
   Comment(COMMENT, 
           "\n\n| Gain: ", day_gain, 
           "\n| Loss: ", day_loss, 
           "\n| Next deal: ", last_deal, 
           "\n| Stop reached: ", max_loss_reached);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTrade()
  {
   last_deal = TimeCurrent() + 60;
  }
//+------------------------------------------------------------------+
