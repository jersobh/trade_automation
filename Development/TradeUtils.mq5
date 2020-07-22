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
// TODO: check if there are comment starting with sl (stop loss)
int StopLossAnalysis(string comment)
  {
   HistorySelect(0, TimeCurrent());

   uint total = HistoryDealsTotal();
   ulong ticket = 0;
   int loss_counter = 0;

   CDateTime current_time;
   CDateTime trade_date;

// inicializa o current_time
   current_time.DateTime(TimeCurrent());

   for(uint i = 0; i < total; i++)
     {
      ticket = HistoryDealGetTicket(i);

      if(ticket > 0)
        {
         datetime history_time = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
         double hisoty_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         string history_comment = HistoryDealGetString(ticket, DEAL_COMMENT);

         trade_date.DateTime(history_time);

         if(current_time.day_of_year == trade_date.day_of_year)
           {
            if(comment == history_comment)
              {
               if(hisoty_profit < 0)
                 {
                  loss_counter++;
                 }
              }
           }
        }
     }

   return loss_counter;
  }
//+------------------------------------------------------------------+
void ClosePositions(double price, int volume, string comment)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      string position_comment = PositionGetString(POSITION_COMMENT);
      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

      if(comment == position_comment)
        {
         if(position_type == POSITION_TYPE_BUY)
           {
            utils_trade.Sell(volume, NULL, price, NULL, NULL, comment);
           }
         else
           {
            utils_trade.Buy(volume, NULL, price, NULL, NULL, comment);
           }
        }
     }
  }

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
