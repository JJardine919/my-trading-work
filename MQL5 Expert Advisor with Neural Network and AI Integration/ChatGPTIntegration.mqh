//+------------------------------------------------------------------+
//|                                           ChatGPTIntegration.mqh |
//|                                                        Manus AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      ""
#property version   "1.00"

//--- ChatGPT API configuration
#define OPENAI_API_URL "https://api.openai.com/v1/chat/completions"
#define MAX_RESPONSE_SIZE 8192
#define MAX_PROMPT_SIZE 4096
#define API_TIMEOUT 30000  // 30 seconds
#define MAX_RETRIES 3

//+------------------------------------------------------------------+
//| ChatGPT Integration Class for Market Analysis                   |
//+------------------------------------------------------------------+
class ChatGPTIntegration
{
private:
   // API configuration
   string            apiKey;
   string            apiUrl;
   string            model;
   double            temperature;
   int               maxTokens;
   
   // Request management
   int               requestCount;
   datetime          lastRequestTime;
   int               rateLimitDelay;
   
   // Response caching
   string            lastPrompt;
   string            lastResponse;
   datetime          cacheTime;
   int               cacheValidityMinutes;
   
   // Market context
   string            currentSymbol;
   ENUM_TIMEFRAMES   currentTimeframe;
   double            currentPrice;
   double            priceChange24h;
   double            volatility;
   
   // Analysis results
   double            sentimentScore;      // -1.0 to 1.0 (bearish to bullish)
   double            confidenceLevel;     // 0.0 to 1.0
   int               recommendedAction;   // 0=HOLD, 1=BUY, 2=SELL
   string            analysisReason;
   
   // Error handling
   string            lastError;
   bool              hasError;
   int               consecutiveErrors;
   
public:
   // Constructor and destructor
                     ChatGPTIntegration(void);
                    ~ChatGPTIntegration(void);
   
   // Initialization
   bool              Initialize(string apiKey, string model = "gpt-4");
   bool              SetApiKey(string key);
   void              SetModel(string modelName);
   void              SetTemperature(double temp);
   void              SetMaxTokens(int tokens);
   
   // Market context management
   void              UpdateMarketContext(string symbol, ENUM_TIMEFRAMES timeframe);
   void              SetCurrentPrice(double price);
   void              SetPriceChange(double change);
   void              SetVolatility(double vol);
   
   // Analysis methods
   bool              AnalyzeMarketConditions(void);
   bool              GetTradingRecommendation(double &marketFeatures[]);
   bool              AnalyzeNewsImpact(string newsText);
   bool              AssessRiskLevel(void);
   
   // Prompt engineering
   string            BuildMarketAnalysisPrompt(double &features[]);
   string            BuildTradingPrompt(void);
   string            BuildRiskAssessmentPrompt(void);
   string            BuildNewsAnalysisPrompt(string newsText);
   
   // API communication
   bool              SendRequest(string prompt, string &response);
   bool              MakeHttpRequest(string jsonPayload, string &response);
   string            BuildJsonPayload(string prompt);
   
   // Response processing
   bool              ParseResponse(string jsonResponse, string &content);
   bool              ExtractTradingSignals(string analysisText);
   double            ExtractSentimentScore(string text);
   double            ExtractConfidenceLevel(string text);
   string            ExtractReasoning(string text);
   
   // Results access
   double            GetSentimentScore(void) { return sentimentScore; }
   double            GetConfidenceLevel(void) { return confidenceLevel; }
   int               GetRecommendedAction(void) { return recommendedAction; }
   string            GetAnalysisReason(void) { return analysisReason; }
   string            GetLastResponse(void) { return lastResponse; }
   
   // Caching and optimization
   bool              IsCacheValid(string prompt);
   void              CacheResponse(string prompt, string response);
   void              ClearCache(void);
   
   // Rate limiting
   bool              CanMakeRequest(void);
   void              UpdateRateLimit(void);
   void              WaitForRateLimit(void);
   
   // Performance monitoring
   int               GetRequestCount(void) { return requestCount; }
   double            GetSuccessRate(void);
   void              ResetStatistics(void);
   
   // Error handling
   string            GetLastError(void) { return lastError; }
   bool              HasError(void) { return hasError; }
   void              ClearError(void);
   
   // Utility methods
   void              PrintAnalysisResults(void);
   bool              ValidateApiKey(void);
   string            GetModelInfo(void);
   
private:
   // Internal helper methods
   bool              IsValidJson(string jsonString);
   string            EscapeJsonString(string input);
   string            CleanJsonResponse(string response);
   void              LogRequest(string prompt, string response);
   void              HandleApiError(int errorCode, string errorMessage);
   
   // Text processing helpers
   string            ExtractJsonValue(string json, string key);
   bool              ContainsKeywords(string text, string keywords[]);
   double            CalculateTextSentiment(string text);
   
   // Market data helpers
   string            FormatMarketData(void);
   string            GetTimeframeString(ENUM_TIMEFRAMES tf);
   string            GetMarketTrend(void);
};

//+------------------------------------------------------------------+
//| ChatGPT Response Structure                                      |
//+------------------------------------------------------------------+
struct ChatGPTResponse
{
   bool              success;
   string            content;
   double            sentimentScore;
   double            confidence;
   int               recommendedAction;
   string            reasoning;
   string            errorMessage;
};

//+------------------------------------------------------------------+
//| Market Analysis Request Structure                               |
//+------------------------------------------------------------------+
struct MarketAnalysisRequest
{
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   double            currentPrice;
   double            priceChange;
   double            volume;
   double            volatility;
   double            rsi;
   double            macd;
   double            bollinger;
   string            trend;
   string            newsContext;
};

//+------------------------------------------------------------------+
//| Trading Signal Enumeration                                     |
//+------------------------------------------------------------------+
enum ENUM_CHATGPT_SIGNAL
{
   CHATGPT_HOLD = 0,
   CHATGPT_BUY = 1,
   CHATGPT_SELL = 2
};

//+------------------------------------------------------------------+
//| Sentiment Analysis Enumeration                                 |
//+------------------------------------------------------------------+
enum ENUM_SENTIMENT
{
   SENTIMENT_VERY_BEARISH = -2,
   SENTIMENT_BEARISH = -1,
   SENTIMENT_NEUTRAL = 0,
   SENTIMENT_BULLISH = 1,
   SENTIMENT_VERY_BULLISH = 2
};

//+------------------------------------------------------------------+
//| Configuration Constants                                         |
//+------------------------------------------------------------------+
#define CHATGPT_DEFAULT_MODEL "gpt-4"
#define CHATGPT_DEFAULT_TEMPERATURE 0.3
#define CHATGPT_DEFAULT_MAX_TOKENS 500
#define CHATGPT_CACHE_VALIDITY_MINUTES 5
#define CHATGPT_RATE_LIMIT_DELAY 1000  // 1 second between requests
#define CHATGPT_MIN_CONFIDENCE 0.6
#define CHATGPT_MAX_CONSECUTIVE_ERRORS 5

