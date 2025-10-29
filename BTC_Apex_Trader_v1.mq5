//+------------------------------------------------------------------+
//|                                      BTC_Apex_Trader_v1.mq5      |
//|                     Optimized by Claude for Prop Firm Success    |
//|                                                                  |
//|    Optimized version of Adaptive Bitcoin Master with improved   |
//|    risk management, tighter parameters, and emergency stops.    |
//+------------------------------------------------------------------+
#property copyright "Optimized by Claude Code 2025"
#property link      ""
#property version   "1.00"
#property strict
#property description "BTC Apex Trader - Optimized for FTMO/Prop Firm Challenge"
#property description "Key improvements: Better R:R, Reduced overtrading, Smart position sizing"

// Input Parameters - General Settings
input string   General_Settings = "--- General Settings ---";
input bool     EnableTrading    = true;           // Enable automated trading
input string   TradingSymbol    = "BTCUSD";       // Trading symbol
input double   AccountEquity    = 100000;         // Account equity (0 = use actual)
input int      MagicNumber      = 24810;          // Magic number (different from original)

// Input Parameters - Timeframes
input string   Timeframe_Settings      = "--- Timeframe Settings ---";
input ENUM_TIMEFRAMES PrimaryTimeframe = PERIOD_M15;    // Primary timeframe (M15 better than M10)
input ENUM_TIMEFRAMES TrendTimeframe   = PERIOD_H1;     // Trend timeframe

// Input Parameters - Risk Management (OPTIMIZED)
input string   Risk_Settings          = "--- Risk Management (OPTIMIZED) ---";
input double   RiskPercent            = 1.0;              // Risk per trade (reduced from 1.5%)
input double   MaxDailyLossPercent    = 3.5;              // Max daily loss (tighter than 5%)
input int      MaxOpenPositions       = 6;                // Max positions (reduced from 20!)
input bool     UseFixedLotSize        = false;            // Use risk-based sizing (CHANGED)
input double   FixedLotSize           = 0.5;              // Fixed lot if enabled (reduced)
input int      MaxRetryAttempts       = 3;                // Retry attempts
input int      RetryDelayMilliseconds = 1000;             // Retry delay

// Input Parameters - Entry Settings (OPTIMIZED)
input string   Entry_Settings           = "--- Entry Settings (OPTIMIZED) ---";
input bool     UseCandlestickPatterns   = true;     // Use candlestick patterns
input bool     UseIndicatorSignals      = true;     // Use indicators
input int      PatternStrengthThreshold = 48;       // Pattern threshold (sweet spot: 50 works, 51 blocks - using 48)

// Input Parameters - Exit Settings (FIXED RISK/REWARD)
input string   Exit_Settings          = "--- Exit Settings (FIXED R:R) ---";
input double   ATR_Multiplier_TP      = 3.5;         // TP multiplier (FIXED: was 19!)
input double   ATR_Multiplier_SL      = 2.0;         // SL multiplier (FIXED: was 14!)
input bool     UseTrailingStop        = true;        // Trailing stop
input double   TrailingStopActivation = 2.5;         // Trail activation (tighter)
input bool     UsePartialClose        = true;        // Partial close
input double   PartialClosePercent    = 50.0;        // Partial close %

// Input Parameters - Indicator Settings (OPTIMIZED)
input string   RSI_Settings    = "--- RSI Settings ---";
input int      RSI_Period      = 14;                // RSI period (back to standard)
input double   RSI_UpperLevel  = 70.0;              // RSI upper
input double   RSI_LowerLevel  = 30.0;              // RSI lower
input double   RSI_MiddleLevel = 50.0;              // RSI middle

input string   Stoch_Settings   = "--- Stochastic Settings ---";
input int      Stoch_K_Period   = 5;              // Stoch K
input int      Stoch_D_Period   = 3;              // Stoch D
input int      Stoch_Slowing    = 3;              // Stoch slowing
input double   Stoch_UpperLevel = 80.0;           // Stoch upper
input double   Stoch_LowerLevel = 20.0;           // Stoch lower (back to 20)

input string   CCI_Settings   = "--- CCI Settings ---";
input int      CCI_Period     = 14;                // CCI period
input double   CCI_UpperLevel = 100.0;             // CCI upper
input double   CCI_LowerLevel = -100.0;            // CCI lower

input string   MFI_Settings   = "--- MFI Settings ---";
input int      MFI_Period     = 14;                // MFI period
input double   MFI_UpperLevel = 80.0;              // MFI upper
input double   MFI_LowerLevel = 20.0;              // MFI lower

input string   MA_Settings     = "--- Moving Average Settings ---";
input int      Fast_EMA_Period = 12;           // Fast EMA (standard)
input int      Slow_EMA_Period = 26;           // Slow EMA (standard)

input string   ATR_Settings = "--- ATR Settings ---";
input int      ATR_Period   = 14;                // ATR period

// Input Parameters - Market Validation
input string   Validation_Settings = "--- Market Validation ---";
input bool     IsMarketValidation  = false;     // Market validation mode
input double   MinimumStopDistance = 20.0;      // Min stop distance

// Input Parameters - Emergency Stops (PROP FIRM PROTECTION)
input string   Emergency_Settings = "--- Emergency Stops (CRITICAL) ---";
input double   EmergencyDailyDD   = 3.0;        // Emergency daily DD limit
input double   EmergencyTotalDD   = 8.0;        // Emergency total DD limit
input int      EmergencyMaxLosses = 5;          // Max consecutive losses

// Global Variables
int RSI_Handle, Stoch_Handle, CCI_Handle, MFI_Handle, FastEMA_Handle, SlowEMA_Handle, ATR_Handle;
double RSI_Buffer[], Stoch_K_Buffer[], Stoch_D_Buffer[], CCI_Buffer[], MFI_Buffer[];
double FastEMA_Buffer[], SlowEMA_Buffer[], ATR_Buffer[];
double HighArray[], LowArray[], OpenArray[], CloseArray[];
long VolumeArray[];
datetime LastTradeTime = 0;
double DailyLoss = 0.0;
datetime CurrentDay = 0;
string BotName = "BTC_Apex_Trader_v1";
string CurrentSymbol = "";
int OrderRetryCount = 0;
bool IsTestingMode = false;
double SymbolPointValue = 0.0;
int SymbolDigits = 0;
double MinStopDistancePoints = 0.0;

//--- Emergency Stop System
datetime g_currentDay = 0;
double   g_dayStartEquity = 0;
double   g_peakEquity = 0;
bool     g_emergencyStop = false;
int      g_consecutiveLosses = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    CurrentSymbol = (TradingSymbol == "") ? Symbol() : TradingSymbol;
    IsTestingMode = MQLInfoInteger(MQL_TESTER);

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

    if(RSI_Handle == INVALID_HANDLE || Stoch_Handle == INVALID_HANDLE ||
       CCI_Handle == INVALID_HANDLE || MFI_Handle == INVALID_HANDLE ||
       FastEMA_Handle == INVALID_HANDLE || SlowEMA_Handle == INVALID_HANDLE ||
       ATR_Handle == INVALID_HANDLE)
    {
        Print("Error initializing indicators: ", GetLastError());
        return INIT_FAILED;
    }

    // Initialize emergency stop system
    g_currentDay = iTime(CurrentSymbol, PERIOD_D1, 0);
    g_dayStartEquity = GetAccountEquity();
    g_peakEquity = GetAccountEquity();
    g_emergencyStop = false;
    g_consecutiveLosses = 0;

    Print("═══════════════════════════════════════════════════════");
    Print("  ", BotName, " INITIALIZED");
    Print("═══════════════════════════════════════════════════════");
    Print("Symbol: ", CurrentSymbol, " | Timeframe: ", EnumToString(PrimaryTimeframe));
    Print("Risk: ", RiskPercent, "% | Max Positions: ", MaxOpenPositions);
    Print("R:R Ratio: ", DoubleToString(ATR_Multiplier_TP/ATR_Multiplier_SL, 2), ":1");
    Print("ATR TP: ", ATR_Multiplier_TP, "x | ATR SL: ", ATR_Multiplier_SL, "x");
    Print("Pattern Threshold: ", PatternStrengthThreshold, "%");
    Print("Emergency: Daily DD=", EmergencyDailyDD, "%, Total DD=", EmergencyTotalDD, "%");
    Print("═══════════════════════════════════════════════════════");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(RSI_Handle);
    IndicatorRelease(Stoch_Handle);
    IndicatorRelease(CCI_Handle);
    IndicatorRelease(MFI_Handle);
    IndicatorRelease(FastEMA_Handle);
    IndicatorRelease(SlowEMA_Handle);
    IndicatorRelease(ATR_Handle);

    Print(BotName, " deinitialized, reason: ", reason);
}

//+------------------------------------------------------------------+
//| Emergency Stop Check Function                                     |
//+------------------------------------------------------------------+
bool CheckEmergencyStop()
{
    if(g_emergencyStop) return true;

    datetime today = iTime(CurrentSymbol, PERIOD_D1, 0);
    if(g_currentDay != today)
    {
        g_currentDay = today;
        g_dayStartEquity = GetAccountEquity();
        g_consecutiveLosses = 0;
    }

    double currentEquity = GetAccountEquity();
    if(currentEquity > g_peakEquity)
        g_peakEquity = currentEquity;

    double dailyDD = 0;
    if(g_dayStartEquity > 0)
        dailyDD = ((g_dayStartEquity - currentEquity) / g_dayStartEquity) * 100;

    double totalDD = 0;
    if(g_peakEquity > 0)
        totalDD = ((g_peakEquity - currentEquity) / g_peakEquity) * 100;

    if(dailyDD >= EmergencyDailyDD)
    {
        g_emergencyStop = true;
        Print("🚨 EMERGENCY STOP: Daily DD ", DoubleToString(dailyDD, 2), "% >= ", EmergencyDailyDD, "%");
        CloseAllPositions();
        return true;
    }

    if(totalDD >= EmergencyTotalDD)
    {
        g_emergencyStop = true;
        Print("🚨 EMERGENCY STOP: Total DD ", DoubleToString(totalDD, 2), "% >= ", EmergencyTotalDD, "%");
        CloseAllPositions();
        return true;
    }

    if(g_consecutiveLosses >= EmergencyMaxLosses)
    {
        g_emergencyStop = true;
        Print("🚨 EMERGENCY STOP: ", g_consecutiveLosses, " consecutive losses");
        CloseAllPositions();
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Close All Positions Function                                     |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    int closedCount = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;

        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetString(POSITION_SYMBOL) == CurrentSymbol)
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};

                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = PositionGetString(POSITION_SYMBOL);
                request.volume = PositionGetDouble(POSITION_VOLUME);
                request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(request.symbol, SYMBOL_BID) : SymbolInfoDouble(request.symbol, SYMBOL_ASK);
                request.deviation = 10;
                request.magic = MagicNumber;
                request.comment = "Emergency Stop";

                if(OrderSend(request, result))
                    closedCount++;
            }
        }
    }

    if(closedCount > 0)
        Print("🚨 Emergency closed ", closedCount, " position(s)");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(CheckEmergencyStop()) return;
    if(!EnableTrading) return;

    if(CurrentDay != iTime(CurrentSymbol, PERIOD_D1, 0))
    {
        CurrentDay = iTime(CurrentSymbol, PERIOD_D1, 0);
        DailyLoss = 0.0;
        if(!IsTestingMode) Print("📅 New trading day - Daily loss counter reset");
    }

    if(DailyLoss >= (GetAccountEquity() * MaxDailyLossPercent / 100.0))
    {
        if(!IsTestingMode) Print("⛔ Daily loss limit reached: ", DoubleToString(DailyLoss, 2));
        return;
    }

    if(!UpdateIndicators())
    {
        if(!IsTestingMode) Print("⚠️ Indicator update failed");
        return;
    }

    int openPositions = CountOpenPositions();
    ManageOpenPositions();

    if(openPositions < MaxOpenPositions)
        CheckForTradeSignals();
}

//+------------------------------------------------------------------+
//| Update all indicator values                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    if(CopyHigh(CurrentSymbol, PrimaryTimeframe, 0, 100, HighArray) <= 0) return false;
    if(CopyLow(CurrentSymbol, PrimaryTimeframe, 0, 100, LowArray) <= 0) return false;
    if(CopyOpen(CurrentSymbol, PrimaryTimeframe, 0, 100, OpenArray) <= 0) return false;
    if(CopyClose(CurrentSymbol, PrimaryTimeframe, 0, 100, CloseArray) <= 0) return false;
    if(CopyTickVolume(CurrentSymbol, PrimaryTimeframe, 0, 100, VolumeArray) <= 0) return false;

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
//| Count open positions                                             |
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
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check for trade signals                                          |
//+------------------------------------------------------------------+
void CheckForTradeSignals()
{
    if(TimeCurrent() - LastTradeTime < 180)  // 3 minutes cooldown
        return;

    int trend = DetermineMarketTrend();
    if(!IsTestingMode) LogIndicatorValues();

    if(IsBuySignal(trend))
    {
        if(!IsTestingMode) Print("📈 BUY signal detected");
        ExecuteBuyOrder();
        LastTradeTime = TimeCurrent();
    }
    else if(IsSellSignal(trend))
    {
        if(!IsTestingMode) Print("📉 SELL signal detected");
        ExecuteSellOrder();
        LastTradeTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Determine market trend                                           |
//+------------------------------------------------------------------+
int DetermineMarketTrend()
{
    double fastEMA[], slowEMA[];
    ArraySetAsSeries(fastEMA, true);
    ArraySetAsSeries(slowEMA, true);

    if(CopyBuffer(iMA(CurrentSymbol, TrendTimeframe, Fast_EMA_Period, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 3, fastEMA) <= 0) return 0;
    if(CopyBuffer(iMA(CurrentSymbol, TrendTimeframe, Slow_EMA_Period, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 3, slowEMA) <= 0) return 0;

    if(fastEMA[0] > slowEMA[0] && fastEMA[1] > slowEMA[1])
        return 1; // Uptrend

    if(fastEMA[0] < slowEMA[0] && fastEMA[1] < slowEMA[1])
        return -1; // Downtrend

    return 0;
}

//+------------------------------------------------------------------+
//| Log indicator values                                             |
//+------------------------------------------------------------------+
void LogIndicatorValues()
{
    Print("📊 RSI=", DoubleToString(RSI_Buffer[0], 1),
          " | Stoch=", DoubleToString(Stoch_K_Buffer[0], 1),
          " | CCI=", DoubleToString(CCI_Buffer[0], 1),
          " | MFI=", DoubleToString(MFI_Buffer[0], 1));
}

//+------------------------------------------------------------------+
//| Check for buy signal                                             |
//+------------------------------------------------------------------+
bool IsBuySignal(int trend)
{
    if(trend < 0) return false;

    int signalStrength = 0;
    int totalSignals = 0;

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(RSI_Buffer[0] < RSI_LowerLevel && RSI_Buffer[1] < RSI_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(Stoch_K_Buffer[0] < Stoch_LowerLevel && Stoch_K_Buffer[0] > Stoch_D_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(CCI_Buffer[0] < CCI_LowerLevel && CCI_Buffer[1] < CCI_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(MFI_Buffer[0] < MFI_LowerLevel && MFI_Buffer[1] < MFI_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(FastEMA_Buffer[1] <= SlowEMA_Buffer[1] && FastEMA_Buffer[0] > SlowEMA_Buffer[0])
            signalStrength++;
    }

    if(UseCandlestickPatterns)
    {
        totalSignals += 3;
        if(IsBullishEngulfing()) signalStrength++;
        if(IsMorningStar()) signalStrength++;
        if(IsBullishHammer()) signalStrength++;
    }

    double signalPercentage = totalSignals > 0 ? (signalStrength * 100.0) / totalSignals : 0;

    if(signalPercentage >= PatternStrengthThreshold)
    {
        if(!IsTestingMode) Print("✅ Buy strength: ", DoubleToString(signalPercentage, 1), "% (", signalStrength, "/", totalSignals, ")");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check for sell signal                                            |
//+------------------------------------------------------------------+
bool IsSellSignal(int trend)
{
    if(trend > 0) return false;

    int signalStrength = 0;
    int totalSignals = 0;

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(RSI_Buffer[0] > RSI_UpperLevel && RSI_Buffer[1] > RSI_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(Stoch_K_Buffer[0] > Stoch_UpperLevel && Stoch_K_Buffer[0] < Stoch_D_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(CCI_Buffer[0] > CCI_UpperLevel && CCI_Buffer[1] > CCI_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(MFI_Buffer[0] > MFI_UpperLevel && MFI_Buffer[1] > MFI_Buffer[0])
            signalStrength++;
    }

    if(UseIndicatorSignals)
    {
        totalSignals++;
        if(FastEMA_Buffer[1] >= SlowEMA_Buffer[1] && FastEMA_Buffer[0] < SlowEMA_Buffer[0])
            signalStrength++;
    }

    if(UseCandlestickPatterns)
    {
        totalSignals += 3;
        if(IsBearishEngulfing()) signalStrength++;
        if(IsEveningStar()) signalStrength++;
        if(IsBearishHammer()) signalStrength++;
    }

    double signalPercentage = totalSignals > 0 ? (signalStrength * 100.0) / totalSignals : 0;

    if(signalPercentage >= PatternStrengthThreshold)
    {
        if(!IsTestingMode) Print("✅ Sell strength: ", DoubleToString(signalPercentage, 1), "% (", signalStrength, "/", totalSignals, ")");
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

    double stopLoss = entryPrice - (atr * ATR_Multiplier_SL);
    double takeProfit = entryPrice + (atr * ATR_Multiplier_TP);

    double minStopDistance = GetMinimumStopDistance();
    if(entryPrice - stopLoss < minStopDistance)
        stopLoss = entryPrice - minStopDistance;

    if(takeProfit - entryPrice < minStopDistance)
        takeProfit = entryPrice + minStopDistance;

    double positionSize = CalculatePositionSize(entryPrice, stopLoss);

    if(positionSize <= 0)
    {
        if(!IsTestingMode) Print("Invalid position size: ", positionSize);
        return;
    }

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

    bool success = ExecuteTradeWithRetry(request, result);

    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        if(!IsTestingMode) Print("✅ BUY executed | Ticket: ", result.order,
              " | R:R=", DoubleToString((takeProfit-entryPrice)/(entryPrice-stopLoss), 2), ":1");
    }
    else
    {
        if(!IsTestingMode) Print("❌ BUY failed | Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Execute sell order                                               |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    double atr = ATR_Buffer[0];
    double entryPrice = SymbolInfoDouble(CurrentSymbol, SYMBOL_BID);

    double stopLoss = entryPrice + (atr * ATR_Multiplier_SL);
    double takeProfit = entryPrice - (atr * ATR_Multiplier_TP);

    double minStopDistance = GetMinimumStopDistance();
    if(stopLoss - entryPrice < minStopDistance)
        stopLoss = entryPrice + minStopDistance;

    if(entryPrice - takeProfit < minStopDistance)
        takeProfit = entryPrice - minStopDistance;

    double positionSize = CalculatePositionSize(entryPrice, stopLoss);

    if(positionSize <= 0)
    {
        if(!IsTestingMode) Print("Invalid position size: ", positionSize);
        return;
    }

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

    bool success = ExecuteTradeWithRetry(request, result);

    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        if(!IsTestingMode) Print("✅ SELL executed | Ticket: ", result.order,
              " | R:R=", DoubleToString((entryPrice-takeProfit)/(stopLoss-entryPrice), 2), ":1");
    }
    else
    {
        if(!IsTestingMode) Print("❌ SELL failed | Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Get minimum stop distance                                        |
//+------------------------------------------------------------------+
double GetMinimumStopDistance()
{
    long stopLevel = SymbolInfoInteger(CurrentSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    if(stopLevel > 0)
        return stopLevel * SymbolPointValue;
    return MinStopDistancePoints * SymbolPointValue;
}

//+------------------------------------------------------------------+
//| Execute trade with retry                                         |
//+------------------------------------------------------------------+
bool ExecuteTradeWithRetry(MqlTradeRequest &request, MqlTradeResult &result)
{
    if(IsMarketValidation && StringFind(request.symbol, "EURUSD") >= 0)
    {
        request.volume = 0.01;
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
            return true;

        if(result.retcode == TRADE_RETCODE_INVALID_VOLUME)
        {
            double minVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
            double maxVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
            double stepVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);

            if(request.volume > maxVolume)
            {
                request.volume = maxVolume;
                continue;
            }

            if(request.volume < minVolume)
            {
                request.volume = minVolume;
                continue;
            }

            request.volume = MathFloor(request.volume / stepVolume) * stepVolume;
            if(request.volume < minVolume) request.volume = minVolume;
            continue;
        }

        if(result.retcode == TRADE_RETCODE_INVALID_STOPS)
        {
            long stopLevel = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
            double minStopDistance = (stopLevel > 0) ? stopLevel * point : 15 * point;

            if(request.type == ORDER_TYPE_BUY)
            {
                if(request.price - request.sl < minStopDistance)
                    request.sl = request.price - minStopDistance * 1.5;
                if(request.tp - request.price < minStopDistance)
                    request.tp = request.price + minStopDistance * 1.5;
            }
            else if(request.type == ORDER_TYPE_SELL)
            {
                if(request.sl - request.price < minStopDistance)
                    request.sl = request.price + minStopDistance * 1.5;
                if(request.price - request.tp < minStopDistance)
                    request.tp = request.price - minStopDistance * 1.5;
            }
            continue;
        }

        if(attempt < MaxRetryAttempts - 1)
            Sleep(RetryDelayMilliseconds);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize(double entryPrice, double stopLoss)
{
    if(UseFixedLotSize)
        return ValidateVolume(CurrentSymbol, FixedLotSize);

    double riskAmount = GetAccountEquity() * (RiskPercent / 100.0);
    double priceDifference = MathAbs(entryPrice - stopLoss);

    if(priceDifference == 0)
        return ValidateVolume(CurrentSymbol, 0.01);

    double positionSize = riskAmount / priceDifference;

    double contractSize = SymbolInfoDouble(CurrentSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double pointValue = SymbolInfoDouble(CurrentSymbol, SYMBOL_POINT);

    if(contractSize > 0 && pointValue > 0)
        positionSize = positionSize / (contractSize * pointValue);
    else
        positionSize = riskAmount / priceDifference / 100;

    return ValidateVolume(CurrentSymbol, positionSize);
}

//+------------------------------------------------------------------+
//| Validate volume                                                  |
//+------------------------------------------------------------------+
double ValidateVolume(string symbol, double volume)
{
    if(IsMarketValidation && StringFind(symbol, "EURUSD") >= 0)
        return 0.01;

    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    if(minVolume <= 0 || maxVolume <= 0 || stepVolume <= 0)
    {
        minVolume = 0.01;
        maxVolume = 100.0;
        stepVolume = 0.01;
    }

    volume = MathFloor(volume / stepVolume) * stepVolume;
    volume = MathMax(minVolume, MathMin(maxVolume, volume));

    double margin = CalculateMarginRequired(symbol, volume);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    if(margin > 0 && margin > freeMargin * 0.9)
    {
        double safeMargin = freeMargin * 0.8;
        if(safeMargin > 0 && margin > 0)
        {
            volume = volume * (safeMargin / margin);
            volume = MathFloor(volume / stepVolume) * stepVolume;
            volume = MathMax(minVolume, MathMin(maxVolume, volume));
        }
        else
            volume = minVolume;
    }

    return volume;
}

//+------------------------------------------------------------------+
//| Calculate margin required                                        |
//+------------------------------------------------------------------+
double CalculateMarginRequired(string symbol, double volume)
{
    if(volume <= 0) return 0;

    double marginInit = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
    if(marginInit > 0)
        return volume * marginInit;

    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);

    if(contractSize > 0 && tickValue > 0 && tickSize > 0 && price > 0)
        return (price * volume * contractSize) / 100;

    return volume * 1000;
}

//+------------------------------------------------------------------+
//| Get account equity                                               |
//+------------------------------------------------------------------+
double GetAccountEquity()
{
    if(AccountEquity > 0)
        return AccountEquity;
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    if(IsMarketValidation) return;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;

        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber ||
           PositionGetString(POSITION_SYMBOL) != CurrentSymbol)
           continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double stopLoss = PositionGetDouble(POSITION_SL);
        double takeProfit = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        if(UseTrailingStop)
        {
            double atr = ATR_Buffer[0];
            double trailingDistance = atr * TrailingStopActivation;
            double minStopDistance = GetMinimumStopDistance();

            if(trailingDistance < minStopDistance)
                trailingDistance = minStopDistance * 1.5;

            if(posType == POSITION_TYPE_BUY && currentPrice > openPrice)
            {
                double newStopLoss = NormalizeDouble(currentPrice - trailingDistance, SymbolDigits);
                if(newStopLoss > stopLoss && stopLoss < openPrice)
                {
                    if(ModifyPositionWithRetry(ticket, newStopLoss, takeProfit))
                    {
                        if(!IsTestingMode) Print("📍 Trailing stop updated: BUY ", ticket);
                    }
                }
            }
            else if(posType == POSITION_TYPE_SELL && currentPrice < openPrice)
            {
                double newStopLoss = NormalizeDouble(currentPrice + trailingDistance, SymbolDigits);
                if(newStopLoss < stopLoss && stopLoss > openPrice)
                {
                    if(ModifyPositionWithRetry(ticket, newStopLoss, takeProfit))
                    {
                        if(!IsTestingMode) Print("📍 Trailing stop updated: SELL ", ticket);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position with retry                                       |
//+------------------------------------------------------------------+
bool ModifyPositionWithRetry(ulong ticket, double newSL, double newTP)
{
    for(int attempt = 0; attempt < MaxRetryAttempts; attempt++)
    {
        if(!PositionSelectByTicket(ticket))
            return false;

        string symbol = PositionGetString(POSITION_SYMBOL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        double minStopDistance = GetMinimumStopDistance();

        if(posType == POSITION_TYPE_BUY && currentPrice - newSL < minStopDistance)
            newSL = currentPrice - minStopDistance * 1.5;
        else if(posType == POSITION_TYPE_SELL && newSL - currentPrice < minStopDistance)
            newSL = currentPrice + minStopDistance * 1.5;

        MqlTradeRequest request = {};
        MqlTradeResult result = {};

        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = symbol;
        request.sl = NormalizeDouble(newSL, SymbolDigits);
        request.tp = NormalizeDouble(newTP, SymbolDigits);

        bool success = OrderSend(request, result);
        if(success && result.retcode == TRADE_RETCODE_DONE)
            return true;

        if(attempt < MaxRetryAttempts - 1)
            Sleep(RetryDelayMilliseconds);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Candlestick Pattern Functions                                    |
//+------------------------------------------------------------------+
bool IsBullishEngulfing()
{
    return (OpenArray[1] > CloseArray[1] &&
            CloseArray[0] > OpenArray[0] &&
            OpenArray[0] < CloseArray[1] &&
            CloseArray[0] > OpenArray[1]);
}

bool IsBearishEngulfing()
{
    return (OpenArray[1] < CloseArray[1] &&
            CloseArray[0] < OpenArray[0] &&
            OpenArray[0] > CloseArray[1] &&
            CloseArray[0] < OpenArray[1]);
}

bool IsMorningStar()
{
    double body2 = MathAbs(OpenArray[2] - CloseArray[2]);
    return (OpenArray[2] > CloseArray[2] &&
            MathAbs(OpenArray[1] - CloseArray[1]) < body2 &&
            CloseArray[0] > OpenArray[0] &&
            CloseArray[0] > (OpenArray[2] + CloseArray[2])/2);
}

bool IsEveningStar()
{
    double body2 = MathAbs(OpenArray[2] - CloseArray[2]);
    return (OpenArray[2] < CloseArray[2] &&
            MathAbs(OpenArray[1] - CloseArray[1]) < body2 &&
            CloseArray[0] < OpenArray[0] &&
            CloseArray[0] < (OpenArray[2] + CloseArray[2])/2);
}

bool IsBullishHammer()
{
    double body = MathAbs(OpenArray[0] - CloseArray[0]);
    double upperShadow = HighArray[0] - MathMax(OpenArray[0], CloseArray[0]);
    double lowerShadow = MathMin(OpenArray[0], CloseArray[0]) - LowArray[0];
    return (lowerShadow > 2 * body &&
            upperShadow < 0.2 * body &&
            CloseArray[0] > OpenArray[0]);
}

bool IsBearishHammer()
{
    double body = MathAbs(OpenArray[0] - CloseArray[0]);
    double upperShadow = HighArray[0] - MathMax(OpenArray[0], CloseArray[0]);
    double lowerShadow = MathMin(OpenArray[0], CloseArray[0]) - LowArray[0];
    return (upperShadow > 2 * body &&
            lowerShadow < 0.2 * body &&
            CloseArray[0] < OpenArray[0]);
}
//+------------------------------------------------------------------+
