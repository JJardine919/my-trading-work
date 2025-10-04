
//+------------------------------------------------------------------+
//|                                                   StrikeBot.mq5  |
//|        Final: Adaptive RSI + Rolling SL + Dynamic TP + Relay    |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input double LotSize = 0.01;
input double SL_Percent = 1.0;
input double TP_BasePoints = 500;
input double Max_Drawdown = 0.0; // Balance drawdown zeroed
input double MaxDailyDrawdown = 0.75;
input int MaxLossesPerDay = 50;
input string RelayURL = "https://strikebot-relay--jimjardine919.repl.co/api/chatgpt";

CTrade trade;
CPositionInfo pos;
double initialBalance;
double dayStartBalance;
int dailyLosses = 0;
bool allowTrade = true;

// Adaptive RSI tracking
double lastTradeProfit1 = 0.0;
double lastTradeProfit2 = 0.0;

int OnInit()
{
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dayStartBalance = initialBalance;
    return INIT_SUCCEEDED;
}

void OnTick()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyDD = (dayStartBalance - equity) / dayStartBalance * 100.0;
    double balanceDD = (initialBalance - balance) / initialBalance * 100.0;

    if (balanceDD > Max_Drawdown) return;
    if (dailyLosses >= MaxLossesPerDay || dailyDD >= MaxDailyDrawdown) return;

    if (EntrySignalBuy() && allowTrade && !hasOpenBuy())
    {
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = NormalizeDouble(ask - ask * SL_Percent / 100.0, _Digits);
        double tp = NormalizeDouble(ask + TP_BasePoints * _Point, _Digits);
        if (!trade.Buy(LotSize, _Symbol, ask, sl, tp, "StrikeBot Buy"))
            dailyLosses++;
        else
            UpdateLastProfit();
    }

    if (EntrySignalSell() && allowTrade && !hasOpenSell())
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = NormalizeDouble(bid + bid * SL_Percent / 100.0, _Digits);
        double tp = NormalizeDouble(bid - TP_BasePoints * _Point, _Digits);
        if (!trade.Sell(LotSize, _Symbol, bid, sl, tp, "StrikeBot Sell"))
            dailyLosses++;
        else
            UpdateLastProfit();
    }

    ManageTrailingStop();
}

bool hasOpenBuy()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
        if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            return true;
    return false;
}

bool hasOpenSell()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
        if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            return true;
    return false;
}

bool EntrySignalBuy()
{
    int rsiHandle = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if (CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0) return false;

    double threshold = 30;
    if (lastTradeProfit1 < 0 && lastTradeProfit2 < 0) threshold = 35;
    else if (lastTradeProfit1 > 0 && lastTradeProfit2 > 0) threshold = 25;

    if (rsi[0] < threshold)
    {
        allowTrade = ChatGPTRelay("BUY", rsi[0]);
        return allowTrade;
    }
    return false;
}

bool EntrySignalSell()
{
    int rsiHandle = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if (CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0) return false;

    double threshold = 70;
    if (lastTradeProfit1 < 0 && lastTradeProfit2 < 0) threshold = 65;
    else if (lastTradeProfit1 > 0 && lastTradeProfit2 > 0) threshold = 75;

    if (rsi[0] > threshold)
    {
        allowTrade = ChatGPTRelay("SELL", rsi[0]);
        return allowTrade;
    }
    return false;
}

void ManageTrailingStop()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (!pos.SelectByIndex(i)) continue;

        string sym = pos.Symbol();
        if (sym != _Symbol) continue;

        int type = (int)pos.PositionType();
        double openPrice = pos.PriceOpen();
        double sl = pos.StopLoss();
        double price = SymbolInfoDouble(sym, (type == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);

        double trailDist = 250 * _Point;
        double newSL;

        if (type == POSITION_TYPE_BUY && price - openPrice > trailDist)
        {
            newSL = price - trailDist;
            if (newSL > sl)
                trade.PositionModify(sym, NormalizeDouble(newSL, _Digits), pos.TakeProfit());
        }
        else if (type == POSITION_TYPE_SELL && openPrice - price > trailDist)
        {
            newSL = price + trailDist;
            if (newSL < sl || sl == 0.0)
                trade.PositionModify(sym, NormalizeDouble(newSL, _Digits), pos.TakeProfit());
        }
    }
}

void UpdateLastProfit()
{
    ulong ticket = PositionGetTicket(0);
    if (HistoryDealsTotal() > 0 && HistorySelectByPosition(ticket))
    {
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        lastTradeProfit2 = lastTradeProfit1;
        lastTradeProfit1 = profit;
    }
}

bool ChatGPTRelay(string direction, double rsi)
{
    string json = StringFormat("{\"symbol\":\"%s\",\"time\":\"%s\",\"direction\":\"%s\",\"rsi\":%.2f}",
                               _Symbol, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), direction, rsi);

    char post[];
    StringToCharArray(json, post);

    char result[];
    string responseHeaders;
    int timeout = 5000;
    string headers = "Content-Type: application/json\r\n";

    int code = WebRequest("POST", RelayURL, headers, timeout, post, result, responseHeaders);

    if (code > 0)
    {
        string reply = CharArrayToString(result);
        Print("Relay response: ", reply);
        return StringFind(reply, "ALLOW") >= 0;
    }
    else
    {
        Print("Relay failed: ", GetLastError());
        return true;
    }
}
