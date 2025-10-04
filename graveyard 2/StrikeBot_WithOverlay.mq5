//+------------------------------------------------------------------+
//| Expert Advisor: StrikeBot_Adaptive                               |
//| Includes overlay panel and 2% drawdown protection                |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include "StrikeBot_OverlayPanel.mqh"

input double    LotSize           = 0.01;
input int       RSI_Period        = 14;
input double    BaseOverbought    = 70.0;
input double    BaseOversold      = 30.0;
input int       MAPeriod          = 100;
input double    SL_Pct            = 0.25;
input double    TP_Pct            = 0.66;
input int       ModeOverride      = 0;     // 0=Auto, 1=Bull, 2=Bear, 3=Neutral
input bool      AutotradeEnabled  = true;
input int       MagicNumber       = 9911;

double InitialEquity;

int OnInit() {
    InitialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    PrintFormat("[StrikeBot] Initializing. Initial Equity: %.2f", InitialEquity);
    InitOverlayPanel();
    return INIT_SUCCEEDED;
}

void OnTick() {
    if (!AutotradeEnabled || !TerminalInfoInteger(TERMINAL_CONNECTED)) {
        return;
    }

    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double drawdownPct = 100.0 * (InitialEquity - currentEquity) / InitialEquity;
    if (drawdownPct > 2.0) {
        PrintFormat("[StrikeBot] Drawdown limit reached: %.2f%% > 2%%. Autotrading paused.", drawdownPct);
        UpdateOverlayPanel(0, 0, "Paused", currentEquity, drawdownPct);
        return;
    }

    if (PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        return;

    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if (Bars(_Symbol, PERIOD_CURRENT) < MathMax(RSI_Period, MAPeriod)) {
        PrintFormat("[StrikeBot] Not enough bars for indicators.");
        return;
    }

    double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    double ma  = iMA(_Symbol, PERIOD_CURRENT, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);

    if (rsi == EMPTY_VALUE || ma == EMPTY_VALUE) {
        PrintFormat("[StrikeBot] Invalid indicator values.");
        return;
    }

    double adjOverbought = BaseOverbought - (price < ma ? 5 : 0);
    double adjOversold   = BaseOversold   + (price > ma ? 5 : 0);

    int mode = DetectMarketMode(ma, rsi, adjOverbought, adjOversold);
    if (ModeOverride > 0)
        mode = ModeOverride;

    string status = "HOLD";
    double sl, tp;
    if (mode == 1) {
        sl = NormalizeDouble(price * (1 - SL_Pct / 100.0), _Digits);
        tp = NormalizeDouble(price * (1 + TP_Pct / 100.0), _Digits);
        status = "BUY";
        OpenTrade(ORDER_TYPE_BUY, ask, sl, tp);
    } else if (mode == 2) {
        sl = NormalizeDouble(price * (1 + SL_Pct / 100.0), _Digits);
        tp = NormalizeDouble(price * (1 - TP_Pct / 100.0), _Digits);
        status = "SELL";
        OpenTrade(ORDER_TYPE_SELL, price, sl, tp);
    }

    UpdateOverlayPanel(rsi, ma, status, currentEquity, drawdownPct);
}

int DetectMarketMode(double ma, double rsi, double ob, double os) {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if (price > ma && rsi < os)
        return 1;
    if (price < ma && rsi > ob)
        return 2;
    return 0;
}

void OpenTrade(int type, double price, double sl, double tp) {
    MqlTradeRequest req;
    MqlTradeResult  res;
    ZeroMemory(req);
    ZeroMemory(res);

    req.action       = TRADE_ACTION_DEAL;
    req.symbol       = _Symbol;
    req.volume       = LotSize;
    req.type         = type;
    req.price        = NormalizeDouble(price, _Digits);
    req.sl           = NormalizeDouble(sl, _Digits);
    req.tp           = NormalizeDouble(tp, _Digits);
    req.magic        = MagicNumber;
    req.deviation    = 5;
    req.type_filling = ORDER_FILLING_IOC;

    string tradeTypeStr = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    PrintFormat("[StrikeBot] Attempting %s order. Price: %.5f SL: %.5f TP: %.5f", tradeTypeStr, price, sl, tp);

    if (!OrderSend(req, res)) {
        PrintFormat("[StrikeBot] OrderSend FAILED! Error Code: %d, Comment: %s", GetLastError(), res.comment);
    } else {
        if (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED) {
            PrintFormat("[StrikeBot] %s order successful! Deal: %d, Order: %d", tradeTypeStr, res.deal, res.order);
        } else {
            PrintFormat("[StrikeBot] OrderSend returned with code: %d, Comment: %s", res.retcode, res.comment);
        }
    }
}
