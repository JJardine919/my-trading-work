//+------------------------------------------------------------------+
//|                                           BB_Donchian_Bot.mq5 |
//|                                  Copyright 2025, Manus AI        |
//|                                                                  |
//| Bollinger Bands & Donchian Channel Trading Bot for MetaTrader 5  |
//| Designed for Funding Traders prop firm compliance                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Manus AI"
#property link      ""
#property version   "1.00"
#property strict

// Input Parameters
input string   Strategy_Info = "--- Bollinger Bands & Donchian Channel Strategy Settings ---";
input bool     EnableTrading = true;           // Enable automated trading
input string   Symbol_Settings = "--- Symbol Settings ---";
input string   TradingSymbol = "BTCUSD";       // Trading symbol
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;  // Primary timeframe

input string   BB_Settings = "--- Bollinger Bands Settings ---";
input int      BB_Period = 120;                // Bollinger Bands period
input double   BB_Deviation = 1.0;             // Bollinger Bands deviation

input string   Donchian_Settings = "--- Donchian Channel Settings ---";
input int      Donchian_Period = 80;           // Donchian Channel period

input string   Trend_Settings = "--- Trend Verification Settings ---";
input int      Trend_Period = 70;              // Period for trend verification

input string   ATR_Settings = "--- ATR Settings ---";
input int      ATR_Period = 21;                // ATR period
input double   SL_ATR_Multiplier = 3.0;        // Stop loss in ATR
input double   TP_ATR_Multiplier = 7.0;        // Take profit in ATR

input string   Risk_Settings = "--- Risk Management Settings ---";
input int      MagicNumber = 123;              // Magic order number
input double   FixedLotSize = 0.1;             // Trade volume
input double   AccountEquity = 50000.0;         // Your account equity amount
input int      Slippage = 30;                  // Slippage in points

// Global Variables
int BB_Handle, ATR_Handle;
double BB_Upper[], BB_Lower[], BB_Middle[];
double Donchian_Upper[], Donchian_Lower[], Donchian_Middle[];
double ATR_Buffer[];
double HighArray[], LowArray[], CloseArray[];
string BotName = "BB_Donchian_Bot";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize indicators
    BB_Handle = iBands(_Symbol, Timeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
    ATR_Handle = iATR(_Symbol, Timeframe, ATR_Period);
    
    // Initialize arrays
    ArraySetAsSeries(BB_Upper, true);
    ArraySetAsSeries(BB_Lower, true);
    ArraySetAsSeries(BB_Middle, true);
    ArraySetAsSeries(Donchian_Upper, true);
    ArraySetAsSeries(Donchian_Lower, true);
    ArraySetAsSeries(Donchian_Middle, true);
    ArraySetAsSeries(ATR_Buffer, true);
    ArraySetAsSeries(HighArray, true);
    ArraySetAsSeries(LowArray, true);
    ArraySetAsSeries(CloseArray, true);
    
    // Check if indicators initialized successfully
    if(BB_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE)
    {
        Print("Error initializing indicators: ", GetLastError());
        return INIT_FAILED;
    }
    
    // Log initialization
    Print(BotName, " initialized successfully on ", _Symbol, " ", EnumToString(Timeframe));
    Print("Strategy parameters: BB Period=", BB_Period, ", Donchian Period=", Donchian_Period, 
          ", ATR Period=", ATR_Period, ", SL=", SL_ATR_Multiplier, "xATR, TP=", TP_ATR_Multiplier, "xATR");
    Print("Risk settings: Magic Number=", MagicNumber, ", Lot Size=", FixedLotSize, 
          ", Account Equity=$", AccountEquity, ", Slippage=", Slippage);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(BB_Handle);
    IndicatorRelease(ATR_Handle);
    
    Print(BotName, " deinitialized, reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Skip if trading is disabled
    if(!EnableTrading)
        return;
    
    // Get indicator values
    if(!UpdateIndicators())
    {
        Print("Failed to update indicators, skipping this tick");
        return;
    }
    
    // Calculate Donchian Channel manually
    CalculateDonchianChannel();
    
    // Check for open positions
    if(PositionSelect(_Symbol))
    {
        // Manage existing position
        ManagePosition();
    }
    else
    {
        // Check for new trade opportunities
        CheckForTradeSignals();
    }
}

//+------------------------------------------------------------------+
//| Update all indicator values                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    // Copy Bollinger Bands data
    if(CopyBuffer(BB_Handle, 0, 0, 3, BB_Middle) <= 0) return false;
    if(CopyBuffer(BB_Handle, 1, 0, 3, BB_Upper) <= 0) return false;
    if(CopyBuffer(BB_Handle, 2, 0, 3, BB_Lower) <= 0) return false;
    
    // Copy ATR data
    if(CopyBuffer(ATR_Handle, 0, 0, 3, ATR_Buffer) <= 0) return false;
    
    // Copy price data for Donchian Channel calculation
    if(CopyHigh(_Symbol, Timeframe, 0, Donchian_Period + Trend_Period, HighArray) <= 0) return false;
    if(CopyLow(_Symbol, Timeframe, 0, Donchian_Period + Trend_Period, LowArray) <= 0) return false;
    if(CopyClose(_Symbol, Timeframe, 0, 3, CloseArray) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Donchian Channel manually                              |
//+------------------------------------------------------------------+
void CalculateDonchianChannel()
{
    // Resize arrays
    ArrayResize(Donchian_Upper, 3);
    ArrayResize(Donchian_Lower, 3);
    ArrayResize(Donchian_Middle, 3);
    
    // Calculate for current and previous bars
    for(int i = 0; i < 3; i++)
    {
        // Find highest high and lowest low in the Donchian period
        double highestHigh = HighArray[ArrayMaximum(HighArray, i, Donchian_Period)];
        double lowestLow = LowArray[ArrayMinimum(LowArray, i, Donchian_Period)];
        
        Donchian_Upper[i] = highestHigh;
        Donchian_Lower[i] = lowestLow;
        Donchian_Middle[i] = (highestHigh + lowestLow) / 2.0;
    }
}

//+------------------------------------------------------------------+
//| Check for new trade signals                                      |
//+------------------------------------------------------------------+
void CheckForTradeSignals()
{
    // Log current indicator values
    LogIndicatorValues();
    
    // Check for buy signal
    if(IsBuySignal())
    {
        ExecuteBuyOrder();
    }
    // Check for sell signal
    else if(IsSellSignal())
    {
        ExecuteSellOrder();
    }
}

//+------------------------------------------------------------------+
//| Check if buy signal conditions are met                           |
//+------------------------------------------------------------------+
bool IsBuySignal()
{
    // Price breaks above upper Bollinger Band
    bool bbBreakout = CloseArray[1] <= BB_Upper[1] && CloseArray[0] > BB_Upper[0];
    
    // Price is above Donchian middle line
    bool aboveDonchianMiddle = CloseArray[0] > Donchian_Middle[0];
    
    // Trend verification - check if highs are rising
    bool trendUp = IsUptrend();
    
    // Log signal components
    if(bbBreakout || aboveDonchianMiddle || trendUp)
    {
        Print("Buy signal components - BB Breakout: ", bbBreakout, 
              ", Above Donchian Middle: ", aboveDonchianMiddle, 
              ", Uptrend: ", trendUp);
    }
    
    // Return true if all conditions are met
    return bbBreakout && aboveDonchianMiddle && trendUp;
}

//+------------------------------------------------------------------+
//| Check if sell signal conditions are met                          |
//+------------------------------------------------------------------+
bool IsSellSignal()
{
    // Price breaks below lower Bollinger Band
    bool bbBreakout = CloseArray[1] >= BB_Lower[1] && CloseArray[0] < BB_Lower[0];
    
    // Price is below Donchian middle line
    bool belowDonchianMiddle = CloseArray[0] < Donchian_Middle[0];
    
    // Trend verification - check if lows are falling
    bool trendDown = IsDowntrend();
    
    // Log signal components
    if(bbBreakout || belowDonchianMiddle || trendDown)
    {
        Print("Sell signal components - BB Breakout: ", bbBreakout, 
              ", Below Donchian Middle: ", belowDonchianMiddle, 
              ", Downtrend: ", trendDown);
    }
    
    // Return true if all conditions are met
    return bbBreakout && belowDonchianMiddle && trendDown;
}

//+------------------------------------------------------------------+
//| Check if market is in uptrend                                    |
//+------------------------------------------------------------------+
bool IsUptrend()
{
    // Check if highs are rising over the trend period
    double highestHigh1 = HighArray[ArrayMaximum(HighArray, 0, Trend_Period/2)];
    double highestHigh2 = HighArray[ArrayMaximum(HighArray, Trend_Period/2, Trend_Period/2)];
    
    return highestHigh1 > highestHigh2;
}

//+------------------------------------------------------------------+
//| Check if market is in downtrend                                  |
//+------------------------------------------------------------------+
bool IsDowntrend()
{
    // Check if lows are falling over the trend period
    double lowestLow1 = LowArray[ArrayMinimum(LowArray, 0, Trend_Period/2)];
    double lowestLow2 = LowArray[ArrayMinimum(LowArray, Trend_Period/2, Trend_Period/2)];
    
    return lowestLow1 < lowestLow2;
}

//+------------------------------------------------------------------+
//| Execute a buy order                                              |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = CalculateStopLoss(true, entryPrice);
    double takeProfit = CalculateTakeProfit(true, entryPrice);
    double lotSize = FixedLotSize; // Using fixed lot size as specified
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    request.comment = BotName + "_BUY";
    request.type_filling = ORDER_FILLING_FOK;
    
    // Send order
    bool success = OrderSend(request, result);
    
    // Log order result
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("BUY order executed successfully. Ticket: ", result.order, 
              ", Price: ", entryPrice, 
              ", Stop Loss: ", stopLoss, 
              ", Take Profit: ", takeProfit, 
              ", Lot Size: ", lotSize);
    }
    else
    {
        Print("BUY order failed. Error code: ", result.retcode, 
              ", Error description: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Execute a sell order                                             |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = CalculateStopLoss(false, entryPrice);
    double takeProfit = CalculateTakeProfit(false, entryPrice);
    double lotSize = FixedLotSize; // Using fixed lot size as specified
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    request.comment = BotName + "_SELL";
    request.type_filling = ORDER_FILLING_FOK;
    
    // Send order
    bool success = OrderSend(request, result);
    
    // Log order result
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("SELL order executed successfully. Ticket: ", result.order, 
              ", Price: ", entryPrice, 
              ", Stop Loss: ", stopLoss, 
              ", Take Profit: ", takeProfit, 
              ", Lot Size: ", lotSize);
    }
    else
    {
        Print("SELL order failed. Error code: ", result.retcode, 
              ", Error description: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate stop loss price based on ATR                           |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy, double entryPrice)
{
    // Calculate stop loss based on ATR
    double atrValue = ATR_Buffer[0];
    double stopDistance = atrValue * SL_ATR_Multiplier;
    
    // Calculate stop loss price
    double stopLoss = isBuy ? entryPrice - stopDistance : entryPrice + stopDistance;
    
    // Log calculation
    Print("Stop Loss calculation - Entry: ", entryPrice, 
          ", ATR: ", atrValue, 
          ", Stop Distance: ", stopDistance, 
          ", Stop Loss Price: ", stopLoss);
    
    return NormalizeDouble(stopLoss, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate take profit price based on ATR                         |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isBuy, double entryPrice)
{
    // Calculate take profit based on ATR
    double atrValue = ATR_Buffer[0];
    double takeDistance = atrValue * TP_ATR_Multiplier;
    
    // Calculate take profit price
    double takeProfit = isBuy ? entryPrice + takeDistance : entryPrice - takeDistance;
    
    // Log calculation
    Print("Take Profit calculation - Entry: ", entryPrice, 
          ", ATR: ", atrValue, 
          ", Take Profit Distance: ", takeDistance, 
          ", Take Profit Price: ", takeProfit);
    
    return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Manage existing position                                         |
//+------------------------------------------------------------------+
void ManagePosition()
{
    // Get position details
    ulong ticket = PositionGetTicket(0);
    if(ticket <= 0)
        return;
    
    double positionProfit = PositionGetDouble(POSITION_PROFIT);
    double positionVolume = PositionGetDouble(POSITION_VOLUME);
    
    // Log position status
    Print("Managing position - Ticket: ", ticket, 
          ", Type: ", (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
          ", Profit: ", positionProfit);
    
    // No additional management logic - using fixed SL/TP
}

//+------------------------------------------------------------------+
//| Log current indicator values                                     |
//+------------------------------------------------------------------+
void LogIndicatorValues()
{
    static datetime lastLogTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Log indicator values every 5 minutes
    if(currentTime - lastLogTime >= 300)
    {
        Print("Current indicator values - ",
              "BB Upper: ", BB_Upper[0], 
              ", BB Middle: ", BB_Middle[0], 
              ", BB Lower: ", BB_Lower[0], 
              ", Donchian Upper: ", Donchian_Upper[0], 
              ", Donchian Middle: ", Donchian_Middle[0], 
              ", Donchian Lower: ", Donchian_Lower[0], 
              ", ATR: ", ATR_Buffer[0]);
        
        lastLogTime = currentTime;
    }
}
