//+------------------------------------------------------------------+
//|                                                     StrikeBot    |
//|                          Precision Trading System (MQL5)         |
//|                  Corrected for modern MQL5 compatibility         |
//+------------------------------------------------------------------+
#property copyright "Revised by Gemini"
#property link      "https://gemini.google.com"
#property version   "1.1"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input double    SL_Percent        = 0.15;
input double    TP_Percent        = 0.1;
input int       Drawdown_Mode     = 0;    // 0 = Static, 1 = Elevated, 2 = MaxFlex
input double    Trailing_SL_Extra = 0.15;
input int       MagicNumber       = 30250626;
input bool      Autotrade         = true;
input int       Inp_MA_Period     = 100;
input double    DynamicTrail_Percent = 0.2;
input double    DynamicTP_LiftPercent = 0.2;
input int       RSI_Period        = 14;
input double    RSI_Overbought    = 70.0;
input double    RSI_Oversold      = 30.0;
input int       MaxConsecutiveLosses = 3;
input double    WinRateTarget     = 70.0;
input double    BaseLotSize       = 0.01;
input double    MaxLotSize        = 0.03;
input double    VolumeScaleFactor = 0.005;
input double    TP_Points         =  500;       // Take Profit in points
input int       FastRSI           =  7.0;
input int       SlowRSI           =   14;
input double    Max_Drawdown      =  2.0;
input double    Balance_Drawdown  =  0.5;

//--- Global
CTrade trade;
int    fast_ma_handle;
int    slow_ma_handle;
double entry_price = 0.0;

//+------------------------------------------------------------------+
int OnInit()
{
  trade.SetExpertMagicNumber(MagicNumber);
  trade.SetAsyncMode(true);

  fast_ma_handle = iMA(_Symbol, _Period, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
  slow_ma_handle = iMA(_Symbol, _Period, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

  if(fast_ma_handle == INVALID_HANDLE || slow_ma_handle == INVALID_HANDLE)
  {
    Print("Error creating indicator handles. Error code: ", GetLastError());
    return(INIT_FAILED);
  }

  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  IndicatorRelease(fast_ma_handle);
  IndicatorRelease(slow_ma_handle);
}
//+------------------------------------------------------------------+
void OnTick()
{
  if(PositionsTotal() > 0 && PositionGetSymbol(0) == _Symbol)
  {
    ManageOpenPosition();
    return;
  }

  double fast_ma_buffer[2];
  double slow_ma_buffer[2];

  if(CopyBuffer(fast_ma_handle, 0, 1, 2, fast_ma_buffer) != 2 ||
     CopyBuffer(slow_ma_handle, 0, 1, 2, slow_ma_buffer) != 2)
  {
    Print("Error copying indicator buffer data. Error: ", GetLastError());
    return;
  }

  double fastMA = fast_ma_buffer[0];
  double slowMA = slow_ma_buffer[0];

  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  if(ask == 0 || bid == 0) return;

  if(fastMA > slowMA)
  {
    double sl_price = bid - StopLoss * _Point;
    double tp_price = bid + TakeProfit * _Point;

    trade.Buy(LotSize, _Symbol, ask, sl_price, tp_price, "StrikeBot Buy");
    entry_price = ask;

    if(trade.ResultRetcode() != TRADE_RETCODE_DONE && trade.ResultRetcode() != TRADE_RETCODE_PLACED)
      Print("Trade failed: ", trade.ResultRetcode(), " - ", trade.ResultComment());
    else
      Print("Trade executed: Ticket#", trade.ResultOrder());
  }
}
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
  if (!PositionSelect(_Symbol))
    return;

  ulong  ticket         = PositionGetInteger(POSITION_TICKET);
  double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
  double sl             = PositionGetDouble(POSITION_SL);
  double current_price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  double current_tp     = PositionGetDouble(POSITION_TP);

  // Trailing Stop
  if (current_price - position_price >= TrailingStop * _Point)
  {
    double new_sl = current_price - TrailingStop * _Point;
    if (new_sl > sl)
    {
      trade.PositionModify(ticket, new_sl, current_tp);
      Print("Trailing Stop updated to: ", new_sl);
    }
  }

  // Dynamic TP
  double new_tp = position_price + DynamicTP * _Point;
  if (current_tp != new_tp)
  {
    trade.PositionModify(ticket, sl, new_tp);
    Print("Dynamic Take Profit updated to: ", new_tp);
  }
}
//+------------------------------------------------------------------+
void CloseTrade()
{
  for (int i = 0; i < PositionsTotal(); i++)
  {
    if(PositionGetSymbol(i) == _Symbol)
    {
      ulong ticket = PositionGetTicket(i);
      if (!trade.PositionClose(ticket))
        Print("Failed to close position: ", GetLastError());
      else
        Print("Position closed successfully: Ticket#", ticket);
    }
  }
}
//+------------------------------------------------------------------+
