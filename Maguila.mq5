//+------------------------------------------------------------------+
//|                                                      Maguila.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>

CTrade trade;

static int position=-1;
static datetime last_check;
static bool candle_touched=false;
input int stop_rating=150;
input int profit_rating=180;
input int loss_limit=3;
input int contracts=1;
input int ema1=21;
input int ema2=42;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   MqlRates current_price[];
   GetPrices(current_price, 3);

   if(StopLimitReached())
      return;

   const double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   const double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   if(PositionsTotal() == 0)
     {
      const double stop_buy = (ask-stop_rating*_Point);
      const double take_buy = (ask+profit_rating*_Point);
      const double stop_sell = (bid+stop_rating*_Point);
      const double take_sell = (bid-profit_rating*_Point);

      CheckEntry(current_price);

      if(position != -1)
        {
         if(WaitNextCandle(current_price))
           {
            position = -1;
            return;
           }

         if(position == 1)
            trade.Buy(contracts,NULL,ask,stop_buy,take_buy,"[MAGUILA] BUY");

         if(position == 0)
            trade.Sell(contracts,NULL, bid,stop_sell,take_sell,"[MAGUILA] SELL");

         SetNextTime(current_price);
         position = -1;
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
   datetime current;

   current = price_info[0].time;
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
   double open_current_price = NormalizeDouble(price_info[0].open,_Digits);
   double close_previous_price = NormalizeDouble(price_info[1].close,_Digits);
   double points_difference = NormalizeDouble(MathAbs(close_previous_price-open_current_price)/_Point,_Digits);

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

      ArraySetAsSeries(ema21_array,true);
      ArraySetAsSeries(ema42_array,true);

      int ema21_definition=iMA(_Symbol,_Period,ema1,0,MODE_EMA,PRICE_CLOSE);
      int ema42_definition=iMA(_Symbol,_Period,ema2,0,MODE_EMA,PRICE_CLOSE);

      CopyBuffer(ema21_definition,0,0,1,ema21_array);
      CopyBuffer(ema42_definition,0,0,1,ema42_array);

      double ema21_value=NormalizeDouble(ema21_array[0],_Digits);
      double ema42_value=NormalizeDouble(ema42_array[0],_Digits);

      // -- sell analysis
      bool sell_signal0 = SellSignal(price_info, 0, 1, ema21_value, ema42_value);
      bool sell_signal1 = SellSignal(price_info, 1, 2, ema21_value, ema42_value);

      if(sell_signal0 && !sell_signal1)
         position = 0;

      // -- buy analysis
      bool buy_signal0 = BuySignal(price_info, 0, 1, ema21_value, ema42_value);
      bool buy_signal1 = BuySignal(price_info, 1, 2, ema21_value, ema42_value);

      if(buy_signal0 && !buy_signal1)
         position = 1;
     }
  }
//+------------------------------------------------------------------+
bool SellSignal(MqlRates &price_info[], int price_index0, int price_index1, double ema21, double ema42)
  {
   MqlRates current_price = price_info[price_index0];
   MqlRates previous_price = price_info[price_index1];

// media de 21 menor do que a media de 42?
   if(ema21 < ema42)
     {
      // fechamento da vela anterior menor que media de 21?
      // fechamento da vela anterior menor que media de 42?
      // maxima da vela anterior tocou na media de 21?
      if(previous_price.close < ema21 && previous_price.close < ema42 && previous_price.high > ema21)
        {
         // abertura da vela atual menor que meida de 21?
         // abertura da vela atual menor que media de 42?
         if(current_price.open < ema21 && current_price.open < ema42)
           {
            // vela atual perdeu a minima da vela anterior?
            if(current_price.close < previous_price.low)
              {
               // sinal de entrada para venda
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
bool BuySignal(MqlRates &price_info[], int price_index0, int price_index1, double ema21, double ema42)
  {
   MqlRates current_price = price_info[price_index0];
   MqlRates previous_price = price_info[price_index1];

// media de 21 maior do que a media de 42?
   if(ema21 > ema42)
     {
      // fechamento da vela anterior maior que media de 21?
      // fechamento da vela anterior maior que media de 42?
      // minima da vela anterior tocou na media de 21?
      if(previous_price.close > ema21 && previous_price.close > ema42 && previous_price.low < ema21)
        {
         // abertura da vela atual maior que meida de 21?
         // abertura da vela atual maior que media de 42?
         if(current_price.open > ema21 && current_price.open > ema42)
           {
            // vela atual ganhou a maxima da vela anterior?
            if(current_price.close > previous_price.high)
              {
               // sinal de entrada para venda
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
         ulong position_ticket = PositionGetInteger(POSITION_TICKET);
         double profit = PositionGetDouble(POSITION_PROFIT);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double current_stop_loss = PositionGetDouble(POSITION_SL);
         double current_stop_gain = PositionGetDouble(POSITION_TP);
         int points = current_price-open_price;
         int resto = points % 100;

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
