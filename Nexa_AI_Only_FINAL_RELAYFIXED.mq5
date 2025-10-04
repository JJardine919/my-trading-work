
//+------------------------------------------------------------------+
//|                                           Nexa_AI_Only.mq5       |
//|                  Minimal AI-Only Trading Bot via Relay           |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string RelayURL = "http://127.0.0.1:5000";
input ulong MagicNumber = 92001;
input double StopLossPercent = 2.0;
input double TakeProfitPercent = 3.0;

datetime lastTradeTime = 0;
int Slippage = 10;

int OnInit() {
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFillingBySymbol(_Symbol);
    Print("🟢 Nexa AI (Minimal Relay v2.00) initialized.");
    return INIT_SUCCEEDED;
}

void OnTick() {
    int rsi_handle = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return;

    double rsi_buffer[1];
    if(CopyBuffer(rsi_handle, 0, 1, 1, rsi_buffer) <= 0) return;
    double rsi = rsi_buffer[0];

    string direction = GetAIDirection(rsi);
    if(direction == "None") return;

    double price = (direction == "Buy") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (direction == "Buy") ? price - price * StopLossPercent / 100.0 : price + price * StopLossPercent / 100.0;
    double tp = (direction == "Buy") ? price + price * TakeProfitPercent / 100.0 : price - price * TakeProfitPercent / 100.0;

    double lot = 0.01; // Fixed lot for now

    bool result = (direction == "Buy") ? trade.Buy(lot, _Symbol, price, sl, tp, "AI Buy") :
                                         trade.Sell(lot, _Symbol, price, sl, tp, "AI Sell");

    if(result)
        Print("✅ Trade executed: ", direction, " @ ", DoubleToString(price, _Digits));
    else
        Print("❌ Trade failed. Error: ", GetLastError());
}

string GetAIDirection(double rsi) {
    string json = StringFormat("{"symbol":"%s","RSI":%.2f}", _Symbol, rsi);
    char post[];
    StringToCharArray(json, post, 0, -1, CP_UTF8);

    string headers = "Content-Type: application/json\r\n";
    char result[];
    string result_headers;
    int timeout = 5000;

    Print("📤 Sending Payload: ", json);

    int res = WebRequest("POST", RelayURL + "/analyze", headers, timeout, post, result, result_headers);
    if(res != 200) {
        Print("❌ Relay error. Code: ", res, ", LastError: ", GetLastError());
        return "None";
    }

    string response = CharArrayToString(result);
    Print("📬 AI Signal Received: ", response);

    if(StringFind(response, "Buy") >= 0) return "Buy";
    if(StringFind(response, "Sell") >= 0) return "Sell";
    return "None";
}
