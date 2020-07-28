//+------------------------------------------------------------------+
//|                                                  PriceAction.mq5 |
//|                                             Camilo Dias da Silva |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Camilo Dias da Silva"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include "TradeUtils.mq5";

input string Name="Pattern #1";
input uint   NumderBar=1; // number on the right side
//--- input parameters of the script
input string            InpFont="Arial";         // Font
input int               InpFontSize=10;          // Font size
input color             InpColor=clrRed;         // Color
input double            InpAngle=90.0;           // Slope angle in degrees
input ENUM_ANCHOR_POINT InpAnchor=ANCHOR_LEFT; // Anchor type
input bool              InpBack=false;           // Background object
input bool              InpSelection=false;      // Highlight to move
input bool              InpHidden=true;          // Hidden in the object list
input long              InpZOrder=0;             // Priority for mouse click

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime date[]; // array for storing dates of visible bars
   double   low[];  // array for storing Low prices of visible bars
   double   high[]; // array for storing High prices of visible bars
//--- memory allocation
   ArrayResize(date,NumderBar);
   ArrayResize(low,NumderBar);
   ArrayResize(high,NumderBar);
//--- fill the array of dates
   ResetLastError();
   if(CopyTime(Symbol(),Period(),NumderBar,1,date)==-1)
     {
      Print("Failed to copy time values! Error code = ",GetLastError());
      return;
     }
   Print(date[0]);
//--- fill the array of Low prices
   if(CopyLow(Symbol(),Period(),NumderBar,1,low)==-1)
     {
      Print("Failed to copy the values of Low prices! Error code = ",GetLastError());
      return;
     }
   Print(low[0]);
//--- fill the array of High prices
   if(CopyHigh(Symbol(),Period(),NumderBar,1,high)==-1)
     {
      Print("Failed to copy the values of High prices! Error code = ",GetLastError());
      return;
     }
   Print(high[0]);
//--- create the texts
   if(!TextCreate(0,"UP_"+(string)NumderBar,0,date[0],high[0],Name,InpFont,InpFontSize,
                  InpColor,InpAngle,InpAnchor,InpBack,InpSelection,InpHidden,InpZOrder))
     {
      return;
     }
   if(!TextCreate(0,"DOWN_"+(string)NumderBar,0,date[0],low[0],Name,InpFont,InpFontSize,
                  InpColor,-InpAngle,InpAnchor,InpBack,InpSelection,InpHidden,InpZOrder))
     {
      return;
     }
  }

//+------------------------------------------------------------------+
bool TextCreate(const long              chart_ID=0,               // chart's ID
                const string            name="Text",              // object name
                const int               sub_window=0,             // subwindow index
                datetime                time=0,                   // anchor point time
                double                  price=0,                  // anchor point price
                const string            text="Text",              // the text itself
                const string            font="Arial",             // font
                const int               font_size=10,             // font size
                const color             clr=clrRed,               // color
                const double            angle=0.0,                // text slope
                const ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER, // anchor type
                const bool              back=false,               // in the background
                const bool              selection=false,          // highlight to move
                const bool              hidden=true,              // hidden in the object list
                const long              z_order=0)                // priority for mouse click
  {
//--- set anchor point coordinates if they are not set
//ChangeTextEmptyPoint(time,price);
//--- reset the error value
   ResetLastError();
//--- create Text object
   if(!ObjectCreate(chart_ID,name,OBJ_TEXT,sub_window,time,price))
     {
      Print(__FUNCTION__,
            ": failed to create \"Text\" object! Error code = ",GetLastError());
      return(false);
     }
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set the slope angle of the text
   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
//--- set anchor type
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
//--- set color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the object by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
