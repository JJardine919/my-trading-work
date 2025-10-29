//+------------------------------------------------------------------+
//| finmem.mq5 |
//| Copyright 2025, Sustai Labs |
//| Deep LSTM ONNX Integration for Maximal EA Efficacy - Fully Restored |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, CryptoSamurai"
#property link "https://cryptosamurai.ai"
#property version "2.30" // FIXED: Added Emergency Stops + ONNX Integration
#property strict
#property description "Advanced Grid Trading + FinMem + Deep LSTM ONNX - Comprehensive"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "OnnxHandler.mqh"  // FIXED: Using local OnnxHandler instead of missing Onnx.mqh

//+------------------------------------------------------------------+
//| Input Parameters (Global Scope Ensured) |
//+------------------------------------------------------------------+
input group "=== Lot Sizing & Grid ==="
input bool   LotsAuto              = false;  // Auto lot sizing
input double LotsInitial           = 0.03;   // Initial lots if auto=false
input double LotsMultiplier        = 1.4;    // Lot multiplier for grid (>1.0)
input double LotsMaxPerTrade       = 1.4;    // Max lots per trade
input int    GridMaximumTrades     = 30;     // Max concurrent trades
input group "=== Trading Control ==="
input int    CooldownSeconds       = 500;    // Seconds between trades
input int    MaxDailyTrades        = 50;     // Daily trade limit
input group "=== Position Control ==="
input double TakeProfitPoints      = 150000; //Take Profit in points
input double StopLossPoints        = 15000;  // Stop Loss in points
input group "=== Safety ==="
input double DrawdownFreezePercent = 15.3;   // Freeze if BALANCE drops this % from peak
input bool   UseEquityDrawdown     = true;   // Use balance instead of equity for drawdown
input bool   PrintDebugInfo        = false;  // Enable debug info
input group "=== Emergency Stops (NEW) ==="
input double EmergencyDailyDD      = 3.0;    // Emergency daily drawdown limit (%)
input double EmergencyTotalDD      = 8.0;    // Emergency total drawdown limit (%)
input int    EmergencyMaxLosses    = 5;      // Emergency max consecutive losses
input group "=== Simple Entry Logic ==="
input int    RSI_Period            = 19;     // RSI period
input double RSI_Oversold          = 77.1;   // RSI oversold level
input double RSI_Overbought        = 28.4;   // RSI overbought level
input bool   BothDirections        = true;   // Trade both buy and sell
input group "=== EA Identification ==="
input int    MagicNumber           = 19720421;
input string TradeComment          = "StrikeBOSS";
input group "=== FinMem Integration ==="
input bool   UseFinMem             = true;                                                                                              // Enable FinMem
input int    ATR_Period            = 14;                                                                                                // For volatility
input int    MA_Fast               = 30;                                                                                                // Fast MA for trend
input int    MA_Slow               = 70;                                                                                                // Slow MA for trend
input string FINMEM_URL            = "https://mql5-sentinel-80923b8d.base44.app/api/apps/68eda7a6b1c779fb80923b8d/functions/eaWebhook"; // FinMem endpoint
input string FINMEM_API_KEY        = "17aa067b5d4b4946b3f6336f913b6ac2";                                                                // Your Base44 anon/public API Key
input group "=== ONNX Neural Network ==="
input bool   UseONNX               = false;                   // DISABLED by default - enable when ready
input string ONNX_ModelFile        = "strikeboss_lstm.onnx";  // ONNX model filename in Files/
input double ONNX_Threshold        = 0.6;                     // Min confidence for NN signal override
input int    SequenceLength        = 20;                      // LSTM timesteps for depth
input double SmoothingAlpha        = 0.2;                     // EMA smoothing for transitions
input group "=== Ensemble ==="
input bool   UseEnsemble           = false; // CatBoost fusion (disabled for simplicity)

//+------------------------------------------------------------------+
//| Forward Declarations (Classes and Functions only) |
//+------------------------------------------------------------------+
class CGridPositionManager;
class CSimpleDrawdownGuard;
class CReplayBuffer;
struct SExperience;

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
void SendToFinMem(string type);
void OpenTrade(ENUM_ORDER_TYPE type, double confidence);
bool CheckVolumeValue(double volume, string &description);
bool CheckMoneyForTrade(string symbol, double lots, ENUM_ORDER_TYPE type);
bool CheckEmergencyStop();
void CloseAllPositions();

//+------------------------------------------------------------------+
//| Class Definitions and Implementations (Fixed CPositionInfo passing) |
//+------------------------------------------------------------------+
class CGridPositionManager
{
private:
   int               m_magic;
   string            m_symbol;
   int               m_max_trades;
public:
   void              Init(int magic, string symbol, int max_trades)
   {
      m_magic = magic;
      m_symbol = symbol;
      m_max_trades = max_trades;
   }
   int               CountPositions(CPositionInfo &posInfoRef)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(posInfoRef.SelectByIndex(i) && posInfoRef.Magic() == m_magic && posInfoRef.Symbol() == m_symbol)
         {
            count++;
         }
      }
      return count;
   }
   double            GetNextLotSize(ENUM_POSITION_TYPE direction, CPositionInfo &posInfoRef)
   {
      double last_lot = 0.0;
      long last_time = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(posInfoRef.SelectByIndex(i) && posInfoRef.Magic() == m_magic && posInfoRef.Symbol() == m_symbol && posInfoRef.PositionType() == direction)
         {
            if(posInfoRef.Time() > last_time)
            {
               last_lot = posInfoRef.Volume();
               last_time = posInfoRef.Time();
            }
         }
      }
      if(last_lot == 0.0) return LotsInitial;
      return(last_lot * LotsMultiplier);
   }
   bool              IsMaxTradesReached(CPositionInfo &posInfoRef)
   {
      return(CountPositions(posInfoRef) >= m_max_trades);
   }
};
//+------------------------------------------------------------------+
class CSimpleDrawdownGuard
{
private:
   double            m_peak_balance;
   double            m_freeze_percent;
   bool              m_use_equity;
   bool              m_is_frozen;
public:
   void              Init(double freeze_percent, bool use_equity)
   {
      m_peak_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_freeze_percent = freeze_percent;
      m_use_equity = use_equity;
      m_is_frozen = false;
   }
   void              Update()
   {
      double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(current_balance > m_peak_balance) m_peak_balance = current_balance;
      double check_value = m_use_equity ? AccountInfoDouble(ACCOUNT_EQUITY) : current_balance;
      double drawdown = (m_peak_balance > 0) ? (m_peak_balance - check_value) / m_peak_balance * 100.0 : 0.0;
      if(drawdown >= m_freeze_percent)
      {
         if(!m_is_frozen)
         {
            Print("Drawdown limit of ", DoubleToString(m_freeze_percent, 2), "% reached. Trading frozen.");
            m_is_frozen = true;
         }
      }
      else
      {
         if(m_is_frozen)
         {
            Print("Drawdown is back within limits. Trading resumed.");
            m_is_frozen = false;
         }
      }
   }
   bool              IsFrozen()
   {
      return m_is_frozen;
   }
};
//+------------------------------------------------------------------+
struct SExperience
{
   double            state[20][8];
   double            action[2];
   double            reward;
   double            priority;
};
//+------------------------------------------------------------------+
class CReplayBuffer
{
private:
   SExperience       m_buffer[];
   int               m_size;
   int               m_max_size;
public:
   void              Init(int max_size)
   {
      ArrayResize(m_buffer, max_size);
      m_size = 0;
      m_max_size = max_size;
   }
   void              Add(const double &state[][8], const double &action[], double reward)
   {
      if (m_size >= m_max_size) m_size = 0;
      for(int t = 0; t < 20; t++)
      {
         for(int f = 0; f < 8; f++)
         {
            m_buffer[m_size].state[t][f] = state[t][f];
         }
      }
      for(int a = 0; a < 2; a++)
      {
         m_buffer[m_size].action[a] = action[a];
      }
      m_buffer[m_size].reward = reward;
      m_buffer[m_size].priority = MathAbs(reward) + 1e-5;
      m_size++;
   }
   void              UpdateLastReward(double reward)
   {
      if (m_size > 0)
      {
         m_buffer[m_size - 1].reward = reward;
      }
   }
   void              Save(const string filename)
   {
      int handle = FileOpen(filename, FILE_WRITE | FILE_BIN);
      if (handle != INVALID_HANDLE)
      {
         FileWriteArray(handle, m_buffer, 0, m_size);
         FileClose(handle);
      }
   }
   void              Load(const string filename)
   {
      int handle = FileOpen(filename, FILE_READ | FILE_BIN);
      if (handle != INVALID_HANDLE)
      {
         FileReadArray(handle, m_buffer);
         FileClose(handle);
         m_size = ArraySize(m_buffer);
      }
   }
};

//+------------------------------------------------------------------+
//| Global Variables |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo posInfo;
CGridPositionManager gridManager;
CSimpleDrawdownGuard drawdownGuard;
CReplayBuffer replayBuffer;
COnnxHandler onnxHandler;  // ONNX handler instance

int tradesToday = 0;
datetime lastTradeTime = 0;
datetime dateToday = 0;

// Indicator handles
int rsi_handle = INVALID_HANDLE;
int atr_handle = INVALID_HANDLE;
int ma_fast_handle = INVALID_HANDLE;
int ma_slow_handle = INVALID_HANDLE;

// ONNX Globals
const int INPUT_FEATURES = 8;
const int OUTPUT_ACTIONS = 2;
double sequence_buffer[20][8];
int seq_idx = 0;
double smoothed_buy = 0.0;
double smoothed_sell = 0.0;
string replay_filename = "deep_replay.bin";

// Emergency Stop System
datetime g_currentDay = 0;
double   g_dayStartEquity = 0;
double   g_peakEquity = 0;
bool     g_emergencyStop = false;
int      g_consecutiveLosses = 0;

//+------------------------------------------------------------------+
//| Emergency Stop Check Function |
//+------------------------------------------------------------------+
bool CheckEmergencyStop()
{
   if(g_emergencyStop) return true;

   // Check for new day
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(g_currentDay != today)
   {
      g_currentDay = today;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_consecutiveLosses = 0;
   }

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Track peak equity
   if(currentEquity > g_peakEquity)
      g_peakEquity = currentEquity;

   // Calculate drawdowns
   double dailyDD = 0;
   if(g_dayStartEquity > 0)
      dailyDD = ((g_dayStartEquity - currentEquity) / g_dayStartEquity) * 100;

   double totalDD = 0;
   if(g_peakEquity > 0)
      totalDD = ((g_peakEquity - currentEquity) / g_peakEquity) * 100;

   // Check daily drawdown limit
   if(dailyDD >= EmergencyDailyDD)
   {
      g_emergencyStop = true;
      Print("🚨 EMERGENCY STOP: Daily drawdown ", DoubleToString(dailyDD, 2), "% (limit: ", EmergencyDailyDD, "%)");
      CloseAllPositions();
      return true;
   }

   // Check total drawdown limit
   if(totalDD >= EmergencyTotalDD)
   {
      g_emergencyStop = true;
      Print("🚨 EMERGENCY STOP: Total drawdown ", DoubleToString(totalDD, 2), "% (limit: ", EmergencyTotalDD, "%)");
      CloseAllPositions();
      return true;
   }

   // Check consecutive losses
   if(g_consecutiveLosses >= EmergencyMaxLosses)
   {
      g_emergencyStop = true;
      Print("🚨 EMERGENCY STOP: ", g_consecutiveLosses, " consecutive losses (limit: ", EmergencyMaxLosses, ")");
      CloseAllPositions();
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Close All Positions Function |
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
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(trade.PositionClose(ticket))
            {
               closedCount++;
            }
         }
      }
   }

   if(closedCount > 0)
   {
      Print("Emergency stop closed ", closedCount, " position(s)");
   }
}

//+------------------------------------------------------------------+
//| Expert Initialization Function |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   gridManager.Init(MagicNumber, _Symbol, GridMaximumTrades);
   drawdownGuard.Init(DrawdownFreezePercent, UseEquityDrawdown);
   replayBuffer.Init(20000);
   replayBuffer.Load(replay_filename);

   // Initialize emergency stop system
   g_currentDay = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_emergencyStop = false;
   g_consecutiveLosses = 0;

   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   ma_fast_handle = iMA(_Symbol, _Period, MA_Fast, 0, MODE_SMA, PRICE_CLOSE);
   ma_slow_handle = iMA(_Symbol, _Period, MA_Slow, 0, MODE_SMA, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE ||
      ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return(INIT_FAILED);
   }

   // ONNX Initialization (enabled when UseONNX = true)
   if (UseONNX)
   {
      if(!onnxHandler.LoadModel(ONNX_ModelFile))
      {
         Print("Warning: ONNX model failed to load. Continuing with RSI signals only.");
      }
      else
      {
         Print("ONNX model loaded successfully: ", ONNX_ModelFile);
      }
   }

   ArrayInitialize(sequence_buffer, 0.0);
   dateToday = TimeCurrent();

   Print("finmem.mq5 initialized successfully");
   Print("Emergency stops: Daily DD=", EmergencyDailyDD, "%, Total DD=", EmergencyTotalDD,
         "%, Max Consecutive Losses=", EmergencyMaxLosses);
   Print("ONNX: ", UseONNX ? "ENABLED" : "DISABLED");
   Print("FinMem: ", UseFinMem ? "ENABLED" : "DISABLED");

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert Deinitialization Function |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
   IndicatorRelease(ma_fast_handle);
   IndicatorRelease(ma_slow_handle);

   // Release ONNX model if loaded
   if (UseONNX && onnxHandler.IsLoaded())
   {
      onnxHandler.UnloadModel();
   }

   replayBuffer.Save(replay_filename);
   Print("Resources released and replay saved.");
}
//+------------------------------------------------------------------+
//| Expert Tick Function (Fixed to use non-const posInfo) |
//+------------------------------------------------------------------+
void OnTick()
{
   // EMERGENCY STOP CHECK FIRST - HIGHEST PRIORITY
   if(CheckEmergencyStop()) return;

   datetime server_time = TimeCurrent();
   if(server_time / 86400 > dateToday / 86400)
   {
      tradesToday = 0;
      dateToday = server_time;
   }
   if(TimeCurrent() < lastTradeTime + CooldownSeconds) return;
   drawdownGuard.Update();
   if(drawdownGuard.IsFrozen()) return;

   if(gridManager.IsMaxTradesReached(posInfo) || tradesToday >= MaxDailyTrades) return;

   double rsi_values[3];
   if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_values) <= 0) return;
   double current_rsi = rsi_values[0];

   double atr_values[1], ma_fast_values[1], ma_slow_values[1];
   double open_val = iOpen(_Symbol, _Period, 0);
   double high_val = iHigh(_Symbol, _Period, 0);
   double low_val = iLow(_Symbol, _Period, 0);
   double close_val = iClose(_Symbol, _Period, 0);
   if (CopyBuffer(atr_handle, 0, 0, 1, atr_values) <= 0 ||
       CopyBuffer(ma_fast_handle, 0, 0, 1, ma_fast_values) <= 0 ||
       CopyBuffer(ma_slow_handle, 0, 0, 1, ma_slow_values) <= 0) return;
   double atr = atr_values[0];
   double fast_ma = ma_fast_values[0];
   double slow_ma = ma_slow_values[0];
   double state[8] = {current_rsi / 100.0, atr, fast_ma, slow_ma, open_val, high_val, low_val, close_val};

   for(int f = 0; f < 8; f++)
   {
      sequence_buffer[seq_idx][f] = state[f];
   }
   seq_idx = (seq_idx + 1) % SequenceLength;

   double nn_buy_conf = 0.0;
   double nn_sell_conf = 0.0;

   // ONNX INFERENCE (when enabled)
   if (UseONNX && onnxHandler.IsLoaded())
   {
      // Flatten sequence buffer for ONNX input
      double flat_input[];
      ArrayResize(flat_input, SequenceLength * INPUT_FEATURES);

      for(int t = 0; t < SequenceLength; t++)
      {
         int buf_idx = (seq_idx - SequenceLength + t + SequenceLength) % SequenceLength;
         for(int f = 0; f < INPUT_FEATURES; f++)
         {
            flat_input[t * INPUT_FEATURES + f] = sequence_buffer[buf_idx][f];
         }
      }

      double nn_output[];
      ArrayResize(nn_output, OUTPUT_ACTIONS);

      if(onnxHandler.RunInference(flat_input, nn_output))
      {
         // Smooth predictions with EMA
         smoothed_buy = SmoothingAlpha * nn_output[0] + (1.0 - SmoothingAlpha) * smoothed_buy;
         smoothed_sell = SmoothingAlpha * nn_output[1] + (1.0 - SmoothingAlpha) * smoothed_sell;

         nn_buy_conf = smoothed_buy;
         nn_sell_conf = smoothed_sell;

         if(PrintDebugInfo)
         {
            Print("ONNX Predictions - Buy: ", DoubleToString(nn_buy_conf, 4),
                  " Sell: ", DoubleToString(nn_sell_conf, 4));
         }
      }
   }

   // Signal logic: ONNX overrides RSI when confidence is high
   bool buy_signal = (UseONNX && nn_buy_conf > ONNX_Threshold) || (current_rsi < RSI_Oversold);
   bool sell_signal = (UseONNX && nn_sell_conf > ONNX_Threshold) || (current_rsi > RSI_Overbought);

   if (buy_signal)
   {
      bool condition_buy = BothDirections || (gridManager.CountPositions(posInfo) == 0) ||
                          (PositionsTotal() > 0 && posInfo.SelectByIndex(0) && posInfo.PositionType() == POSITION_TYPE_BUY);
      if (condition_buy)
      {
         OpenTrade(ORDER_TYPE_BUY, nn_buy_conf);
      }
   }
   if (sell_signal)
   {
      bool condition_sell = BothDirections || (gridManager.CountPositions(posInfo) == 0) ||
                           (PositionsTotal() > 0 && posInfo.SelectByIndex(0) && posInfo.PositionType() == POSITION_TYPE_SELL);
      if (condition_sell)
      {
         OpenTrade(ORDER_TYPE_SELL, nn_sell_conf);
      }
   }
}
//+------------------------------------------------------------------+
//| FinMem Integration Function |
//+------------------------------------------------------------------+
void SendToFinMem(string type)
{
   if(!UseFinMem || FINMEM_API_KEY == "" || FINMEM_API_KEY == "17aa067b5d4b4946b3f6336f913b6ac2") return;
   double atr_val[1], ma_fast_val[1], ma_slow_val[1];
   CopyBuffer(atr_handle, 0, 1, 1, atr_val);
   CopyBuffer(ma_fast_handle, 0, 1, 1, ma_fast_val);
   CopyBuffer(ma_slow_handle, 0, 1, 1, ma_slow_val);
   double atr = (ArraySize(atr_val) > 0) ? atr_val[0] : 0.0;
   double fast_ma = (ArraySize(ma_fast_val) > 0) ? ma_fast_val[0] : 0.0;
   double slow_ma = (ArraySize(ma_slow_val) > 0) ? ma_slow_val[0] : 0.0;
   int positions = gridManager.CountPositions(posInfo);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string json = StringFormat("{\"type\":\"%s\",\"symbol\":\"%s\",\"atr\":%.5f,\"fast_ma\":%.5f,\"slow_ma\":%.5f,\"positions\":%d,\"balance\":%.2f,\"equity\":%.2f}",
                              type, _Symbol, atr, fast_ma, slow_ma, positions, balance, equity);
   if(PrintDebugInfo) Print("FinMem JSON: ", json);
   string headers = "apikey: " + FINMEM_API_KEY + "\r\nContent-Type: application/json";
   char post_data[], result_data[];
   string result_headers;
   ResetLastError();
   int res_code = WebRequest("POST", FINMEM_URL, headers, 5000, post_data, result_data, result_headers);
   if(res_code == 200)
   {
      if(PrintDebugInfo) Print("FinMem signal sent successfully.");
   }
   else
   {
      Print("FinMem Error. Code: ", res_code, ". MQL5 Error: ", GetLastError(), ". Response: ", CharArrayToString(result_data));
   }
}
//+------------------------------------------------------------------+
//| Trade Execution Function |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double confidence)
{
   double lots = LotsAuto ? gridManager.GetNextLotSize((ENUM_POSITION_TYPE)type, posInfo) : LotsInitial;
   if(lots > LotsMaxPerTrade) lots = LotsMaxPerTrade;
   string vol_desc;
   if(!CheckVolumeValue(lots, vol_desc))
   {
      Print("Volume check failed: ", vol_desc);
      return;
   }
   if(!CheckMoneyForTrade(_Symbol, lots, type)) return;
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calculate SL/TP based on Points input
   double sl = 0, tp = 0;
   double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(type == ORDER_TYPE_BUY)
   {
      sl = (StopLossPoints > 0) ? price - StopLossPoints * point_size : 0;
      tp = (TakeProfitPoints > 0) ? price + TakeProfitPoints * point_size : 0;
   }
   else // ORDER_TYPE_SELL
   {
      sl = (StopLossPoints > 0) ? price + StopLossPoints * point_size : 0;
      tp = (TakeProfitPoints > 0) ? price - TakeProfitPoints * point_size : 0;
   }

   // Use NormalizeDouble to ensure correct price formatting for broker
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if (sl > 0) sl = NormalizeDouble(sl, digits);
   if (tp > 0) tp = NormalizeDouble(tp, digits);

   if(trade.PositionOpen(_Symbol, type, lots, price, sl, tp, TradeComment))
   {
      tradesToday++;
      lastTradeTime = TimeCurrent();
      SendToFinMem("Trade Executed");
      double action[2] = {0.0, 0.0};
      action[(type == ORDER_TYPE_BUY) ? 0 : 1] = confidence;
      double temp_state[20][8];
      for(int t = 0; t < 20; t++)
      {
         for(int f = 0; f < 8; f++)
         {
            int buf_idx = (seq_idx - SequenceLength + t + SequenceLength) % SequenceLength;
            temp_state[t][f] = sequence_buffer[buf_idx][f];
         }
      }
      replayBuffer.Add(temp_state, action, 0.0);
   }
   else
   {
      Print("OrderSend failed. Error: ", trade.ResultRetcode(), ", Price: ", price, ", SL: ", sl, ", TP: ", tp);
   }
}
//+------------------------------------------------------------------+
//| Trade Transaction Event |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.symbol == _Symbol)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         if(deal_magic == MagicNumber)
         {
            long deal_entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(deal_entry == DEAL_ENTRY_OUT)
            {
               double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
               replayBuffer.UpdateLastReward(profit);

               // Track consecutive losses for emergency stop
               if(profit < 0)
               {
                  g_consecutiveLosses++;
               }
               else
               {
                  g_consecutiveLosses = 0;
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Volume Validation Function |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume, string &description)
{
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(volume < min_volume)
   {
      description = StringFormat("Volume %.4f is less than minimal allowed %.4f", volume, min_volume);
      return false;
   }
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(volume > max_volume)
   {
      description = StringFormat("Volume %.4f is greater than maximal allowed %.4f", volume, max_volume);
      return false;
   }
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume_step > 0)
   {
      double check_volume = NormalizeDouble(volume / volume_step, 0);
      double check_val = NormalizeDouble(check_volume * volume_step, 8);
      if(MathAbs(check_val - volume) > 0.0000001)
      {
         description = StringFormat("Volume %.4f is not multiple of step %.4f, closest: %.4f",
                                  volume, volume_step, check_val);
         return false;
      }
   }
   description = "Volume is valid";
   return true;
}
//+------------------------------------------------------------------+
//| Money Check Function |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symbol, double lots, ENUM_ORDER_TYPE type)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
   {
      Print("Error getting tick info for ", symbol, ", code=", GetLastError());
      return false;
   }
   double price = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
   double margin, free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(type, symbol, lots, price, margin))
   {
      Print("Error calculating margin, code=", GetLastError());
      return false;
   }
   if(margin > free_margin)
   {
      Print("Not enough money for ", EnumToString(type), " ", DoubleToString(lots, 2), " ", symbol,
            " Required: ", DoubleToString(margin, 2), " Available: ", DoubleToString(free_margin, 2));
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
