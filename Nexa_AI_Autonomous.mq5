
//+------------------------------------------------------------------+
//|                                  Nexa_AI_Autonomous.mq5         |
//|      Fully autonomous RSI-based AI trading bot with directive   |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string RelayURL = "http://127.0.0.1:5000";
input ulong MagicNumber = 92001;
input double StopLossPercent = 2.0;
input double TakeProfitPercent = 3.0;

bool firstRun = true;
int Slippage = 10;

int OnInit() {
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFillingBySymbol(_Symbol);
    Print("🟢 Nexa AI Autonomous initialized.");
    return INIT_SUCCEEDED;
}

void OnTick() {
    if(firstRun) {
        SendDirective();
        firstRun = false;
    }

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

    double lot = 0.01;

    bool result = (direction == "Buy") ? trade.Buy(lot, _Symbol, price, sl, tp, "AI Buy") :
                                         trade.Sell(lot, _Symbol, price, sl, tp, "AI Sell");

    if(result)
        Print("✅ Trade executed: ", direction, " @ ", DoubleToString(price, _Digits));
    else
        Print("❌ Trade failed. Error: ", GetLastError());
}

void SendDirective() {
    string json =
        "{"
        ""directive":"You are acting as a fully autonomous crypto trading assistant. Maintain the following rules until told otherwise:","
        ""symbol":"" + _Symbol + "","
        ""strategy":{"
        ""trade_logic":"Use RSI only. Buy above 70, Sell below 30. Hold otherwise.","
        ""risk_percent":1.0,"
        ""stop_loss_percent":2.0,"
        ""take_profit_percent":3.0,"
        ""enable_trailing_stop":true,"
        ""trailing_trigger_percent":1.5,"
        ""trailing_step_percent":0.25,"
        ""max_drawdown_percent":5.0,"
        ""max_open_trades":5,"
        ""cooldown_seconds":60"
        "},"
        ""fail_safe":"If risk is exceeded or RSI is inconclusive, do not trade.""
        "}";

    char post[];
    StringToCharArray(json, post, 0, -1, CP_UTF8);
    string headers = "Content-Type: application/json\r\n";
    char result[];
    string result_headers;
    int timeout = 5000;

    Print("📤 Sending AI directive payload...");
    int res = WebRequest("POST", RelayURL + "/analyze", headers, timeout, post, result, result_headers);
    if(res != 200)
        Print("❌ Directive failed. Code: ", res, ", LastError: ", GetLastError());
    else
        Print("✅ Directive accepted: ", CharArrayToString(result));
}

string GetAIDirection(double rsi) {
    string json = StringFormat("{"symbol":"%s","RSI":%.2f}", _Symbol, rsi);
    char post[];
    StringToCharArray(json, post, 0, -1, CP_UTF8);

    string headers = "Content-Type: application/json\r\n";
    char result[];
    string result_headers;
    int timeout = 5000;

    int res = WebRequest("POST", RelayURL + "/analyze", headers, timeout, post, result, result_headers);
    if(res != 200) {
        Print("❌ Relay error. Code: ", res, ", LastError: ", GetLastError());
        return "None";
    }

    string response = CharArrayToString(result);
    Print("📬 AI Signal: ", response);

    if(StringFind(response, "Buy") >= 0) return "Buy";
    if(StringFind(response, "Sell") >= 0) return "Sell";
    return "None";
}
