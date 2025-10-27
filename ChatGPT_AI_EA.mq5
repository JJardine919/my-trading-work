//+------------------------------------------------------------------+
//|                                             ChatGPT AI EA v2.0   |
//|                           Copyright 2025, Allan Munene Mutiiria. |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link "https://t.me/Forex_Algo_Trader"
#property version "2.00"
#property strict
#property description "AI-Powered Trading Assistant with ChatGPT Integration"
#property description "SETUP REQUIRED: Add https://api.openai.com to WebRequest allowed URLs"
#property description "Tools -> Options -> Expert Advisors -> Allow WebRequest for: https://api.openai.com"
#property description "Place API key in: MQL5/Files/chatgpt_api_key.txt"

//+------------------------------------------------------------------+
//| UI Layout Constants - No more magic numbers!                     |
//+------------------------------------------------------------------+
#define UI_MARGIN_LEFT          20
#define UI_MARGIN_TOP           20
#define UI_INPUT_WIDTH          400
#define UI_INPUT_HEIGHT         40
#define UI_BUTTON_WIDTH         100
#define UI_BUTTON_HEIGHT        40
#define UI_BUTTON_X             (UI_MARGIN_LEFT + UI_INPUT_WIDTH + 10)
#define UI_RESPONSE_BG_Y        70
#define UI_RESPONSE_BG_WIDTH    510
#define UI_RESPONSE_BG_HEIGHT   300
#define UI_CLEAR_BUTTON_X       (UI_BUTTON_X + UI_BUTTON_WIDTH + 10)
#define UI_TEXT_PADDING         10
#define UI_MAX_CHARS_PER_LINE   60

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== API Configuration ==="
input string OpenAI_API_Key_File = "chatgpt_api_key.txt";    // API Key Filename (in MQL5/Files/)
input string OpenAI_Model = "gpt-4o-mini";                   // OpenAI Model (gpt-4o-mini, gpt-4o, gpt-3.5-turbo)
input string OpenAI_Endpoint = "https://api.openai.com/v1/chat/completions"; // API Endpoint

input group "=== Conversation Settings ==="
input int MaxHistoryMessages = 10;                           // Max conversation messages to keep
input bool SendConversationContext = true;                   // Send previous messages for context
input int MaxTokensPerResponse = 500;                        // Max tokens per AI response

input group "=== Cost & Performance ==="
input bool EnableCostTracking = true;                        // Track API usage costs
input int APIRetryAttempts = 3;                              // Retry failed requests (1-5)
input int APIRetryDelayMs = 2000;                            // Delay between retries (ms)

input group "=== Trading Parameters ==="
input bool EnableTradingSignals = false;                     // Parse AI responses for trade signals
input double DefaultLotSize = 0.01;                          // Default lot size for trades
input int DefaultStopLoss = 50;                              // Default stop loss (pips)
input int DefaultTakeProfit = 100;                           // Default take profit (pips)
input int MagicNumber = 78901;                               // Magic number for EA trades

input group "=== Logging ==="
input string LogFileName = "ChatGPT_EA_Log.txt";             // Log file name
input bool VerboseLogging = false;                           // Enable detailed debug logs

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
string g_api_key = "";                                       // Loaded API key (secured)
string g_conversation_history = "";                          // Full conversation history
int g_message_count = 0;                                     // Number of messages in history
int g_log_file_handle = INVALID_HANDLE;                     // Log file handle
bool g_button_hover = false;                                 // Button hover state
color g_button_original_bg = clrRoyalBlue;                   // Original button color
color g_button_darker_bg;                                    // Darker button for hover
double g_total_cost_usd = 0.0;                               // Cumulative API cost
int g_total_requests = 0;                                    // Total API requests made
int g_failed_requests = 0;                                   // Failed requests count

//+------------------------------------------------------------------+
//| Cost tracking per model (approximate as of 2025)                |
//+------------------------------------------------------------------+
struct ModelPricing {
   string model_name;
   double input_cost_per_1k;                                 // USD per 1000 input tokens
   double output_cost_per_1k;                                // USD per 1000 output tokens
};

ModelPricing g_model_pricing[] = {
   {"gpt-4o", 0.0025, 0.01},                                 // GPT-4o pricing
   {"gpt-4o-mini", 0.00015, 0.0006},                         // GPT-4o-mini pricing
   {"gpt-3.5-turbo", 0.0005, 0.0015}                         // GPT-3.5-turbo pricing
};

//+------------------------------------------------------------------+
//| Enumeration of JSON value types                                  |
//+------------------------------------------------------------------+
enum JsonValueType {JsonUndefined, JsonNull, JsonBoolean, JsonInteger, JsonDouble, JsonString, JsonArray, JsonObject};

//+------------------------------------------------------------------+
//| Class representing a JSON value                                  |
//+------------------------------------------------------------------+
class JsonValue {
public:
   JsonValue m_children[];
   string m_key;
   string m_temporaryKey;
   JsonValue *m_parent;
   JsonValueType m_type;
   bool m_booleanValue;
   long m_integerValue;
   double m_doubleValue;
   string m_stringValue;
   static int encodingCodePage;

   JsonValue() { Reset(); }
   JsonValue(JsonValue *parent, JsonValueType type) { Reset(); m_type = type; m_parent = parent; }
   JsonValue(JsonValueType type, string value) { Reset(); SetFromString(type, value); }
   JsonValue(const int integerValue) { Reset(); m_type = JsonInteger; m_integerValue = integerValue; m_doubleValue = (double)m_integerValue; m_stringValue = IntegerToString(m_integerValue); m_booleanValue = integerValue != 0; }
   JsonValue(const JsonValue &other) { Reset(); CopyFrom(other); }
   ~JsonValue() { Reset(); }

   void Reset() {
      m_parent = NULL;
      m_key = "";
      m_temporaryKey = "";
      m_type = JsonUndefined;
      m_booleanValue = false;
      m_integerValue = 0;
      m_doubleValue = 0;
      m_stringValue = "";
      ArrayResize(m_children, 0);
   }

   bool CopyFrom(const JsonValue &source) {
      m_key = source.m_key;
      CopyDataFrom(source);
      return true;
   }

   void CopyDataFrom(const JsonValue &source) {
      m_type = source.m_type;
      m_booleanValue = source.m_booleanValue;
      m_integerValue = source.m_integerValue;
      m_doubleValue = source.m_doubleValue;
      m_stringValue = source.m_stringValue;
      CopyChildrenFrom(source);
   }

   void CopyChildrenFrom(const JsonValue &source) {
      int numChildren = ArrayResize(m_children, ArraySize(source.m_children));
      for(int index = 0; index < numChildren; index++) {
         m_children[index] = source.m_children[index];
         m_children[index].m_parent = GetPointer(this);
      }
   }

   JsonValue *FindChildByKey(string key) {
      for(int index = ArraySize(m_children) - 1; index >= 0; --index) {
         if(m_children[index].m_key == key) return GetPointer(m_children[index]);
      }
      return NULL;
   }

   JsonValue *operator[](string key) {
      if(m_type == JsonUndefined) m_type = JsonObject;
      JsonValue *value = FindChildByKey(key);
      if(value) return value;
      JsonValue newValue(GetPointer(this), JsonUndefined);
      newValue.m_key = key;
      value = AddChild(newValue);
      return value;
   }

   JsonValue *operator[](int index) {
      if(m_type == JsonUndefined) m_type = JsonArray;
      while(index >= ArraySize(m_children)) {
         JsonValue newValue(GetPointer(this), JsonUndefined);
         if(CheckPointer(AddChild(newValue)) == POINTER_INVALID) return NULL;
      }
      return GetPointer(m_children[index]);
   }

   void operator=(const JsonValue &value) { CopyFrom(value); }
   void operator=(string stringValue) { m_type = (stringValue != NULL) ? JsonString : JsonNull; m_stringValue = stringValue; m_integerValue = StringToInteger(m_stringValue); m_doubleValue = StringToDouble(m_stringValue); m_booleanValue = stringValue != NULL; }
   void operator=(const int integerValue) { m_type = JsonInteger; m_integerValue = integerValue; m_doubleValue = (double)m_integerValue; m_stringValue = IntegerToString(m_integerValue); m_booleanValue = integerValue != 0; }

   bool ToBoolean() const { return m_booleanValue; }
   string ToString() { return m_stringValue; }

   void SetFromString(JsonValueType type, string stringValue) {
      m_type = type;
      switch(m_type) {
         case JsonBoolean:
            m_booleanValue = (StringToInteger(stringValue) != 0);
            m_integerValue = (long)m_booleanValue;
            m_doubleValue = (double)m_booleanValue;
            m_stringValue = stringValue;
            break;
         case JsonString:
            m_stringValue = UnescapeString(stringValue);
            m_type = (m_stringValue != NULL) ? JsonString : JsonNull;
            m_integerValue = StringToInteger(m_stringValue);
            m_doubleValue = StringToDouble(m_stringValue);
            m_booleanValue = m_stringValue != NULL;
            break;
      }
   }

   string GetSubstringFromArray(char &jsonCharacterArray[], int startPosition, int substringLength) {
      if(substringLength <= 0) return "";
      char temporaryArray[];
      ArrayCopy(temporaryArray, jsonCharacterArray, 0, startPosition, substringLength);
      return CharArrayToString(temporaryArray, 0, WHOLE_ARRAY, encodingCodePage);
   }

   JsonValue *AddChild(const JsonValue &item) {
      if(m_type == JsonUndefined) m_type = JsonArray;
      return AddChildInternal(item);
   }

   JsonValue *AddChild(string stringValue) { JsonValue item(JsonString, stringValue); return AddChild(item); }
   JsonValue *AddChild(const int integerValue) { JsonValue item(integerValue); return AddChild(item); }

   JsonValue *AddChildInternal(const JsonValue &item) {
      int currentSize = ArraySize(m_children);
      ArrayResize(m_children, currentSize + 1);
      m_children[currentSize] = item;
      m_children[currentSize].m_parent = GetPointer(this);
      return GetPointer(m_children[currentSize]);
   }

   string SerializeToString() {
      string jsonString;
      SerializeToString(jsonString);
      return jsonString;
   }

   void SerializeToString(string &jsonString, bool includeKey = false, bool includeComma = false) {
      if(m_type == JsonUndefined) return;
      if(includeComma) jsonString += ",";
      if(includeKey) jsonString += StringFormat("\"%s\":", m_key);
      int numChildren = ArraySize(m_children);
      switch(m_type) {
         case JsonNull: jsonString += "null"; break;
         case JsonBoolean: jsonString += (m_booleanValue ? "true" : "false"); break;
         case JsonInteger: jsonString += IntegerToString(m_integerValue); break;
         case JsonDouble: jsonString += DoubleToString(m_doubleValue); break;
         case JsonString: {
            string escaped = EscapeString(m_stringValue);
            jsonString += (StringLen(escaped) > 0) ? StringFormat("\"%s\"", escaped) : "null";
         } break;
         case JsonArray: {
            jsonString += "[";
            for(int index = 0; index < numChildren; index++) m_children[index].SerializeToString(jsonString, false, index > 0);
            jsonString += "]";
         } break;
         case JsonObject: {
            jsonString += "{";
            for(int index = 0; index < numChildren; index++) m_children[index].SerializeToString(jsonString, true, index > 0);
            jsonString += "}";
         } break;
      }
   }

   bool DeserializeFromArray(char &jsonCharacterArray[], int arrayLength, int &currentIndex) {
      string validNumericCharacters = "0123456789+-.eE";
      int startPosition = currentIndex;
      for(; currentIndex < arrayLength; currentIndex++) {
         char currentCharacter = jsonCharacterArray[currentIndex];
         if(currentCharacter == 0) break;
         switch(currentCharacter) {
            case '\t': case '\r': case '\n': case ' ': startPosition = currentIndex + 1; break;
            case '[': {
               startPosition = currentIndex + 1;
               if(m_type != JsonUndefined) return false;
               m_type = JsonArray;
               currentIndex++;
               JsonValue childValue(GetPointer(this), JsonUndefined);
               while(childValue.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) {
                  if(childValue.m_type != JsonUndefined) AddChild(childValue);
                  if(childValue.m_type == JsonInteger || childValue.m_type == JsonDouble || childValue.m_type == JsonArray) currentIndex++;
                  childValue.Reset();
                  childValue.m_parent = GetPointer(this);
                  if(jsonCharacterArray[currentIndex] == ']') break;
                  currentIndex++;
                  if(currentIndex >= arrayLength) return false;
               }
               return (jsonCharacterArray[currentIndex] == ']' || jsonCharacterArray[currentIndex] == 0);
            }
            case ']': return (m_parent && m_parent.m_type == JsonArray);
            case ':': {
               if(m_temporaryKey == "") return false;
               JsonValue childValue(GetPointer(this), JsonUndefined);
               JsonValue *addedChild = AddChild(childValue);
               addedChild.m_key = m_temporaryKey;
               m_temporaryKey = "";
               currentIndex++;
               if(!addedChild.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false;
            } break;
            case ',': {
               startPosition = currentIndex + 1;
               if(!m_parent && m_type != JsonObject) return false;
               if(m_parent && m_parent.m_type != JsonArray && m_parent.m_type != JsonObject) return false;
               if(m_parent && m_parent.m_type == JsonArray && m_type == JsonUndefined) return true;
            } break;
            case '{': {
               startPosition = currentIndex + 1;
               if(m_type != JsonUndefined) return false;
               m_type = JsonObject;
               currentIndex++;
               if(!DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false;
               return (jsonCharacterArray[currentIndex] == '}' || jsonCharacterArray[currentIndex] == 0);
            } break;
            case '}': return (m_type == JsonObject);
            case 't': case 'T': case 'f': case 'F': {
               if(m_type != JsonUndefined) return false;
               m_type = JsonBoolean;
               if(currentIndex + 3 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "true", false) == 0) {
                  m_booleanValue = true; currentIndex += 3; return true;
               }
               if(currentIndex + 4 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 5), "false", false) == 0) {
                  m_booleanValue = false; currentIndex += 4; return true;
               }
               return false;
            } break;
            case 'n': case 'N': {
               if(m_type != JsonUndefined) return false;
               m_type = JsonNull;
               if(currentIndex + 3 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "null", false) == 0) {
                  currentIndex += 3; return true;
               }
               return false;
            } break;
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
            case '-': case '+': case '.': {
               if(m_type != JsonUndefined) return false;
               bool isDouble = false;
               int startOfNumber = currentIndex;
               while(jsonCharacterArray[currentIndex] != 0 && currentIndex < arrayLength) {
                  currentIndex++;
                  if(StringFind(validNumericCharacters, GetSubstringFromArray(jsonCharacterArray, currentIndex, 1)) < 0) break;
                  if(!isDouble) isDouble = (jsonCharacterArray[currentIndex] == '.' || jsonCharacterArray[currentIndex] == 'e' || jsonCharacterArray[currentIndex] == 'E');
               }
               m_stringValue = GetSubstringFromArray(jsonCharacterArray, startOfNumber, currentIndex - startOfNumber);
               if(isDouble) {
                  m_type = JsonDouble;
                  m_doubleValue = StringToDouble(m_stringValue);
                  m_integerValue = (long)m_doubleValue;
                  m_booleanValue = m_integerValue != 0;
               } else {
                  m_type = JsonInteger;
                  m_integerValue = StringToInteger(m_stringValue);
                  m_doubleValue = (double)m_integerValue;
                  m_booleanValue = m_integerValue != 0;
               }
               currentIndex--;
               return true;
            } break;
            case '\"': {
               if(m_type == JsonObject) {
                  currentIndex++;
                  int startOfString = currentIndex;
                  if(!ExtractStringFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false;
                  m_temporaryKey = GetSubstringFromArray(jsonCharacterArray, startOfString, currentIndex - startOfString);
               } else {
                  if(m_type != JsonUndefined) return false;
                  m_type = JsonString;
                  currentIndex++;
                  int startOfString = currentIndex;
                  if(!ExtractStringFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false;
                  SetFromString(JsonString, GetSubstringFromArray(jsonCharacterArray, startOfString, currentIndex - startOfString));
                  return true;
               }
            } break;
         }
      }
      return true;
   }

   bool ExtractStringFromArray(char &jsonCharacterArray[], int arrayLength, int &currentIndex) {
      for(; jsonCharacterArray[currentIndex] != 0 && currentIndex < arrayLength; currentIndex++) {
         char currentCharacter = jsonCharacterArray[currentIndex];
         if(currentCharacter == '\"') break;
         if(currentCharacter == '\\' && currentIndex + 1 < arrayLength) {
            currentIndex++;
            currentCharacter = jsonCharacterArray[currentIndex];
            switch(currentCharacter) {
               case '/': case '\\': case '\"': case 'b': case 'f': case 'r': case 'n': case 't': break;
               case 'u': {
                  currentIndex++;
                  for(int hexIndex = 0; hexIndex < 4 && currentIndex < arrayLength && jsonCharacterArray[currentIndex] != 0; hexIndex++, currentIndex++) {
                     if(!((jsonCharacterArray[currentIndex] >= '0' && jsonCharacterArray[currentIndex] <= '9') || (jsonCharacterArray[currentIndex] >= 'A' && jsonCharacterArray[currentIndex] <= 'F') || (jsonCharacterArray[currentIndex] >= 'a' && jsonCharacterArray[currentIndex] <= 'f'))) return false;
                  }
                  currentIndex--;
                  break;
               }
               default: break;
            }
         }
      }
      return true;
   }

   string EscapeString(string value) {
      ushort inputCharacters[], escapedCharacters[];
      int inputLength = StringToShortArray(value, inputCharacters);
      if(ArrayResize(escapedCharacters, 2 * inputLength) != 2 * inputLength) return NULL;
      int escapedIndex = 0;
      for(int inputIndex = 0; inputIndex < inputLength; inputIndex++) {
         switch(inputCharacters[inputIndex]) {
            case '\\': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '\\'; escapedIndex++; break;
            case '"': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '"'; escapedIndex++; break;
            case '/': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '/'; escapedIndex++; break;
            case 8: escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'b'; escapedIndex++; break;
            case 12: escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'f'; escapedIndex++; break;
            case '\n': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'n'; escapedIndex++; break;
            case '\r': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'r'; escapedIndex++; break;
            case '\t': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 't'; escapedIndex++; break;
            default: escapedCharacters[escapedIndex] = inputCharacters[inputIndex]; escapedIndex++; break;
         }
      }
      return ShortArrayToString(escapedCharacters, 0, escapedIndex);
   }

   string UnescapeString(string value) {
      ushort inputCharacters[], unescapedCharacters[];
      int inputLength = StringToShortArray(value, inputCharacters);
      if(ArrayResize(unescapedCharacters, inputLength) != inputLength) return NULL;
      int outputIndex = 0, inputIndex = 0;
      while(inputIndex < inputLength) {
         ushort currentCharacter = inputCharacters[inputIndex];
         if(currentCharacter == '\\' && inputIndex < inputLength - 1) {
            switch(inputCharacters[inputIndex + 1]) {
               case '\\': currentCharacter = '\\'; inputIndex++; break;
               case '"': currentCharacter = '"'; inputIndex++; break;
               case '/': currentCharacter = '/'; inputIndex++; break;
               case 'b': currentCharacter = 8; inputIndex++; break;
               case 'f': currentCharacter = 12; inputIndex++; break;
               case 'n': currentCharacter = '\n'; inputIndex++; break;
               case 'r': currentCharacter = '\r'; inputIndex++; break;
               case 't': currentCharacter = '\t'; inputIndex++; break;
            }
         }
         unescapedCharacters[outputIndex] = currentCharacter;
         outputIndex++;
         inputIndex++;
      }
      return ShortArrayToString(unescapedCharacters, 0, outputIndex);
   }
};

int JsonValue::encodingCodePage = CP_UTF8;

//+------------------------------------------------------------------+
//| Load API Key from External File (SECURE METHOD)                  |
//+------------------------------------------------------------------+
string LoadAPIKey() {
   ResetLastError();

   // Try FILE_COMMON first (shared across all MT5 instances)
   int handle = FileOpen(OpenAI_API_Key_File, FILE_READ | FILE_TXT | FILE_COMMON);

   // If not found, try local Files folder
   if(handle == INVALID_HANDLE) {
      handle = FileOpen(OpenAI_API_Key_File, FILE_READ | FILE_TXT);
   }

   if(handle == INVALID_HANDLE) {
      string error_msg = StringFormat(
         "CRITICAL ERROR: API key file not found!\n" +
         "Expected file: %s\n" +
         "Location 1: %%APPDATA%%\\MetaQuotes\\Terminal\\Common\\Files\\%s\n" +
         "Location 2: MQL5\\Files\\%s\n\n" +
         "Create this file and paste your OpenAI API key (one line, no spaces).\n" +
         "Error code: %d",
         OpenAI_API_Key_File, OpenAI_API_Key_File, OpenAI_API_Key_File, GetLastError()
      );
      Alert(error_msg);
      Print(error_msg);
      return "";
   }

   string key = FileReadString(handle);
   FileClose(handle);

   // Clean the key
   StringTrimLeft(key);
   StringTrimRight(key);

   // Validate key format (OpenAI keys start with "sk-")
   if(StringLen(key) < 20 || StringFind(key, "sk-") != 0) {
      Alert("ERROR: Invalid API key format in " + OpenAI_API_Key_File + "\nKey must start with 'sk-' and be at least 20 characters.");
      Print("ERROR: Invalid API key format. Length: ", StringLen(key), ", Starts with: ", StringSubstr(key, 0, 3));
      return "";
   }

   Print("✓ API key loaded successfully (length: ", StringLen(key), " chars)");
   return key;
}

//+------------------------------------------------------------------+
//| Validate WebRequest URL Permission                               |
//+------------------------------------------------------------------+
bool ValidateWebRequestPermission() {
   // Test with a dummy request to check if URL is whitelisted
   char post_data[];
   char result[];
   string result_headers;

   // Attempt minimal request (will fail auth but that's OK - we just need to see if URL is allowed)
   int response_code = WebRequest(
      "GET",
      "https://api.openai.com/v1/models",
      "Authorization: Bearer test\r\n",
      500,  // Short timeout
      post_data,
      result,
      result_headers
   );

   if(response_code == -1) {
      int error = GetLastError();
      if(error == 4014 || error == 5200) {  // URL not allowed errors
         Alert(
            "SETUP REQUIRED: WebRequest URL Not Allowed!\n\n" +
            "Please add the following URL to allowed list:\n" +
            "https://api.openai.com\n\n" +
            "Steps:\n" +
            "1. Tools -> Options\n" +
            "2. Expert Advisors tab\n" +
            "3. Check 'Allow WebRequest for listed URL:'\n" +
            "4. Add: https://api.openai.com\n" +
            "5. Click OK and restart EA"
         );
         Print("ERROR: WebRequest not allowed for https://api.openai.com. Error code: ", error);
         return false;
      }
   }

   Print("✓ WebRequest permission validated for OpenAI API");
   return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("========================================");
   Print("  ChatGPT AI EA v2.0 Initializing...  ");
   Print("========================================");

   // Step 1: Load API Key
   g_api_key = LoadAPIKey();
   if(g_api_key == "") {
      Print("INIT FAILED: Could not load API key");
      return INIT_FAILED;
   }

   // Step 2: Validate WebRequest Permission
   if(!ValidateWebRequestPermission()) {
      Print("INIT FAILED: WebRequest permission not granted");
      return INIT_FAILED;
   }

   // Step 3: Validate input parameters
   if(APIRetryAttempts < 1 || APIRetryAttempts > 5) {
      Print("WARNING: APIRetryAttempts out of range (1-5), setting to 3");
      APIRetryAttempts = 3;
   }

   if(MaxHistoryMessages < 1) {
      Print("WARNING: MaxHistoryMessages must be >= 1, setting to 1");
      MaxHistoryMessages = 1;
   }

   // Step 4: Open log file
   g_log_file_handle = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_TXT);
   if(g_log_file_handle == INVALID_HANDLE) {
      Print("WARNING: Failed to open log file: ", GetLastError());
   } else {
      FileSeek(g_log_file_handle, 0, SEEK_END);
      FileWriteString(g_log_file_handle, "\n========================================\n");
      FileWriteString(g_log_file_handle, "EA Initialized: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n");
      FileWriteString(g_log_file_handle, "Model: " + OpenAI_Model + "\n");
      FileWriteString(g_log_file_handle, "Max History: " + IntegerToString(MaxHistoryMessages) + " messages\n");
      FileWriteString(g_log_file_handle, "========================================\n");
   }

   // Step 5: Initialize UI
   g_button_darker_bg = DarkenColor(g_button_original_bg);
   CreateDashboard();
   UpdateResponseDisplay();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   Print("✓ EA initialized successfully!");
   Print("Model: ", OpenAI_Model);
   Print("Max history: ", MaxHistoryMessages, " messages");
   Print("Trading signals: ", EnableTradingSignals ? "ENABLED" : "DISABLED");
   Print("Cost tracking: ", EnableCostTracking ? "ENABLED" : "DISABLED");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("========================================");
   Print("  ChatGPT AI EA Shutting Down...  ");
   Print("========================================");

   // Clean up UI
   ObjectsDeleteAll(0, "ChatGPT_");

   // Log final stats
   if(g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "\n========================================\n");
      FileWriteString(g_log_file_handle, "EA Deinitialized: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n");
      FileWriteString(g_log_file_handle, "Session Stats:\n");
      FileWriteString(g_log_file_handle, "  Total Requests: " + IntegerToString(g_total_requests) + "\n");
      FileWriteString(g_log_file_handle, "  Failed Requests: " + IntegerToString(g_failed_requests) + "\n");
      if(EnableCostTracking) {
         FileWriteString(g_log_file_handle, "  Estimated Cost: $" + DoubleToString(g_total_cost_usd, 6) + " USD\n");
      }
      FileWriteString(g_log_file_handle, "  Reason: " + IntegerToString(reason) + "\n");
      FileWriteString(g_log_file_handle, "========================================\n");
      FileClose(g_log_file_handle);
   }

   Print("Total API requests: ", g_total_requests);
   Print("Failed requests: ", g_failed_requests);
   if(EnableCostTracking) {
      Print("Estimated cost: $", DoubleToString(g_total_cost_usd, 6), " USD");
   }
   Print("Shutdown complete.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Future: Implement periodic market analysis if enabled
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == "ChatGPT_SubmitButton") {
         HandleSubmitClick();
      } else if(sparam == "ChatGPT_ClearButton") {
         HandleClearClick();
      }
   } else if(id == CHARTEVENT_MOUSE_MOVE) {
      HandleMouseMove((int)lparam, (int)dparam);
   }
}

//+------------------------------------------------------------------+
//| Handle Submit Button Click                                       |
//+------------------------------------------------------------------+
void HandleSubmitClick() {
   string prompt = ObjectGetString(0, "ChatGPT_InputEdit", OBJPROP_TEXT);

   // Validate input
   StringTrimLeft(prompt);
   StringTrimRight(prompt);

   if(StringLen(prompt) == 0) {
      return;  // Empty input, ignore
   }

   if(StringLen(prompt) > 4000) {
      Alert("Message too long! Maximum 4000 characters.");
      return;
   }

   // Get AI response
   string response = GetChatGPTResponse(prompt);

   // Update conversation history
   UpdateConversationHistory(prompt, response);

   // Clear input
   ObjectSetString(0, "ChatGPT_InputEdit", OBJPROP_TEXT, "");

   // Refresh display
   UpdateResponseDisplay();

   // Check for trading signals if enabled
   if(EnableTradingSignals) {
      ParseTradingSignals(response);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Handle Clear Button Click                                        |
//+------------------------------------------------------------------+
void HandleClearClick() {
   if(MessageBox("Clear entire conversation history?", "Confirm Clear", MB_YESNO | MB_ICONQUESTION) == IDYES) {
      g_conversation_history = "";
      g_message_count = 0;
      UpdateResponseDisplay();
      Print("Conversation history cleared");

      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] History cleared by user\n");
      }
   }
}

//+------------------------------------------------------------------+
//| Handle Mouse Movement for Hover Effects                          |
//+------------------------------------------------------------------+
void HandleMouseMove(int mouseX, int mouseY) {
   bool isOverSubmit = (mouseX >= UI_BUTTON_X && mouseX <= UI_BUTTON_X + UI_BUTTON_WIDTH &&
                        mouseY >= UI_MARGIN_TOP && mouseY <= UI_MARGIN_TOP + UI_BUTTON_HEIGHT);

   if(isOverSubmit && !g_button_hover) {
      ObjectSetInteger(0, "ChatGPT_SubmitButton", OBJPROP_BGCOLOR, g_button_darker_bg);
      g_button_hover = true;
      ChartRedraw();
   } else if(!isOverSubmit && g_button_hover) {
      ObjectSetInteger(0, "ChatGPT_SubmitButton", OBJPROP_BGCOLOR, g_button_original_bg);
      g_button_hover = false;
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Update Conversation History with Limits                          |
//+------------------------------------------------------------------+
void UpdateConversationHistory(string prompt, string response) {
   // Prepend to history
   string new_entry = "You: " + prompt + "\nAI: " + response + "\n\n";
   g_conversation_history = new_entry + g_conversation_history;
   g_message_count++;

   // Enforce message limit by truncating old messages
   if(g_message_count > MaxHistoryMessages * 2) {  // *2 because each exchange is 2 messages
      // Find the last occurrence to keep
      int keep_count = MaxHistoryMessages * 2;
      int pos = 0;
      int found_count = 0;

      while(pos < StringLen(g_conversation_history)) {
         int next_you = StringFind(g_conversation_history, "You: ", pos);
         if(next_you == -1) break;
         found_count++;
         if(found_count >= keep_count) {
            g_conversation_history = StringSubstr(g_conversation_history, 0, next_you);
            g_message_count = keep_count;
            break;
         }
         pos = next_you + 5;
      }
   }

   // Also enforce character limit (prevent memory issues)
   int max_chars = 10000;
   if(StringLen(g_conversation_history) > max_chars) {
      g_conversation_history = StringSubstr(g_conversation_history, 0, max_chars);
   }

   if(VerboseLogging && g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] History updated. Messages: " +
                      IntegerToString(g_message_count) + ", Chars: " + IntegerToString(StringLen(g_conversation_history)) + "\n");
   }
}

//+------------------------------------------------------------------+
//| Parse Trading Signals from AI Response                           |
//+------------------------------------------------------------------+
void ParseTradingSignals(string response) {
   // Convert to uppercase for case-insensitive matching
   string upper_response = response;
   StringToUpper(upper_response);

   // Simple signal detection (can be enhanced)
   bool has_buy = (StringFind(upper_response, "BUY") >= 0 || StringFind(upper_response, "LONG") >= 0);
   bool has_sell = (StringFind(upper_response, "SELL") >= 0 || StringFind(upper_response, "SHORT") >= 0);

   if(has_buy && !has_sell) {
      Print(">>> TRADING SIGNAL DETECTED: BUY");
      // Future: Implement actual trade execution here
      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] BUY signal detected in AI response\n");
      }
   } else if(has_sell && !has_buy) {
      Print(">>> TRADING SIGNAL DETECTED: SELL");
      // Future: Implement actual trade execution here
      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] SELL signal detected in AI response\n");
      }
   }

   // Note: This is a basic implementation. Real trading logic should include:
   // - SL/TP extraction from response
   // - Risk validation
   // - Position size calculation
   // - Confirmation requirements
   // - Market condition checks
}

//+------------------------------------------------------------------+
//| Darkens a given color by a factor                                |
//+------------------------------------------------------------------+
color DarkenColor(color colorValue, double factor = 0.8) {
   int red = (int)((colorValue & 0xFF) * factor);
   int green = (int)(((colorValue >> 8) & 0xFF) * factor);
   int blue = (int)(((colorValue >> 16) & 0xFF) * factor);
   return (color)(red | (green << 8) | (blue << 16));
}

//+------------------------------------------------------------------+
//| Creates a rectangle label object                                 |
//+------------------------------------------------------------------+
bool createRecLabel(string objName, int xDistance, int yDistance, int xSize, int ySize,
                    color bgColor, int borderWidth, color borderColor = clrNONE,
                    ENUM_BORDER_TYPE borderType = BORDER_FLAT,
                    ENUM_LINE_STYLE borderStyle = STYLE_SOLID,
                    ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed to create rec label! Error code = ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, borderType);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, borderStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, borderWidth);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   return true;
}

//+------------------------------------------------------------------+
//| Creates a button object                                          |
//+------------------------------------------------------------------+
bool createButton(string objName, int xDistance, int yDistance, int xSize, int ySize,
                  string text = "", color textColor = clrBlack, int fontSize = 12,
                  color bgColor = clrNONE, color borderColor = clrNONE,
                  string font = "Arial Rounded MT Bold",
                  ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER, bool isBack = false) {
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed to create the button! Error code = ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderColor);
   ObjectSetInteger(0, objName, OBJPROP_BACK, isBack);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   return true;
}

//+------------------------------------------------------------------+
//| Creates an edit field object                                     |
//+------------------------------------------------------------------+
bool createEdit(string objName, int xDistance, int yDistance, int xSize, int ySize,
                string text = "", color textColor = clrBlack, int fontSize = 12,
                color bgColor = clrNONE, color borderColor = clrNONE,
                string font = "Arial Rounded MT Bold",
                ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                int align = ALIGN_LEFT, bool readOnly = false) {
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed to create the edit! Error code = ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderColor);
   ObjectSetInteger(0, objName, OBJPROP_ALIGN, align);
   ObjectSetInteger(0, objName, OBJPROP_READONLY, readOnly);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   return true;
}

//+------------------------------------------------------------------+
//| Creates a text label object                                      |
//+------------------------------------------------------------------+
bool createLabel(string objName, int xDistance, int yDistance,
                 string text, color textColor = clrBlack, int fontSize = 12,
                 string font = "Arial Rounded MT Bold",
                 ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                 ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER) {
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed to create the label! Error code = ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
   return true;
}

//+------------------------------------------------------------------+
//| Wraps text respecting newlines and max width                     |
//+------------------------------------------------------------------+
void WrapText(const string inputText, const string font, const int fontSize, const int maxWidth, string &wrappedLines[], int offset = 0) {
   ArrayResize(wrappedLines, 0);
   TextSetFont(font, -fontSize * 10, 0);

   string paragraphs[];
   int numParagraphs = StringSplit(inputText, '\n', paragraphs);

   for (int p = 0; p < numParagraphs; p++) {
      string para = paragraphs[p];
      if (StringLen(para) == 0) continue;

      string words[];
      int numWords = StringSplit(para, ' ', words);
      string currentLine = "";

      for (int w = 0; w < numWords; w++) {
         string testLine = currentLine + (StringLen(currentLine) > 0 ? " " : "") + words[w];
         uint wid, hei;
         TextGetSize(testLine, wid, hei);
         int textWidth = (int)wid;

         if (textWidth + offset <= maxWidth && StringLen(testLine) <= UI_MAX_CHARS_PER_LINE) {
            currentLine = testLine;
         } else {
            if (StringLen(currentLine) > 0) {
               int size = ArraySize(wrappedLines);
               ArrayResize(wrappedLines, size + 1);
               wrappedLines[size] = currentLine;
            }
            currentLine = words[w];
            TextGetSize(currentLine, wid, hei);
            textWidth = (int)wid;

            if (textWidth + offset > maxWidth || StringLen(currentLine) > UI_MAX_CHARS_PER_LINE) {
               string wrappedWord = "";
               for (int c = 0; c < StringLen(words[w]); c++) {
                  string testWord = wrappedWord + StringSubstr(words[w], c, 1);
                  TextGetSize(testWord, wid, hei);
                  int wordWidth = (int)wid;

                  if (wordWidth + offset > maxWidth || StringLen(testWord) > UI_MAX_CHARS_PER_LINE) {
                     if (StringLen(wrappedWord) > 0) {
                        int size = ArraySize(wrappedLines);
                        ArrayResize(wrappedLines, size + 1);
                        wrappedLines[size] = wrappedWord;
                     }
                     wrappedWord = StringSubstr(words[w], c, 1);
                  } else {
                     wrappedWord = testWord;
                  }
               }
               currentLine = wrappedWord;
            }
         }
      }

      if (StringLen(currentLine) > 0) {
         int size = ArraySize(wrappedLines);
         ArrayResize(wrappedLines, size + 1);
         wrappedLines[size] = currentLine;
      }
   }
}

//+------------------------------------------------------------------+
//| Creates the dashboard UI                                         |
//+------------------------------------------------------------------+
void CreateDashboard() {
   // Input field
   createEdit("ChatGPT_InputEdit", UI_MARGIN_LEFT, UI_MARGIN_TOP, UI_INPUT_WIDTH, UI_INPUT_HEIGHT,
              "", clrBlack, 12, clrWhiteSmoke, clrDarkGray, "Arial", CORNER_LEFT_UPPER, ALIGN_LEFT, false);

   // Submit button
   createButton("ChatGPT_SubmitButton", UI_BUTTON_X, UI_MARGIN_TOP, UI_BUTTON_WIDTH, UI_BUTTON_HEIGHT,
                "Send", clrWhite, 12, g_button_original_bg, clrDarkBlue, "Arial", CORNER_LEFT_UPPER, false);

   // Clear button
   createButton("ChatGPT_ClearButton", UI_CLEAR_BUTTON_X, UI_MARGIN_TOP, 80, UI_BUTTON_HEIGHT,
                "Clear", clrWhite, 10, clrCrimson, clrDarkRed, "Arial", CORNER_LEFT_UPPER, false);

   // Response background
   createRecLabel("ChatGPT_ResponseBg", UI_MARGIN_LEFT, UI_RESPONSE_BG_Y, UI_RESPONSE_BG_WIDTH, UI_RESPONSE_BG_HEIGHT,
                  clrWhite, 2, clrLightGray, BORDER_FLAT, STYLE_SOLID, CORNER_LEFT_UPPER);

   // Stats label (if cost tracking enabled)
   if(EnableCostTracking) {
      createLabel("ChatGPT_StatsLabel", UI_MARGIN_LEFT, UI_RESPONSE_BG_Y + UI_RESPONSE_BG_HEIGHT + 10,
                  "Requests: 0 | Cost: $0.00", clrDimGray, 8, "Arial", CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Updates the response display                                     |
//+------------------------------------------------------------------+
void UpdateResponseDisplay() {
   // Delete old response lines
   int total = ObjectsTotal(0, 0, -1);
   for (int j = total - 1; j >= 0; j--) {
      string name = ObjectName(0, j, 0, -1);
      if (StringFind(name, "ChatGPT_ResponseLine_") == 0 || StringFind(name, "ChatGPT_MessageBg_") == 0) {
         ObjectDelete(0, name);
      }
   }

   // Update stats if enabled
   if(EnableCostTracking) {
      string stats_text = StringFormat("Requests: %d | Failed: %d | Cost: $%.6f USD",
                                       g_total_requests, g_failed_requests, g_total_cost_usd);
      ObjectSetString(0, "ChatGPT_StatsLabel", OBJPROP_TEXT, stats_text);
   }

   string displayText = g_conversation_history;

   if (displayText == "") {
      createLabel("ChatGPT_ResponseLine_0", UI_MARGIN_LEFT + UI_TEXT_PADDING, UI_RESPONSE_BG_Y + UI_TEXT_PADDING,
                  "Type your message above and click Send to chat with the AI.", clrGray, 10, "Arial",
                  CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER);
      ChartRedraw();
      return;
   }

   string font = "Arial";
   int fontSize = 10;
   int maxWidth = UI_RESPONSE_BG_WIDTH - 2 * UI_TEXT_PADDING;
   string wrappedLines[];

   WrapText(displayText, font, fontSize, maxWidth, wrappedLines, 0);

   TextSetFont(font, -fontSize * 10, 0);
   uint wid, hei;
   TextGetSize("A", wid, hei);
   int lineHeight = (int)hei;
   int maxVisibleLines = (UI_RESPONSE_BG_HEIGHT - 2 * UI_TEXT_PADDING) / lineHeight;
   int numLines = ArraySize(wrappedLines);
   int startLine = MathMax(0, numLines - maxVisibleLines);
   int textX = UI_MARGIN_LEFT + UI_TEXT_PADDING;
   int textY = UI_RESPONSE_BG_Y + UI_TEXT_PADDING;
   color currentColor = clrWhite;

   for (int i = startLine; i < numLines; i++) {
      string line = wrappedLines[i];

      if (StringFind(line, "You: ") == 0) {
         currentColor = clrDarkSlateGray;
      } else if (StringFind(line, "AI: ") == 0) {
         currentColor = clrRoyalBlue;
      }

      string objName = "ChatGPT_ResponseLine_" + IntegerToString(i - startLine);
      createLabel(objName, textX, textY, line, currentColor, fontSize, font, CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER);
      textY += lineHeight;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Escapes string for JSON                                          |
//+------------------------------------------------------------------+
string JsonEscape(string value) {
   StringReplace(value, "\\", "\\\\");
   StringReplace(value, "\"", "\\\"");
   StringReplace(value, "\n", "\\n");
   StringReplace(value, "\r", "\\r");
   StringReplace(value, "\t", "\\t");
   StringReplace(value, "\f", "\\f");

   for(int i = 0; i < StringLen(value); i++) {
      ushort charCode = StringGetCharacter(value, i);
      if(charCode < 32 || charCode == 127) {
         string hex = StringFormat("\\u%04x", charCode);
         string before = StringSubstr(value, 0, i);
         string after = StringSubstr(value, i + 1);
         value = before + hex + after;
         i += 5;
      }
   }
   return value;
}

//+------------------------------------------------------------------+
//| Gets ChatGPT response via API with retry logic                   |
//+------------------------------------------------------------------+
string GetChatGPTResponse(string prompt) {
   string response = "";

   for(int attempt = 1; attempt <= APIRetryAttempts; attempt++) {
      if(attempt > 1) {
         Print("Retry attempt ", attempt, "/", APIRetryAttempts);
         Sleep(APIRetryDelayMs);
      }

      response = SendChatGPTRequest(prompt);

      // Check if we got a valid response
      if(StringFind(response, "Error:") != 0 && StringFind(response, "API request failed") != 0) {
         g_total_requests++;
         return response;  // Success!
      }

      // Log failed attempt
      if(attempt < APIRetryAttempts) {
         Print("Request failed, retrying... (", attempt, "/", APIRetryAttempts, ")");
      }
   }

   // All retries failed
   g_failed_requests++;
   g_total_requests++;
   Print("ERROR: All ", APIRetryAttempts, " retry attempts failed");
   return response;
}

//+------------------------------------------------------------------+
//| Send actual ChatGPT API request                                  |
//+------------------------------------------------------------------+
string SendChatGPTRequest(string prompt) {
   // Build messages array with conversation context if enabled
   string messages_json = "";

   if(SendConversationContext && StringLen(g_conversation_history) > 0) {
      // Parse history and build messages array
      // For simplicity, we'll send last few exchanges
      string history_lines[];
      StringSplit(g_conversation_history, '\n', history_lines);

      messages_json = "[";
      int message_count = 0;
      int max_context_messages = MathMin(MaxHistoryMessages * 2, 10);

      for(int i = 0; i < ArraySize(history_lines) && message_count < max_context_messages; i++) {
         string line = history_lines[i];
         StringTrimLeft(line);
         StringTrimRight(line);

         if(StringLen(line) == 0) continue;

         if(StringFind(line, "You: ") == 0) {
            string user_msg = StringSubstr(line, 5);
            if(StringLen(user_msg) > 0) {
               if(message_count > 0) messages_json += ",";
               messages_json += "{\"role\":\"user\",\"content\":\"" + JsonEscape(user_msg) + "\"}";
               message_count++;
            }
         } else if(StringFind(line, "AI: ") == 0) {
            string ai_msg = StringSubstr(line, 4);
            if(StringLen(ai_msg) > 0) {
               if(message_count > 0) messages_json += ",";
               messages_json += "{\"role\":\"assistant\",\"content\":\"" + JsonEscape(ai_msg) + "\"}";
               message_count++;
            }
         }
      }

      // Add current prompt
      if(message_count > 0) messages_json += ",";
      messages_json += "{\"role\":\"user\",\"content\":\"" + JsonEscape(prompt) + "\"}";
      messages_json += "]";
   } else {
      // No context, just send current prompt
      messages_json = "[{\"role\":\"user\",\"content\":\"" + JsonEscape(prompt) + "\"}]";
   }

   // Build request JSON
   string requestData = "{\"model\":\"" + OpenAI_Model + "\",\"messages\":" + messages_json +
                        ",\"max_tokens\":" + IntegerToString(MaxTokensPerResponse) + "}";

   if(VerboseLogging && g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] Request: " + requestData + "\n");
   }

   // Convert to char array
   char postData[];
   int dataLen = StringToCharArray(requestData, postData, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(postData, dataLen - 1);

   // Build headers
   string headers = "Authorization: Bearer " + g_api_key + "\r\n" +
                    "Content-Type: application/json; charset=UTF-8\r\n";

   // Send request
   char result[];
   string resultHeaders;
   int res = WebRequest("POST", OpenAI_Endpoint, headers, 10000, postData, result, resultHeaders);

   if(res != 200) {
      string error_response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      string errMsg = StringFormat("API request failed: HTTP %d, Error: %d, Response: %s",
                                   res, GetLastError(), error_response);
      Print(errMsg);

      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] " + errMsg + "\n");
      }

      return errMsg;
   }

   // Parse response
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   if(VerboseLogging && g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] Response: " + response + "\n");
   }

   JsonValue jsonObject;
   int index = 0;
   char charArray[];
   int arrayLength = StringToCharArray(response, charArray, 0, WHOLE_ARRAY, CP_UTF8);

   if(!jsonObject.DeserializeFromArray(charArray, arrayLength, index)) {
      string errMsg = "Error: Failed to parse API response JSON: " + response;
      Print(errMsg);
      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] " + errMsg + "\n");
      }
      return errMsg;
   }

   // Check for API error
   JsonValue *error = jsonObject.FindChildByKey("error");
   if(error != NULL) {
      string errMsg = "API Error: " + error["message"].ToString();
      Print(errMsg);
      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] " + errMsg + "\n");
      }
      return errMsg;
   }

   // Extract content
   string content = jsonObject["choices"][0]["message"]["content"].ToString();

   if(StringLen(content) > 0) {
      StringReplace(content, "\\n", "\n");
      StringTrimLeft(content);
      StringTrimRight(content);

      // Track cost if enabled
      if(EnableCostTracking) {
         JsonValue *usage = jsonObject.FindChildByKey("usage");
         if(usage != NULL) {
            int prompt_tokens = (int)usage["prompt_tokens"].m_integerValue;
            int completion_tokens = (int)usage["completion_tokens"].m_integerValue;

            double cost = CalculateAPIRequestCost(prompt_tokens, completion_tokens);
            g_total_cost_usd += cost;

            if(VerboseLogging) {
               Print(StringFormat("Tokens used: %d prompt + %d completion = %d total. Cost: $%.6f",
                                  prompt_tokens, completion_tokens, prompt_tokens + completion_tokens, cost));
            }
         }
      }

      return content;
   }

   string errMsg = "Error: No content in API response: " + response;
   Print(errMsg);
   if(g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] " + errMsg + "\n");
   }
   return errMsg;
}

//+------------------------------------------------------------------+
//| Calculate API Request Cost                                       |
//+------------------------------------------------------------------+
double CalculateAPIRequestCost(int prompt_tokens, int completion_tokens) {
   // Find pricing for current model
   double input_cost = 0.0;
   double output_cost = 0.0;

   for(int i = 0; i < ArraySize(g_model_pricing); i++) {
      if(StringFind(OpenAI_Model, g_model_pricing[i].model_name) >= 0) {
         input_cost = g_model_pricing[i].input_cost_per_1k;
         output_cost = g_model_pricing[i].output_cost_per_1k;
         break;
      }
   }

   // If model not found in pricing table, use default (gpt-3.5-turbo rates)
   if(input_cost == 0.0) {
      input_cost = 0.0005;
      output_cost = 0.0015;
   }

   double cost = (prompt_tokens / 1000.0 * input_cost) + (completion_tokens / 1000.0 * output_cost);
   return cost;
}
//+------------------------------------------------------------------+
