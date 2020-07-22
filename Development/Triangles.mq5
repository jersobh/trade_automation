//+------------------------------------------------------------------+
//|                                                    Triangles.mq5 |
//|                            Copyright 2020, Camilo Dias da Silva. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Camilo Dias da Silva."
#property link      "https://www.mql5.com"
#property version   "1.00"

void OnTick()
  {
   PlotIndexSetInteger(0,                    //  The number of a graphical style
                       PLOT_LINE_COLOR,      //  Property identifier
                       0,       //  The index of the color, where we write the color
                       clrRed); 
  }
