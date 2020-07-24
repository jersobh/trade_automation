//+------------------------------------------------------------------+
//|                                                     Paula_V3.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include "PROD_TradeUtils.mq5";

CTrade trader;

// input
enum OPERATION {
   DOLAR,
   INDICE
};
input const OPERATION operation;
input const int gain_rating = 100;
input const int loss_rating = 100;
input const int contracts_number = 1;
input const double max_loss_allowed = 20.0;

// static and consts
static bool should_close_on_middle_band = false;
static bool max_loss_reached = false;
static double day_gain = 0.0;
static double day_loss = 0.0;
static datetime last_deal = TimeCurrent();
static string last_position = "";
static const string START_TRADE_TIME = "09:30:00";
static const string END_TRADE_TIME = "17:30:00";
static const string COMMENT = "PAULA";

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
         should_close_on_middle_band = false;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ShouldPlacePosition()
  {
   MqlRates prices[];
   GetPrices(prices,3);

   if(!IsTradingTime(START_TRADE_TIME, END_TRADE_TIME))
      return "";

   max_loss_reached = ShouldStopToTrade() >= max_loss_allowed;
   if(max_loss_reached)
      return "";

   if(last_deal > TimeCurrent())
      return "";

   bool sell = SellAnalysis(prices);
   if(sell)
     {
      should_close_on_middle_band = ShouldStopOnMiddleBand(prices);
      return "sell";
     }

   bool buy = BuyAnalysis(prices);
   if(buy)
     {
      should_close_on_middle_band = ShouldStopOnMiddleBand(prices);
      return "buy";
     }

   return "";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellAnalysis(MqlRates &prices[])
  {
   MqlRates first = prices[0];
   MqlRates second = prices[1];
   MqlRates third = prices[2];

   double lower[], middle[], upper[];
   GetBollingerBandsValues(lower, middle, upper, 20, 3);

   double points = NormalizeDouble(MathAbs(first.close-second.low),_Digits);
   double operation_points = operation == INDICE ? (30*_Point) : (3000*_Point);

   bool result = third.close > upper[2] &&
                 second.close < upper[1] &&
                 first.close < upper[0] &&
                 first.close > middle[0] &&
                 first.close < second.low &&
                 points > operation_points;

   return result;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuyAnalysis(MqlRates &prices[])
  {
   MqlRates first = prices[0];
   MqlRates second = prices[1];
   MqlRates third = prices[2];

   double lower[], middle[], upper[];
   GetBollingerBandsValues(lower, middle, upper, 20, 3);

   double points = NormalizeDouble(MathAbs(first.close-second.high),_Digits);
   double operation_points = operation == INDICE ? (30*_Point) : (3000*_Point);

   bool result = third.close < lower[2] &&
                 second.close > lower[1] &&
                 first.close > lower[0] &&
                 first.close < middle[0] &&
                 first.close > second.high &&
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

   double lower[], middle[], upper[];
   GetBollingerBandsValues(lower, middle, upper, 20, 1);

   if(last_position == "buy")
     {
      // -- profit
      if(should_close_on_middle_band)
         if(prices[0].close > middle[0])
            return true;

      // -- profit
      if(prices[0].close > upper[0])
         return true;
      // -- loss
      if(prices[1].close < lower[0])
         return true;
     }

   if(last_position == "sell")
     {
      // -- profit
      if(should_close_on_middle_band)
         if(prices[0].close < middle[0])
            return true;

      // -- profit
      if(prices[0].close < lower[0])
         return true;
      // -- loss
      if(prices[1].close > upper[0])
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ShouldStopOnMiddleBand(MqlRates &price_info[])
  {
   MqlRates price = price_info[0];

   double lower[], middle[], upper[];
   GetBollingerBandsValues(lower, middle, upper, 20, 3);

   double middle_band_distance = NormalizeDouble(MathAbs(price.close-middle[0])/_Point,_Digits);

   return middle_band_distance >= 120;
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
