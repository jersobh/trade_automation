//+------------------------------------------------------------------+
//|                                                      Maguila.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                  https://github.com/camilodsilva |
//+------------------------------------------------------------------+
#property copyright "Camilo Dias da Silva"
#property link      "https://github.com/camilodsilvam"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>

CTrade trade;

input int stop_rating               = 150;
input int profit_rating             = 180;
input int loss_limit                = 3;
input int contracts                 = 1;
input int ema1                      = 21;
input int ema2                      = 42;
static int position                 = -1;
static int last_position            = position;
static datetime last_check          = TimeCurrent();
static bool candle_touched          = false;
static const string  BUY_COMMENT    = "[MAGUILA] BUY";
static const string  SELL_COMMENT   = "[MAGUILA] SELL";
static const int     TRADE_DELAY    = 900;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   MqlRates current_price[];
   GetPrices(current_price, 10);

   if(StopLimitReached())
      return;

   const double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   const double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   if(PositionsTotal() == 0)
     {
      CheckEntry(current_price);

      if(position != -1)
        {
         if(WaitNextCandle(current_price))
           {
            position = -1;
            return;
           }

         const double stop_buy   = (ask-stop_rating*_Point);
         const double take_buy   = (ask+profit_rating*_Point);
         const double stop_sell  = (bid+stop_rating*_Point);
         const double take_sell  = (bid-profit_rating*_Point);

         if(position == 1)
            trade.Buy(contracts,NULL,ask,stop_buy,take_buy,"[MAGUILA] BUY");

         if(position == 0)
            trade.Sell(contracts,NULL, bid,stop_sell,take_sell,"[MAGUILA] SELL");

         SetNextTime(current_price);
         last_position = position;
         position = -1;
        }
     }
   else
     {
      PutLossAtEntracePrice();
      
      if(CheckClosePosition(current_price))
        {
         if(HasOpenedOrders())
           {
            ClosePositions();
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
//|                                                                  |
//+------------------------------------------------------------------+
bool WaitNextCandle(MqlRates &price_info[])
  {
   datetime current  =price_info[0].time;

   if(current > last_check)
     {
      last_check = current;
      return false;
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsGap(MqlRates &price_info[])
  {
   double open_current_price     = NormalizeDouble(price_info[0].open,_Digits);
   double close_previous_price   = NormalizeDouble(price_info[1].close,_Digits);
   double points_difference      = NormalizeDouble(MathAbs(close_previous_price-open_current_price)/_Point,_Digits);

   if(points_difference >= 250)
     {
      SetNextTime(price_info);
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
void SetNextTime(MqlRates &price_info[])
  {
   last_check = price_info[0].time + 900;
  }
//+------------------------------------------------------------------+
void CheckEntry(MqlRates &price_info[])
  {
   if(!IsGap(price_info))
     {
      double ema21_array[];
      double ema42_array[];
      double md_array[];

      ArraySetAsSeries(ema21_array,true);
      ArraySetAsSeries(ema42_array,true);
      ArraySetAsSeries(md_array,true);

      int ema21_definition=iMA(_Symbol,_Period,ema1,0,MODE_EMA,PRICE_CLOSE);
      int ema42_definition=iMA(_Symbol,_Period,ema2,0,MODE_EMA,PRICE_CLOSE);
      int md_definition=iCustom(_Symbol,_Period,"Market\\McGinley_Dynamic",20);

      CopyBuffer(ema21_definition,0,0,1,ema21_array);
      CopyBuffer(ema42_definition,0,0,1,ema42_array);
      CopyBuffer(md_definition,0,0,1,md_array);

      double ema21_value=NormalizeDouble(ema21_array[0],_Digits);
      double ema42_value=NormalizeDouble(ema42_array[0],_Digits);
      double md_value=NormalizeDouble(md_array[0],_Digits);

      // -- sell analysis
      bool sell_signal0 = SellSignal(price_info, 0, ema21_value, ema42_value, md_value);
      bool sell_signal1 = SellSignal(price_info, 1, ema21_value, ema42_value, md_value);

      if(sell_signal0 && !sell_signal1)
         position = 0;

      // -- buy analysis
      bool buy_signal0 = BuySignal(price_info, 0, ema21_value, ema42_value, md_value);
      bool buy_signal1 = BuySignal(price_info, 1, ema21_value, ema42_value, md_value);

      if(buy_signal0 && !buy_signal1)
         position = 1;
     }
  }
//+------------------------------------------------------------------+
bool SellSignal(MqlRates &price_info[], int price_index, double ema21, double ema42, double md)
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
      if(third_price.open < ema21 && third_price.open > md)
        {
         // fechamento da vela anterior menor que media de 21?
         // fechamento da vela anterior menor que media de 42?
         // maxima da vela anterior tocou na media de 21?
         if(second_price.close < ema21 && second_price.close < ema42 && second_price.high > ema21)
           {
            // abertura da vela atual menor que meida de 21?
            // vela atual perdeu a minima da vela anterior?
            if(first_price.open < ema21 && first_price.open < md && first_price.close < second_price.low)
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
bool BuySignal(MqlRates &price_info[], int price_index, double ema21, double ema42, double md)
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
      if(third_price.open > ema21 && third_price.open > md)
        {
         // fechamento da vela anterior menor que media de 21?
         // fechamento da vela anterior menor que media de 42?
         // maxima da vela anterior tocou na media de 21?
         if(second_price.close > ema21 && second_price.close > ema42 && second_price.low < ema21)
           {
            // abertura da vela atual menor que meida de 21?
            // vela atual perdeu a minima da vela anterior?
            if(first_price.open > ema21 && first_price.open > md && first_price.close > second_price.high)
              {
               return true;
              }
           }
        }
     }

   return false;
  }
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
         int points                 = current_price-open_price;
         int resto                  = points % 100;

         if(resto == 0 && points > 0 && profit > 0)
           {
            trade.PositionModify(position_ticket, (open_price+50*_Point), current_stop_gain);
           }

         if(resto == 0 && points < 0 && profit > 0)
           {
            trade.PositionModify(position_ticket, (open_price-50*_Point), current_stop_gain);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PutLossAtEntracePrice()
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
bool StopLimitReached()
  {
   HistorySelect(0,TimeCurrent());

   uint total = HistoryDealsTotal();
   int ticket = 0;
   int total_loss = 0;

   CDateTime current_time;
   CDateTime trade_date;
   datetime time;
   double profit;

// inicializa o current_time
   current_time.DateTime(TimeCurrent());

   for(uint i=0; i<total; i++)
     {
      ticket=HistoryDealGetTicket(i);

      if(ticket > 0)
        {
         time = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
         profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         trade_date.DateTime(time);

         if(current_time.day_of_year == trade_date.day_of_year)
           {
            if(profit < 0)
               total_loss++;
           }
        }

     }

   return total_loss >= loss_limit;
  }
//+------------------------------------------------------------------+
bool HasOpenedOrders()
  {
   PositionSelect(_Symbol);
   string comment = PositionGetString(POSITION_COMMENT);

   if(comment == BUY_COMMENT || comment == SELL_COMMENT)
      return true;

   return false;
  }
//+------------------------------------------------------------------+
bool CheckClosePosition(MqlRates &price_info[])
  {
   MqlRates current_price = price_info[0];

   double md_array[];

   ArraySetAsSeries(md_array,true);

   int md_definition=iCustom(_Symbol,_Period,"Market\\McGinley_Dynamic",20);

   CopyBuffer(md_definition,0,0,1,md_array);

   double md_value=NormalizeDouble(md_array[0],_Digits);

   if(last_position != -1)
     {
      // buy position
      if(last_position == 1)
        {
         if(current_price.close < md_value)
           {
            return true;
           }
        }

      // sell position
      if(last_position == 0)
        {
         if(current_price.close > md_value)
           {
            return true;
           }
        }
     }

   return false;
  }
//+------------------------------------------------------------------+
void ClosePositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      int ticket = PositionGetTicket(i);

      string comment = PositionGetString(POSITION_COMMENT);

      if(comment == BUY_COMMENT || comment == SELL_COMMENT)
         trade.PositionClose(ticket);
     }
  }