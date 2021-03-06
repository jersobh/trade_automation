//+------------------------------------------------------------------+
//|                                                MovingAverage.mq5 |
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
input string stop_time = "17:30:00";

// configuration and controllers
static int position = -1;
static int last_position = position;
static int total_loss = 0;
static int next_trailing_target = 50;
static int trade_delay = 120;
static datetime last_check = TimeCurrent();
static string display_content = "";
static const string COMMENT = "[MAGUILA 2.0]";

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

   const double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   const double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   display_content = "";

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
         const double stop_buy   = (ask-stop_rating*_Point);
         const double take_buy   = (ask+profit_rating*_Point);
         const double stop_sell  = (bid+stop_rating*_Point);
         const double take_sell  = (bid-profit_rating*_Point);

         if(position == 1)
            trade.Buy(contracts,NULL,ask,stop_buy,take_buy,COMMENT);

         if(position == 0)
            trade.Sell(contracts,NULL, bid,stop_sell,take_sell,COMMENT);

         // to avoid negotiation after stop gain or loses
         SetNextTime(current_price[0].time, last_check, trade_delay);
         last_position = position;
         position = -1;
        }
     }
   else
     {
      PlaceLossAtEntracePrice();
      // next_trailing_target = CheckTrailingStop(next_trailing_target);

      if(CheckClosePosition(current_price))
        {
         if(HasOpenedOrders(COMMENT))
           {
            double current_close_price = current_price[0].close;

            ClosePositions(current_close_price, contracts, COMMENT);
            SetNextTime(current_price[0].time, last_check, trade_delay);
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
      SetNextTime(price_info[0].time, last_check, trade_delay);
      return;
     }

   double ema21[];
   double ema42[];
   double mg_ginley35[];

   GetEmaValues(ema21, 21, 3);
   GetEmaValues(ema42, 42, 3);
   GetMcGinleyValues(mg_ginley35, 35, 3);

   bool sell_signal0 = SellSignal(price_info, ema21, ema42, mg_ginley35, 0);

   if(sell_signal0) {
      position = 0;
      return;
   }

    bool buy_signal0 = BuySignal(price_info, ema21, ema42, mg_ginley35, 0);

   if(buy_signal0) {
      position = 1;
      return;
   }
  }
//+------------------------------------------------------------------+
bool SellSignal(MqlRates &price_info[], double &ema21[], double &ema42[], double &mc_ginley35[], int price_index)
  {
   MqlRates price0 = price_info[price_index];
   MqlRates price1 = price_info[price_index+1];
   MqlRates price2 = price_info[price_index+2];

   if(price0.open < mc_ginley35[0] && price0.close < mc_ginley35[0] &&
      price1.open < mc_ginley35[1] && price1.close < mc_ginley35[1] &&
      price2.open < mc_ginley35[2] && price2.close < mc_ginley35[2])
     {
      if(ema21[0] < ema42[0] &&
         ema21[1] < ema42[1] &&
         ema21[2] < ema42[2])
        {
         if(price0.close < ema21[0] && price0.close < price1.low)
           {
            if(price1.open < ema21[1] && price1.high > ema21[1])
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
bool BuySignal(MqlRates &price_info[], double &ema21[], double &ema42[], double &mc_ginley35[], int price_index)
  {
   MqlRates price0 = price_info[price_index];
   MqlRates price1 = price_info[price_index+1];
   MqlRates price2 = price_info[price_index+2];

   if(price0.open > mc_ginley35[0] && price0.close > mc_ginley35[0] &&
      price1.open > mc_ginley35[1] && price1.close > mc_ginley35[1] &&
      price2.open > mc_ginley35[2] && price2.close > mc_ginley35[2])
     {
      if(ema21[0] > ema42[0] &&
         ema21[1] > ema42[1] &&
         ema21[2] > ema42[2])
        {
         if(price0.close > ema21[0] && price0.close > price1.low)
           {
            if(price1.open > ema21[1] && price1.high < ema21[1])
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
   MqlRates price1 = price_info[0];
   MqlRates price2 = price_info[1];
   double ema21[];
   double ema42[];
   double mg_ginley35[];

   GetEmaValues(ema21, 21, 2);
   GetEmaValues(ema42, 42, 2);
   GetMcGinleyValues(mg_ginley35, 35, 2);

   if(last_position != -1)
     {
      // buy position
      if(last_position == 1)
        {
         if(price2.close < mg_ginley35[0])
           {
            return true;
           }
        }

      // sell position
      if(last_position == 0)
        {
         if(price2.close > mg_ginley35[0])
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
void BuildDisplay(bool stop_limit_reached, bool stop_time_reached)
  {
   string header = BuildDisplayHeader(COMMENT, stop_limit_reached, stop_time_reached);

   Comment(header, "\n", display_content);
  }
//+------------------------------------------------------------------+
void GetEmaValues(double &values[], int ema_period, int count)
  {
   double ema_array[];

   ArraySetAsSeries(ema_array,true);
   ArrayResize(values, count);

   int ema_definition=iMA(_Symbol,_Period,ema_period,0,MODE_EMA,PRICE_CLOSE);

   CopyBuffer(ema_definition,0,0,count,ema_array);

   for(int i=0; i<count; i++)
     {
      values[i] = ema_array[i];
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetMcGinleyValues(double &values[], int mg_ginley_period, int count)
  {
   double mg_ginley_array[];

   ArraySetAsSeries(mg_ginley_array,true);
   ArrayResize(values, count);

   int mg_ginley_definition=iCustom(_Symbol,_Period,"Market\\McGinley_Dynamic",mg_ginley_period);

   CopyBuffer(mg_ginley_definition,0,0,count,mg_ginley_array);

   for(int i=0; i<count; i++)
     {
      values[i] = mg_ginley_array[i];
     }
  }
//+------------------------------------------------------------------+
