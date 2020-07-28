//+------------------------------------------------------------------+
//|                                                      Maguila.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                  https://github.com/camilodsilva |
//+------------------------------------------------------------------+
#property copyright "Camilo Dias da Silva"
#property link      "https://github.com/camilodsilva"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include "../../Libraries/TradeUtils.mq5";

CTrade trade;

// inputs
input int stop_rating = 150;
input int profit_rating = 180;
input int loss_limit = 3;
input int contracts = 1;
input int ema1 = 21;
input int ema2 = 42;
input string stop_time = "17:30:00";

// configuration and controllers
static int position = -1;
static int last_position = position;
static int total_loss = 0;
static bool candle_touched = false;
static datetime last_check = TimeCurrent();
static const string COMMENT = "[MAGUILA]";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlRates current_price[];
   GetPrices(current_price, 10);

   bool stop_limit_reached = LossLimitReached();
   bool stop_time_reached = StopTimeReached(stop_time);

   Comment("** - EA - MAGUILA **\n",
           "\n| STOP LIMIT : ", stop_limit_reached,
           "\n| STOP TIME  : ", stop_time_reached);

   if(stop_limit_reached || stop_time_reached)
     {
      if(PositionsTotal() > 0)
        {
         double current_close_price = current_price[0].close;

         ClosePositions(current_close_price, contracts, COMMENT);
        }
      return;
     }

   const double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   const double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   if(PositionsTotal() == 0)
     {
      CheckEntry(current_price);

      if(position != -1)
        {
         if(WaitNextTime(current_price[0].time, last_check))
           {
            position = -1;
            return;
           }

         const double stop_buy   = (ask-stop_rating*_Point);
         const double take_buy   = (ask+profit_rating*_Point);
         const double stop_sell  = (bid+stop_rating*_Point);
         const double take_sell  = (bid-profit_rating*_Point);

         if(position == 1)
            trade.Buy(contracts,NULL,ask,stop_buy,take_buy,COMMENT);

         if(position == 0)
            trade.Sell(contracts,NULL, bid,stop_sell,take_sell,COMMENT);

         SetNextTime(current_price[0].time, last_check, 900);
         last_position = position;
         position = -1;
        }
     }
   else
     {
      // PlaceLossAtEntracePrice();
      if(CheckClosePosition(current_price))
        {
         if(HasOpenedOrders(COMMENT))
           {
            double current_close_price = current_price[0].close;

            ClosePositions(current_close_price, contracts, COMMENT);
            last_position = -1;
            position = -1;
           }
        }
     }
  }
//+------------------------------------------------------------------+
void GetPrices(MqlRates &price_info[], int range)
  {
   ArraySetAsSeries(price_info,true);
   CopyRates(Symbol(),Period(),0,range,price_info);
  }

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

   double ema21_array[];
   double ema42_array[];

   ArraySetAsSeries(ema21_array,true);
   ArraySetAsSeries(ema42_array,true);

   int ema21_definition=iMA(_Symbol,_Period,ema1,0,MODE_EMA,PRICE_CLOSE);
   int ema42_definition=iMA(_Symbol,_Period,ema2,0,MODE_EMA,PRICE_CLOSE);

   CopyBuffer(ema21_definition,0,0,1,ema21_array);
   CopyBuffer(ema42_definition,0,0,1,ema42_array);

   double ema21_value=NormalizeDouble(ema21_array[0],_Digits);
   double ema42_value=NormalizeDouble(ema42_array[0],_Digits);

// -- sell analysis
   bool sell_signal0 = SellSignal(price_info, 0, ema21_value, ema42_value);
   bool sell_signal1 = SellSignal(price_info, 1, ema21_value, ema42_value);
   bool sell_signal2 = SellSignal(price_info, 2, ema21_value, ema42_value);

   if(sell_signal0 && !sell_signal1 && sell_signal2)
      position = 0;

// -- buy analysis
   bool buy_signal0 = BuySignal(price_info, 0, ema21_value, ema42_value);
   bool buy_signal1 = BuySignal(price_info, 1, ema21_value, ema42_value);
   bool buy_signal2 = BuySignal(price_info, 2, ema21_value, ema42_value);

   if(buy_signal0 && !buy_signal1 && !buy_signal2)
      position = 1;

  }
//+------------------------------------------------------------------+
bool SellSignal(MqlRates &price_info[], int price_index, double ema21, double ema42)
  {
   MqlRates first_price    = price_info[price_index++];
   MqlRates second_price   = price_info[price_index++];
   MqlRates third_price    = price_info[price_index++];
   MqlRates fourth_price   = price_info[price_index++];
   MqlRates fifth_price    = price_info[price_index];

// media de 21 menor do que a media de 42?
   if(ema21 < ema42)
     {
      // fechamento quinta vela menor que media de 21
      // fechamento quart vela menor que media de 21
      // fechamento terceira vela menor que media de 21
      if(third_price.open < ema21 && second_price.close < ema42 )
        {
         // fechamento da vela anterior menor que media de 21?
         // fechamento da vela anterior menor que media de 42?
         // maxima da vela anterior tocou na media de 21?
         if(second_price.close < ema21 && second_price.high > ema21)
           {
            // abertura da vela atual menor que meida de 21?
            // vela atual perdeu a minima da vela anterior?
            if(first_price.open < ema21 && first_price.close < second_price.low)
              {
               double p1=NormalizeDouble(first_price.close,_Digits);
               double p2=NormalizeDouble(second_price.low,_Digits);
               double points=NormalizeDouble(MathAbs(p1-p2) / _Point, _Digits);

               if(points >= 50)
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
bool BuySignal(MqlRates &price_info[], int price_index, double ema21, double ema42)
  {
   MqlRates first_price    = price_info[price_index++];
   MqlRates second_price   = price_info[price_index++];
   MqlRates third_price    = price_info[price_index++];
   MqlRates fourth_price   = price_info[price_index++];
   MqlRates fifth_price    = price_info[price_index];

// media de 21 menor do que a media de 42?
   if(ema21 > ema42)
     {
      // fechamento quinta vela menor que media de 21
      // fechamento quart vela menor que media de 21
      // fechamento terceira vela menor que media de 21
      if(third_price.open > ema21 && second_price.close > ema42)
        {
         // fechamento da vela anterior menor que media de 21?
         // fechamento da vela anterior menor que media de 42?
         // maxima da vela anterior tocou na media de 21?
         if(second_price.close > ema21 && second_price.low < ema21)
           {
            // abertura da vela atual menor que meida de 21?
            // vela atual perdeu a minima da vela anterior?
            if(first_price.open > ema21 && first_price.close > second_price.high)
              {
               double p1=NormalizeDouble(first_price.close,_Digits);
               double p2=NormalizeDouble(second_price.high,_Digits);
               double points=NormalizeDouble(MathAbs(p1-p2) / _Point, _Digits);

               if(points >= 50)
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
void PlaceLossAtEntracePrice()
  {
   int positions = PositionsTotal()-1;

   for(int i=positions; i>=0; i--)
     {
      string symbol = PositionGetSymbol(i);

      if(symbol == _Symbol)
        {
         ulong position_ticket      = PositionGetInteger(POSITION_TICKET);
         double profit              = PositionGetDouble(POSITION_PROFIT);
         double open_price          = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_price       = PositionGetDouble(POSITION_PRICE_CURRENT);
         double current_stop_gain   = PositionGetDouble(POSITION_TP);
         int points                 = current_price-open_price;

         if(points > 100 && profit > 0)
           {
            trade.PositionModify(position_ticket, (open_price+50*_Point), current_stop_gain);
           }

         if(points < -100 && profit > 0)
           {
            trade.PositionModify(position_ticket, (open_price-50*_Point), current_stop_gain);
           }
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckClosePosition(MqlRates &price_info[])
  {
   double ema21_array[];
   double ema42_array[];

   ArraySetAsSeries(ema21_array,true);
   ArraySetAsSeries(ema42_array,true);

   int ema21_definition=iMA(_Symbol,_Period,ema1,0,MODE_EMA,PRICE_CLOSE);
   int ema42_definition=iMA(_Symbol,_Period,ema2,0,MODE_EMA,PRICE_CLOSE);

   CopyBuffer(ema21_definition,0,0,1,ema21_array);
   CopyBuffer(ema42_definition,0,0,1,ema42_array);

   double ema21_value=NormalizeDouble(ema21_array[0],_Digits);
   double ema42_value=NormalizeDouble(ema42_array[0],_Digits);

   MqlRates first_price = price_info[0];
   MqlRates second_price = price_info[1];

   if(last_position != -1)
     {
      // buy position
      if(last_position == 1)
        {
         if(second_price.close < ema21_value && second_price.close < ema42_value)
           {
            return true;
           }
        }

      // sell position
      if(last_position == 0)
        {
         if(second_price.close > ema21_value && second_price.close > ema42_value)
           {
            return true;
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
void OnTrade()
  {
   total_loss = StopLossAnalysis(COMMENT);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
