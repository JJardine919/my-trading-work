//+------------------------------------------------------------------+
//|                                    ONNX.eurusd.D1.Prediction.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, MetaQuotes Ltd."
#property link        "https://www.mql5.com"
#property version     "1.00"

#include "ModelEurusdD1_10.mqh"
#include "ModelEurusdD1_30.mqh"
#include "ModelEurusdD1_52.mqh"
#include "ModelEurusdD1_63.mqh"
#include <Trade\Trade.mqh>

input double InpLots = 1.0;    // Lots amount to open position

//CModelEurusdD1_10 ExtModel;
//CModelEurusdD1_30 ExtModel;
//CModelEurusdD1_52 ExtModel;
CModelEurusdD1_63 ExtModel;
CTrade            ExtTrade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ExtModel.Init(_Symbol,_Period))
      return(INIT_FAILED);
   Print("model ",ExtModel.GetModelName());
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtModel.Shutdown();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!ExtModel.CheckOnTick())
      return;

//--- predict next price movement
   vector prob(3);
   int predicted_class=ExtModel.PredictClass(TimeCurrent(),prob);
   Print("predicted class ",predicted_class);
//--- check trading according to prediction
   if(predicted_class>=0)
      if(PositionSelect(_Symbol))
         CheckForClose(predicted_class);
      else
         CheckForOpen(predicted_class);
  }
//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(const int predicted_class)
  {
   ENUM_ORDER_TYPE signal=WRONG_VALUE;
//--- check signals
   if(predicted_class==PRICE_DOWN)
      signal=ORDER_TYPE_SELL;    // sell condition
   else
     {
      if(predicted_class==PRICE_UP)
         signal=ORDER_TYPE_BUY;  // buy condition
     }

//--- open position if possible according to signal
   if(signal!=WRONG_VALUE && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      double price=SymbolInfoDouble(_Symbol,(signal==ORDER_TYPE_SELL) ? SYMBOL_BID : SYMBOL_ASK);
      ExtTrade.PositionOpen(_Symbol,signal,InpLots,price,0,0);
     }
  }
//+------------------------------------------------------------------+
//| Check for close position conditions                              |
//+------------------------------------------------------------------+
void CheckForClose(const int predicted_class)
  {
   bool bsignal=false;
//--- position already selected before
   long type=PositionGetInteger(POSITION_TYPE);
//--- check signals
   if(type==POSITION_TYPE_BUY && predicted_class==PRICE_DOWN)
      bsignal=true;
   if(type==POSITION_TYPE_SELL && predicted_class==PRICE_UP)
      bsignal=true;

//--- close position if possible
   if(bsignal && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      ExtTrade.PositionClose(_Symbol,3);
      //--- open opposite
      CheckForOpen(predicted_class);
     }
  }
//+------------------------------------------------------------------+
