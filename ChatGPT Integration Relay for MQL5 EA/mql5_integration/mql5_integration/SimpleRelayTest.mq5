//+------------------------------------------------------------------+
//|                                             SimpleRelayTest.mq5 |
//|                                    MQL5-ChatGPT Relay Integration |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "MQL5-ChatGPT Relay Integration"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "RelayClient.mqh"

//--- Input parameters
input string RelayServerURL = "http://localhost:5000";  // Relay server URL
input string APIKey = "test-key";                       // API key for relay server

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("Starting ChatGPT Relay Test...");
    
    // Initialize relay client
    RelayClient* relayClient = new RelayClient(RelayServerURL, APIKey, 30000);
    
    // Test 1: Health check
    Print("=== Test 1: Health Check ===");
    bool isHealthy = relayClient.CheckHealth();
    Print("Server health status: ", isHealthy ? "Healthy" : "Not responding");
    
    if(!isHealthy)
    {
        Print("Warning: Server is not responding. Check if the relay server is running.");
        Print("Make sure the server URL is correct: ", RelayServerURL);
        delete relayClient;
        return;
    }
    
    // Test 2: Simple chat request
    Print("\n=== Test 2: Simple Chat Request ===");
    string chatResponse = relayClient.SendChatRequest(
        "What is the current market sentiment for EURUSD?",
        "EURUSD",
        1.0850
    );
    Print("Chat response: ", chatResponse);
    
    // Parse trading signal from chat response
    RelayClient::TradingSignal signal = relayClient.ParseTradingSignal(chatResponse);
    Print("Parsed signal - Direction: ", signal.direction, 
          ", Confidence: ", DoubleToString(signal.confidence, 2));
    
    // Test 3: Market analysis request
    Print("\n=== Test 3: Market Analysis Request ===");
    
    // Get current market data
    MqlTick tick;
    if(SymbolInfoTick(_Symbol, tick))
    {
        // Get OHLC data for current bar
        MqlRates rates[];
        if(CopyRates(_Symbol, _Period, 0, 1, rates) == 1)
        {
            string analysisResponse = relayClient.SendAnalysisRequest(
                _Symbol,
                "H1",
                rates[0].open,
                rates[0].high,
                rates[0].low,
                rates[0].close,
                rates[0].tick_volume
            );
            
            Print("Analysis response: ", analysisResponse);
            
            // Parse analysis result
            RelayClient::AnalysisResult analysis = relayClient.ParseAnalysisResult(analysisResponse);
            Print("Parsed analysis - Trend: ", analysis.overallTrend,
                  ", Strength: ", analysis.trendStrength,
                  ", Recommendation: ", analysis.recommendation,
                  ", Support: ", DoubleToString(analysis.supportLevel, _Digits),
                  ", Resistance: ", DoubleToString(analysis.resistanceLevel, _Digits));
        }
        else
        {
            Print("Error: Could not get rates data for analysis test");
        }
    }
    else
    {
        Print("Error: Could not get tick data for analysis test");
    }
    
    // Test 4: Strategy evaluation request
    Print("\n=== Test 4: Strategy Evaluation Request ===");
    string strategyResponse = relayClient.SendStrategyRequest(
        "RSI Divergence Strategy",
        "Buy when RSI shows bullish divergence with price action",
        0.65,  // 65% win rate
        1.45,  // Sharpe ratio
        0.08   // 8% max drawdown
    );
    Print("Strategy evaluation response: ", strategyResponse);
    
    // Test 5: Error handling test
    Print("\n=== Test 5: Error Handling Test ===");
    RelayClient* badClient = new RelayClient("http://invalid-url:9999", "invalid-key", 5000);
    string errorResponse = badClient.SendChatRequest("This should fail");
    Print("Error response: ", errorResponse);
    delete badClient;
    
    // Cleanup
    delete relayClient;
    
    Print("\n=== ChatGPT Relay Test Completed ===");
    Print("If all tests passed, the relay integration is working correctly.");
    Print("You can now use the ChatGPT_EA.mq5 Expert Advisor for automated trading with AI analysis.");
}

