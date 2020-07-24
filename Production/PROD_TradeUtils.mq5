//+------------------------------------------------------------------+
//|                                                   TradeUtils.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2020, Camilo Dias da Silva."
#property link "https://www.mql5.com"
#property version "1.00"
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>

CTrade utils_trade;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsGap(double open_price, double close_price)
  {
   double n_open_price = NormalizeDouble(open_price, _Digits);
   double n_close_proce = NormalizeDouble(close_price, _Digits);
   double n_points = NormalizeDouble(MathAbs(n_close_proce - n_open_price) / _Point, _Digits);

   if(n_points >= 250)
     {
      return true;
     }

   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool StopTimeReached(string time)
  {
   datetime current_time = TimeCurrent();

   if(current_time >= StringToTime(time))
     {
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ShouldStopToTrade()
  {
   HistorySelect(0, TimeCurrent());
   CDateTime current_time;
   CDateTime trade_date;
   
   int total_loss = 0;
   uint total_deals = HistoryDealsTotal();
   
   current_time.DateTime(TimeCurrent());

   for(uint i = 0; i < total_deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket > 0)
        {
         datetime history_time = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
         double history_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

         trade_date.DateTime(history_time);

         if(current_time.day_of_year == trade_date.day_of_year) {            
            if (history_profit < 0)               
               total_loss++;
         }
        }
     }
   
   return total_loss;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePositions(double volume, string comment)
  {
   MqlRates prices[];
   GetPrices(prices,1);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      string position_comment = PositionGetString(POSITION_COMMENT);
      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

      if(comment == position_comment)
        {
         if(position_type == POSITION_TYPE_BUY)
           {
            utils_trade.Sell(volume, NULL, prices[0].close, NULL, NULL, comment);
           }
         else
           {
            utils_trade.Buy(volume, NULL, prices[0].close, NULL, NULL, comment);
           }
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasOpenedOrders(string comment)
  {
   PositionSelect(_Symbol);
   string position_comment = PositionGetString(POSITION_COMMENT);

   if(comment == position_comment)
      return true;

   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool WaitNextTime(datetime current_time, datetime &last_time_check)
  {
   if(current_time > last_time_check)
     {
      last_time_check = current_time;
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetNextTime(datetime current_time, datetime &last_time_check, int time_interval)
  {
   last_time_check = current_time + time_interval;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTrailingStop(double ask, double bid)
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
         double current_stop_loss   = PositionGetDouble(POSITION_SL);
         double current_stop_gain   = PositionGetDouble(POSITION_TP);
         double points              = NormalizeDouble(MathAbs(current_price-open_price) / _Point, _Digits);

         if(points > 0 && profit > 0)
           {
            utils_trade.PositionModify(position_ticket, (open_price+50*_Point), current_stop_gain);
           }

         if(points < 0 && profit > 0)
           {
            utils_trade.PositionModify(position_ticket, (open_price-50*_Point), current_stop_gain);
           }
        }
     }
  }

//+------------------------------------------------------------------+
void GetPrices(MqlRates &price_info[], int range)
  {
   ArraySetAsSeries(price_info, true);
   CopyRates(Symbol(), Period(), 0, range, price_info);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetBollingerBandsValues(double &lower_values[], double &middle_values[], double &upper_values[], int period, int range)
  {
   double lower_array[], middle_array[], upper_array[];

   ArrayResize(lower_values, range);
   ArrayResize(middle_values, range);
   ArrayResize(upper_values, range);
   ArraySetAsSeries(lower_array, true);
   ArraySetAsSeries(middle_array, true);
   ArraySetAsSeries(upper_array, true);

   int bollinger_bands_definition=iBands(_Symbol,_Period,period,0,2,PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition,2,0,range,lower_array);
   CopyBuffer(bollinger_bands_definition,0,0,range,middle_array);
   CopyBuffer(bollinger_bands_definition,1,0,range,upper_array);

   for(int i=0; i<range; i++)
     {
      lower_values[i] = lower_array[i];
      middle_values[i] = middle_array[i];
      upper_values[i] = upper_array[i];
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
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
bool IsTradingTime(string start_time, string end_time)
  {
   return TimeCurrent() > StringToTime(start_time) && TimeCurrent() < StringToTime(end_time);
  }
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
         double points              = current_price-open_price;

         if(points > 100 && profit > 0)
           {
            utils_trade.PositionModify(position_ticket, (open_price+50*_Point), current_stop_gain);
           }

         if(points < -100 && profit > 0)
           {
            utils_trade.PositionModify(position_ticket, (open_price-50*_Point), current_stop_gain);
           }
        }
     }
  }