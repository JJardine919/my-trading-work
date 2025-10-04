//+------------------------------------------------------------------+
//|                                                  ExpertAdvisor.mq5 |
//|                                                     Manus AI       |
//|                                                  https://www.manus.im |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://www.manus.im"
#property version   "1.00"
#property description "MQL5 Expert Advisor for MetaTrader 5, implementing a momentum-based strategy with risk management."

//--- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Input parameters
input double InpRiskPerTrade = 0.005; // Risk per trade as a percentage of equity (0.5%)
input int    InpMagicNumber = 12345;  // Magic number for orders
input int    InpFastMAPeriod = 10;    // Period for fast Moving Average
input int    InpSlowMAPeriod = 20;    // Period for slow Moving Average
input int    InpMAPeriod = 14;        // Period for the main MA for signal
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA method
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied price
input int    InpCoolDownPeriod = 300; // Cool-down period in seconds after a stop loss

//--- Global variables
CTrade trade;         // Trading object
CPositionInfo position; // Position information object
CSymbolInfo symbol;   // Symbol information object

datetime lastTradeTime = 0; // To track the last trade time for cool-down

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize the CTrade object
   if(!trade.Init(ChartID(), _Symbol, _Period))
     {
      Print("Failed to initialize CTrade object. Error: ", GetLastError());
      return(INIT_FAILED);
     }

//--- Initialize CSymbolInfo
   if(!symbol.Name(_Symbol))
     {
      Print("Failed to initialize CSymbolInfo for ", _Symbol, ". Error: ", GetLastError());
      return(INIT_FAILED);
     }

//--- Set trade properties
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Fill or Kill
   trade.SetTypeTime(ORDER_TIME_GTC);    // Good Till Cancel

//--- Check input parameters
   if (InpRiskPerTrade <= 0 || InpRiskPerTrade >= 1.0)
     {
      Print("Error: Risk per trade must be between 0 and 1 (e.g., 0.005 for 0.5%).");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if (InpFastMAPeriod <= 0 || InpSlowMAPeriod <= 0 || InpFastMAPeriod >= InpSlowMAPeriod)
     {
      Print("Error: MA periods must be positive and Fast MA period must be less than Slow MA period.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   Print("Expert Advisor initialized successfully for ", _Symbol);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Perform cleanup tasks
   Print("Expert Advisor deinitialized. Reason: ", reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Check if there are any open positions for this EA
   if (PositionsTotal() > 0)
     {
      // For simplicity, we only allow one position at a time.
      // In a more complex EA, this would involve managing existing positions.
      return;
     }

//--- Implement cool-down period after a stop loss
   if (lastTradeTime > 0 && (TimeCurrent() - lastTradeTime) < InpCoolDownPeriod)
     {
      Print("Cool-down period active. Remaining: ", InpCoolDownPeriod - (TimeCurrent() - lastTradeTime), " seconds.");
      return;
     }

//--- Get current Bid and Ask prices
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
     {
      Print("Failed to get tick data: ", GetLastError());
      return;
     }
   double bid = tick.bid;
   double ask = tick.ask;

//--- Calculate Moving Averages
   double fastMA = iMA(_Symbol, _Period, InpFastMAPeriod, 0, InpMAMethod, InpAppliedPrice, 0);
   double slowMA = iMA(_Symbol, _Period, InpSlowMAPeriod, 0, InpMAMethod, InpAppliedPrice, 0);

   if (fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE)
     {
      Print("Error calculating Moving Averages. Check data availability.");
      return;
     }

//--- Trading logic (momentum-based strategy: MA crossover)
   bool buySignal = (fastMA > slowMA && iMA(_Symbol, _Period, InpFastMAPeriod, 0, InpMAMethod, InpAppliedPrice, 1) <= iMA(_Symbol, _Period, InpSlowMAPeriod, 0, InpMAMethod, InpAppliedPrice, 1));
   bool sellSignal = (fastMA < slowMA && iMA(_Symbol, _Period, InpFastMAPeriod, 0, InpMAMethod, InpAppliedPrice, 1) >= iMA(_Symbol, _Period, InpSlowMAPeriod, 0, InpMAMethod, InpAppliedPrice, 1));

   if (buySignal)
     {
      ExecuteTrade(ORDER_TYPE_BUY, ask, bid);
     }
   else if (sellSignal)
     {
      ExecuteTrade(ORDER_TYPE_SELL, bid, ask);
     }
  }

//+------------------------------------------------------------------+
//| Function to calculate and normalize lot size                     |
//+------------------------------------------------------------------+
double CalculateAndNormalizeLot(double price, ENUM_ORDER_TYPE order_type)
  {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = accountEquity * InpRiskPerTrade;

   // Get symbol specific information
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if (tickSize == 0) tickSize = point; // Fallback if tick size is not defined

   // Calculate stop loss in points based on a fixed percentage of price for BTC
   // For BTC, a fixed pip value is not as meaningful as a percentage of price
   double stopLossPoints = (order_type == ORDER_TYPE_BUY) ? (price * 0.005 / point) : (price * 0.005 / point); // 0.5% of price as SL

   if (stopLossPoints <= 0)
     {
      Print("Error: Calculated Stop Loss points is zero or negative.");
      return 0.0;
     }

   // Calculate potential loss per lot
   double lossPerLot = stopLossPoints * tickValue / point; // Loss in account currency per standard lot

   if (lossPerLot <= 0)
     {
      Print("Error: Calculated loss per lot is zero or negative.");
      return 0.0;
     }

   double calculatedLots = riskAmount / lossPerLot;

   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   calculatedLots = fmax(minLot, calculatedLots); // Ensure at least minLot
   calculatedLots = fmin(maxLot, calculatedLots); // Ensure not more than maxLot

   // Round to the nearest lot step
   calculatedLots = MathRound(calculatedLots / lotStep) * lotStep;

   // Ensure the lot size is still within min/max after rounding
   calculatedLots = fmax(minLot, calculatedLots);
   calculatedLots = fmin(maxLot, calculatedLots);

   return calculatedLots;
  }

//+------------------------------------------------------------------+
//| Function to execute a trade                                      |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double opposite_price)
  {
   double lotSize = CalculateAndNormalizeLot(entry_price, order_type);

   if (lotSize <= 0)
     {
      Print("Cannot execute trade: Invalid lot size calculated.");
      return;
     }

   double stopLossPrice;
   double takeProfitPrice;

   // Calculate Stop Loss and Take Profit based on InpRiskPerTrade (0.5% of entry price)
   double sl_offset = entry_price * InpRiskPerTrade; // 0.5% of entry price
   double tp_offset = sl_offset * 2; // Example: 1:2 Risk-Reward Ratio

   if (order_type == ORDER_TYPE_BUY)
     {
      stopLossPrice = entry_price - sl_offset;
      takeProfitPrice = entry_price + tp_offset;
     }
   else // ORDER_TYPE_SELL
     {
      stopLossPrice = entry_price + sl_offset;
      takeProfitPrice = entry_price - tp_offset;
     }

   // Normalize prices to symbol digits
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   stopLossPrice = NormalizeDouble(stopLossPrice, digits);
   takeProfitPrice = NormalizeDouble(takeProfitPrice, digits);

   // Send the order
   bool result;
   if (order_type == ORDER_TYPE_BUY)
     {
      result = trade.Buy(lotSize, _Symbol, entry_price, stopLossPrice, takeProfitPrice, "Buy Order");
     }
   else
     {
      result = trade.Sell(lotSize, _Symbol, entry_price, stopLossPrice, takeProfitPrice, "Sell Order");
     }

   if (result)
     {
      Print(EnumToString(order_type), " order placed successfully. Lot: ", lotSize, ", SL: ", stopLossPrice, ", TP: ", takeProfitPrice);
      lastTradeTime = TimeCurrent(); // Update last trade time
     }
   else
     {
      Print("Failed to place ", EnumToString(order_type), " order. Error: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Helper function to get current time                              |
//+------------------------------------------------------------------+
// This is a placeholder for TimeCurrent() which is a built-in MQL5 function.
// No need to define it here, but keeping it as a reminder for potential custom time handling.
// datetime GetCurrentTime() { return TimeCurrent(); }

//+------------------------------------------------------------------+

