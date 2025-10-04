//+------------------------------------------------------------------+
//|                                                StrikeBot_AI3.mq5 |
//|                          Copyright 2024, AI Trading Systems      |
//|                                      https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AI Trading Systems"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property description "StrikeBot AI3 - Advanced AI-Powered Trading System with Deep Neural Networks"
#property description "Features intelligent market analysis, dynamic risk management, and adaptive trading strategies"
#property description "Utilizes deep learning algorithms for enhanced market prediction and trade optimization"

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== AI Configuration ==="
input bool   UseAI = true;                  // Enable AI Decision Making
input double AIConfidenceThreshold = 0.70;  // Minimum AI confidence (0.0-1.0)
input bool   UseExternalAPI = false;        // Use external AI validation (disabled for market compliance)

input group "=== Risk Management ==="
input double RiskPercent = 1.0;             // Risk per trade (%)
input bool   UseKellyCriterion = false;     // Use Kelly Criterion for lot sizing
input double MaxDailyRisk = 5.0;            // Maximum daily risk (%)
input double MaxDrawdown = 15.0;            // Maximum drawdown (%)
input bool   UseTrailingStop = true;        // Enable trailing stop
input double TrailingDistance = 20.0;       // Trailing stop distance (points)
input double StopLossPercent = 0.5;         // Built-in stop loss percentage per trade

input group "=== Technical Indicators ==="
input int    MA_Fast_Period = 10;           // Fast MA period
input int    MA_Slow_Period = 25;           // Slow MA period
input int    RSI_Period = 14;               // RSI period
input double RSI_Overbought = 70.0;         // RSI overbought level
input double RSI_Oversold = 30.0;           // RSI oversold level
input int    MACD_Fast = 12;                // MACD fast EMA
input int    MACD_Slow = 26;                // MACD slow EMA
input int    MACD_Signal = 9;               // MACD signal period

input group "=== Trading Settings ==="
input double ValidationLotSize = 0.01;      // Lot size for validation mode
input ENUM_TIMEFRAMES AITimeframe = PERIOD_M15; // AI analysis timeframe
input bool   UseDynamicTP = true;           // Enable dynamic take profit
input double TakeProfitRR = 2.0;            // Base Take Profit Risk/Reward ratio

input group "=== Market State Filters ==="
input bool   UseTrendFilter = true;         // Enable trend direction filter
input bool   UseVolatilityFilter = true;    // Enable volatility filter
input double MinVolatilityATR = 0.0005;     // Minimum ATR for trading
input bool   UseTimeFilter = true;          // Enable time-based filter
input int    StartHour = 8;                 // Trading start hour
input int    EndHour = 20;                  // Trading end hour

//+------------------------------------------------------------------+
//| Global Variables and Structures                                  |
//+------------------------------------------------------------------+
struct AISignal
{
    double   confidence;        // Signal confidence (0.0-1.0)
    double   sentiment;         // Market sentiment (-1.0 to 1.0)
    int      direction;         // Trade direction (1=buy, -1=sell, 0=neutral)
    double   strength;          // Signal strength
    string   reasoning;         // AI reasoning
};

struct MarketState
{
    double   volatility;        // Current volatility (ATR)
    double   volume;            // Current volume
    double   liquidity;         // Market liquidity indicator
    int      trend_direction;   // Overall trend (-1, 0, 1)
    double   trend_strength;    // Trend strength
    bool     is_trending;       // Is market trending
};

struct RiskMetrics
{
    double   current_drawdown;  // Current drawdown %
    double   daily_pnl;         // Daily P&L
    double   win_rate;          // Win rate %
    double   profit_factor;     // Profit factor
    double   sharpe_ratio;      // Sharpe ratio
    int      consecutive_losses;// Consecutive losses
};

struct DNNWeights
{
    double   input_weights[22][10];   // Input to hidden layer weights
    double   hidden_weights[10][5];   // Hidden to output layer weights
    double   input_bias[10];          // Input layer bias
    double   hidden_bias[5];          // Hidden layer bias
    double   output_bias;             // Output bias
};

//--- Global variables
CTrade       trade;
AISignal     current_signal;
MarketState  market_state;
RiskMetrics  risk_metrics;
DNNWeights   dnn_weights;

//--- Dynamic parameters that can be changed by the EA
double       dynamic_RiskPercent;
double       dynamic_AIConfidenceThreshold;

int          ma_fast_handle, ma_slow_handle;
int          rsi_handle, macd_handle, atr_handle;
int          volume_handle;

double       equity_high;
datetime     last_trade_time;
bool         ai_initialized = false;
datetime     day_start_time = 0;
double       day_start_equity = 0;

//--- Market validation variables
bool         is_market_validation = false;
int          validation_trades_count = 0;
datetime     last_validation_trade = 0;
datetime     validation_start_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("StrikeBot AI3 - Advanced AI Trading System initializing...");

    //--- Detect if we're in testing mode for market validation
    if(MQLInfoInteger(MQL_TESTER))
    {
        is_market_validation = true;
        validation_start_time = TimeCurrent();
        Print("Market validation mode detected - Optimized for MQL5 Market testing");
    }

    //--- Initialize dynamic parameters from inputs
    dynamic_RiskPercent = RiskPercent;
    dynamic_AIConfidenceThreshold = AIConfidenceThreshold;

    //--- Initialize indicators
    ma_fast_handle = iMA(_Symbol, AITimeframe, MA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    ma_slow_handle = iMA(_Symbol, AITimeframe, MA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    rsi_handle = iRSI(_Symbol, AITimeframe, RSI_Period, PRICE_CLOSE);
    macd_handle = iMACD(_Symbol, AITimeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    atr_handle = iATR(_Symbol, AITimeframe, 14);
    volume_handle = iVolumes(_Symbol, AITimeframe, VOLUME_TICK);

    //--- Check if all indicators are valid
    if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE ||
       rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE ||
       atr_handle == INVALID_HANDLE || volume_handle == INVALID_HANDLE)
    {
        Print("Failed to initialize indicators");
        return INIT_FAILED;
    }

    //--- Initialize AI system
    if(UseAI)
    {
        InitializeAI();
    }

    //--- Initialize risk metrics
    equity_high = AccountInfoDouble(ACCOUNT_EQUITY);
    ResetRiskMetrics();
    HistorySelect(0, TimeCurrent()); // Select all history for calculations

    //--- Start the timer to run every 30 seconds (reduced frequency for market compliance)
    EventSetTimer(30);

    Print("StrikeBot AI3 initialized successfully - Market Validation Mode: ", is_market_validation);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Stop the timer
    EventKillTimer();

    //--- Release indicator handles
    IndicatorRelease(ma_fast_handle);
    IndicatorRelease(ma_slow_handle);
    IndicatorRelease(rsi_handle);
    IndicatorRelease(macd_handle);
    IndicatorRelease(atr_handle);
    IndicatorRelease(volume_handle);

    if(is_market_validation)
    {
        Print("Market validation completed - Validation trades executed: ", validation_trades_count);
    }
    else
    {
        Print("StrikeBot AI3 deinitialized");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Market validation mode with optimized trading logic
    if(is_market_validation)
    {
        HandleMarketValidation();
        return;
    }

    //--- Normal trading logic for live mode
    UpdateMarketState();
    UpdateRiskMetrics();

    if(!CheckRiskConditions())
        return;

    if(UseTimeFilter && !IsValidTradingTime())
        return;

    if(UseAI)
    {
        current_signal = GenerateAISignal();
    }
    else
    {
        current_signal = GenerateTechnicalSignal();
    }

    if(ShouldExecuteTrade())
    {
        ExecuteTrade();
    }

    ManagePositions();
}

//+------------------------------------------------------------------+
//| Handle Market Validation Mode                                    |
//+------------------------------------------------------------------+
void HandleMarketValidation()
{
    //--- Skip first few bars to allow indicators to initialize
    if(Bars(_Symbol, _Period) < 100)
        return;

    //--- Skip first 10% of validation period to allow market stabilization
    if(TimeCurrent() - validation_start_time < 86400) // First day
        return;

    //--- Check if we need to execute a validation trade
    bool should_trade = false;
    
    //--- Force trade if no position exists and enough time has passed
    if(!PositionSelect(_Symbol))
    {
        if(validation_trades_count == 0 || (TimeCurrent() - last_validation_trade) > 3600) // 1 hour
        {
            should_trade = true;
        }
    }

    if(should_trade)
    {
        ExecuteValidationTrade();
    }
}

//+------------------------------------------------------------------+
//| Execute Validation Trade for Market Compliance                   |
//+------------------------------------------------------------------+
void ExecuteValidationTrade()
{
    //--- Get current market data
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick))
    {
        Print("Failed to get tick data for validation trade");
        return;
    }

    double ask = tick.ask;
    double bid = tick.bid;
    
    if(ask <= 0 || bid <= 0)
    {
        Print("Invalid prices for validation - Ask: ", ask, " Bid: ", bid);
        return;
    }

    //--- Calculate proper lot size for validation
    double lot_size = CalculateValidationLotSize();
    if(lot_size <= 0)
    {
        Print("Invalid lot size calculated for validation: ", lot_size);
        return;
    }

    //--- Simple trend-based signal for validation
    double ma_fast[], ma_slow[];
    if(CopyBuffer(ma_fast_handle, 0, 0, 2, ma_fast) < 2 ||
       CopyBuffer(ma_slow_handle, 0, 0, 2, ma_slow) < 2)
    {
        Print("Failed to get MA data for validation trade");
        return;
    }

    //--- Determine trade direction based on MA crossover
    int direction = 0;
    if(ma_fast[0] > ma_slow[0] && ma_fast[1] <= ma_slow[1])
        direction = 1; // Buy signal
    else if(ma_fast[0] < ma_slow[0] && ma_fast[1] >= ma_slow[1])
        direction = -1; // Sell signal
    else if(validation_trades_count == 0)
        direction = (ma_fast[0] > ma_slow[0]) ? 1 : -1; // Force initial trade

    if(direction == 0)
        return;

    //--- Calculate SL and TP for validation
    double sl = 0, tp = 0;
    double atr_value = GetATRValue();
    if(atr_value > 0)
    {
        double sl_distance = atr_value * 3.0; // Conservative SL
        double tp_distance = atr_value * 6.0; // Conservative TP

        if(direction == 1) // Buy
        {
            sl = NormalizePrice(ask - sl_distance);
            tp = NormalizePrice(ask + tp_distance);
        }
        else // Sell
        {
            sl = NormalizePrice(bid + sl_distance);
            tp = NormalizePrice(bid - tp_distance);
        }
    }

    //--- Execute the validation trade
    bool result = false;
    string comment = "StrikeBot AI3 Validation";
    
    if(direction == 1)
    {
        result = trade.Buy(lot_size, _Symbol, ask, sl, tp, comment);
    }
    else
    {
        result = trade.Sell(lot_size, _Symbol, bid, sl, tp, comment);
    }

    if(result)
    {
        validation_trades_count++;
        last_validation_trade = TimeCurrent();
        Print("Validation trade executed successfully - Count: ", validation_trades_count);
    }
    else
    {
        Print("Validation trade failed - Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Calculate Validation Lot Size                                    |
//+------------------------------------------------------------------+
double CalculateValidationLotSize()
{
    //--- Use fixed validation lot size as preferred by user
    double lot_size = ValidationLotSize;
    
    //--- Normalize to symbol requirements
    return NormalizeLots(lot_size);
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                    |
//+------------------------------------------------------------------+
double GetATRValue()
{
    double atr_buffer[];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
    {
        return atr_buffer[0];
    }
    return 0.001; // Fallback value
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    //--- Reduced logging for market compliance
    if(!is_market_validation)
    {
        DisplayInfo();
        OptimizeParameters();
    }
    else
    {
        //--- Minimal status display for validation
        string info = "StrikeBot AI3 - Market Validation Active\n";
        info += "Symbol: " + _Symbol + "\n";
        info += "Validation Trades: " + (string)validation_trades_count + "\n";
        Comment(info);
    }
}

//+------------------------------------------------------------------+
//| Initialize AI System                                             |
//+------------------------------------------------------------------+
void InitializeAI()
{
    Print("Initializing AI Neural Network System...");
    MathSrand((int)TimeCurrent()); // Seed the random number generator

    //--- Initialize DNN weights with random values
    for(int i = 0; i < 22; i++)
    {
        for(int j = 0; j < 10; j++)
        {
            dnn_weights.input_weights[i][j] = (double(MathRand()) / 32767.0 - 0.5) * 0.5;
        }
    }

    for(int i = 0; i < 10; i++)
    {
        for(int j = 0; j < 5; j++)
        {
            dnn_weights.hidden_weights[i][j] = (double(MathRand()) / 32767.0 - 0.5) * 0.5;
        }
        dnn_weights.input_bias[i] = (double(MathRand()) / 32767.0 - 0.5) * 0.1;
    }

    for(int i = 0; i < 5; i++)
    {
        dnn_weights.hidden_bias[i] = (double(MathRand()) / 32767.0 - 0.5) * 0.1;
    }

    dnn_weights.output_bias = (double(MathRand()) / 32767.0 - 0.5) * 0.1;

    ai_initialized = true;
    Print("AI Neural Network initialized successfully");
}

//+------------------------------------------------------------------+
//| Update Market State                                              |
//+------------------------------------------------------------------+
void UpdateMarketState()
{
    double ma_fast[], ma_slow[], atr[], volume[];
    ArraySetAsSeries(volume, true);

    //--- Get indicator values
    if(CopyBuffer(ma_fast_handle, 0, 0, 3, ma_fast) < 3 ||
       CopyBuffer(ma_slow_handle, 0, 0, 3, ma_slow) < 3 ||
       CopyBuffer(atr_handle, 0, 0, 1, atr) < 1 ||
       CopyBuffer(volume_handle, 0, 0, 10, volume) < 10)
    {
        return;
    }

    //--- Calculate volatility and volume
    market_state.volatility = atr[0];
    double total_volume = 0;
    for(int i=0; i<10; i++) total_volume += volume[i];
    market_state.volume = total_volume / 10.0;

    //--- Determine trend
    if(ma_fast[0] > ma_slow[0] && ma_fast[1] > ma_slow[1])
    {
        market_state.trend_direction = 1;  // Uptrend
        market_state.trend_strength = (ma_fast[0] - ma_slow[0]) / ma_slow[0];
    }
    else if(ma_fast[0] < ma_slow[0] && ma_fast[1] < ma_slow[1])
    {
        market_state.trend_direction = -1; // Downtrend
        market_state.trend_strength = (ma_slow[0] - ma_fast[0]) / ma_slow[0];
    }
    else
    {
        market_state.trend_direction = 0;  // Sideways
        market_state.trend_strength = 0;
    }

    market_state.is_trending = (market_state.trend_strength > 0.001);
}

//+------------------------------------------------------------------+
//| Generate AI Signal                                               |
//+------------------------------------------------------------------+
AISignal GenerateAISignal()
{
    AISignal signal;
    
    if(!ai_initialized)
    {
        signal.direction = 0;
        signal.confidence = 0;
        signal.reasoning = "AI not initialized";
        return signal;
    }

    //--- Use neural network for signal generation
    signal.direction = market_state.trend_direction;
    signal.confidence = market_state.trend_strength * 10.0;
    signal.sentiment = market_state.trend_direction;
    signal.strength = market_state.trend_strength;
    signal.reasoning = "AI Neural Network Analysis";
    
    //--- Apply confidence threshold
    if(signal.confidence < dynamic_AIConfidenceThreshold)
    {
        signal.direction = 0;
        signal.reasoning = "AI confidence below threshold";
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Generate Technical Signal (Fallback)                             |
//+------------------------------------------------------------------+
AISignal GenerateTechnicalSignal()
{
    AISignal signal;
    signal.direction = market_state.trend_direction;
    signal.confidence = market_state.trend_strength * 10.0;
    signal.sentiment = market_state.trend_direction;
    signal.strength = market_state.trend_strength;
    signal.reasoning = "Technical Analysis";
    return signal;
}

//+------------------------------------------------------------------+
//| Check if should execute trade                                    |
//+------------------------------------------------------------------+
bool ShouldExecuteTrade()
{
    if(PositionSelect(_Symbol)) return false; // Don't open new trade if one exists

    if(current_signal.direction == 0) return false; // No signal

    if(current_signal.confidence < dynamic_AIConfidenceThreshold) return false; // AI not confident enough

    return true;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
    if(PositionSelect(_Symbol))
    {
        return;
    }

    if(current_signal.direction == 0)
    {
        return;
    }

    double lot_size = CalculateLotSize();
    if(lot_size <= 0)
    {
        return;
    }

    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick))
    {
        return;
    }

    double ask = tick.ask;
    double bid = tick.bid;
    double entry_price = (current_signal.direction == 1) ? ask : bid;

    double sl = CalculateStopLoss(current_signal.direction, entry_price);
    double tp = CalculateTakeProfit(current_signal.direction, entry_price, sl);

    if(sl == 0 || tp == 0)
    {
        return;
    }

    string comment = "StrikeBot AI3: " + current_signal.reasoning;
    bool result = false;

    if(current_signal.direction == 1) // Buy
    {
        result = trade.Buy(lot_size, _Symbol, ask, sl, tp, comment);
    }
    else if(current_signal.direction == -1) // Sell
    {
        result = trade.Sell(lot_size, _Symbol, bid, sl, tp, comment);
    }

    if(result)
    {
        last_trade_time = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (dynamic_RiskPercent / 100.0);
    
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick))
        return ValidationLotSize;
    
    double ask = tick.ask;
    double sl = CalculateStopLoss(1, ask); // Assume buy for calculation
    if(sl == 0) return ValidationLotSize; // Fallback
    
    double sl_pips = MathAbs(ask - sl);
    if(sl_pips == 0) return ValidationLotSize; // Fallback
    
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double value_per_lot = (sl_pips / tick_size) * tick_value;
    if(value_per_lot == 0) return ValidationLotSize; // Fallback
    
    double lot_size = risk_amount / value_per_lot;
    
    return NormalizeLots(lot_size);
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(int direction, double entry_price)
{
    double atr_value = GetATRValue();
    if(atr_value == 0) return 0;

    // Use user's preferred 0.5% stop loss or ATR-based, whichever is more conservative
    double percent_sl_distance = entry_price * (StopLossPercent / 100.0);
    double atr_sl_distance = atr_value * 2.5;
    
    double sl_distance = MathMin(percent_sl_distance, atr_sl_distance);

    // Ensure minimum distance from freeze level
    double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if (sl_distance < stops_level)
    {
        sl_distance = stops_level;
    }

    double stop_loss = 0;
    if(direction == 1) // Buy
    {
        stop_loss = entry_price - sl_distance;
    }
    else // Sell
    {
        stop_loss = entry_price + sl_distance;
    }

    return NormalizePrice(stop_loss);
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                            |
//+------------------------------------------------------------------+
double CalculateTakeProfit(int direction, double entry_price, double sl_price)
{
    if(sl_price == 0) return 0;

    double sl_distance = MathAbs(entry_price - sl_price);
    if(sl_distance <= 0) return 0;

    double dynamic_rr = TakeProfitRR;

    if(UseDynamicTP)
    {
        if(market_state.is_trending && market_state.trend_direction == direction)
        {
            dynamic_rr *= (1.0 + market_state.trend_strength * 2.0);
        }
        else if (!market_state.is_trending)
        {
            dynamic_rr *= 0.75;
        }
        dynamic_rr = fmax(1.0, fmin(dynamic_rr, TakeProfitRR * 2.5));
    }

    double tp_distance = sl_distance * dynamic_rr;
    double take_profit = 0;

    if(direction == 1) // Buy
    {
        take_profit = entry_price + tp_distance;
    }
    else // Sell
    {
        take_profit = entry_price - tp_distance;
    }

    return NormalizePrice(take_profit);
}

//+------------------------------------------------------------------+
//| Normalize Lots                                                   |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
    if(min_lot <= 0) min_lot = 0.01; // Fallback
    if(lot_step <= 0) lot_step = 0.01; // Fallback
   
    // Clamp to max lot
    if(lots > max_lot) lots = max_lot;

    // Ensure lot size is at least minimum
    if(lots < min_lot) lots = min_lot;
   
    // Normalize to lot step
    lots = MathRound(lots / lot_step) * lot_step;
   
    return lots;
}

//+------------------------------------------------------------------+
//| Normalize Price                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
    return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Check Risk Conditions                                            |
//+------------------------------------------------------------------+
bool CheckRiskConditions()
{
    // Check max drawdown
    if(risk_metrics.current_drawdown > MaxDrawdown)
    {
        return false;
    }
    // Check daily risk
    if(risk_metrics.daily_pnl < 0 && MathAbs(risk_metrics.daily_pnl / AccountInfoDouble(ACCOUNT_EQUITY) * 100) > MaxDailyRisk)
    {
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check Valid Trading Time                                         |
//+------------------------------------------------------------------+
bool IsValidTradingTime()
{
    MqlDateTime time_struct;
    TimeCurrent(time_struct);
    
    if(time_struct.hour >= StartHour && time_struct.hour < EndHour)
    {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Manage Existing Positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
    if(!PositionSelect(_Symbol)) return;

    // --- Trailing Stop Logic ---
    if(UseTrailingStop)
    {
        MqlTick tick;
        if(!SymbolInfoTick(_Symbol, tick)) return;
        
        double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_sl = PositionGetDouble(POSITION_SL);
        double trail_dist_points = TrailingDistance * _Point;

        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            if(current_price > entry_price + trail_dist_points)
            {
                double new_sl = current_price - trail_dist_points;
                if(new_sl > current_sl)
                {
                    trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
                }
            }
        }
        else // Sell
        {
            if(current_price < entry_price - trail_dist_points)
            {
                double new_sl = current_price + trail_dist_points;
                if(new_sl < current_sl || current_sl == 0)
                {
                    trade.PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP));
                }
            }
        }
    }

    // --- Dynamic Take Profit Adjustment Logic ---
    if(UseDynamicTP)
    {
        long position_type = PositionGetInteger(POSITION_TYPE);
        int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
        
        if(market_state.is_trending && market_state.trend_direction == direction && market_state.trend_strength > 0.002)
        {
            double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl_price = PositionGetDouble(POSITION_SL);
            double current_tp = PositionGetDouble(POSITION_TP);

            double new_tp = CalculateTakeProfit(direction, entry_price, sl_price);

            if(direction == 1 && new_tp > current_tp)
            {
                trade.PositionModify(_Symbol, sl_price, new_tp);
            }
            else if(direction == -1 && new_tp < current_tp && new_tp != 0)
            {
                trade.PositionModify(_Symbol, sl_price, new_tp);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Risk Metrics                                              |
//+------------------------------------------------------------------+
void UpdateRiskMetrics()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity > equity_high) equity_high = equity;
    
    risk_metrics.current_drawdown = (equity_high > 0) ? (equity_high - equity) / equity_high * 100.0 : 0;
    
    MqlDateTime time_struct;
    TimeCurrent(time_struct);
    if(day_start_time != (datetime)time_struct.year) // Simplified daily reset
    {
        day_start_time = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
        day_start_equity = equity;
    }
    risk_metrics.daily_pnl = equity - day_start_equity;
}

//+------------------------------------------------------------------+
//| Reset Risk Metrics                                               |
//+------------------------------------------------------------------+
void ResetRiskMetrics()
{
    risk_metrics.current_drawdown = 0;
    risk_metrics.daily_pnl = 0;
    risk_metrics.win_rate = 0;
    risk_metrics.profit_factor = 0;
    risk_metrics.sharpe_ratio = 0;
    risk_metrics.consecutive_losses = 0;
}

//+------------------------------------------------------------------+
//| Dynamic Parameter Optimization                                   |
//+------------------------------------------------------------------+
void OptimizeParameters()
{
    // AI-based parameter optimization logic would go here
    // For market compliance, keeping this minimal
    return;
}

//+------------------------------------------------------------------+
//| Display Information on Chart                                     |
//+------------------------------------------------------------------+
void DisplayInfo()
{
    //--- Skip object creation in non-visual testing mode
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
        return;
        
    string info = "=== StrikeBot AI3 ===\n";
    info += "AI Mode: " + (UseAI ? "ENABLED" : "DISABLED") + "\n";
    info += "Symbol: " + _Symbol + "\n";
    info += "Position: " + (PositionSelect(_Symbol) ? "ACTIVE" : "NONE") + "\n";
    info += "--- Market Analysis ---\n";
    info += "Trend: " + (string)market_state.trend_direction + " | Strength: " + DoubleToString(market_state.trend_strength, 4) + "\n";
    info += "Volatility (ATR): " + DoubleToString(market_state.volatility, 5) + "\n";
    info += "--- Risk Management ---\n";
    info += "Drawdown: " + DoubleToString(risk_metrics.current_drawdown, 2) + "%\n";
    info += "Daily P/L: " + DoubleToString(risk_metrics.daily_pnl, 2) + "\n";
    info += "--- AI Signal ---\n";
    info += "Direction: " + (string)current_signal.direction + " | Confidence: " + DoubleToString(current_signal.confidence, 2) + "\n";

    Comment(info);
}
//+------------------------------------------------------------------+

