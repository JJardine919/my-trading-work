//+------------------------------------------------------------------+
//|                                                  RelayClient.mqh |
//|                                    MQL5-ChatGPT Relay Integration |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "MQL5-ChatGPT Relay Integration"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| RelayClient class for communicating with ChatGPT relay server   |
//+------------------------------------------------------------------+
class RelayClient
{
private:
    string m_serverUrl;
    string m_apiKey;
    int    m_timeout;
    
    // Helper function to convert string to char array
    bool StringToCharArray(string str, char &arr[])
    {
        int len = StringLen(str);
        ArrayResize(arr, len + 1);
        for(int i = 0; i < len; i++)
        {
            arr[i] = (char)StringGetCharacter(str, i);
        }
        arr[len] = 0; // Null terminator
        return true;
    }
    
    // Helper function to convert char array to string
    string CharArrayToString(char &arr[])
    {
        return CharArrayToString(arr, 0, ArraySize(arr));
    }
    
    // Parse JSON response (basic implementation)
    string ExtractJsonValue(string json, string key)
    {
        string searchKey = "\"" + key + "\":";
        int pos = StringFind(json, searchKey);
        if(pos == -1) return "";
        
        pos += StringLen(searchKey);
        
        // Skip whitespace
        while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t'))
            pos++;
        
        // Check if value is a string (starts with quote)
        if(StringGetCharacter(json, pos) == '"')
        {
            pos++; // Skip opening quote
            int endPos = StringFind(json, "\"", pos);
            if(endPos == -1) return "";
            return StringSubstr(json, pos, endPos - pos);
        }
        else
        {
            // Find end of value (comma, brace, or bracket)
            int endPos = pos;
            while(endPos < StringLen(json))
            {
                ushort ch = StringGetCharacter(json, endPos);
                if(ch == ',' || ch == '}' || ch == ']' || ch == '\n' || ch == '\r')
                    break;
                endPos++;
            }
            return StringSubstr(json, pos, endPos - pos);
        }
    }

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    RelayClient(string serverUrl = "http://localhost:5000", string apiKey = "test-key", int timeout = 30000)
    {
        m_serverUrl = serverUrl;
        m_apiKey = apiKey;
        m_timeout = timeout;
    }
    
    //+------------------------------------------------------------------+
    //| Set server configuration                                         |
    //+------------------------------------------------------------------+
    void SetServer(string url, string apiKey, int timeout = 30000)
    {
        m_serverUrl = url;
        m_apiKey = apiKey;
        m_timeout = timeout;
    }
    
    //+------------------------------------------------------------------+
    //| Send chat completion request                                     |
    //+------------------------------------------------------------------+
    string SendChatRequest(string message, string symbol = "", double currentPrice = 0.0)
    {
        string url = m_serverUrl + "/api/v1/chat";
        
        // Build JSON payload
        string payload = "{\"message\":\"" + message + "\"";
        
        if(symbol != "" || currentPrice > 0)
        {
            payload += ",\"context\":{";
            if(symbol != "")
                payload += "\"symbol\":\"" + symbol + "\"";
            if(currentPrice > 0)
            {
                if(symbol != "") payload += ",";
                payload += "\"current_price\":" + DoubleToString(currentPrice, 5);
            }
            payload += "}";
        }
        
        payload += "}";
        
        // Prepare headers
        string headers = "Content-Type: application/json\r\n";
        headers += "Authorization: Bearer " + m_apiKey + "\r\n";
        
        // Convert payload to char array
        char postData[];
        StringToCharArray(payload, postData);
        
        // Prepare result arrays
        char result[];
        string resultHeaders;
        
        // Make HTTP request
        ResetLastError();
        int httpResult = WebRequest("POST", url, headers, m_timeout, postData, result, resultHeaders);
        
        if(httpResult == -1)
        {
            int error = GetLastError();
            Print("WebRequest error: ", error);
            return "{\"status\":\"error\",\"error\":{\"code\":\"NETWORK_ERROR\",\"message\":\"WebRequest failed with error " + IntegerToString(error) + "\"}}";
        }
        
        if(httpResult != 200)
        {
            Print("HTTP error: ", httpResult);
            return "{\"status\":\"error\",\"error\":{\"code\":\"HTTP_ERROR\",\"message\":\"HTTP status " + IntegerToString(httpResult) + "\"}}";
        }
        
        return CharArrayToString(result);
    }
    
    //+------------------------------------------------------------------+
    //| Send market analysis request                                     |
    //+------------------------------------------------------------------+
    string SendAnalysisRequest(string symbol, string timeframe, double open, double high, double low, double close, long volume = 0)
    {
        string url = m_serverUrl + "/api/v1/analyze";
        
        // Build JSON payload
        string payload = "{";
        payload += "\"symbol\":\"" + symbol + "\",";
        payload += "\"timeframe\":\"" + timeframe + "\",";
        payload += "\"analysis_type\":\"technical\",";
        payload += "\"data\":{";
        payload += "\"price_data\":{";
        payload += "\"open\":" + DoubleToString(open, 5) + ",";
        payload += "\"high\":" + DoubleToString(high, 5) + ",";
        payload += "\"low\":" + DoubleToString(low, 5) + ",";
        payload += "\"close\":" + DoubleToString(close, 5);
        if(volume > 0)
            payload += ",\"volume\":" + IntegerToString(volume);
        payload += "}";
        payload += "}";
        payload += "}";
        
        // Prepare headers
        string headers = "Content-Type: application/json\r\n";
        headers += "Authorization: Bearer " + m_apiKey + "\r\n";
        
        // Convert payload to char array
        char postData[];
        StringToCharArray(payload, postData);
        
        // Prepare result arrays
        char result[];
        string resultHeaders;
        
        // Make HTTP request
        ResetLastError();
        int httpResult = WebRequest("POST", url, headers, m_timeout, postData, result, resultHeaders);
        
        if(httpResult == -1)
        {
            int error = GetLastError();
            Print("WebRequest error: ", error);
            return "{\"status\":\"error\",\"error\":{\"code\":\"NETWORK_ERROR\",\"message\":\"WebRequest failed with error " + IntegerToString(error) + "\"}}";
        }
        
        if(httpResult != 200)
        {
            Print("HTTP error: ", httpResult);
            return "{\"status\":\"error\",\"error\":{\"code\":\"HTTP_ERROR\",\"message\":\"HTTP status " + IntegerToString(httpResult) + "\"}}";
        }
        
        return CharArrayToString(result);
    }
    
    //+------------------------------------------------------------------+
    //| Send strategy evaluation request                                 |
    //+------------------------------------------------------------------+
    string SendStrategyRequest(string strategyName, string description, double winRate, double sharpeRatio, double maxDrawdown)
    {
        string url = m_serverUrl + "/api/v1/strategy";
        
        // Build JSON payload
        string payload = "{";
        payload += "\"strategy_name\":\"" + strategyName + "\",";
        payload += "\"strategy_description\":\"" + description + "\",";
        payload += "\"backtest_data\":{";
        payload += "\"win_rate\":" + DoubleToString(winRate, 3) + ",";
        payload += "\"sharpe_ratio\":" + DoubleToString(sharpeRatio, 2) + ",";
        payload += "\"max_drawdown\":" + DoubleToString(maxDrawdown, 3);
        payload += "}";
        payload += "}";
        
        // Prepare headers
        string headers = "Content-Type: application/json\r\n";
        headers += "Authorization: Bearer " + m_apiKey + "\r\n";
        
        // Convert payload to char array
        char postData[];
        StringToCharArray(payload, postData);
        
        // Prepare result arrays
        char result[];
        string resultHeaders;
        
        // Make HTTP request
        ResetLastError();
        int httpResult = WebRequest("POST", url, headers, m_timeout, postData, result, resultHeaders);
        
        if(httpResult == -1)
        {
            int error = GetLastError();
            Print("WebRequest error: ", error);
            return "{\"status\":\"error\",\"error\":{\"code\":\"NETWORK_ERROR\",\"message\":\"WebRequest failed with error " + IntegerToString(error) + "\"}}";
        }
        
        if(httpResult != 200)
        {
            Print("HTTP error: ", httpResult);
            return "{\"status\":\"error\",\"error\":{\"code\":\"HTTP_ERROR\",\"message\":\"HTTP status " + IntegerToString(httpResult) + "\"}}";
        }
        
        return CharArrayToString(result);
    }
    
    //+------------------------------------------------------------------+
    //| Check server health                                              |
    //+------------------------------------------------------------------+
    bool CheckHealth()
    {
        string url = m_serverUrl + "/api/v1/health";
        
        char postData[];
        char result[];
        string resultHeaders;
        
        ResetLastError();
        int httpResult = WebRequest("GET", url, "", m_timeout, postData, result, resultHeaders);
        
        if(httpResult == -1)
        {
            Print("Health check failed - WebRequest error: ", GetLastError());
            return false;
        }
        
        if(httpResult != 200)
        {
            Print("Health check failed - HTTP status: ", httpResult);
            return false;
        }
        
        string response = CharArrayToString(result);
        string status = ExtractJsonValue(response, "status");
        
        return (status == "healthy");
    }
    
    //+------------------------------------------------------------------+
    //| Parse trading signal from chat response                         |
    //+------------------------------------------------------------------+
    struct TradingSignal
    {
        string direction;    // "buy", "sell", "hold"
        string strength;     // "weak", "moderate", "strong"
        double entryPrice;
        double stopLoss;
        double takeProfit;
        double confidence;
    };
    
    TradingSignal ParseTradingSignal(string jsonResponse)
    {
        TradingSignal signal;
        signal.direction = "hold";
        signal.strength = "weak";
        signal.entryPrice = 0.0;
        signal.stopLoss = 0.0;
        signal.takeProfit = 0.0;
        signal.confidence = 0.0;
        
        // Check if response contains trading_signal
        if(StringFind(jsonResponse, "trading_signal") != -1)
        {
            signal.direction = ExtractJsonValue(jsonResponse, "direction");
            signal.strength = ExtractJsonValue(jsonResponse, "strength");
            
            string entryStr = ExtractJsonValue(jsonResponse, "entry_price");
            if(entryStr != "") signal.entryPrice = StringToDouble(entryStr);
            
            string slStr = ExtractJsonValue(jsonResponse, "stop_loss");
            if(slStr != "") signal.stopLoss = StringToDouble(slStr);
            
            string tpStr = ExtractJsonValue(jsonResponse, "take_profit");
            if(tpStr != "") signal.takeProfit = StringToDouble(tpStr);
        }
        
        string confStr = ExtractJsonValue(jsonResponse, "confidence");
        if(confStr != "") signal.confidence = StringToDouble(confStr);
        
        return signal;
    }
    
    //+------------------------------------------------------------------+
    //| Parse analysis result                                            |
    //+------------------------------------------------------------------+
    struct AnalysisResult
    {
        string overallTrend;     // "bullish", "bearish", "neutral"
        string trendStrength;    // "weak", "moderate", "strong"
        double supportLevel;
        double resistanceLevel;
        double confidence;
        string recommendation;   // "buy", "sell", "hold"
    };
    
    AnalysisResult ParseAnalysisResult(string jsonResponse)
    {
        AnalysisResult analysis;
        analysis.overallTrend = "neutral";
        analysis.trendStrength = "weak";
        analysis.supportLevel = 0.0;
        analysis.resistanceLevel = 0.0;
        analysis.confidence = 0.0;
        analysis.recommendation = "hold";
        
        analysis.overallTrend = ExtractJsonValue(jsonResponse, "overall_trend");
        analysis.trendStrength = ExtractJsonValue(jsonResponse, "trend_strength");
        
        string supportStr = ExtractJsonValue(jsonResponse, "immediate_support");
        if(supportStr != "") analysis.supportLevel = StringToDouble(supportStr);
        
        string resistanceStr = ExtractJsonValue(jsonResponse, "immediate_resistance");
        if(resistanceStr != "") analysis.resistanceLevel = StringToDouble(resistanceStr);
        
        // Look for recommendation in recommendations array
        if(StringFind(jsonResponse, "recommendations") != -1)
        {
            analysis.recommendation = ExtractJsonValue(jsonResponse, "action");
            string confStr = ExtractJsonValue(jsonResponse, "confidence");
            if(confStr != "") analysis.confidence = StringToDouble(confStr);
        }
        
        return analysis;
    }
};

