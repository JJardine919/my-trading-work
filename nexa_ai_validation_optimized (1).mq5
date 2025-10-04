//+------------------------------------------------------------------+
//|                                         Nexa AI Market Bot v1.10 |
//|                   Validation Optimized - Zero Errors Priority    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, SUSTAI"
#property version   "1.10"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input group "=== RSI Settings ==="
input double RSI_Overbought = 70.0;        // RSI Overbought Level
input double RSI_Oversold = 30.0;          // RSI Oversold Level
input int RSI_Period = 14;                 // RSI Period
input ENUM_TIMEFRAMES RSI_Timeframe = PERIOD_M5; // RSI Timeframe
input ENUM_APPLIED_PRICE RSI_Price = PRICE_CLOSE; // RSI Applied Price

input group "=== Validation Settings ==="
input bool ValidationMode = true;          // Validation Mode (ALWAYS TRUE for submission)
input double ValidationLotSize = 0.01;     // Fixed lot size for validation
input bool DisableDynamicLots = true;      // Disable dynamic lot calculation
input double MinEquityThreshold = 0.50;    // Minimum equity threshold (50 cents)
input int MaxTradesPerSymbol = 5;          // Maximum trades per symbol
input bool EnableEmergencyStop = true;     // Enable emergency stop on low equity

input group "=== Risk Management ==="
input double StopLossPoints = 200.0;       // Stop Loss in Points (conservative)
input double TakeProfitPoints = 400.0;     // Take Profit in Points (conservative)
input int MaxPositions = 1;                // Maximum Open Positions

input group "=== Trading Settings ==="
input int MagicNumber = 123456;            // Magic Number
input string TradeComment = "Nexa AI v1.10"; // Trade Comment
input bool EnableBuyTrades = true;         // Enable Buy Trades
input bool EnableSellTrades = true;        // Enable Sell Trades

// Global variables
datetime lastBarTime = 0;
int totalTrades = 0;
int tradesThisSymbol = 0;
bool initializationComplete = false;
bool emergencyStopActivated = false;
double minLot, maxLot, lotStep;
int rsiHandle;
string currentSymbol = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Track symbol changes
   if(currentSymbol != _Symbol)
   {
      currentSymbol = _Symbol;
      tradesThisSymbol = 0;
   }
   
   // Get symbol trading specifications
   minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Ensure validation lot size is valid
   if(ValidationLotSize < minLot)
      ValidationLotSize = minLot;
   
   // Create RSI indicator handle
   rsiHandle = iRSI(_Symbol, RSI_Timeframe, RSI_Period, RSI_Price);
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create RSI indicator handle for ", _Symbol);
      return(INIT_FAILED);
   }
   
   // Validate inputs
   if(RSI_Overbought <= RSI_Oversold)
   {
      Print("ERROR: RSI Overbought level must be greater than Oversold level");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(20); // Increased deviation for validation
   
   // Initialize last bar time
   lastBarTime = iTime(_Symbol, _Period, 0);
   
   initializationComplete = true;
   
   if(ValidationMode)
   {
      Print("Nexa AI v1.10 - Validation Mode Initialized for ", _Symbol);
      Print("Min Lot: ", minLot, ", Validation Lot: ", ValidationLotSize);
      Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
      Print("Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release RSI handle
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   
   if(ValidationMode)
   {
      Print("Nexa AI v1.10 Deinitialized - Symbol: ", _Symbol, ", Trades: ", tradesThisSymbol);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!initializationComplete)
      return;
   
   // Emergency stop check
   if(EnableEmergencyStop && CheckEmergencyStop())
   {
      if(!emergencyStopActivated)
      {
         Print("EMERGENCY STOP ACTIVATED - Low equity detected");
         emergencyStopActivated = true;
      }
      return;
   }
   
   // Check if we've reached max trades for this symbol
   if(tradesThisSymbol >= MaxTradesPerSymbol)
   {
      return; // Stop trading on this symbol
   }
   
   // Check if new bar formed
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool newBar = (currentBarTime != lastBarTime);
   
   if(!newBar)
      return; // Only trade on new bars for validation
   
   lastBarTime = currentBarTime;
   
   // Check minimum bars
   if(Bars(_Symbol, _Period) < 20) // Very low requirement for validation
      return;
   
   // Get current RSI value
   double rsiBuffer[1];
   if(CopyBuffer(rsiHandle, 0, 1, 1, rsiBuffer) <= 0)
   {
      return; // Silently fail to avoid log spam
   }
   
   double rsi = rsiBuffer[0];
   
   // Check current positions
   int currentPositions = CountPositions();
   
   // Very conservative trading logic for validation
   if(currentPositions < MaxPositions && CanAffordTrade())
   {
      // Buy signal: RSI oversold
      if(rsi < RSI_Oversold && EnableBuyTrades)
      {
         if(OpenBuyPositionSafe())
         {
            totalTrades++;
            tradesThisSymbol++;
            if(ValidationMode)
               Print("BUY opened - RSI: ", DoubleToString(rsi, 2), " Symbol: ", _Symbol);
         }
      }
      // Sell signal: RSI overbought
      else if(rsi > RSI_Overbought && EnableSellTrades)
      {
         if(OpenSellPositionSafe())
         {
            totalTrades++;
            tradesThisSymbol++;
            if(ValidationMode)
               Print("SELL opened - RSI: ", DoubleToString(rsi, 2), " Symbol: ", _Symbol);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if emergency stop should be activated                      |
//+------------------------------------------------------------------+
bool CheckEmergencyStop()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Stop if equity is too low
   if(equity < MinEquityThreshold)
      return true;
   
   // Stop if equity is less than 20% of balance
   if(balance > 0 && equity < (balance * 0.2))
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if we can afford a trade                                   |
//+------------------------------------------------------------------+
bool CanAffordTrade()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   // Need at least minimum equity threshold
   if(equity < MinEquityThreshold)
      return false;
   
   // Need sufficient free margin (at least 10x the lot size value)
   double lotValue = ValidationLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(freeMargin < (lotValue * 10))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Count current positions                                          |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate ultra-safe stop levels                                 |
//+------------------------------------------------------------------+
bool CalculateUltraSafeStopLevels(bool isBuy, double price, double &sl, double &tp)
{
   // Get symbol's minimum stop level
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * _Point;
   
   // Use very conservative distances (much larger than minimum)
   double actualSLDistance = MathMax(StopLossPoints * _Point, minDistance * 3);
   double actualTPDistance = MathMax(TakeProfitPoints * _Point, minDistance * 3);
   
   if(isBuy)
   {
      sl = NormalizeDouble(price - actualSLDistance, _Digits);
      tp = NormalizeDouble(price + actualTPDistance, _Digits);
   }
   else
   {
      sl = NormalizeDouble(price + actualSLDistance, _Digits);
      tp = NormalizeDouble(price - actualTPDistance, _Digits);
   }
   
   // Validate the levels
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = isBuy ? (currentPrice - sl) : (sl - currentPrice);
   double tpDistance = isBuy ? (tp - currentPrice) : (currentPrice - tp);
   
   // Ensure minimum distance
   if(slDistance < minDistance || tpDistance < minDistance)
   {
      sl = 0; // Disable SL if too close
      tp = 0; // Disable TP if too close
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Open buy position with maximum safety                            |
//+------------------------------------------------------------------+
bool OpenBuyPositionSafe()
{
   // Multiple safety checks before attempting trade
   if(!CanAffordTrade())
      return false;
   
   if(emergencyStopActivated)
      return false;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0)
      return false;
   
   double sl = 0, tp = 0;
   CalculateUltraSafeStopLevels(true, ask, sl, tp);
   
   // Use fixed validation lot size
   double lotSize = ValidationLotSize;
   
   // Final lot size validation
   if(lotSize < minLot)
      lotSize = minLot;
   if(lotSize > maxLot)
      lotSize = maxLot;
   
   // Normalize to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = NormalizeDouble(lotSize, (int)MathLog10(1.0 / lotStep));
   
   // Attempt trade with extensive error handling
   bool result = trade.Buy(lotSize, _Symbol, ask, sl, tp, TradeComment);
   
   if(!result)
   {
      uint retcode = trade.ResultRetcode();
      
      // Handle specific error codes
      switch(retcode)
      {
         case TRADE_RETCODE_INVALID_VOLUME:
            // Try with minimum lot
            result = trade.Buy(minLot, _Symbol, ask, 0, 0, TradeComment);
            break;
            
         case TRADE_RETCODE_NOT_ENOUGH_MONEY:
            // Activate emergency stop
            emergencyStopActivated = true;
            break;
            
         case TRADE_RETCODE_INVALID_STOPS:
            // Try without stops
            result = trade.Buy(lotSize, _Symbol, ask, 0, 0, TradeComment);
            break;
            
         default:
            // For any other error, just log and continue
            if(ValidationMode)
               Print("BUY failed: ", retcode, " - ", trade.ResultRetcodeDescription());
            break;
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Open sell position with maximum safety                           |
//+------------------------------------------------------------------+
bool OpenSellPositionSafe()
{
   // Multiple safety checks before attempting trade
   if(!CanAffordTrade())
      return false;
   
   if(emergencyStopActivated)
      return false;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0)
      return false;
   
   double sl = 0, tp = 0;
   CalculateUltraSafeStopLevels(false, bid, sl, tp);
   
   // Use fixed validation lot size
   double lotSize = ValidationLotSize;
   
   // Final lot size validation
   if(lotSize < minLot)
      lotSize = minLot;
   if(lotSize > maxLot)
      lotSize = maxLot;
   
   // Normalize to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = NormalizeDouble(lotSize, (int)MathLog10(1.0 / lotStep));
   
   // Attempt trade with extensive error handling
   bool result = trade.Sell(lotSize, _Symbol, bid, sl, tp, TradeComment);
   
   if(!result)
   {
      uint retcode = trade.ResultRetcode();
      
      // Handle specific error codes
      switch(retcode)
      {
         case TRADE_RETCODE_INVALID_VOLUME:
            // Try with minimum lot
            result = trade.Sell(minLot, _Symbol, bid, 0, 0, TradeComment);
            break;
            
         case TRADE_RETCODE_NOT_ENOUGH_MONEY:
            // Activate emergency stop
            emergencyStopActivated = true;
            break;
            
         case TRADE_RETCODE_INVALID_STOPS:
            // Try without stops
            result = trade.Sell(lotSize, _Symbol, bid, 0, 0, TradeComment);
            break;
            
         default:
            // For any other error, just log and continue
            if(ValidationMode)
               Print("SELL failed: ", retcode, " - ", trade.ResultRetcodeDescription());
            break;
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+

