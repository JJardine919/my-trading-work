//+------------------------------------------------------------------+
//|                                                  IC_009_EA_ONNX_Static_2_5pct_FIXED.mq5 |
//|  VAM + DL(MACD) EA | Corrected SL/TP + Model Path fallback       |
//+------------------------------------------------------------------+
#property strict
#property copyright "Javier Santiago Gaston de Iriarte Cabrera"
#property link      "https://www.mql5.com/en/users/jsgaston/news"
#property version   "1.01"

#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>
#include <Arrays\ArrayFloat.mqh>
#include <Expert\Expert.mqh>
//#include <stdlib.mqh>             // <- Commented out due to missing file
//#include <ONNX\onnxruntime.mqh>  // <- Commented out due to missing file

input double   LotSize             = 0.01;
input double   SL_Percent          = 4.0;     // StopLoss as % of price
input double   TP_BasePoints       = 200;     // Fixed TP points
input double   Max_Drawdown        = 1.0;     // Hard lock at 0% drawdown
input double   MaxDailyDrawdown    = 5.0;
input int      MaxLossesPerDay     = 10.0;
input string   RelayURL            = "https://yourserver.com/XpVLK17YfC05LityNozGf6UxaxZL4xUijFfDYdF_0q_ySzuiNxAq17lJ3_stVxY8g6TPYFvBidT3BlbkFJ43fcq5r1Snxkq5LfsfmylAyOYlsjL2c3hhGm2YArTwW4vzlNom5Ul_6EAxC7zVF-DiwiPEpoAA/chatgpt"; // Replace with your secure backend
input double   TP_Percent          = 2.5;
input string   ModelFileName       = "stock_prediction_model_MACD.onnx";
input bool     EnableTrading       = true;           // Enable automated trading

string model_path = "";

int OnInit()
{
    string localPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ModelFileName;
    if (FileIsExist(localPath))
    {
        model_path = localPath;
        Print("Loaded model from Files folder: ", model_path);
    }
    else if (FileIsExist(ModelFileName))
    {
        model_path = ModelFileName;
        Print("Loaded model from local root: ", model_path);
    }
    else
    {
        Print("ERROR: Model file not found: ", ModelFileName);
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}
