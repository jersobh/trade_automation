//+------------------------------------------------------------------+
//|                                                     Paula_V2.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Camilo Dias da Silva."
#property link "https://github.com/camilodsilva"
#property version "1.00"
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include "../../Libraries/TradeUtils.mq5";

CTrade trade;

// inputs
input int profit_rating = 150;
input int stop_rating = 150;
input int contracts = 1;
input int loss_limit = 3;
input string stop_time = "17:30:00";

// configuration and controllers
static bool stop_on_middle_band = false;
static int position = -1;
static int last_position = position;
static int total_loss = 0;
static datetime last_check = TimeCurrent();
static string display_content = "";
static const string COMMENT = "[PAULA]";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlRates current_price[];
   GetPrices(current_price, 10);

   bool stop_limit_reached = LossLimitReached();
   bool stop_time_reached = StopTimeReached(stop_time);

   if(stop_limit_reached || stop_time_reached)
     {
      if(PositionsTotal() > 0)
        {
         double current_close_price = current_price[0].close;

         ClosePositions(current_close_price, contracts, COMMENT);
        }
      return;
     }

   if(PositionsTotal() == 0)
     {
      if(last_position != -1 && WaitNextTime(current_price[0].time, last_check))
         return;
      else
         last_position = -1;

      CheckEntry(current_price);

      BuildDisplay(stop_limit_reached, stop_time_reached);

      if(position != -1)
        {
         const double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
         const double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
         const double stop_buy = (ask - stop_rating * _Point);
         const double take_buy = (ask + profit_rating * _Point);
         const double stop_sell = (bid + stop_rating * _Point);
         const double take_sell = (bid - profit_rating * _Point);
         display_content = "";

         if(position == 1)
            trade.Buy(contracts, NULL, ask, stop_buy, take_buy, COMMENT);

         if(position == 0)
            trade.Sell(contracts, NULL, bid, stop_sell, take_sell, COMMENT);

         SetNextTime(current_price[0].time, last_check, 120);
         last_position = position;
         position = -1;
        }
     }
   else
     {
      if(CheckClosePosition(current_price))
        {
         if(HasOpenedOrders(COMMENT))
           {
            double current_close_price = current_price[0].close;

            ClosePositions(current_close_price, contracts, COMMENT);
            position = -1;
            stop_on_middle_band = false;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetPrices(MqlRates &price_info[], int range)
  {
   ArraySetAsSeries(price_info, true);
   CopyRates(Symbol(), Period(), 0, range, price_info);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckEntry(MqlRates &price_info[])
  {
   double open_price = price_info[0].open;
   double close_price = price_info[1].close;
   bool is_gap = IsGap(open_price, close_price);

   if(is_gap)
     {
      SetNextTime(price_info[0].time, last_check, 900);
      return;
     }


   bool sell_signal0 = SellSignal(price_info, 0, 1, 2);

   if(sell_signal0)
     {
      stop_on_middle_band = StopOnMiddleBand(price_info);
      position = 0;
      return;
     }

   bool buy_signal0 = BuySignal(price_info, 0, 1, 2);

   if(buy_signal0)
     {
      stop_on_middle_band = StopOnMiddleBand(price_info);
      position = 1;
      return;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal(MqlRates &price_info[], int price_index0, int price_index1, int price_index2)
  {
   MqlRates first_price = price_info[price_index0];
   MqlRates second_price = price_info[price_index1];
   MqlRates third_price = price_info[price_index2];

   double upper_band_array[];

   ArraySetAsSeries(upper_band_array, true);

   int bollinger_bands_definition = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition, 1, 0, 3, upper_band_array);

   double upper_band_value0 = upper_band_array[0];
   double upper_band_value1 = upper_band_array[1];
   double upper_band_value2 = upper_band_array[2];

// primeiro fechamento menor que banda superior
// terceiro fechamento maior que banda superior
// segundo fechamento menor que banda superior
// primeiro fechamento menor que mínima do segundo
   if(third_price.close > upper_band_value2)
     {
      if(second_price.close < upper_band_value1)
        {
         if(first_price.close < upper_band_value0)
           {
            if(first_price.close < second_price.low)
              {
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal(MqlRates &price_info[], int price_index0, int price_index1, int price_index2)
  {
   MqlRates first_price = price_info[price_index0];
   MqlRates second_price = price_info[price_index1];
   MqlRates third_price = price_info[price_index2];

   double lower_band_array[];

   ArraySetAsSeries(lower_band_array, true);

   int bollinger_bands_definition = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition, 2, 0, 3, lower_band_array);

   double lower_band_value0 = lower_band_array[0];
   double lower_band_value1 = lower_band_array[1];
   double lower_band_value2 = lower_band_array[2];

// primeiro fechamento maior que banda inferior
// terceiro fechamento menor que banda inferior
// segundo fechamento maior que banda inferior
// primeiro fechamento maior que maxima do segundo
   if(third_price.close < lower_band_value2)
     {
      if(second_price.close > lower_band_value1)
        {
         if(first_price.close > lower_band_value0)
           {
            if(first_price.close > second_price.high)
              {
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckClosePosition(MqlRates &price_info[])
  {
   MqlRates current_price = price_info[0];
   MqlRates previous_price = price_info[0];

   double upper_band_array[];
   double middle_band_array[];
   double lower_band_array[];

   ArraySetAsSeries(upper_band_array, true);
   ArraySetAsSeries(middle_band_array, true);
   ArraySetAsSeries(lower_band_array, true);

   int bollinger_bands_definition = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition, 0, 0, 1, middle_band_array);
   CopyBuffer(bollinger_bands_definition, 1, 0, 1, upper_band_array);
   CopyBuffer(bollinger_bands_definition, 2, 0, 1, lower_band_array);

   double middle_band_value0 = middle_band_array[0];
   double upper_band_value0 = upper_band_array[0];
   double lower_band_value0 = lower_band_array[0];

   if(last_position != -1)
     {
      if(stop_on_middle_band)
        {
         // buy position
         if(last_position == 1)
           {
            if(current_price.close > middle_band_value0)
              {
               return true;
              }
           }

         // sell position
         if(last_position == 0)
           {
            if(current_price.close < middle_band_value0)
              {
               return true;
              }
           }
        }
      else
        {
         // buy position
         if(last_position == 1)
           {
            if(current_price.close > upper_band_value0)
              {
               return true;
              }
           }

         // sell position
         if(last_position == 0)
           {
            if(current_price.close < lower_band_value0)
              {
               return true;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LossLimitReached()
  {
   return total_loss >= loss_limit;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool StopOnMiddleBand(MqlRates &price_info[])
  {
   double middle_band_array[];

   ArraySetAsSeries(middle_band_array, true);

   int bollinger_bands_definition = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition, 0, 0, 1, middle_band_array);

   double middle_band_value0 = middle_band_array[0];
   double current_price = price_info[0].close;
   double middle_band_distance = NormalizeDouble(MathAbs(current_price - middle_band_value0) / _Point, _Digits);

   return middle_band_distance >= 120;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTrade()
  {
   total_loss = StopLossAnalysis(COMMENT);
  }
//+------------------------------------------------------------------+
void BuildDisplay(bool stop_limit_reached, bool stop_time_reached)
  {
   string header = BuildDisplayHeader(COMMENT, stop_limit_reached, stop_time_reached);

   Comment(header, "\n", display_content);
  }
//+------------------------------------------------------------------+
