//+------------------------------------------------------------------+
//|                                                     Paula_V2.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Camilo Dias da Silva."
#property link      "https://github.com/camilodsilva"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>

CTrade trade;

input int            stop_rating          = 80;
input int            profit_rating        = 150;
input int            contracts            = 1;
input int            loss_limit           = 3;
static int           position             = -1;
static int           last_position        = position;
static bool          stop_on_middle_band  = false;
static datetime      last_check           = TimeCurrent();
static const string  BUY_COMMENT          = "[PAULA] BUY";
static const string  SELL_COMMENT         = "[PAULA] SELL";
static const int     TRADE_DELAY          = 900;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlRates current_price[];
   GetPrices(current_price, 10);

   if(StopLimitReached())
      return;

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

         const double ask        = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
         const double bid        = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
         const double stop_buy   = (ask-stop_rating*_Point);
         const double take_buy   = (ask+profit_rating*_Point);
         const double stop_sell  = (bid+stop_rating*_Point);
         const double take_sell  = (bid-profit_rating*_Point);

         if(position == 1)
            trade.Buy(contracts,NULL,ask,stop_buy,take_buy,BUY_COMMENT);

         if(position == 0)
            trade.Sell(contracts,NULL, bid,stop_sell,take_sell,SELL_COMMENT);

         SetNextTime(current_price);
         last_position = position;
         position = -1;
        }
     }
   else
     {
      if(CheckClosePosition(current_price))
        {
         if(HasOpenedOrders())
           {
            ClosePositions();
            last_position = -1;
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
   ArraySetAsSeries(price_info,true);
   CopyRates(Symbol(),Period(),0,range,price_info);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool WaitNextCandle(MqlRates &price_info[])
  {
   const datetime current = price_info[0].time;

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
void CheckEntry(MqlRates &price_info[])
  {
   if(!IsGap(price_info))
     {
      bool sell_signal0 = SellSignal(price_info, 0, 1, 2);
      bool sell_signal1 = SellSignal(price_info, 1, 2, 3);
      bool sell_signal2 = SellSignal(price_info, 2, 3, 4);

      if(sell_signal0 && !sell_signal1 && !sell_signal2)
        {
         stop_on_middle_band = StopOnMiddleBand(price_info);
         position = 0;
         return;
        }

      bool buy_signal0 = BuySignal(price_info, 0, 1, 2);
      bool buy_signal1 = BuySignal(price_info, 1, 2, 3);
      bool buy_signal2 = BuySignal(price_info, 2, 3, 4);

      if(buy_signal0 && !buy_signal1 && !buy_signal2)
        {
         stop_on_middle_band = StopOnMiddleBand(price_info);
         position = 1;
         return;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal(MqlRates &price_info[], int price_index0, int price_index1, int price_index2)
  {
   MqlRates first_price    = price_info[price_index0];
   MqlRates second_price   = price_info[price_index1];
   MqlRates third_price    = price_info[price_index2];

   double upper_band_array[];

   ArraySetAsSeries(upper_band_array,true);

   int bollinger_bands_definition=iBands(_Symbol,_Period,20,0,2,PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition,1,0,3,upper_band_array);

   double upper_band_value0=upper_band_array[0];
   double upper_band_value1=upper_band_array[1];
   double upper_band_value2=upper_band_array[2];

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

   ArraySetAsSeries(lower_band_array,true);

   int bollinger_bands_definition=iBands(_Symbol,_Period,20,0,2,PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition,2,0,3,lower_band_array);

   double lower_band_value0=lower_band_array[0];
   double lower_band_value1=lower_band_array[1];
   double lower_band_value2=lower_band_array[2];

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
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckClosePosition(MqlRates &price_info[])
  {
   MqlRates current_price = price_info[0];

   double upper_band_array[];
   double middle_band_array[];
   double lower_band_array[];

   ArraySetAsSeries(upper_band_array,true);
   ArraySetAsSeries(middle_band_array,true);
   ArraySetAsSeries(lower_band_array,true);

   int bollinger_bands_definition=iBands(_Symbol,_Period,20,0,2,PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition,0,0,1,middle_band_array);
   CopyBuffer(bollinger_bands_definition,1,0,1,upper_band_array);
   CopyBuffer(bollinger_bands_definition,2,0,1,lower_band_array);

   double middle_band_value0  = middle_band_array[0];
   double upper_band_value0   = upper_band_array[0];
   double lower_band_value0   = lower_band_array[0];


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
void SetNextTime(MqlRates &price_info[])
  {
   last_check = price_info[0].time + TRADE_DELAY;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool StopLimitReached()
  {
   HistorySelect(0,TimeCurrent());

   uint total     = HistoryDealsTotal();
   int ticket     = 0;
   int total_loss = 0;

   CDateTime current_time;
   CDateTime trade_date;
   datetime time;
   double profit;

// inicializa o current_time
   current_time.DateTime(TimeCurrent());

   for(uint i=0; i<total; i++)
     {
      ticket = HistoryDealGetTicket(i);

      if(ticket > 0)
        {
         time     = (datetime) HistoryDealGetInteger(ticket, DEAL_TIME);
         profit   = HistoryDealGetDouble(ticket, DEAL_PROFIT);
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
//|                                                                  |
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
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool StopOnMiddleBand(MqlRates &price_info[])
  {
   double middle_band_array[];

   ArraySetAsSeries(middle_band_array,true);

   int bollinger_bands_definition=iBands(_Symbol,_Period,20,0,2,PRICE_CLOSE);

   CopyBuffer(bollinger_bands_definition,0,0,1,middle_band_array);

   double middle_band_value0     = middle_band_array[0];
   double current_price          = price_info[0].close;
   double middle_band_distance   = NormalizeDouble(MathAbs(current_price-middle_band_value0)/_Point,_Digits);

   return middle_band_distance >= 120;
  }
//+------------------------------------------------------------------+
