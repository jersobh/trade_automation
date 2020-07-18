//+------------------------------------------------------------------+
//|                                                        Paula.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>

CTrade trade;
input int stopRating=50;
input int takeRating=100;
input double contracts=1.0;
input double minimunPips=0.0;
static datetime timestampLastCheck;
input string timeToStopTrade="17:30:00";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   EventSetTimer(60);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlRates priceInfo[];
   ArraySetAsSeries(priceInfo,true);
   CopyRates(Symbol(),Period(),0,3,priceInfo);

   MqlRates currentPrice=priceInfo[0];
   const double ask=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   const double bid=NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

// first check if the current time is greater than the time to stop trade
   /*if (TimeCurrent() <= StringToTime(timeToStopTrade))
    {
      CloseAllPositions();
      return;
    }*/

// second check if the candle is the same
   if(WaitNextCandle(currentPrice))
      return;

// third check if there is no open positions
   if(PositionsTotal() == 0)
     {
      const string signal = CheckEntry();

      if(signal=="buy")
        {
         double stop=(ask-stopRating*_Point);
         double take=(ask+takeRating*_Point);

         trade.Buy(contracts,NULL,ask,NULL,NULL,"[PAULA] BUY");
         timestampLastCheck = currentPrice.time;
         Comment("Ask: ", ask, "\nStop: ", stop, "\nTake: ", take);
        }

      if(signal=="sell")
        {
         double stop=(bid+stopRating*_Point);
         double take=(bid-takeRating*_Point);

         trade.Sell(contracts,NULL, bid,NULL,NULL,"[PAULA] SELL");
         timestampLastCheck = currentPrice.time;
         Comment("Bid: ", bid, "\nStop: ", stop, "\nTake: ", take);
        }
     }
   else
     {
      CheckClose();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   Comment("AQUIIII");
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      int ticket=PositionGetTicket(i);
      trade.PositionClose(i);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool WaitNextCandle(MqlRates &priceInfo)
  {
   datetime timestampCurrentCandle;

   timestampCurrentCandle = priceInfo.time;
   if(timestampCurrentCandle != timestampLastCheck)
     {
      timestampLastCheck = timestampCurrentCandle;
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CheckEntry()
  {
   MqlRates priceInfo[];
   ArraySetAsSeries(priceInfo,true);

   int data=CopyRates(Symbol(),Period(),0,3,priceInfo);
   string signal="";

   double middleBandArray[];
   double upperBandArray[];
   double lowerBandArray[];

   ArraySetAsSeries(middleBandArray,true);
   ArraySetAsSeries(upperBandArray,true);
   ArraySetAsSeries(lowerBandArray,true);

   int bollingerBandsDefinition=iBands(_Symbol,_Period,20,0,2,PRICE_CLOSE);

   CopyBuffer(bollingerBandsDefinition,0,0,3,middleBandArray);
   CopyBuffer(bollingerBandsDefinition,1,0,3,upperBandArray);
   CopyBuffer(bollingerBandsDefinition,2,0,3,lowerBandArray);

   double myMiddleBandValue0=middleBandArray[0];
   double myUpperBandValue0=upperBandArray[0];
   double myLowerBandValue0=lowerBandArray[0];

   double myMiddleBandValue1=middleBandArray[1];
   double myUpperBandValue1=upperBandArray[1];
   double myLowerBandValue1=lowerBandArray[1];

   double myMiddleBandValue2=middleBandArray[2];
   double myUpperBandValue2=upperBandArray[2];
   double myLowerBandValue2=lowerBandArray[2];

   double open=NormalizeDouble(priceInfo[1].open,_Digits);
   double close=NormalizeDouble(priceInfo[1].close,_Digits);
   double pips=NormalizeDouble(MathAbs(close-open)/_Point,_Digits);

// buy position
   if((priceInfo[2].low <= myLowerBandValue2)&&
      (priceInfo[1].high >= myLowerBandValue1)&&
      (priceInfo[0].close >= priceInfo[1].high))
      signal="buy";

// sell position
   if((priceInfo[2].high >= myUpperBandValue2)&&
      (priceInfo[1].low <= myUpperBandValue1)&&
      (priceInfo[0].close <= priceInfo[1].low))
      signal="sell";

   return signal;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose()
  {
   MqlRates priceInfo[];
   ArraySetAsSeries(priceInfo,true);

   int data=CopyRates(Symbol(),Period(),0,3,priceInfo);
   string signal="";

   double middleBandArray[];
   double upperBandArray[];
   double lowerBandArray[];

   ArraySetAsSeries(middleBandArray,true);
   ArraySetAsSeries(upperBandArray,true);
   ArraySetAsSeries(lowerBandArray,true);

   int bollingerBandsDefinition=iBands(_Symbol,_Period,20,0,2,PRICE_CLOSE);

   CopyBuffer(bollingerBandsDefinition,0,0,3,middleBandArray);
   CopyBuffer(bollingerBandsDefinition,1,0,3,upperBandArray);
   CopyBuffer(bollingerBandsDefinition,2,0,3,lowerBandArray);

   double myMiddleBandValue0=middleBandArray[0];
   double myUpperBandValue0=upperBandArray[0];
   double myLowerBandValue0=lowerBandArray[0];

// close buy position
   if((priceInfo[0].high >= myMiddleBandValue0)||
      (priceInfo[0].high >= myUpperBandValue0)||
      (priceInfo[0].close >= myMiddleBandValue0)||
      (priceInfo[0].close >= myUpperBandValue0))
      CloseAllPositions();
      
   if((priceInfo[0].low <= myLowerBandValue0)||
      (priceInfo[0].close <= myLowerBandValue0))
      CloseAllPositions();

// close sell position
   if((priceInfo[0].low <= myMiddleBandValue0)||
      (priceInfo[0].low <= myLowerBandValue0)||
      (priceInfo[0].close <= myMiddleBandValue0)||
      (priceInfo[0].close <= myLowerBandValue0))
      CloseAllPositions();
      
   if((priceInfo[0].high >= myUpperBandValue0)||
      (priceInfo[0].close >= myUpperBandValue0))
      CloseAllPositions();
  }
//+------------------------------------------------------------------+
