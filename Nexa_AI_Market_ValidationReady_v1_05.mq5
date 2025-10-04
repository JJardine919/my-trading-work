//+------------------------------------------------------------------+
//|                                                    Nexa AI      |
//|                              Version: 1.05 (Market Validation)  |
//+------------------------------------------------------------------+
#property strict
#property version "1.05"
#property description "Neural Network-Only Trading Bot for MQL5 Market Validation"

#include <Trade/Trade.mqh>
CTrade trade;

input string RelayURL = "http://127.0.0.1:5000"; // Local AI relay URL
input double LotSize = 0.01;
input int RSI_Period = 14;
input int RSI_Overbought = 70;
input int RSI_Oversold = 30;

double rsiValue;
datetime lastTradeTime = 0;
int cooldownSeconds = 3600;

int OnInit() {
   Print("EA Initialized.");
   return(INIT_SUCCEEDED);
}

void OnTick() {
   if (TimeCurrent() - lastTradeTime < cooldownSeconds) return;

   rsiValue = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE, 0);
   if (rsiValue < RSI_Oversold && PositionSelect(_Symbol) == false) {
      if (trade.Buy(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, "AI Buy")) {
         lastTradeTime = TimeCurrent();
      }
   } else if (rsiValue > RSI_Overbought && PositionSelect(_Symbol) == false) {
      if (trade.Sell(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), 0, 0, "AI Sell")) {
         lastTradeTime = TimeCurrent();
      }
   }
}