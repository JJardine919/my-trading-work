//+------------------------------------------------------------------+
//|                                             ChatGPT AI EA v2.0   |
//|                           Copyright 2025, Allan Munene Mutiiria. |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link "https://t.me/Forex_Algo_Trader"
#property version "2.00"
#property description "AI-Powered Trading Assistant with ChatGPT Integration"
#property description "SETUP REQUIRED: Add https://api.openai.com to WebRequest allowed URLs"
#property description "Tools -> Options -> Expert Advisors -> Allow WebRequest for: https://api.openai.com"
#property description "Place API key in: MQL5/Files/chatgpt_api_key.txt"

//+------------------------------------------------------------------+
//| UI Layout Constants                                              |
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
input string OpenAI_API_Key_File = "chatgpt_api_key.txt";
input string OpenAI_Model = "gpt-4o-mini";
input string OpenAI_Endpoint = "http://127.0.0.1:5000/chat";

input group "=== Conversation Settings ==="
input int MaxHistoryMessages = 10;
input bool SendConversationContext = true;
input int MaxTokensPerResponse = 500;

input group "=== Cost & Performance ==="
input bool EnableCostTracking = true;
input int APIRetryAttempts = 3;
input int APIRetryDelayMs = 2000;

input group "=== Trading Parameters ==="
input bool EnableTradingSignals = false;
input double DefaultLotSize = 0.01;
input int DefaultStopLoss = 50;
input int DefaultTakeProfit = 100;
input int MagicNumber = 78901;

input group "=== Logging ==="
input string LogFileName = "ChatGPT_EA_Log.txt";
input bool VerboseLogging = false;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
string g_api_key = "";
string g_conversation_history = "";
int g_message_count = 0;
int g_log_file_handle = INVALID_HANDLE;
bool g_button_hover = false;
color g_button_original_bg = clrRoyalBlue;
color g_button_darker_bg;
double g_total_cost_usd = 0.0;
int g_total_requests = 0;
int g_failed_requests = 0;
datetime g_last_request_time = 0;
int g_retry_attempts = 3;
int g_max_history = 10;

//+------------------------------------------------------------------+
//| Cost tracking per model                                          |
//+------------------------------------------------------------------+
struct ModelPricing {
   string model_name;
   double input_cost_per_1k;
   double output_cost_per_1k;
};

ModelPricing g_model_pricing[] = {
   {"gpt-4o-mini", 0.00015, 0.0006},
   {"gpt-4o", 0.0025, 0.01},
   {"gpt-3.5-turbo", 0.0005, 0.0015}
};

//+------------------------------------------------------------------+
//| JSON value types                                                 |
//+------------------------------------------------------------------+
enum JsonValueType {JsonUndefined, JsonNull, JsonBoolean, JsonInteger, JsonDouble, JsonString, JsonArray, JsonObject};

//+------------------------------------------------------------------+
//| JSON Value Class                                                 |
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
   void operator=(string stringValue) {
      m_type = (StringLen(stringValue) > 0) ? JsonString : JsonNull;
      m_stringValue = stringValue;
      m_integerValue = StringToInteger(m_stringValue);
      m_doubleValue = StringToDouble(m_stringValue);
      m_booleanValue = StringLen(stringValue) > 0;
   }
   void operator=(const int integerValue) {
      m_type = JsonInteger;
      m_integerValue = integerValue;
      m_doubleValue = (double)m_integerValue;
      m_stringValue = IntegerToString(m_integerValue);
      m_booleanValue = integerValue != 0;
   }

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
            m_type = (StringLen(m_stringValue) > 0) ? JsonString : JsonNull;
            m_integerValue = StringToInteger(m_stringValue);
            m_doubleValue = StringToDouble(m_stringValue);
            m_booleanValue = StringLen(m_stringValue) > 0;
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
            jsonString += (StringLen(escaped) > 0) ? StringFormat("\"%s\"", escaped) : "\"\"";
         } break;
         case JsonArray: {
            jsonString += "[";
            for(int index = 0; index < numChildren; index++)
               m_children[index].SerializeToString(jsonString, false, index > 0);
            jsonString += "]";
         } break;
         case JsonObject: {
            jsonString += "{";
            for(int index = 0; index < numChildren; index++)
               m_children[index].SerializeToString(jsonString, true, index > 0);
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
            case '\t': case '\r': case '\n': case ' ':
               startPosition = currentIndex + 1;
               break;
            case '[': {
               startPosition = currentIndex + 1;
               if(m_type != JsonUndefined) return false;
               m_type = JsonArray;
               currentIndex++;
               JsonValue childValue(GetPointer(this), JsonUndefined);
               while(childValue.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) {
                  if(childValue.m_type != JsonUndefined) AddChild(childValue);
                  if(childValue.m_type == JsonInteger || childValue.m_type == JsonDouble || childValue.m_type == JsonArray)
                     currentIndex++;
                  childValue.Reset();
                  childValue.m_parent = GetPointer(this);
                  if(jsonCharacterArray[currentIndex] == ']') break;
                  currentIndex++;
                  if(currentIndex >= arrayLength) return false;
               }
               return (jsonCharacterArray[currentIndex] == ']' || jsonCharacterArray[currentIndex] == 0);
            }
            case ']':
               return (m_parent && m_parent.m_type == JsonArray);
            case ':': {
               if(m_temporaryKey == "") return false;
               JsonValue childValue(GetPointer(this), JsonUndefined);
               JsonValue *addedChild = AddChild(childValue);
               addedChild.m_key = m_temporaryKey;
               m_temporaryKey = "";
               currentIndex++;
               if(!addedChild.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex))
                  return false;
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
            case '}':
               return (m_type == JsonObject);
            case 't': case 'T': case 'f': case 'F': {
               if(m_type != JsonUndefined) return false;
               m_type = JsonBoolean;
               if(currentIndex + 4 <= arrayLength &&
                  StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "true", false) == 0) {
                  m_booleanValue = true;
                  currentIndex += 3;
                  return true;
               }
               if(currentIndex + 5 <= arrayLength &&
                  StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 5), "false", false) == 0) {
                  m_booleanValue = false;
                  currentIndex += 4;
                  return true;
               }
               return false;
            } break;
            case 'n': case 'N': {
               if(m_type != JsonUndefined) return false;
               m_type = JsonNull;
               if(currentIndex + 4 <= arrayLength &&
                  StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "null", false) == 0) {
                  currentIndex += 3;
                  return true;
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
                  if(StringFind(validNumericCharacters, GetSubstringFromArray(jsonCharacterArray, currentIndex, 1)) < 0)
                     break;
                  if(!isDouble)
                     isDouble = (jsonCharacterArray[currentIndex] == '.' ||
                                 jsonCharacterArray[currentIndex] == 'e' ||
                                 jsonCharacterArray[currentIndex] == 'E');
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
               case '/': case '\\': case '\"': case 'b': case 'f': case 'r': case 'n': case 't':
                  break;
               case 'u': {
                  currentIndex++;
                  for(int hexIndex = 0; hexIndex < 4 && currentIndex < arrayLength && jsonCharacterArray[currentIndex] != 0; hexIndex++, currentIndex++) {
                     if(!((jsonCharacterArray[currentIndex] >= '0' && jsonCharacterArray[currentIndex] <= '9') ||
                          (jsonCharacterArray[currentIndex] >= 'A' && jsonCharacterArray[currentIndex] <= 'F') ||
                          (jsonCharacterArray[currentIndex] >= 'a' && jsonCharacterArray[currentIndex] <= 'f')))
                        return false;
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
      if(ArrayResize(escapedCharacters, 2 * inputLength) != 2 * inputLength) return "";
      int escapedIndex = 0;
      for(int inputIndex = 0; inputIndex < inputLength; inputIndex++) {
         switch(inputCharacters[inputIndex]) {
            case '\\':
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = '\\';
               break;
            case '"':
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = '"';
               break;
            case '/':
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = '/';
               break;
            case 8:
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = 'b';
               break;
            case 12:
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = 'f';
               break;
            case '\n':
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = 'n';
               break;
            case '\r':
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = 'r';
               break;
            case '\t':
               escapedCharacters[escapedIndex++] = '\\';
               escapedCharacters[escapedIndex++] = 't';
               break;
            default:
               escapedCharacters[escapedIndex++] = inputCharacters[inputIndex];
               break;
         }
      }
      return ShortArrayToString(escapedCharacters, 0, escapedIndex);
   }

   string UnescapeString(string value) {
      ushort inputCharacters[], unescapedCharacters[];
      int inputLength = StringToShortArray(value, inputCharacters);
      if(ArrayResize(unescapedCharacters, inputLength) != inputLength) return "";
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
               case 'u': {
                  if(inputIndex + 5 < inputLength) {
                     string hex = "";
                     for(int h = 0; h < 4; h++) {
                        hex += ShortToString(inputCharacters[inputIndex + 2 + h]);
                     }
                     int unicode_val = 0;
                     for(int h = 0; h < StringLen(hex); h++) {
                        ushort ch = StringGetCharacter(hex, h);
                        unicode_val *= 16;
                        if(ch >= '0' && ch <= '9') unicode_val += ch - '0';
                        else if(ch >= 'A' && ch <= 'F') unicode_val += ch - 'A' + 10;
                        else if(ch >= 'a' && ch <= 'f') unicode_val += ch - 'a' + 10;
                     }
                     currentCharacter = (ushort)unicode_val;
                     inputIndex += 5;
                  }
                  break;
               }
            }
         }
         unescapedCharacters[outputIndex++] = currentCharacter;
         inputIndex++;
      }
      return ShortArrayToString(unescapedCharacters, 0, outputIndex);
   }
};

int JsonValue::encodingCodePage = CP_UTF8;

//+------------------------------------------------------------------+
//| Load API Key                                                     |
//+------------------------------------------------------------------+
string LoadAPIKey() {
   ResetLastError();
   int handle = FileOpen(OpenAI_API_Key_File, FILE_READ | FILE_TXT | FILE_COMMON);
   if(handle == INVALID_HANDLE) {
      handle = FileOpen(OpenAI_API_Key_File, FILE_READ | FILE_TXT);
   }
   if(handle == INVALID_HANDLE) {
      string error_msg = StringFormat(
         "CRITICAL ERROR: API key file not found!\n" +
         "Expected: %s\n" +
         "Location: %%APPDATA%%\\MetaQuotes\\Terminal\\Common\\Files\\%s\n" +
         "Error: %d",
         OpenAI_API_Key_File, OpenAI_API_Key_File, GetLastError()
      );
      Alert(error_msg);
      Print(error_msg);
      return "";
   }
   string key = FileReadString(handle);
   FileClose(handle);
   StringTrimLeft(key);
   StringTrimRight(key);
   if(StringLen(key) < 20 || StringFind(key, "sk-") != 0) {
      Alert("ERROR: Invalid API key format. Must start with 'sk-' and be 20+ characters.");
      return "";
   }
   Print("API key loaded successfully");
   return key;
}

//+------------------------------------------------------------------+
//| Validate WebRequest                                              |
//+------------------------------------------------------------------+
bool ValidateWebRequestPermission() {
   char post_data[], result[];
   string result_headers;
   int response_code = WebRequest("GET", "https://api.openai.com/v1/models",
                                   "Authorization: Bearer test\r\n", 500,
                                   post_data, result, result_headers);
   if(response_code == -1) {
      int error = GetLastError();
      if(error == 4014 || error == 5200) {
         Alert("SETUP REQUIRED: Add https://api.openai.com to WebRequest allowed URLs\n" +
               "Tools -> Options -> Expert Advisors -> Allow WebRequest");
         return false;
      }
   }
   Print("WebRequest permission validated");
   return true;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   Print("ChatGPT AI EA v2.0 Initializing...");

   g_api_key = LoadAPIKey();
   if(g_api_key == "") return INIT_FAILED;

   if(!ValidateWebRequestPermission()) return INIT_FAILED;

   g_retry_attempts = APIRetryAttempts;
   if(g_retry_attempts < 1 || g_retry_attempts > 5) {
      Print("WARNING: APIRetryAttempts out of range, using 3");
      g_retry_attempts = 3;
   }

   g_max_history = MaxHistoryMessages;
   if(g_max_history < 1) {
      Print("WARNING: MaxHistoryMessages must be >= 1, using 1");
      g_max_history = 1;
   }

   g_log_file_handle = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_TXT);
   if(g_log_file_handle != INVALID_HANDLE) {
      FileSeek(g_log_file_handle, 0, SEEK_END);
      FileWriteString(g_log_file_handle, "\n=== EA Initialized: " + TimeToString(TimeCurrent()) + " ===\n");
   }

   g_button_darker_bg = DarkenColor(g_button_original_bg);
   CreateDashboard();
   UpdateResponseDisplay();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   Print("EA initialized successfully!");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "ChatGPT_");
   if(g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "=== EA Shutdown: " + TimeToString(TimeCurrent()) + " ===\n");
      FileWriteString(g_log_file_handle, "Requests: " + IntegerToString(g_total_requests) +
                      " | Failed: " + IntegerToString(g_failed_requests) +
                      " | Cost: $" + DoubleToString(g_total_cost_usd, 6) + "\n");
      FileClose(g_log_file_handle);
   }
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick() {
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == "ChatGPT_SubmitButton") HandleSubmitClick();
      else if(sparam == "ChatGPT_ClearButton") HandleClearClick();
   } else if(id == CHARTEVENT_MOUSE_MOVE) {
      HandleMouseMove((int)lparam, (int)dparam);
   }
}

//+------------------------------------------------------------------+
//| Handle Submit                                                    |
//+------------------------------------------------------------------+
void HandleSubmitClick() {
   string prompt = ObjectGetString(0, "ChatGPT_InputEdit", OBJPROP_TEXT);
   StringTrimLeft(prompt);
   StringTrimRight(prompt);

   if(StringLen(prompt) == 0) return;
   if(StringLen(prompt) > 4000) {
      Alert("Message too long! Max 4000 characters.");
      return;
   }

   if(TimeCurrent() - g_last_request_time < 2) {
      Alert("Please wait 2 seconds between requests.");
      return;
   }
   g_last_request_time = TimeCurrent();

   string response = GetChatGPTResponse(prompt);
   UpdateConversationHistory(prompt, response);
   ObjectSetString(0, "ChatGPT_InputEdit", OBJPROP_TEXT, "");
   UpdateResponseDisplay();

   if(EnableTradingSignals) ParseTradingSignals(response);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Handle Clear                                                     |
//+------------------------------------------------------------------+
void HandleClearClick() {
   if(MessageBox("Clear conversation history?", "Confirm", MB_YESNO | MB_ICONQUESTION) == IDYES) {
      g_conversation_history = "";
      g_message_count = 0;
      UpdateResponseDisplay();
      Print("History cleared");
   }
}

//+------------------------------------------------------------------+
//| Handle Mouse Move                                                |
//+------------------------------------------------------------------+
void HandleMouseMove(int mouseX, int mouseY) {
   bool isOver = (mouseX >= UI_BUTTON_X && mouseX <= UI_BUTTON_X + UI_BUTTON_WIDTH &&
                  mouseY >= UI_MARGIN_TOP && mouseY <= UI_MARGIN_TOP + UI_BUTTON_HEIGHT);
   if(isOver && !g_button_hover) {
      ObjectSetInteger(0, "ChatGPT_SubmitButton", OBJPROP_BGCOLOR, g_button_darker_bg);
      g_button_hover = true;
      ChartRedraw();
   } else if(!isOver && g_button_hover) {
      ObjectSetInteger(0, "ChatGPT_SubmitButton", OBJPROP_BGCOLOR, g_button_original_bg);
      g_button_hover = false;
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Update History                                                   |
//+------------------------------------------------------------------+
void UpdateConversationHistory(string prompt, string response) {
   string new_entry = "You: " + prompt + "\nAI: " + response + "\n\n";
   g_conversation_history = new_entry + g_conversation_history;
   g_message_count++;

   if(g_message_count > g_max_history * 2) {
      int keep_count = g_max_history * 2;
      int pos = 0, found_count = 0;
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

   if(StringLen(g_conversation_history) > 10000) {
      g_conversation_history = StringSubstr(g_conversation_history, 0, 10000);
   }
}

//+------------------------------------------------------------------+
//| Parse Trading Signals                                            |
//+------------------------------------------------------------------+
void ParseTradingSignals(string response) {
   string upper = response;
   StringToUpper(upper);
   bool has_buy = (StringFind(upper, "BUY") >= 0 || StringFind(upper, "LONG") >= 0);
   bool has_sell = (StringFind(upper, "SELL") >= 0 || StringFind(upper, "SHORT") >= 0);

   if(has_buy && !has_sell) {
      Print(">>> TRADING SIGNAL: BUY");
      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] BUY signal detected\n");
      }
   } else if(has_sell && !has_buy) {
      Print(">>> TRADING SIGNAL: SELL");
      if(g_log_file_handle != INVALID_HANDLE) {
         FileWriteString(g_log_file_handle, "[" + TimeToString(TimeCurrent()) + "] SELL signal detected\n");
      }
   }
}

//+------------------------------------------------------------------+
//| Darken Color                                                     |
//+------------------------------------------------------------------+
color DarkenColor(color colorValue, double factor = 0.8) {
   int red = (int)((colorValue & 0xFF) * factor);
   int green = (int)(((colorValue >> 8) & 0xFF) * factor);
   int blue = (int)(((colorValue >> 16) & 0xFF) * factor);
   return (color)(red | (green << 8) | (blue << 16));
}

//+------------------------------------------------------------------+
//| Create Rectangle Label                                           |
//+------------------------------------------------------------------+
bool createRecLabel(string objName, int xDistance, int yDistance, int xSize, int ySize,
                    color bgColor, int borderWidth, color borderColor = clrNONE,
                    ENUM_BORDER_TYPE borderType = BORDER_FLAT,
                    ENUM_LINE_STYLE borderStyle = STYLE_SOLID,
                    ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {
   ResetLastError();
   if(!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed! Error = ", GetLastError());
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
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   return true;
}

//+------------------------------------------------------------------+
//| Create Button                                                    |
//+------------------------------------------------------------------+
bool createButton(string objName, int xDistance, int yDistance, int xSize, int ySize,
                  string text = "", color textColor = clrBlack, int fontSize = 12,
                  color bgColor = clrNONE, color borderColor = clrNONE,
                  string font = "Arial", ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {
   ResetLastError();
   if(!ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed! Error = ", GetLastError());
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
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   return true;
}

//+------------------------------------------------------------------+
//| Create Edit                                                      |
//+------------------------------------------------------------------+
bool createEdit(string objName, int xDistance, int yDistance, int xSize, int ySize,
                string text = "", color textColor = clrBlack, int fontSize = 12,
                color bgColor = clrNONE, color borderColor = clrNONE,
                string font = "Arial", ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                int align = ALIGN_LEFT, bool readOnly = false) {
   ResetLastError();
   if(!ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed! Error = ", GetLastError());
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
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   return true;
}

//+------------------------------------------------------------------+
//| Create Label                                                     |
//+------------------------------------------------------------------+
bool createLabel(string objName, int xDistance, int yDistance, string text,
                 color textColor = clrBlack, int fontSize = 12, string font = "Arial",
                 ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                 ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER) {
   ResetLastError();
   if(!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
      Print(__FUNCTION__, ": failed! Error = ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   return true;
}

//+------------------------------------------------------------------+
//| Wrap Text                                                        |
//+------------------------------------------------------------------+
void WrapText(const string inputText, const string font, const int fontSize,
              const int maxWidth, string &wrappedLines[], int offset = 0) {
   ArrayResize(wrappedLines, 0);
   TextSetFont(font, -fontSize * 10, 0);
   string paragraphs[];
   int numParagraphs = StringSplit(inputText, '\n', paragraphs);

   for(int p = 0; p < numParagraphs; p++) {
      string para = paragraphs[p];
      if(StringLen(para) == 0) continue;

      string words[];
      int numWords = StringSplit(para, ' ', words);
      string currentLine = "";

      for(int w = 0; w < numWords; w++) {
         string testLine = currentLine + (StringLen(currentLine) > 0 ? " " : "") + words[w];
         uint wid, hei;
         TextGetSize(testLine, wid, hei);
         int textWidth = (int)wid;

         if(textWidth + offset <= maxWidth && StringLen(testLine) <= UI_MAX_CHARS_PER_LINE) {
            currentLine = testLine;
         } else {
            if(StringLen(currentLine) > 0) {
               int size = ArraySize(wrappedLines);
               ArrayResize(wrappedLines, size + 1);
               wrappedLines[size] = currentLine;
            }
            currentLine = words[w];
         }
      }

      if(StringLen(currentLine) > 0) {
         int size = ArraySize(wrappedLines);
         ArrayResize(wrappedLines, size + 1);
         wrappedLines[size] = currentLine;
      }
   }
}

//+------------------------------------------------------------------+
//| Create Dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard() {
   createEdit("ChatGPT_InputEdit", UI_MARGIN_LEFT, UI_MARGIN_TOP, UI_INPUT_WIDTH,
              UI_INPUT_HEIGHT, "", clrBlack, 12, clrWhiteSmoke, clrDarkGray);
   createButton("ChatGPT_SubmitButton", UI_BUTTON_X, UI_MARGIN_TOP, UI_BUTTON_WIDTH,
                UI_BUTTON_HEIGHT, "Send", clrWhite, 12, g_button_original_bg, clrDarkBlue);
   createButton("ChatGPT_ClearButton", UI_CLEAR_BUTTON_X, UI_MARGIN_TOP, 80,
                UI_BUTTON_HEIGHT, "Clear", clrWhite, 10, clrCrimson, clrDarkRed);
   createRecLabel("ChatGPT_ResponseBg", UI_MARGIN_LEFT, UI_RESPONSE_BG_Y,
                  UI_RESPONSE_BG_WIDTH, UI_RESPONSE_BG_HEIGHT, clrWhite, 2,
                  clrLightGray, BORDER_FLAT, STYLE_SOLID);

   if(EnableCostTracking) {
      createLabel("ChatGPT_StatsLabel", UI_MARGIN_LEFT,
                  UI_RESPONSE_BG_Y + UI_RESPONSE_BG_HEIGHT + 10,
                  "Requests: 0 | Cost: $0.00", clrDimGray, 8);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Display                                                   |
//+------------------------------------------------------------------+
void UpdateResponseDisplay() {
   int total = ObjectsTotal(0, 0, -1);
   for(int j = total - 1; j >= 0; j--) {
      string name = ObjectName(0, j, 0, -1);
      if(StringFind(name, "ChatGPT_ResponseLine_") == 0 ||
         StringFind(name, "ChatGPT_MessageBg_") == 0) {
         ObjectDelete(0, name);
      }
   }

   if(EnableCostTracking) {
      string stats = StringFormat("Requests: %d | Failed: %d | Cost: $%.6f",
                                  g_total_requests, g_failed_requests, g_total_cost_usd);
      ObjectSetString(0, "ChatGPT_StatsLabel", OBJPROP_TEXT, stats);
   }

   if(g_conversation_history == "") {
      createLabel("ChatGPT_ResponseLine_0", UI_MARGIN_LEFT + UI_TEXT_PADDING,
                  UI_RESPONSE_BG_Y + UI_TEXT_PADDING,
                  "Type your message above and click Send to chat with AI.",
                  clrGray, 10);
      ChartRedraw();
      return;
   }

   string wrappedLines[];
   WrapText(g_conversation_history, "Arial", 10,
            UI_RESPONSE_BG_WIDTH - 2 * UI_TEXT_PADDING, wrappedLines);

   TextSetFont("Arial", -100, 0);
   uint wid, hei;
   TextGetSize("A", wid, hei);
   int lineHeight = (int)hei;
   int maxVisibleLines = (UI_RESPONSE_BG_HEIGHT - 2 * UI_TEXT_PADDING) / lineHeight;
   int numLines = ArraySize(wrappedLines);
   int startLine = MathMax(0, numLines - maxVisibleLines);
   int textY = UI_RESPONSE_BG_Y + UI_TEXT_PADDING;

   for(int i = startLine; i < numLines; i++) {
      string line = wrappedLines[i];
      color currentColor = clrDarkSlateGray;

      if(StringFind(line, "You: ") == 0) currentColor = clrDarkSlateGray;
      else if(StringFind(line, "AI: ") == 0) currentColor = clrRoyalBlue;

      createLabel("ChatGPT_ResponseLine_" + IntegerToString(i - startLine),
                  UI_MARGIN_LEFT + UI_TEXT_PADDING, textY, line, currentColor, 10);
      textY += lineHeight;
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| JSON Escape                                                      |
//+------------------------------------------------------------------+
string JsonEscape(string value) {
   StringReplace(value, "\\", "\\\\");
   StringReplace(value, "\"", "\\\"");
   StringReplace(value, "\n", "\\n");
   StringReplace(value, "\r", "\\r");
   StringReplace(value, "\t", "\\t");
   return value;
}

//+------------------------------------------------------------------+
//| Get ChatGPT Response                                             |
//+------------------------------------------------------------------+
string GetChatGPTResponse(string prompt) {
   string response = "";
   for(int attempt = 1; attempt <= g_retry_attempts; attempt++) {
      if(attempt > 1) {
         Print("Retry ", attempt, "/", g_retry_attempts);
         Sleep(APIRetryDelayMs);
      }

      response = SendChatGPTRequest(prompt);

      bool isError = (StringFind(response, "Error:") == 0 ||
                      StringFind(response, "API Error:") == 0 ||
                      StringFind(response, "API request failed") == 0);

      if(!isError) {
         g_total_requests++;
         return response;
      }
   }

   g_failed_requests++;
   g_total_requests++;
   Print("All retries failed");
   return response;
}

//+------------------------------------------------------------------+
//| Send Request                                                     |
//+------------------------------------------------------------------+
string SendChatGPTRequest(string prompt) {
   string messages_json = "[";

   if(SendConversationContext && StringLen(g_conversation_history) > 0) {
      string lines[];
      StringSplit(g_conversation_history, '\n', lines);

      string current_role = "";
      string current_content = "";
      int message_count = 0;
      int max_context = MathMin(g_max_history * 2, 10);

      for(int i = 0; i < ArraySize(lines) && message_count < max_context; i++) {
         string line = lines[i];
         StringTrimLeft(line);
         StringTrimRight(line);
         if(StringLen(line) == 0) continue;

         if(StringFind(line, "You: ") == 0) {
            if(current_role != "" && current_content != "") {
               if(message_count > 0) messages_json += ",";
               messages_json += "{\"role\":\"" + current_role + "\",\"content\":\"" +
                                JsonEscape(current_content) + "\"}";
               message_count++;
            }
            current_role = "user";
            current_content = StringSubstr(line, 5);
         } else if(StringFind(line, "AI: ") == 0) {
            if(current_role != "" && current_content != "") {
               if(message_count > 0) messages_json += ",";
               messages_json += "{\"role\":\"" + current_role + "\",\"content\":\"" +
                                JsonEscape(current_content) + "\"}";
               message_count++;
            }
            current_role = "assistant";
            current_content = StringSubstr(line, 4);
         } else if(current_role != "" && line != "") {
            current_content += "\n" + line;
         }
      }

      if(current_role != "" && current_content != "") {
         if(message_count > 0) messages_json += ",";
         messages_json += "{\"role\":\"" + current_role + "\",\"content\":\"" +
                          JsonEscape(current_content) + "\"}";
      }

      if(message_count > 0) messages_json += ",";
   }

   messages_json += "{\"role\":\"user\",\"content\":\"" + JsonEscape(prompt) + "\"}]";

   string requestData = "{\"model\":\"" + OpenAI_Model +
                        "\",\"messages\":" + messages_json +
                        ",\"max_tokens\":" + IntegerToString(MaxTokensPerResponse) + "}";

   if(VerboseLogging && g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "Request: " + requestData + "\n");
   }

   char postData[];
   int dataLen = StringToCharArray(requestData, postData, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(postData, dataLen - 1);

   string headers = "Authorization: Bearer " + g_api_key + "\r\n" +
                    "Content-Type: application/json; charset=UTF-8\r\n";

   char result[];
   string resultHeaders;
   int res = WebRequest("POST", OpenAI_Endpoint, headers, 10000, postData, result, resultHeaders);

   if(res != 200) {
      string error_response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      string errMsg = StringFormat("API request failed: HTTP %d, Response: %s", res, error_response);
      Print(errMsg);
      return errMsg;
   }

   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   if(VerboseLogging && g_log_file_handle != INVALID_HANDLE) {
      FileWriteString(g_log_file_handle, "Response: " + response + "\n");
   }

   JsonValue jsonObject;
   int index = 0;
   char charArray[];
   int arrayLength = StringToCharArray(response, charArray, 0, WHOLE_ARRAY, CP_UTF8);

   if(!jsonObject.DeserializeFromArray(charArray, arrayLength, index)) {
      string errMsg = "Failed to parse JSON: " + response;
      Print(errMsg);
      return errMsg;
   }

   JsonValue *error = jsonObject.FindChildByKey("error");
   if(error != NULL) {
      string errMsg = "API Error: " + error["message"].ToString();
      Print(errMsg);
      return errMsg;
   }

   string content = jsonObject["choices"][0]["message"]["content"].ToString();

   if(StringLen(content) > 0) {
      StringReplace(content, "\\n", "\n");
      StringTrimLeft(content);
      StringTrimRight(content);

      if(EnableCostTracking) {
         JsonValue *usage = jsonObject.FindChildByKey("usage");
         if(usage != NULL) {
            int prompt_tokens = (int)usage["prompt_tokens"].m_integerValue;
            int completion_tokens = (int)usage["completion_tokens"].m_integerValue;
            double cost = CalculateAPIRequestCost(prompt_tokens, completion_tokens);
            g_total_cost_usd += cost;
         }
      }

      return content;
   }

   string errMsg = "No content in response";
   Print(errMsg);
   return errMsg;
}

//+------------------------------------------------------------------+
//| Calculate Cost                                                   |
//+------------------------------------------------------------------+
double CalculateAPIRequestCost(int prompt_tokens, int completion_tokens) {
   double input_cost = 0.0;
   double output_cost = 0.0;

   for(int i = 0; i < ArraySize(g_model_pricing); i++) {
      if(OpenAI_Model == g_model_pricing[i].model_name ||
         (StringFind(OpenAI_Model, g_model_pricing[i].model_name) >= 0 &&
          i == 0)) {
         input_cost = g_model_pricing[i].input_cost_per_1k;
         output_cost = g_model_pricing[i].output_cost_per_1k;
         break;
      }
   }

   if(input_cost == 0.0) {
      input_cost = 0.0005;
      output_cost = 0.0015;
   }

   return (prompt_tokens / 1000.0 * input_cost) + (completion_tokens / 1000.0 * output_cost);
}
//+------------------------------------------------------------------+
