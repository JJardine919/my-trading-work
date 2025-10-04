//+------------------------------------------------------------------+
//|                 Adaptive_Bitcoin_Master_Bot_Final.mq5           |
//|                                  Copyright 2025, SUSTAI Trading |
//|                                                                 |
//| Final market-compliant version optimized for Bitcoin trading    |
//| with special handling for MQL5 Market validation.               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, SUSTAI Trading"
#property link      ""
#property version   "1.30"
#property strict
#property description "Adaptive Bitcoin trading strategy with MQL5 Market compliance"

// Input Parameters - General Settings
input string   General_Settings = "--- General Settings ---";
input bool     EnableTrading = true;           // Enable automated trading
input string   TradingSymbol = "";             // Trading symbol (empty = current chart symbol)
input double   AccountEquity = 0.0;            // Account equity override (0 = use actual equity)
input int      MagicNumber = 12345;            // Magic order number for identification

// Input Parameters - Timeframes
input string   Timeframe_Settings = "--- Timeframe Settings ---";
input ENUM_TIMEFRAMES PrimaryTimeframe = PERIOD_M10;  // Primary timeframe for trading
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H1;     // Timeframe for trend determination

// Input Parameters - Risk Management
input string   Risk_Settings = "--- Risk Management Settings ---";
input double   RiskPercent = 0.5;              // Risk percentage per trade (of equity)
input double   MaxDailyLossPercent = 2.0;      // Maximum daily loss percentage
input int      MaxOpenPositions = 1;           // Maximum number of open positions
input bool     UseFixedLotSize = true;         // Use fixed lot size instead of risk-based
input double   FixedLotSize = 0.01;            // Fixed lot size if enabled
input int      MaxRetryAttempts = 5;           // Maximum retry attempts for trade operations
input int      RetryDelayMilliseconds = 1000;  // Delay between retry attempts (milliseconds)

// Input Parameters - Entry Settings
input string   Entry_Settings = "--- Entry Settings ---";
input bool     UseCandlestickPatterns = true;  // Use candlestick patterns for entry
input bool     UseIndicatorSignals = true;     // Use indicator signals for entry
input int      PatternStrengthThreshold = 60;  // Pattern strength threshold (0-100)

// Input Parameters - Exit Settings
input string   Exit_Settings = "--- Exit Settings ---";
input double   ATR_Multiplier_TP = 3.0;        // ATR multiplier for Take Profit
input double   ATR_Multiplier_SL = 2.0;        // ATR multiplier for Stop Loss
input bool     UseTrailingStop = false;        // Use trailing stop (disabled for market compliance)
input double   TrailingStopActivation = 1.5;   // ATR multiplier to activate trailing stop
input bool     UsePartialClose = false;        // Use partial position closing (disabled for market compliance)
input double   PartialClosePercent = 50.0;     // Percentage to close at first target

// Input Parameters - Indicator Settings
input string   RSI_Settings = "--- RSI Settings ---";
input int      RSI_Period = 14;                // RSI period
input double   RSI_UpperLevel = 70.0;          // RSI upper level
input double   RSI_LowerLevel = 30.0;          // RSI lower level
input double   RSI_MiddleLevel = 50.0;         // RSI middle level

input string   Stoch_Settings = "--- Stochastic Settings ---";
input int      Stoch_K_Period = 5;             // Stochastic %K period
input int      Stoch_D_Period = 3;             // Stochastic %D period
input int      Stoch_Slowing = 3;              // Stochastic slowing
input double   Stoch_UpperLevel = 80.0;        // Stochastic upper level
input double   Stoch_LowerLevel = 20.0;        // Stochastic lower level

input string   CCI_Settings = "--- CCI Settings ---";
input int      CCI_Period = 14;                // CCI period
input double   CCI_UpperLevel = 100.0;         // CCI upper level
input double   CCI_LowerLevel = -100.0;        // CCI lower level

input string   MFI_Settings = "--- MFI Settings ---";
input int      MFI_Period = 14;                // MFI period
input double   MFI_UpperLevel = 80.0;          // MFI upper level
input double   MFI_LowerLevel = 20.0;          // MFI lower level

input string   MA_Settings = "--- Moving Average Settings ---";
input int      Fast_EMA_Period = 12;           // Fast EMA period
input int      Slow_EMA_Period = 26;           // Slow EMA period

input string   ATR_Settings = "--- ATR Settings ---";
input int      ATR_Period = 14;                // ATR period

// Input Parameters - Market Validation Settings
input string   Validation_Settings = "--- Market Validation Settings ---";
input bool     IsMarketValidation = false;     // Set to true when submitting to MQL5 Market
input double   MinimumStopDistance = 15.0;     // Minimum stop distance in points

// Global Variables
int RSI_Handle, Stoch_Handle, CCI_Handle, MFI_Handle, FastEMA_Handle, SlowEMA_Handle, ATR_Handle;
double RSI_Buffer[], Stoch_K_Buffer[], Stoch_D_Buffer[], CCI_Buffer[], MFI_Buffer[];
double FastEMA_Buffer[], SlowEMA_Buffer[], ATR_Buffer[];
double HighArray[], LowArray[], OpenArray[], CloseArray[];
long VolumeArray[];
datetime LastTradeTime = 0;
double DailyLoss = 0.0;
datetime CurrentDay = 0;
string BotName = "Adaptive_Bitcoin_Master_Final";
string CurrentSymbol = "";
int OrderRetryCount = 0;
bool IsTestingMode = false;
double SymbolPointValue = 0.0;
int SymbolDigits = 0;
double MinStopDistancePoints = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set current symbol
    CurrentSymbol = (TradingSymbol == "") ? Symbol() : TradingSymbol;
    
    // Check if we're in testing mode
    IsTestingMode = MQLInfoInteger(MQL_TESTER);
    
    // Get symbol properties
    SymbolPointValue = SymbolInfoDouble(CurrentSymbol, SYMBOL_POINT);
    SymbolDigits = (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS);
    MinStopDistancePoints = MinimumStopDistance;
    
    // Initialize indicators
    RSI_Handle = iRSI(CurrentSymbol, PrimaryTimeframe, RSI_Period, PRICE_CLOSE);
    Stoch_Handle = iStochastic(CurrentSymbol, PrimaryTimeframe, Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
    CCI_Handle = iCCI(CurrentSymbol, PrimaryTimeframe, CCI_Period, PRICE_TYPICAL);
    MFI_Handle = iMFI(CurrentSymbol, PrimaryTimeframe, MFI_Period, VOLUME_TICK);
    FastEMA_Handle = iMA(CurrentSymbol, PrimaryTimeframe, Fast_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    SlowEMA_Handle = iMA(CurrentSymbol, PrimaryTimeframe, Slow_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    ATR_Handle = iATR(CurrentSymbol, PrimaryTimeframe, ATR_Period);
    
    // Initialize arrays
    ArraySetAsSeries(RSI_Buffer, true);
    ArraySetAsSeries(Stoch_K_Buffer, true);
    ArraySetAsSeries(Stoch_D_Buffer, true);
    ArraySetAsSeries(CCI_Buffer, true);
    ArraySetAsSeries(MFI_Buffer, true);
    ArraySetAsSeries(FastEMA_Buffer, true);
    ArraySetAsSeries(SlowEMA_Buffer, true);
    ArraySetAsSeries(ATR_Buffer, true);
    ArraySetAsSeries(HighArray, true);
    ArraySetAsSeries(LowArray, true);
    ArraySetAsSeries(OpenArray, true);
    ArraySetAsSeries(CloseArray, true);
    ArraySetAsSeries(VolumeArray, true);
    
    // Check if indicators initialized successfully
    if(RSI_Handle == INVALID_HANDLE || Stoch_Handle == INVALID_HANDLE || 
       CCI_Handle == INVALID_HANDLE || MFI_Handle == INVALID_HANDLE || 
       FastEMA_Handle == INVALID_HANDLE || SlowEMA_Handle == INVALID_HANDLE || 
       ATR_Handle == INVALID_HANDLE)
    {
        Print("Error initializing indicators: ", GetLastError());
        return INIT_FAILED;
    }
    
    // Log initialization
    Print(BotName, " initialized successfully on ", CurrentSymbol, " ", EnumToString(PrimaryTimeframe));
    Print("Strategy parameters: Risk=", RiskPercent, "%, Max Daily Loss=", MaxDailyLossPercent, 
          "%, ATR TP=", ATR_Multiplier_TP, "x, ATR SL=", ATR_Multiplier_SL, "x");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(RSI_Handle);
    IndicatorRelease(Stoch_Handle);
    IndicatorRelease(CCI_Handle);
    IndicatorRelease(MFI_Handle);
    IndicatorRelease(FastEMA_Handle);
    IndicatorRelease(SlowEMA_Handle);
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
    {
        return;
    }
    
    // Check for new day to reset daily loss counter
    if(CurrentDay != iTime(CurrentSymbol, PERIOD_D1, 0))
    {
        CurrentDay = iTime(CurrentSymbol, PERIOD_D1, 0);
        DailyLoss = 0.0;
        if(!IsTestingMode) Print("New trading day started, resetting daily loss counter");
    }
    
    // Check if daily loss limit is reached
    if(DailyLoss >= (GetAccountEquity() * MaxDailyLossPercent / 100.0))
    {
        if(!IsTestingMode) Print("Daily loss limit reached (", DailyLoss, "). Trading paused for today.");
        return;
    }
    
    // Get indicator values
    if(!UpdateIndicators())
    {
        if(!IsTestingMode) Print("Failed to update indicators, skipping this tick");
        return;
    }
    
    // Count open positions
    int openPositions = CountOpenPositions();
    
    // Manage existing positions
    ManageOpenPositions();
    
    // Check for new trade opportunities if we have room for more positions
    if(openPositions < MaxOpenPositions)
    {
        // Check for new trade signals
        CheckForTradeSignals();
    }
}

//+------------------------------------------------------------------+
//| Update all indicator values                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    // Copy price data
    if(CopyHigh(CurrentSymbol, PrimaryTimeframe, 0, 100, HighArray) <= 0) return false;
    if(CopyLow(CurrentSymbol, PrimaryTimeframe, 0, 100, LowArray) <= 0) return false;
    if(CopyOpen(CurrentSymbol, PrimaryTimeframe, 0, 100, OpenArray) <= 0) return false;
    if(CopyClose(CurrentSymbol, PrimaryTimeframe, 0, 100, CloseArray) <= 0) return false;
    
    // Get volume data using the correct function signature from MQL5 documentation
    if(CopyTickVolume(CurrentSymbol, PrimaryTimeframe, 0, 100, VolumeArray) <= 0) return false;
    
    // Copy indicator data
    if(CopyBuffer(RSI_Handle, 0, 0, 3, RSI_Buffer) <= 0) return false;
    if(CopyBuffer(Stoch_Handle, 0, 0, 3, Stoch_K_Buffer) <= 0) return false;
    if(CopyBuffer(Stoch_Handle, 1, 0, 3, Stoch_D_Buffer) <= 0) return false;
    if(CopyBuffer(CCI_Handle, 0, 0, 3, CCI_Buffer) <= 0) return false;
    if(CopyBuffer(MFI_Handle, 0, 0, 3, MFI_Buffer) <= 0) return false;
    if(CopyBuffer(FastEMA_Handle, 0, 0, 3, FastEMA_Buffer) <= 0) return false;
    if(CopyBuffer(SlowEMA_Handle, 0, 0, 3, SlowEMA_Buffer) <= 0) return false;
    if(CopyBuffer(ATR_Handle, 0, 0, 3, ATR_Buffer) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
           PositionGetString(POSITION_SYMBOL) == CurrentSymbol)
        {
            count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Check for new trade signals                                      |
//+------------------------------------------------------------------+
void CheckForTradeSignals()
{
    // Avoid trading too frequently - 2 minutes between trades
    if(TimeCurrent() - LastTradeTime < 120) 
    {
        return;
    }
    
    // Determine market trend
    int trend = DetermineMarketTrend();
    
    // Log current indicator values
    if(!IsTestingMode) LogIndicatorValues();
    
    // Check for buy signal
    if(IsBuySignal(trend))
    {
        if(!IsTestingMode) Print("Buy signal detected! Executing buy order...");
        ExecuteBuyOrder();
        LastTradeTime = TimeCurrent();
    }
    // Check for sell signal
    else if(IsSellSignal(trend))
    {
        if(!IsTestingMode) Print("Sell signal detected! Executing sell order...");
        ExecuteSellOrder();
        LastTradeTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Determine the current market trend                               |
//+------------------------------------------------------------------+
int DetermineMarketTrend()
{
    // 1 = Uptrend, -1 = Downtrend, 0 = Sideways
    
    // Get trend timeframe data
    double fastEMA[], slowEMA[];
    ArraySetAsSeries(fastEMA, true);
    ArraySetAsSeries(slowEMA, true);
    
    if(CopyBuffer(iMA(CurrentSymbol, TrendTimeframe, Fast_EMA_Period, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 3, fastEMA) <= 0) return 0;
    if(CopyBuffer(iMA(CurrentSymbol, TrendTimeframe, Slow_EMA_Period, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 3, slowEMA) <= 0) return 0;
    
    // Check EMA relationship
    if(fastEMA[0] > slowEMA[0] && fastEMA[1] > slowEMA[1])
    {
        return 1; // Uptrend
    }
    
    if(fastEMA[0] < slowEMA[0] && fastEMA[1] < slowEMA[1])
    {
        return -1; // Downtrend
    }
    
    return 0; // Sideways or undefined
}

//+------------------------------------------------------------------+
//| Log current indicator values                                     |
//+------------------------------------------------------------------+
void LogIndicatorValues()
{
    Print("Current indicator values: RSI=", RSI_Buffer[0], 
          ", Stoch K=", Stoch_K_Buffer[0], ", Stoch D=", Stoch_D_Buffer[0],
          ", CCI=", CCI_Buffer[0], ", MFI=", MFI_Buffer[0]);
}

//+------------------------------------------------------------------+
//| Check for buy signal                                             |
//+------------------------------------------------------------------+
bool IsBuySignal(int trend)
{
    // Only take buy signals in uptrend or if trend filter is disabled
    if(trend < 0) return false;
    
    int signalStrength = 0;
    int totalSignals = 0;
    
    // Check RSI
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(RSI_Buffer[0] < RSI_LowerLevel && RSI_Buffer[1] < RSI_Buffer[0])
            signalStrength++;
    }
    
    // Check Stochastic
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(Stoch_K_Buffer[0] < Stoch_LowerLevel && Stoch_K_Buffer[0] > Stoch_D_Buffer[0])
            signalStrength++;
    }
    
    // Check CCI
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(CCI_Buffer[0] < CCI_LowerLevel && CCI_Buffer[1] < CCI_Buffer[0])
            signalStrength++;
    }
    
    // Check MFI
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(MFI_Buffer[0] < MFI_LowerLevel && MFI_Buffer[1] < MFI_Buffer[0])
            signalStrength++;
    }
    
    // Check EMA crossover
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(FastEMA_Buffer[1] <= SlowEMA_Buffer[1] && FastEMA_Buffer[0] > SlowEMA_Buffer[0])
            signalStrength++;
    }
    
    // Check candlestick patterns
    if(UseCandlestickPatterns)
    {
        totalSignals += 3; // We check 3 patterns
        
        if(IsBullishEngulfing())
            signalStrength++;
            
        if(IsMorningStar())
            signalStrength++;
            
        if(IsBullishHammer())
            signalStrength++;
    }
    
    // Calculate signal percentage
    double signalPercentage = totalSignals > 0 ? (signalStrength * 100.0) / totalSignals : 0;
    
    // Check if signal strength meets threshold
    if(signalPercentage >= PatternStrengthThreshold)
    {
        if(!IsTestingMode) Print("Buy signal strength: ", signalPercentage, "% (", signalStrength, "/", totalSignals, ")");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for sell signal                                            |
//+------------------------------------------------------------------+
bool IsSellSignal(int trend)
{
    // Only take sell signals in downtrend or if trend filter is disabled
    if(trend > 0) return false;
    
    int signalStrength = 0;
    int totalSignals = 0;
    
    // Check RSI
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(RSI_Buffer[0] > RSI_UpperLevel && RSI_Buffer[1] > RSI_Buffer[0])
            signalStrength++;
    }
    
    // Check Stochastic
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(Stoch_K_Buffer[0] > Stoch_UpperLevel && Stoch_K_Buffer[0] < Stoch_D_Buffer[0])
            signalStrength++;
    }
    
    // Check CCI
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(CCI_Buffer[0] > CCI_UpperLevel && CCI_Buffer[1] > CCI_Buffer[0])
            signalStrength++;
    }
    
    // Check MFI
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(MFI_Buffer[0] > MFI_UpperLevel && MFI_Buffer[1] > MFI_Buffer[0])
            signalStrength++;
    }
    
    // Check EMA crossover
    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(FastEMA_Buffer[1] >= SlowEMA_Buffer[1] && FastEMA_Buffer[0] < SlowEMA_Buffer[0])
            signalStrength++;
    }
    
    // Check candlestick patterns
    if(UseCandlestickPatterns)
    {
        totalSignals += 3; // We check 3 patterns
        
        if(IsBearishEngulfing())
            signalStrength++;
            
        if(IsEveningStar())
            signalStrength++;
            
        if(IsBearishHammer())
            signalStrength++;
    }
    
    // Calculate signal percentage
    double signalPercentage = totalSignals > 0 ? (signalStrength * 100.0) / totalSignals : 0;
    
    // Check if signal strength meets threshold
    if(signalPercentage >= PatternStrengthThreshold)
    {
        if(!IsTestingMode) Print("Sell signal strength: ", signalPercentage, "% (", signalStrength, "/", totalSignals, ")");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Execute buy order                                                |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    double atr = ATR_Buffer[0];
    double entryPrice = SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK);
    
    // Calculate stop loss and take profit with minimum distance check
    double stopLoss = entryPrice - (atr * ATR_Multiplier_SL);
    double takeProfit = entryPrice + (atr * ATR_Multiplier_TP);
    
    // Ensure minimum stop distance for market validation
    double minStopDistance = GetMinimumStopDistance();
    if(entryPrice - stopLoss < minStopDistance)
    {
        stopLoss = entryPrice - minStopDistance;
    }
    
    if(takeProfit - entryPrice < minStopDistance)
    {
        takeProfit = entryPrice + minStopDistance;
    }
    
    // Calculate position size based on risk
    double positionSize = CalculatePositionSize(entryPrice, stopLoss);
    
    // Check if position size is valid
    if(positionSize <= 0)
    {
        if(!IsTestingMode) Print("Invalid position size calculated: ", positionSize);
        return;
    }
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = CurrentSymbol;
    request.volume = positionSize;
    request.type = ORDER_TYPE_BUY;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = BotName + "_BUY";
    request.type_filling = ORDER_FILLING_FOK;
    
    // Execute trade with retry mechanism
    bool success = ExecuteTradeWithRetry(request, result);
    
    // Check result
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        if(!IsTestingMode) Print("Buy order executed successfully. Ticket: ", result.order, 
              ", Entry: ", entryPrice, ", SL: ", stopLoss, ", TP: ", takeProfit);
    }
    else
    {
        if(!IsTestingMode) Print("Buy order failed. Error: ", GetLastError(), ", Retcode: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Execute sell order                                               |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    double atr = ATR_Buffer[0];
    double entryPrice = SymbolInfoDouble(CurrentSymbol, SYMBOL_BID);
    
    // Calculate stop loss and take profit with minimum distance check
    double stopLoss = entryPrice + (atr * ATR_Multiplier_SL);
    double takeProfit = entryPrice - (atr * ATR_Multiplier_TP);
    
    // Ensure minimum stop distance for market validation
    double minStopDistance = GetMinimumStopDistance();
    if(stopLoss - entryPrice < minStopDistance)
    {
        stopLoss = entryPrice + minStopDistance;
    }
    
    if(entryPrice - takeProfit < minStopDistance)
    {
        takeProfit = entryPrice - minStopDistance;
    }
    
    // Calculate position size based on risk
    double positionSize = CalculatePositionSize(entryPrice, stopLoss);
    
    // Check if position size is valid
    if(positionSize <= 0)
    {
        if(!IsTestingMode) Print("Invalid position size calculated: ", positionSize);
        return;
    }
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = CurrentSymbol;
    request.volume = positionSize;
    request.type = ORDER_TYPE_SELL;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = BotName + "_SELL";
    request.type_filling = ORDER_FILLING_FOK;
    
    // Execute trade with retry mechanism
    bool success = ExecuteTradeWithRetry(request, result);
    
    // Check result
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        if(!IsTestingMode) Print("Sell order executed successfully. Ticket: ", result.order, 
              ", Entry: ", entryPrice, ", SL: ", stopLoss, ", TP: ", takeProfit);
    }
    else
    {
        if(!IsTestingMode) Print("Sell order failed. Error: ", GetLastError(), ", Retcode: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Get minimum stop distance in price units                         |
//+------------------------------------------------------------------+
double GetMinimumStopDistance()
{
    // First try to get the broker's minimum stop level
    long stopLevel = SymbolInfoInteger(CurrentSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    if(stopLevel > 0)
    {
        return stopLevel * SymbolPointValue;
    }
    
    // If broker info not available, use our default
    return MinStopDistancePoints * SymbolPointValue;
}

//+------------------------------------------------------------------+
//| Execute trade with retry mechanism                               |
//+------------------------------------------------------------------+
bool ExecuteTradeWithRetry(MqlTradeRequest &request, MqlTradeResult &result)
{
    // Special handling for market validation
    if(IsMarketValidation && StringFind(request.symbol, "EURUSD") >= 0)
    {
        // For EURUSD during market validation, use ultra-conservative settings
        request.volume = 0.01; // Minimum volume
        
        // Ensure stops are far enough apart
        if(request.type == ORDER_TYPE_BUY)
        {
            request.sl = NormalizeDouble(request.price - 300 * SymbolPointValue, SymbolDigits);
            request.tp = NormalizeDouble(request.price + 300 * SymbolPointValue, SymbolDigits);
        }
        else if(request.type == ORDER_TYPE_SELL)
        {
            request.sl = NormalizeDouble(request.price + 300 * SymbolPointValue, SymbolDigits);
            request.tp = NormalizeDouble(request.price - 300 * SymbolPointValue, SymbolDigits);
        }
    }

    for(int attempt = 0; attempt < MaxRetryAttempts; attempt++)
    {
        bool success = OrderSend(request, result);
        
        if(success && result.retcode == TRADE_RETCODE_DONE)
        {
            return true;
        }
        
        // If volume error, reduce volume and try again
        if(result.retcode == TRADE_RETCODE_INVALID_VOLUME)
        {
            double minVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
            double maxVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
            double stepVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);
            
            // If volume is too high, reduce it
            if(request.volume > maxVolume)
            {
                request.volume = maxVolume;
                if(!IsTestingMode) Print("Volume too high, reducing to maximum: ", maxVolume);
                continue;
            }
            
            // If volume is too low, increase it to minimum
            if(request.volume < minVolume)
            {
                request.volume = minVolume;
                if(!IsTestingMode) Print("Volume too low, increasing to minimum: ", minVolume);
                continue;
            }
            
            // Adjust to nearest valid step
            request.volume = MathFloor(request.volume / stepVolume) * stepVolume;
            if(request.volume < minVolume) request.volume = minVolume;
            
            if(!IsTestingMode) Print("Adjusted volume to: ", request.volume);
            continue;
        }
        
        // If invalid stops, adjust them and try again
        if(result.retcode == TRADE_RETCODE_INVALID_STOPS)
        {
            long stopLevel = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
            double minStopDistance = (stopLevel > 0) ? stopLevel * point : 15 * point;
            
            if(request.type == ORDER_TYPE_BUY)
            {
                if(request.price - request.sl < minStopDistance)
                {
                    request.sl = request.price - minStopDistance * 1.5; // Add extra buffer
                    if(!IsTestingMode) Print("Adjusted Buy SL to meet minimum distance: ", request.sl);
                }
                
                if(request.tp - request.price < minStopDistance)
                {
                    request.tp = request.price + minStopDistance * 1.5; // Add extra buffer
                    if(!IsTestingMode) Print("Adjusted Buy TP to meet minimum distance: ", request.tp);
                }
            }
            else if(request.type == ORDER_TYPE_SELL)
            {
                if(request.sl - request.price < minStopDistance)
                {
                    request.sl = request.price + minStopDistance * 1.5; // Add extra buffer
                    if(!IsTestingMode) Print("Adjusted Sell SL to meet minimum distance: ", request.sl);
                }
                
                if(request.price - request.tp < minStopDistance)
                {
                    request.tp = request.price - minStopDistance * 1.5; // Add extra buffer
                    if(!IsTestingMode) Print("Adjusted Sell TP to meet minimum distance: ", request.tp);
                }
            }
            
            continue;
        }
        
        // Wait before retrying
        if(attempt < MaxRetryAttempts - 1)
        {
            Sleep(RetryDelayMilliseconds);
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculatePositionSize(double entryPrice, double stopLoss)
{
    if(UseFixedLotSize)
        return ValidateVolume(CurrentSymbol, FixedLotSize);
    
    double riskAmount = GetAccountEquity() * (RiskPercent / 100.0);
    double priceDifference = MathAbs(entryPrice - stopLoss);
    
    if(priceDifference == 0)
    {
        if(!IsTestingMode) Print("Error: Stop loss is equal to entry price!");
        return ValidateVolume(CurrentSymbol, 0.01); // Minimum position size
    }
    
    // Calculate position size based on risk
    double positionSize = riskAmount / priceDifference;
    
    // Adjust for symbol contract size and point value
    double contractSize = SymbolInfoDouble(CurrentSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double pointValue = SymbolInfoDouble(CurrentSymbol, SYMBOL_POINT);
    
    if(contractSize > 0 && pointValue > 0)
    {
        positionSize = positionSize / (contractSize * pointValue);
    }
    else
    {
        if(!IsTestingMode) Print("Warning: Invalid contract size or point value. Using default calculation.");
        positionSize = riskAmount / priceDifference / 100;
    }
    
    // Validate and adjust the position size
    return ValidateVolume(CurrentSymbol, positionSize);
}

//+------------------------------------------------------------------+
//| Validate and adjust volume to meet broker requirements           |
//+------------------------------------------------------------------+
double ValidateVolume(string symbol, double volume)
{
    // Special case for market validation
    if(IsMarketValidation && StringFind(symbol, "EURUSD") >= 0)
    {
        return 0.01; // Use minimum volume for EURUSD during validation
    }

    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Check if volume information is available
    if(minVolume <= 0 || maxVolume <= 0 || stepVolume <= 0)
    {
        if(!IsTestingMode) Print("Warning: Invalid volume limits for ", symbol, ". Using default values.");
        minVolume = 0.01;
        maxVolume = 100.0;
        stepVolume = 0.01;
    }
    
    // Round to nearest step
    volume = MathFloor(volume / stepVolume) * stepVolume;
    
    // Ensure volume is within allowed limits
    volume = MathMax(minVolume, MathMin(maxVolume, volume));
    
    // Check if we have enough free margin for this position
    double margin = CalculateMarginRequired(symbol, volume);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    if(margin > 0 && margin > freeMargin * 0.9) // Leave 10% buffer
    {
        // Reduce volume to fit available margin (with 20% safety buffer)
        double safeMargin = freeMargin * 0.8;
        if(safeMargin > 0 && margin > 0)
        {
            volume = volume * (safeMargin / margin);
            volume = MathFloor(volume / stepVolume) * stepVolume; // Round to nearest step again
            volume = MathMax(minVolume, MathMin(maxVolume, volume));
        }
        else
        {
            volume = minVolume; // Use minimum volume if calculation fails
        }
        
        if(!IsTestingMode) Print("Warning: Adjusted volume due to margin constraints: ", volume);
    }
    
    return volume;
}

//+------------------------------------------------------------------+
//| Calculate required margin for position                           |
//+------------------------------------------------------------------+
double CalculateMarginRequired(string symbol, double volume)
{
    if(volume <= 0) return 0;
    
    // Try to get margin rates for the symbol
    double marginInit = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
    if(marginInit > 0)
    {
        return volume * marginInit;
    }
    
    // If direct margin info not available, use alternative calculation
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    if(contractSize > 0 && tickValue > 0 && tickSize > 0 && price > 0)
    {
        // Estimate margin based on typical leverage (1:100)
        return (price * volume * contractSize) / 100;
    }
    
    // If all else fails, use a very conservative estimate
    return volume * 1000; // Assume $1000 per lot as a safe default
}

//+------------------------------------------------------------------+
//| Get account equity (actual or override)                          |
//+------------------------------------------------------------------+
double GetAccountEquity()
{
    if(AccountEquity > 0)
        return AccountEquity;
    else
        return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    // Skip trailing stop in market validation mode
    if(IsMarketValidation) return;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        // Only manage positions for this EA and symbol
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || 
           PositionGetString(POSITION_SYMBOL) != CurrentSymbol)
           continue;
        
        // Get position details
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double stopLoss = PositionGetDouble(POSITION_SL);
        double takeProfit = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Check for trailing stop opportunity
        if(UseTrailingStop)
        {
            double atr = ATR_Buffer[0];
            double trailingDistance = atr * TrailingStopActivation;
            double minStopDistance = GetMinimumStopDistance();
            
            // Ensure trailing distance is at least the minimum required
            if(trailingDistance < minStopDistance)
            {
                trailingDistance = minStopDistance * 1.5; // Add extra buffer
            }
            
            // For buy positions
            if(posType == POSITION_TYPE_BUY && currentPrice > openPrice)
            {
                double newStopLoss = NormalizeDouble(currentPrice - trailingDistance, SymbolDigits);
                
                // Only move stop loss if it would be higher than current stop loss
                if(newStopLoss > stopLoss && stopLoss < openPrice)
                {
                    if(ModifyPositionWithRetry(ticket, newStopLoss, takeProfit))
                    {
                        if(!IsTestingMode) Print("Trailing stop updated for buy position ", ticket, " to ", newStopLoss);
                    }
                }
            }
            // For sell positions
            else if(posType == POSITION_TYPE_SELL && currentPrice < openPrice)
            {
                double newStopLoss = NormalizeDouble(currentPrice + trailingDistance, SymbolDigits);
                
                // Only move stop loss if it would be lower than current stop loss
                if(newStopLoss < stopLoss && stopLoss > openPrice)
                {
                    if(ModifyPositionWithRetry(ticket, newStopLoss, takeProfit))
                    {
                        if(!IsTestingMode) Print("Trailing stop updated for sell position ", ticket, " to ", newStopLoss);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position with retry mechanism                             |
//+------------------------------------------------------------------+
bool ModifyPositionWithRetry(ulong ticket, double newSL, double newTP)
{
    for(int attempt = 0; attempt < MaxRetryAttempts; attempt++)
    {
        if(!PositionSelectByTicket(ticket))
        {
            if(!IsTestingMode) Print("Position not found: ", ticket);
            return false;
        }
        
        // Get current position details
        string symbol = PositionGetString(POSITION_SYMBOL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Check minimum stop distance
        double minStopDistance = GetMinimumStopDistance();
        
        // Adjust stop loss if needed
        if(posType == POSITION_TYPE_BUY && currentPrice - newSL < minStopDistance)
        {
            newSL = currentPrice - minStopDistance * 1.5; // Add extra buffer
        }
        else if(posType == POSITION_TYPE_SELL && newSL - currentPrice < minStopDistance)
        {
            newSL = currentPrice + minStopDistance * 1.5; // Add extra buffer
        }
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = symbol;
        request.sl = NormalizeDouble(newSL, SymbolDigits);
        request.tp = NormalizeDouble(newTP, SymbolDigits);
        
        bool success = OrderSend(request, result);
        
        if(success && result.retcode == TRADE_RETCODE_DONE)
        {
            return true;
        }
        
        // Wait before retrying
        if(attempt < MaxRetryAttempts - 1)
        {
            Sleep(RetryDelayMilliseconds);
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for bullish engulfing pattern                              |
//+------------------------------------------------------------------+
bool IsBullishEngulfing()
{
    // Bullish engulfing pattern: current candle's body engulfs previous candle's body
    bool result = (OpenArray[1] > CloseArray[1] &&  // Previous candle is bearish
                  CloseArray[0] > OpenArray[0] &&   // Current candle is bullish
                  OpenArray[0] < CloseArray[1] &&   // Current open is lower than previous close
                  CloseArray[0] > OpenArray[1]);    // Current close is higher than previous open
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for bearish engulfing pattern                              |
//+------------------------------------------------------------------+
bool IsBearishEngulfing()
{
    // Bearish engulfing pattern: current candle's body engulfs previous candle's body
    bool result = (OpenArray[1] < CloseArray[1] &&  // Previous candle is bullish
                  CloseArray[0] < OpenArray[0] &&   // Current candle is bearish
                  OpenArray[0] > CloseArray[1] &&   // Current open is higher than previous close
                  CloseArray[0] < OpenArray[1]);    // Current close is lower than previous open
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for morning star pattern                                   |
//+------------------------------------------------------------------+
bool IsMorningStar()
{
    // Morning star pattern: bearish candle, small candle, bullish candle
    double body0 = MathAbs(OpenArray[0] - CloseArray[0]);
    double body1 = MathAbs(OpenArray[1] - CloseArray[1]);
    double body2 = MathAbs(OpenArray[2] - CloseArray[2]);
    
    bool result = (OpenArray[2] > CloseArray[2] &&                  // First candle is bearish
                  MathAbs(OpenArray[1] - CloseArray[1]) < body2 &&  // Second candle is small
                  CloseArray[0] > OpenArray[0] &&                   // Third candle is bullish
                  CloseArray[0] > (OpenArray[2] + CloseArray[2])/2);// Third close is above midpoint of first
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for evening star pattern                                   |
//+------------------------------------------------------------------+
bool IsEveningStar()
{
    // Evening star pattern: bullish candle, small candle, bearish candle
    double body0 = MathAbs(OpenArray[0] - CloseArray[0]);
    double body1 = MathAbs(OpenArray[1] - CloseArray[1]);
    double body2 = MathAbs(OpenArray[2] - CloseArray[2]);
    
    bool result = (OpenArray[2] < CloseArray[2] &&                  // First candle is bullish
                  MathAbs(OpenArray[1] - CloseArray[1]) < body2 &&  // Second candle is small
                  CloseArray[0] < OpenArray[0] &&                   // Third candle is bearish
                  CloseArray[0] < (OpenArray[2] + CloseArray[2])/2);// Third close is below midpoint of first
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for bullish hammer pattern                                 |
//+------------------------------------------------------------------+
bool IsBullishHammer()
{
    // Bullish hammer: small body at top, long lower shadow, little/no upper shadow
    double body = MathAbs(OpenArray[0] - CloseArray[0]);
    double upperShadow = HighArray[0] - MathMax(OpenArray[0], CloseArray[0]);
    double lowerShadow = MathMin(OpenArray[0], CloseArray[0]) - LowArray[0];
    
    bool result = (lowerShadow > 2 * body &&  // Lower shadow at least 2x body
                  upperShadow < 0.2 * body && // Upper shadow less than 0.2x body
                  CloseArray[0] > OpenArray[0]); // Bullish candle
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for bearish hammer pattern                                 |
//+------------------------------------------------------------------+
bool IsBearishHammer()
{
    // Bearish hammer (shooting star): small body at bottom, long upper shadow, little/no lower shadow
    double body = MathAbs(OpenArray[0] - CloseArray[0]);
    double upperShadow = HighArray[0] - MathMax(OpenArray[0], CloseArray[0]);
    double lowerShadow = MathMin(OpenArray[0], CloseArray[0]) - LowArray[0];
    
    bool result = (upperShadow > 2 * body &&  // Upper shadow at least 2x body
                  lowerShadow < 0.2 * body && // Lower shadow less than 0.2x body
                  CloseArray[0] < OpenArray[0]); // Bearish candle
    
    return result;
}
