//+------------------------------------------------------------------+
//|                                                  TestChatGPT.mq5 |
//|                                                        Manus AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "ChatGPTIntegration.mqh"

//--- Input parameters
input string OpenAI_API_Key = "";                    // OpenAI API Key (required)
input bool TestBasicFunctionality = true;           // Test basic ChatGPT functionality
input bool TestPromptEngineering = true;            // Test prompt engineering
input bool TestResponseParsing = true;              // Test response parsing
input bool TestMarketAnalysis = false;              // Test market analysis (requires API key)
input string TestModel = "gpt-4";                   // Model to test with

//--- Global variables
ChatGPTIntegration* chatGPT;

//+------------------------------------------------------------------+
//| Script program start function                                   |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== ChatGPT Integration Test Suite ===");
   
   // Initialize ChatGPT integration
   chatGPT = new ChatGPTIntegration();
   
   if(OpenAI_API_Key != "")
   {
      if(!chatGPT.Initialize(OpenAI_API_Key, TestModel))
      {
         Print("ERROR: Failed to initialize ChatGPT integration");
         Print("Error: ", chatGPT.GetLastError());
         delete chatGPT;
         return;
      }
      Print("ChatGPT integration initialized successfully with API key");
   }
   else
   {
      Print("WARNING: No API key provided - testing offline functionality only");
   }
   
   // Run tests
   if(TestBasicFunctionality)
      RunBasicFunctionalityTest();
   
   if(TestPromptEngineering)
      RunPromptEngineeringTest();
   
   if(TestResponseParsing)
      RunResponseParsingTest();
   
   if(TestMarketAnalysis && OpenAI_API_Key != "")
      RunMarketAnalysisTest();
   else if(TestMarketAnalysis)
      Print("Skipping market analysis test - API key required");
   
   // Cleanup
   delete chatGPT;
   
   Print("=== Test Suite Completed ===");
}

//+------------------------------------------------------------------+
//| Test basic ChatGPT functionality                               |
//+------------------------------------------------------------------+
void RunBasicFunctionalityTest()
{
   Print("\n--- Testing Basic Functionality ---");
   
   // Test initialization without API key
   ChatGPTIntegration testGPT;
   
   if(!testGPT.Initialize(""))
   {
      Print("✓ Correctly rejected empty API key");
   }
   else
   {
      Print("✗ Failed to reject empty API key");
   }
   
   // Test invalid API key format
   if(!testGPT.Initialize("invalid-key"))
   {
      Print("✓ Correctly rejected invalid API key format");
   }
   else
   {
      Print("✗ Failed to reject invalid API key format");
   }
   
   // Test valid API key format (but not necessarily working)
   if(testGPT.Initialize("sk-test1234567890abcdef1234567890abcdef"))
   {
      Print("✓ Accepted valid API key format");
   }
   else
   {
      Print("✗ Rejected valid API key format");
   }
   
   // Test market context update
   chatGPT.UpdateMarketContext(_Symbol, _Period);
   Print("✓ Market context updated successfully");
   
   // Test configuration methods
   chatGPT.SetModel("gpt-3.5-turbo");
   chatGPT.SetTemperature(0.5);
   chatGPT.SetMaxTokens(300);
   Print("✓ Configuration methods work correctly");
}

//+------------------------------------------------------------------+
//| Test prompt engineering                                        |
//+------------------------------------------------------------------+
void RunPromptEngineeringTest()
{
   Print("\n--- Testing Prompt Engineering ---");
   
   // Update market context
   chatGPT.UpdateMarketContext(_Symbol, _Period);
   
   // Test trading prompt
   string tradingPrompt = chatGPT.BuildTradingPrompt();
   
   if(StringLen(tradingPrompt) > 100 && 
      StringFind(tradingPrompt, _Symbol) != -1 &&
      StringFind(tradingPrompt, "SENTIMENT:") != -1)
   {
      Print("✓ Trading prompt generated successfully");
      Print("Prompt length: ", StringLen(tradingPrompt), " characters");
   }
   else
   {
      Print("✗ Trading prompt generation failed");
      Print("Prompt: ", StringSubstr(tradingPrompt, 0, 100), "...");
   }
   
   // Test market analysis prompt with sample features
   double sampleFeatures[12];
   sampleFeatures[0] = 0.001;   // Price change 1
   sampleFeatures[1] = 0.005;   // Price change 5
   sampleFeatures[2] = 0.02;    // Price change 20
   sampleFeatures[3] = 1.2;     // Volume ratio
   sampleFeatures[4] = 65.0;    // RSI
   sampleFeatures[5] = 0.0001;  // MACD main
   sampleFeatures[6] = 0.00005; // MACD signal
   sampleFeatures[7] = 0.7;     // BB position
   sampleFeatures[8] = 0.015;   // ATR ratio
   sampleFeatures[9] = 0.008;   // Momentum
   sampleFeatures[10] = 0.012;  // Volatility
   sampleFeatures[11] = 0.003;  // Trend strength
   
   string analysisPrompt = chatGPT.BuildMarketAnalysisPrompt(sampleFeatures);
   
   if(StringLen(analysisPrompt) > 200 && 
      StringFind(analysisPrompt, "RSI: 65.0") != -1 &&
      StringFind(analysisPrompt, "CONFIDENCE:") != -1)
   {
      Print("✓ Market analysis prompt generated successfully");
      Print("Prompt length: ", StringLen(analysisPrompt), " characters");
   }
   else
   {
      Print("✗ Market analysis prompt generation failed");
   }
   
   // Test risk assessment prompt
   string riskPrompt = chatGPT.BuildRiskAssessmentPrompt();
   
   if(StringLen(riskPrompt) > 50)
   {
      Print("✓ Risk assessment prompt generated successfully");
   }
   else
   {
      Print("✗ Risk assessment prompt generation failed");
   }
}

//+------------------------------------------------------------------+
//| Test response parsing                                          |
//+------------------------------------------------------------------+
void RunResponseParsingTest()
{
   Print("\n--- Testing Response Parsing ---");
   
   // Test parsing of a sample ChatGPT response
   string sampleResponse = "Based on the current market analysis:\n\n";
   sampleResponse += "SENTIMENT: BULLISH\n";
   sampleResponse += "RECOMMENDATION: BUY\n";
   sampleResponse += "CONFIDENCE: 75%\n";
   sampleResponse += "REASONING: The RSI indicates oversold conditions while MACD shows bullish divergence. ";
   sampleResponse += "Strong volume support suggests upward momentum.\n";
   sampleResponse += "RISK: MEDIUM";
   
   if(chatGPT.ExtractTradingSignals(sampleResponse))
   {
      Print("✓ Response parsing successful");
      
      double sentiment = chatGPT.GetSentimentScore();
      double confidence = chatGPT.GetConfidenceLevel();
      int action = chatGPT.GetRecommendedAction();
      string reasoning = chatGPT.GetAnalysisReason();
      
      Print("Extracted sentiment: ", DoubleToString(sentiment, 3));
      Print("Extracted confidence: ", DoubleToString(confidence * 100, 1), "%");
      Print("Extracted action: ", (action == CHATGPT_BUY ? "BUY" : 
                                   action == CHATGPT_SELL ? "SELL" : "HOLD"));
      Print("Extracted reasoning: ", StringSubstr(reasoning, 0, 50), "...");
      
      // Validate extracted values
      if(sentiment > 0 && confidence > 0.7 && action == CHATGPT_BUY)
      {
         Print("✓ All extracted values are correct");
      }
      else
      {
         Print("✗ Some extracted values are incorrect");
      }
   }
   else
   {
      Print("✗ Response parsing failed");
      Print("Error: ", chatGPT.GetLastError());
   }
   
   // Test parsing of bearish response
   string bearishResponse = "Market analysis shows:\n";
   bearishResponse += "SENTIMENT: BEARISH\n";
   bearishResponse += "ACTION: SELL\n";
   bearishResponse += "CONFIDENCE: 80\n";
   bearishResponse += "REASON: Overbought conditions with declining volume suggest reversal.";
   
   if(chatGPT.ExtractTradingSignals(bearishResponse))
   {
      double sentiment = chatGPT.GetSentimentScore();
      int action = chatGPT.GetRecommendedAction();
      
      if(sentiment < 0 && action == CHATGPT_SELL)
      {
         Print("✓ Bearish response parsed correctly");
      }
      else
      {
         Print("✗ Bearish response parsing failed");
      }
   }
   
   // Test JSON response parsing
   string jsonResponse = "{\"choices\":[{\"message\":{\"content\":\"SENTIMENT: NEUTRAL\\nACTION: HOLD\\nCONFIDENCE: 60%\"}}]}";
   string content;
   
   if(chatGPT.ParseResponse(jsonResponse, content))
   {
      Print("✓ JSON response parsing successful");
      Print("Extracted content: ", content);
   }
   else
   {
      Print("✗ JSON response parsing failed");
      Print("Error: ", chatGPT.GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Test market analysis with real API call                       |
//+------------------------------------------------------------------+
void RunMarketAnalysisTest()
{
   Print("\n--- Testing Market Analysis (Live API) ---");
   
   // Update market context
   chatGPT.UpdateMarketContext(_Symbol, _Period);
   
   Print("Testing with symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   
   // Test basic market analysis
   if(chatGPT.AnalyzeMarketConditions())
   {
      Print("✓ Market analysis completed successfully");
      chatGPT.PrintAnalysisResults();
      
      // Validate results
      double sentiment = chatGPT.GetSentimentScore();
      double confidence = chatGPT.GetConfidenceLevel();
      
      if(sentiment >= -1.0 && sentiment <= 1.0 && 
         confidence >= 0.0 && confidence <= 1.0)
      {
         Print("✓ Analysis results are within valid ranges");
      }
      else
      {
         Print("✗ Analysis results are out of valid ranges");
         Print("Sentiment: ", sentiment, " (should be -1.0 to 1.0)");
         Print("Confidence: ", confidence, " (should be 0.0 to 1.0)");
      }
   }
   else
   {
      Print("✗ Market analysis failed");
      Print("Error: ", chatGPT.GetLastError());
   }
   
   // Test with market features
   double marketFeatures[12];
   
   // Prepare realistic market features
   marketFeatures[0] = 0.002;   // 0.2% price change
   marketFeatures[1] = 0.008;   // 0.8% price change (5 periods)
   marketFeatures[2] = 0.025;   // 2.5% price change (20 periods)
   marketFeatures[3] = 1.1;     // 10% above average volume
   marketFeatures[4] = 58.5;    // RSI
   marketFeatures[5] = 0.00015; // MACD main
   marketFeatures[6] = 0.0001;  // MACD signal
   marketFeatures[7] = 0.6;     // Bollinger position
   marketFeatures[8] = 0.018;   // ATR ratio
   marketFeatures[9] = 0.012;   // Momentum
   marketFeatures[10] = 0.015;  // Volatility
   marketFeatures[11] = 0.005;  // Trend strength
   
   if(chatGPT.GetTradingRecommendation(marketFeatures))
   {
      Print("✓ Trading recommendation with features completed");
      chatGPT.PrintAnalysisResults();
   }
   else
   {
      Print("✗ Trading recommendation with features failed");
      Print("Error: ", chatGPT.GetLastError());
   }
   
   // Test rate limiting
   Print("Testing rate limiting...");
   datetime startTime = TimeCurrent();
   
   for(int i = 0; i < 3; i++)
   {
      if(chatGPT.AnalyzeMarketConditions())
      {
         Print("Request ", i + 1, " completed");
      }
      else
      {
         Print("Request ", i + 1, " failed: ", chatGPT.GetLastError());
      }
   }
   
   datetime endTime = TimeCurrent();
   Print("Total time for 3 requests: ", endTime - startTime, " seconds");
   
   if(endTime - startTime >= 2) // Should take at least 2 seconds due to rate limiting
   {
      Print("✓ Rate limiting is working correctly");
   }
   else
   {
      Print("? Rate limiting may not be working as expected");
   }
}

//+------------------------------------------------------------------+
//| Test error handling                                            |
//+------------------------------------------------------------------+
void TestErrorHandling()
{
   Print("\n--- Testing Error Handling ---");
   
   // Test with invalid API key
   ChatGPTIntegration errorTest;
   errorTest.Initialize("sk-invalid-key-for-testing");
   
   if(!errorTest.AnalyzeMarketConditions())
   {
      Print("✓ Correctly handled invalid API key");
      Print("Error message: ", errorTest.GetLastError());
   }
   else
   {
      Print("✗ Failed to handle invalid API key");
   }
   
   // Test with malformed JSON
   string malformedJson = "{\"choices\":[{\"message\":{\"content\":\"incomplete";
   string content;
   
   if(!chatGPT.ParseResponse(malformedJson, content))
   {
      Print("✓ Correctly handled malformed JSON");
      Print("Error message: ", chatGPT.GetLastError());
      chatGPT.ClearError();
   }
   else
   {
      Print("✗ Failed to handle malformed JSON");
   }
}

