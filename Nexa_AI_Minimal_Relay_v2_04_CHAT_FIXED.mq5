
//+------------------------------------------------------------------+
//|                      Nexa_AI_Minimal_Relay.mq5                     |
//|         Minimalist AI-Only Bot for Relay Signal Execution        |
//|                      (Revised by Gemini on 2025-07-14)             |
//+------------------------------------------------------------------+
#property strict
#property version   "2.04" // Updated for /chat fix
#property description "A minimal, AI-only trading bot that executes trades based on a relay signal."

#include <Trade\Trade.mqh>
CTrade trade;

//--- Input Parameters
input group "API & Trade Control"
input string RelayURL      = "http://127.0.0.1:5000/chat"; // Fixed endpoint
input bool   Autotrade     = true;                          // Master switch to enable/disable trading
input ulong  MagicNumber   = 92001;                         // Unique identifier for this EA's trades

//--- Hardcoded Settings
double   FixedLotSize  = 0.01;
int      Slippage      = 10;
int      TradeCooldown = 15; // Cooldown in seconds

//--- Global Variables
datetime lastApiCallTime = 0;
int      RSI_Handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetAsyncMode(true);

    RSI_Handle = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
    if(RSI_Handle == INVALID_HANDLE)
    {
        Print("❌ Failed to create RSI handle. Error: " + IntegerToString(GetLastError()));
        return(INIT_FAILED);
    }

    if(!MQLInfoInteger(MQL_TESTER))
    {
        char result[];
        string headers;
        char post_data[];
        WebRequest("GET", RelayURL, "", 5000, post_data, result, headers);
    }

    Print("🟢 Nexa AI (Minimal Relay v2.04) initialized.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(RSI_Handle != INVALID_HANDLE)
        IndicatorRelease(RSI_Handle);
    Print("🔴 Nexa AI deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
void OnTick()
{
    if(!Autotrade || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
    if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == MagicNumber) return;
    if(TimeCurrent() - lastApiCallTime < TradeCooldown) return;

    lastApiCallTime = TimeCurrent();

    string signal = GetAIDirection();
    Print("📬 AI Signal Received: " + signal);

    if(signal == "Buy")
        ExecuteTrade(ORDER_TYPE_BUY);
    else if(signal == "Sell")
        ExecuteTrade(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
string GetAIDirection()
{
    double rsi_buffer[1];
    if(CopyBuffer(RSI_Handle, 0, 0, 1, rsi_buffer) <= 0)
    {
        Print("❌ Failed to copy RSI buffer. Error: " + IntegerToString(GetLastError()));
        return "None";
    }
    double rsi = rsi_buffer[0];

    string json_payload = "{"symbol":"" + _Symbol + "","RSI":" + DoubleToString(rsi, 2) + "}";
    Print("📤 Sending Payload: " + json_payload);

    uchar post_data[];
    StringToCharArray(json_payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);

    string headers = "Content-Type: application/json\r\n";
    uchar result_data[];
    string response_headers;
    int timeout = 5000;

    ResetLastError();
    int code = WebRequest("POST", RelayURL, headers, timeout, post_data, result_data, response_headers);
    
    if(code != 200)
    {
        Print("❌ Relay error. Code: " + IntegerToString(code) + ", LastError: " + IntegerToString(GetLastError()));
        return "None";
    }

    string response = CharArrayToString(result_data);
    Print("📨 Relay Response: " + response);

    if(StringFind(response, "Buy", 0) >= 0) return "Buy";
    if(StringFind(response, "Sell", 0) >= 0) return "Sell";
    return "None";
}

//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type)
{
    double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(price <= 0) return;

    double sl = 0.0;
    double tp = 0.0;
    
    bool result = (type == ORDER_TYPE_BUY) ? trade.Buy(FixedLotSize, _Symbol, price, sl, tp, "AI Buy") :
                                             trade.Sell(FixedLotSize, _Symbol, price, sl, tp, "AI Sell");

    if(result)
        Print("✅ Executed " + EnumToString(type) + " at " + DoubleToString(price, _Digits));
    else
        Print("🟥 Trade failed. Error: " + IntegerToString(GetLastError()));
}
//+------------------------------------------------------------------+
