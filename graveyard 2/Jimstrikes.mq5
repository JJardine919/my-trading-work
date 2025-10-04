//+------------------------------------------------------------------+
//|                                                   StrikeBot EA  |
//|     Reinforced with Full Prompt for ChatGPT Relay Decisions     |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//--- Inputs
input double LotSize = 0.01;
input double SL_Percent = 4.0;
input double TP_BasePoints = 200;
input double Max_Drawdown = 1.0;
input double MaxDailyDrawdown = 5.0;
input int MaxLossesPerDay = 10;
input string RelayURL = "https://strikebot-relay--jimjardine919.repl.co/api/chatgpt";

//--- Variables
double initialBalance;
double dayStartBalance;
int dailyLosses = 0;
bool allowTrade = true;

int OnInit() {
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dayStartBalance = initialBalance;
    return INIT_SUCCEEDED;
}

void OnTick() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dailyDD = (dayStartBalance - equity) / dayStartBalance * 100;

    if (balance < initialBalance * (1.0 - Max_Drawdown / 100.0)) {
        Print("Max balance drawdown exceeded");
        return;
    }

    if (dailyLosses >= MaxLossesPerDay || dailyDD >= MaxDailyDrawdown) {
        Print("Daily drawdown or loss limit hit");
        return;
    }

    if (EntrySignalBuy() && allowTrade && !hasOpenBuy()) {
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = NormalizeDouble(ask - (ask * SL_Percent / 100.0), _Digits);
        double tp = NormalizeDouble(ask + TP_BasePoints * _Point, _Digits);
        if (trade.Buy(LotSize, _Symbol, ask, sl, tp, "StrikeBot Buy"))
            Print("Buy order placed");
        else
            dailyLosses++;
    }

    if (EntrySignalSell() && allowTrade && !hasOpenSell()) {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = NormalizeDouble(bid + (bid * SL_Percent / 100.0), _Digits);
        double tp = NormalizeDouble(bid - TP_BasePoints * _Point, _Digits);
        if (trade.Sell(LotSize, _Symbol, bid, sl, tp, "StrikeBot Sell"))
            Print("Sell order placed");
        else
            dailyLosses++;
    }
}

bool hasOpenBuy() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            return true;
    }
    return false;
}

bool hasOpenSell() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            return true;
    }
    return false;
}

bool EntrySignalBuy() {
    int rsiHandle = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    if (rsiHandle == INVALID_HANDLE) return false;
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if (CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0 && rsi[0] < 30) {
        allowTrade = ChatGPTRelay("BUY", rsi[0]);
        return allowTrade;
    }
    return false;
}

bool EntrySignalSell() {
    int rsiHandle = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    if (rsiHandle == INVALID_HANDLE) return false;
    double rsi[];
    ArraySetAsSeries(rsi, true);
    if (CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0 && rsi[0] > 70) {
        allowTrade = ChatGPTRelay("SELL", rsi[0]);
        return allowTrade;
    }
    return false;
}

bool ChatGPTRelay(string direction, double rsi) {
    string timeStr = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
    string json = "{\"symbol\":\"" + _Symbol + "\",\"time\":\"" + timeStr + "\",\"direction\":\"" + direction + "\",\"rsi\":" + DoubleToString(rsi, 2) + "}";

    char post[];
    StringToCharArray(json, post);

    char result[];
    string headers = "Content-Type: application/json\r\n";
    string responseHeaders;
    int timeout = 5000;

    int code = WebRequest("POST", RelayURL, headers, timeout, post, result, responseHeaders);
    if (code > 0) {
        string response = CharArrayToString(result);
        Print("Relay response: ", response);
        return StringFind(response, "ALLOW") >= 0;
    } else {
        Print("Relay failed with error: ", GetLastError());
        return true;
    }
}

