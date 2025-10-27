//+------------------------------------------------------------------+
//|                                             a. ChatGPT AI EA.mq5 |
//|                           Copyright 2025, Allan Munene Mutiiria. |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link "https://t.me/Forex_Algo_Trader"
#property version "1.00"
#property strict

//--- Input parameters
input string OpenAI_Model = "gpt-3.5-turbo"; // OpenAI Model
input string OpenAI_Endpoint = "https://api.openai.com/v1/chat/completions"; // OpenAI API Endpoint
input int MaxResponseLength = 500; // Max length of ChatGPT response to display
input string LogFileName = "ChatGPT_EA_Log.txt"; // Log file name
//--- Hardcoded API key (confirmed valid via curl test)
string OpenAI_API_Key = "sk-proj-sgUhhd9hYGDgt6Hhjd ... <YOUR API KEY HERE> ... hyU7jhd";
//--- JSON handling class
#define DEBUG_PRINT false
//+------------------------------------------------------------------+
//| Enumeration of JSON value types                                  |
//+------------------------------------------------------------------+
enum JsonValueType {JsonUndefined, JsonNull, JsonBoolean, JsonInteger, JsonDouble, JsonString, JsonArray, JsonObject};
//+------------------------------------------------------------------+
//| Class representing a JSON value                                  |
//+------------------------------------------------------------------+
class JsonValue {
public:
   JsonValue m_children[];                                   //--- Array to hold child JSON values
   string m_key;                                             //--- Key for this JSON value
   string m_temporaryKey;                                    //--- Temporary key used during parsing
   JsonValue *m_parent;                                      //--- Pointer to parent JSON value
   JsonValueType m_type;                                     //--- Type of this JSON value
   bool m_booleanValue;                                      //--- Boolean value storage
   long m_integerValue;                                      //--- Integer value storage
   double m_doubleValue;                                     //--- Double value storage
   string m_stringValue;                                     //--- String value storage
   static int encodingCodePage;                              //--- Static code page for encoding
   JsonValue() { Reset(); }                                  //--- Default constructor calls reset
   JsonValue(JsonValue *parent, JsonValueType type) { Reset(); m_type = type; m_parent = parent; } //--- Constructor with parent and type
   JsonValue(JsonValueType type, string value) { Reset(); SetFromString(type, value); } //--- Constructor with type and string value
   JsonValue(const int integerValue) { Reset(); m_type = JsonInteger; m_integerValue = integerValue; m_doubleValue = (double)m_integerValue; m_stringValue = IntegerToString(m_integerValue); m_booleanValue = m_integerValue != 0; } //--- Constructor from integer
   JsonValue(const JsonValue &other) { Reset(); CopyFrom(other); } //--- Copy constructor
   ~JsonValue() { Reset(); }                                 //--- Destructor calls reset
   void Reset() {                                            //--- Reset all members to default
      m_parent = NULL;                                       //--- Set parent to NULL
      m_key = "";                                            //--- Clear key
      m_temporaryKey = "";                                   //--- Clear temporary key
      m_type = JsonUndefined;                                //--- Set type to undefined
      m_booleanValue = false;                                //--- Set boolean to false
      m_integerValue = 0;                                    //--- Set integer to zero
      m_doubleValue = 0;                                     //--- Set double to zero
      m_stringValue = "";                                    //--- Clear string
      ArrayResize(m_children, 0);                            //--- Resize children array to zero
   }
   bool CopyFrom(const JsonValue &source) {                  //--- Copy from another JsonValue
      m_key = source.m_key;                                  //--- Copy key
      CopyDataFrom(source);                                  //--- Copy data
      return true;                                           //--- Return success
   }
   void CopyDataFrom(const JsonValue &source) {              //--- Copy core data from source
      m_type = source.m_type;                                //--- Copy type
      m_booleanValue = source.m_booleanValue;                //--- Copy boolean
      m_integerValue = source.m_integerValue;                //--- Copy integer
      m_doubleValue = source.m_doubleValue;                  //--- Copy double
      m_stringValue = source.m_stringValue;                  //--- Copy string
      CopyChildrenFrom(source);                              //--- Copy children
   }
   void CopyChildrenFrom(const JsonValue &source) {          //--- Copy children array from source
      int numChildren = ArrayResize(m_children, ArraySize(source.m_children)); //--- Resize to match source
      for(int index = 0; index < numChildren; index++) {     //--- Loop through children
         m_children[index] = source.m_children[index];       //--- Copy child
         m_children[index].m_parent = GetPointer(this);      //--- Set parent to this
      }
   }
   JsonValue *FindChildByKey(string key) {                   //--- Find child by key
      for(int index = ArraySize(m_children) - 1; index >= 0; --index) { //--- Search backwards
         if(m_children[index].m_key == key) return GetPointer(m_children[index]); //--- Return if found
      }
      return NULL;                                           //--- Return NULL if not found
   }
   JsonValue *operator[](string key) {                       //--- Access or create child by key
      if(m_type == JsonUndefined) m_type = JsonObject;       //--- Set to object if undefined
      JsonValue *value = FindChildByKey(key);                //--- Find existing
      if(value) return value;                                //--- Return if exists
      JsonValue newValue(GetPointer(this), JsonUndefined);   //--- Create new
      newValue.m_key = key;                                  //--- Set key
      value = AddChild(newValue);                            //--- Add and return
      return value;                                          //--- Return new value
   }
   JsonValue *operator[](int index) {                        //--- Access or expand array by index
      if(m_type == JsonUndefined) m_type = JsonArray;        //--- Set to array if undefined
      while(index >= ArraySize(m_children)) {                //--- Expand if needed
         JsonValue newValue(GetPointer(this), JsonUndefined); //--- Create new element
         if(CheckPointer(AddChild(newValue)) == POINTER_INVALID) return NULL; //--- Add and check
      }
      return GetPointer(m_children[index]);                  //--- Return element
   }
   void operator=(const JsonValue &value) { CopyFrom(value); } //--- Assignment from JsonValue
   void operator=(string stringValue) { m_type = (stringValue != NULL) ? JsonString : JsonNull; m_stringValue = stringValue; m_integerValue = StringToInteger(m_stringValue); m_doubleValue = StringToDouble(m_stringValue); m_booleanValue = stringValue != NULL; } //--- Assignment from string
   void operator=(const int integerValue) { m_type = JsonInteger; m_integerValue = integerValue; m_doubleValue = (double)m_integerValue; m_stringValue = IntegerToString(m_integerValue); m_booleanValue = integerValue != 0; } //--- Assignment from int
   bool ToBoolean() const { return m_booleanValue; }         //--- Convert to boolean
   string ToString() { return m_stringValue; }               //--- Convert to string
   void SetFromString(JsonValueType type, string stringValue) { //--- Set value from string based on type
      m_type = type;                                         //--- Set type
      switch(m_type) {                                       //--- Handle by type
         case JsonBoolean:                                   //--- Boolean case
            m_booleanValue = (StringToInteger(stringValue) != 0); //--- Convert to bool
            m_integerValue = (long)m_booleanValue;              //--- Set integer
            m_doubleValue = (double)m_booleanValue;             //--- Set double
            m_stringValue = stringValue;                        //--- Set string
            break;                                              //--- Exit case
         case JsonString:                                    //--- String case
            m_stringValue = UnescapeString(stringValue);        //--- Unescape
            m_type = (m_stringValue != NULL) ? JsonString : JsonNull; //--- Adjust type
            m_integerValue = StringToInteger(m_stringValue);    //--- Set integer
            m_doubleValue = StringToDouble(m_stringValue);      //--- Set double
            m_booleanValue = m_stringValue != NULL;             //--- Set boolean
            break;                                              //--- Exit case
      }
   }
   string GetSubstringFromArray(char &jsonCharacterArray[], int startPosition, int substringLength) { //--- Get substring from char array
      if(substringLength <= 0) return "";                    //--- Return empty if invalid length
      char temporaryArray[];                                 //--- Temp array
      ArrayCopy(temporaryArray, jsonCharacterArray, 0, startPosition, substringLength); //--- Copy data
      return CharArrayToString(temporaryArray, 0, WHOLE_ARRAY, encodingCodePage); //--- Convert to string
   }
   JsonValue *AddChild(const JsonValue &item) {              //--- Add child item
      if(m_type == JsonUndefined) m_type = JsonArray;        //--- Set to array if undefined
      return AddChildInternal(item);                         //--- Call internal add
   }
   JsonValue *AddChild(string stringValue) { JsonValue item(JsonString, stringValue); return AddChild(item); } //--- Add string child
   JsonValue *AddChild(const int integerValue) { JsonValue item(integerValue); return AddChild(item); } //--- Add int child
   JsonValue *AddChildInternal(const JsonValue &item) {      //--- Internal add child
      int currentSize = ArraySize(m_children);               //--- Get current size
      ArrayResize(m_children, currentSize + 1);              //--- Resize
      m_children[currentSize] = item;                        //--- Assign item
      m_children[currentSize].m_parent = GetPointer(this);   //--- Set parent
      return GetPointer(m_children[currentSize]);            //--- Return added
   }
   string SerializeToString() {                              //--- Serialize to string
      string jsonString;                                     //--- Declare string
      SerializeToString(jsonString);                         //--- Call serialize
      return jsonString;                                     //--- Return
   }
   void SerializeToString(string &jsonString, bool includeKey = false, bool includeComma = false) { //--- Serialize with options
      if(m_type == JsonUndefined) return;                    //--- Skip if undefined
      if(includeComma) jsonString += ",";                    //--- Add comma if needed
      if(includeKey) jsonString += StringFormat("\"%s\":", m_key); //--- Add key if needed
      int numChildren = ArraySize(m_children);               //--- Get children count
      switch(m_type) {                                       //--- Handle by type
         case JsonNull: jsonString += "null"; break;         //--- Null case
         case JsonBoolean: jsonString += (m_booleanValue ? "true" : "false"); break; //--- Boolean case
         case JsonInteger: jsonString += IntegerToString(m_integerValue); break; //--- Integer case
         case JsonDouble: jsonString += DoubleToString(m_doubleValue); break; //--- Double case
         case JsonString: {                                  //--- String case
            string escaped = EscapeString(m_stringValue);    //--- Escape
            jsonString += (StringLen(escaped) > 0) ? StringFormat("\"%s\"", escaped) : "null"; //--- Append
         } break;                                            //--- Exit case
         case JsonArray: {                                   //--- Array case
            jsonString += "[";                               //--- Start array
            for(int index = 0; index < numChildren; index++) m_children[index].SerializeToString(jsonString, false, index > 0); //--- Serialize children
            jsonString += "]";                               //--- End array
         } break;                                            //--- Exit case
         case JsonObject: {                                  //--- Object case
            jsonString += "{";                               //--- Start object
            for(int index = 0; index < numChildren; index++) m_children[index].SerializeToString(jsonString, true, index > 0); //--- Serialize children
            jsonString += "}";                               //--- End object
         } break;                                            //--- Exit case
      }
   }
   bool DeserializeFromArray(char &jsonCharacterArray[], int arrayLength, int &currentIndex) { //--- Deserialize from array
      string validNumericCharacters = "0123456789+-.eE";     //--- Valid number chars
      int startPosition = currentIndex;                      //--- Start position
      for(; currentIndex < arrayLength; currentIndex++) {    //--- Loop array
         char currentCharacter = jsonCharacterArray[currentIndex]; //--- Current char
         if(currentCharacter == 0) break;                    //--- Break on null
         switch(currentCharacter) {                          //--- Switch on char
            case '\t': case '\r': case '\n': case ' ': startPosition = currentIndex + 1; break; //--- Skip whitespace
            case '[': {                                      //--- Array start
               startPosition = currentIndex + 1;             //--- Update start
               if(m_type != JsonUndefined) return false;     //--- Type check
               m_type = JsonArray;                           //--- Set array
               currentIndex++;                               //--- Increment
               JsonValue childValue(GetPointer(this), JsonUndefined); //--- Child value
               while(childValue.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) { //--- Loop children
                  if(childValue.m_type != JsonUndefined) AddChild(childValue); //--- Add if defined
                  if(childValue.m_type == JsonInteger || childValue.m_type == JsonDouble || childValue.m_type == JsonArray) currentIndex++; //--- Adjust index
                  childValue.Reset();                        //--- Reset child
                  childValue.m_parent = GetPointer(this);    //--- Set parent
                  if(jsonCharacterArray[currentIndex] == ']') break; //--- End array
                  currentIndex++;                            //--- Increment
                  if(currentIndex >= arrayLength) return false; //--- Bounds check
               }
               return (jsonCharacterArray[currentIndex] == ']' || jsonCharacterArray[currentIndex] == 0); //--- Valid end
            }                                                //--- End array case
            case ']': return (m_parent && m_parent.m_type == JsonArray); //--- Array end
            case ':': {                                      //--- Key separator
               if(m_temporaryKey == "") return false;        //--- Key check
               JsonValue childValue(GetPointer(this), JsonUndefined); //--- New child
               JsonValue *addedChild = AddChild(childValue); //--- Add
               addedChild.m_key = m_temporaryKey;            //--- Set key
               m_temporaryKey = "";                          //--- Clear temp
               currentIndex++;                               //--- Increment
               if(!addedChild.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Recurse
            } break;                                         //--- End key case
            case ',': {                                      //--- Value separator
               startPosition = currentIndex + 1;             //--- Update start
               if(!m_parent && m_type != JsonObject) return false; //--- Check context
               if(m_parent && m_parent.m_type != JsonArray && m_parent.m_type != JsonObject) return false; //--- Parent type
               if(m_parent && m_parent.m_type == JsonArray && m_type == JsonUndefined) return true; //--- Undefined in array
            } break;                                         //--- End separator
            case '{': {                                      //--- Object start
               startPosition = currentIndex + 1;             //--- Update start
               if(m_type != JsonUndefined) return false;     //--- Type check
               m_type = JsonObject;                          //--- Set object
               currentIndex++;                               //--- Increment
               if(!DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Recurse
               return (jsonCharacterArray[currentIndex] == '}' || jsonCharacterArray[currentIndex] == 0); //--- Valid end
            } break;                                         //--- End object case
            case '}': return (m_type == JsonObject);         //--- Object end
            case 't': case 'T': case 'f': case 'F': {        //--- Boolean start
               if(m_type != JsonUndefined) return false;     //--- Type check
               m_type = JsonBoolean;                         //--- Set boolean
               if(currentIndex + 3 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "true", false) == 0) { //--- True check
                  m_booleanValue = true; currentIndex += 3; return true; //--- Set true
               }
               if(currentIndex + 4 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 5), "false", false) == 0) { //--- False check
                  m_booleanValue = false; currentIndex += 4; return true; //--- Set false
               }
               return false;                                 //--- Invalid boolean
            } break;                                         //--- End boolean
            case 'n': case 'N': {                            //--- Null start
               if(m_type != JsonUndefined) return false;     //--- Type check
               m_type = JsonNull;                            //--- Set null
               if(currentIndex + 3 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "null", false) == 0) { //--- Null check
                  currentIndex += 3; return true;            //--- Valid null
               }
               return false;                                 //--- Invalid null
            } break;                                         //--- End null
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
            case '-': case '+': case '.': {                  //--- Number start
               if(m_type != JsonUndefined) return false;     //--- Type check
               bool isDouble = false;                        //--- Double flag
               int startOfNumber = currentIndex;             //--- Number start
               while(jsonCharacterArray[currentIndex] != 0 && currentIndex < arrayLength) { //--- Parse number
                  currentIndex++;                            //--- Increment
                  if(StringFind(validNumericCharacters, GetSubstringFromArray(jsonCharacterArray, currentIndex, 1)) < 0) break; //--- Invalid char
                  if(!isDouble) isDouble = (jsonCharacterArray[currentIndex] == '.' || jsonCharacterArray[currentIndex] == 'e' || jsonCharacterArray[currentIndex] == 'E'); //--- Set double
               }
               m_stringValue = GetSubstringFromArray(jsonCharacterArray, startOfNumber, currentIndex - startOfNumber); //--- Get string
               if(isDouble) {                                //--- Double handling
                  m_type = JsonDouble;                       //--- Set type
                  m_doubleValue = StringToDouble(m_stringValue); //--- Convert double
                  m_integerValue = (long)m_doubleValue;      //--- Set integer
                  m_booleanValue = m_integerValue != 0;      //--- Set boolean
               } else {                                      //--- Integer handling
                  m_type = JsonInteger;                      //--- Set type
                  m_integerValue = StringToInteger(m_stringValue); //--- Convert integer
                  m_doubleValue = (double)m_integerValue;    //--- Set double
                  m_booleanValue = m_integerValue != 0;      //--- Set boolean
               }
               currentIndex--;                               //--- Adjust index
               return true;                                  //--- Success
            } break;                                         //--- End number
            case '\"': {                                     //--- String or key start
               if(m_type == JsonObject) {                    //--- Key in object
                  currentIndex++;                            //--- Increment
                  int startOfString = currentIndex;          //--- String start
                  if(!ExtractStringFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Extract
                  m_temporaryKey = GetSubstringFromArray(jsonCharacterArray, startOfString, currentIndex - startOfString); //--- Set temp key
               } else {                                      //--- Value string
                  if(m_type != JsonUndefined) return false;  //--- Type check
                  m_type = JsonString;                       //--- Set string
                  currentIndex++;                            //--- Increment
                  int startOfString = currentIndex;          //--- String start
                  if(!ExtractStringFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Extract
                  SetFromString(JsonString, GetSubstringFromArray(jsonCharacterArray, startOfString, currentIndex - startOfString)); //--- Set value
                  return true;                               //--- Success
               }
            } break;                                         //--- End string
         }
      }
      return true;                                             //--- Default success
   }
   bool ExtractStringFromArray(char &jsonCharacterArray[], int arrayLength, int &currentIndex) { //--- Extract string handling escapes
      for(; jsonCharacterArray[currentIndex] != 0 && currentIndex < arrayLength; currentIndex++) { //--- Loop string
         char currentCharacter = jsonCharacterArray[currentIndex]; //--- Current char
         if(currentCharacter == '\"') break;                 //--- End on quote
         if(currentCharacter == '\\' && currentIndex + 1 < arrayLength) { //--- Escape
            currentIndex++;                                    //--- Increment
            currentCharacter = jsonCharacterArray[currentIndex]; //--- Escaped char
            switch(currentCharacter) {                         //--- Handle escape
               case '/': case '\\': case '\"': case 'b': case 'f': case 'r': case 'n': case 't': break; //--- Standard
               case 'u': {                                     //--- Unicode
                  currentIndex++;                              //--- Increment
                  for(int hexIndex = 0; hexIndex < 4 && currentIndex < arrayLength && jsonCharacterArray[currentIndex] != 0; hexIndex++, currentIndex++) { //--- Hex loop
                     if(!((jsonCharacterArray[currentIndex] >= '0' && jsonCharacterArray[currentIndex] <= '9') || (jsonCharacterArray[currentIndex] >= 'A' && jsonCharacterArray[currentIndex] <= 'F') || (jsonCharacterArray[currentIndex] >= 'a' && jsonCharacterArray[currentIndex] <= 'f'))) return false; //--- Valid hex check
                  }
                  currentIndex--;                              //--- Adjust
                  break;                                       //--- End unicode
               }
               default: break;                                 //--- Other
            }
         }
      }
      return true;                                             //--- Success
   }
   string EscapeString(string value) {                       //--- Escape string
      ushort inputCharacters[], escapedCharacters[];         //--- Arrays
      int inputLength = StringToShortArray(value, inputCharacters); //--- To short array
      if(ArrayResize(escapedCharacters, 2 * inputLength) != 2 * inputLength) return NULL; //--- Resize check
      int escapedIndex = 0;                                  //--- Escaped index
      for(int inputIndex = 0; inputIndex < inputLength; inputIndex++) { //--- Loop input
         switch(inputCharacters[inputIndex]) {               //--- Special chars
            case '\\': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '\\'; escapedIndex++; break; //--- Backslash
            case '"': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '"'; escapedIndex++; break; //--- Quote
            case '/': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '/'; escapedIndex++; break; //--- Slash
            case 8: escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'b'; escapedIndex++; break; //--- Backspace
            case 12: escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'f'; escapedIndex++; break; //--- Form feed
            case '\n': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'n'; escapedIndex++; break; //--- Newline
            case '\r': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'r'; escapedIndex++; break; //--- Carriage return
            case '\t': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 't'; escapedIndex++; break; //--- Tab
            default: escapedCharacters[escapedIndex] = inputCharacters[inputIndex]; escapedIndex++; break; //--- Normal
         }
      }
      return ShortArrayToString(escapedCharacters, 0, escapedIndex); //--- To string
   }
   string UnescapeString(string value) {                     //--- Unescape string
      ushort inputCharacters[], unescapedCharacters[];       //--- Arrays
      int inputLength = StringToShortArray(value, inputCharacters); //--- To short array
      if(ArrayResize(unescapedCharacters, inputLength) != inputLength) return NULL; //--- Resize check
      int outputIndex = 0, inputIndex = 0;                   //--- Indices
      while(inputIndex < inputLength) {                      //--- Loop input
         ushort currentCharacter = inputCharacters[inputIndex]; //--- Current
         if(currentCharacter == '\\' && inputIndex < inputLength - 1) { //--- Escape
            switch(inputCharacters[inputIndex + 1]) {        //--- Handle
               case '\\': currentCharacter = '\\'; inputIndex++; break; //--- Backslash
               case '"': currentCharacter = '"'; inputIndex++; break; //--- Quote
               case '/': currentCharacter = '/'; inputIndex++; break; //--- Slash
               case 'b': currentCharacter = 8; inputIndex++; break; //--- Backspace
               case 'f': currentCharacter = 12; inputIndex++; break; //--- Form feed
               case 'n': currentCharacter = '\n'; inputIndex++; break; //--- Newline
               case 'r': currentCharacter = '\r'; inputIndex++; break; //--- Carriage return
               case 't': currentCharacter = '\t'; inputIndex++; break; //--- Tab
            }
         }
         unescapedCharacters[outputIndex] = currentCharacter; //--- Copy
         outputIndex++;                                         //--- Increment output
         inputIndex++;                                          //--- Increment input
      }
      return ShortArrayToString(unescapedCharacters, 0, outputIndex); //--- To string
   }
};
int JsonValue::encodingCodePage = CP_UTF8;                   //--- Set default code page
//--- Global variables
string conversationHistory = "";                             //--- Stores conversation history
int logFileHandle = INVALID_HANDLE;                          //--- Handle for log file
bool button_hover = false;                                   //--- Flag for button hover state
color button_original_bg = clrRoyalBlue;                     //--- Original button background color
color button_darker_bg;                                      //--- Darkened button background for hover
//+------------------------------------------------------------------+
//| Darkens a given color by a factor                                |
//+------------------------------------------------------------------+
color DarkenColor(color colorValue, double factor = 0.8) {   //--- Darken color function
   int red = int((colorValue & 0xFF) * factor);              //--- Calculate darkened red component
   int green = int(((colorValue >> 8) & 0xFF) * factor);     //--- Calculate darkened green component
   int blue = int(((colorValue >> 16) & 0xFF) * factor);     //--- Calculate darkened blue component
   return (color)(red | (green << 8) | (blue << 16));        //--- Combine and return darkened color
}
//+------------------------------------------------------------------+
//| Creates a rectangle label object                                 |
//+------------------------------------------------------------------+
bool createRecLabel(string objName, int xDistance, int yDistance, int xSize, int ySize,
                    color bgColor, int borderWidth, color borderColor = clrNONE,
                    ENUM_BORDER_TYPE borderType = BORDER_FLAT,
                    ENUM_LINE_STYLE borderStyle = STYLE_SOLID,
                    ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {   //--- Create rectangle label
   ResetLastError();                                         //--- Reset previous errors
   if (!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) { //--- Attempt creation
      Print(__FUNCTION__, ": failed to create rec label! Error code = ", _LastError); //--- Print error
      return (false);                                        //--- Return failure
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance); //--- Set x distance
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance); //--- Set y distance
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);       //--- Set width
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);       //--- Set height
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);     //--- Set corner
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);   //--- Set background color
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, borderType); //--- Set border type
   ObjectSetInteger(0, objName, OBJPROP_STYLE, borderStyle); //--- Set border style
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, borderWidth); //--- Set border width
   ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor); //--- Set border color
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);        //--- Not background
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);       //--- Not pressed
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);  //--- Not selectable
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);    //--- Not selected
   ChartRedraw(0);                                           //--- Redraw chart
   return (true);                                            //--- Success
}
//+------------------------------------------------------------------+
//| Creates a button object                                          |
//+------------------------------------------------------------------+
bool createButton(string objName, int xDistance, int yDistance, int xSize, int ySize,
                  string text = "", color textColor = clrBlack, int fontSize = 12,
                  color bgColor = clrNONE, color borderColor = clrNONE,
                  string font = "Arial Rounded MT Bold",
                  ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER, bool isBack = false) { //--- Create button
   ResetLastError();                                         //--- Reset errors
   if (!ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0)) {    //--- Attempt creation
      Print(__FUNCTION__, ": failed to create the button! Error code = ", _LastError); //--- Print error
      return (false);                                        //--- Failure
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance); //--- Set x distance
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance); //--- Set y distance
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);       //--- Set width
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);       //--- Set height
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);     //--- Set corner
   ObjectSetString(0, objName, OBJPROP_TEXT, text);          //--- Set text
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);   //--- Set text color
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize); //--- Set font size
   ObjectSetString(0, objName, OBJPROP_FONT, font);          //--- Set font
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);   //--- Set background
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderColor); //--- Set border color
   ObjectSetInteger(0, objName, OBJPROP_BACK, isBack);       //--- Set back
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);       //--- Not pressed
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);  //--- Not selectable
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);    //--- Not selected
   ChartRedraw(0);                                           //--- Redraw
   return (true);                                            //--- Success
}
//+------------------------------------------------------------------+
//| Creates an edit field object                                     |
//+------------------------------------------------------------------+
bool createEdit(string objName, int xDistance, int yDistance, int xSize, int ySize,
                string text = "", color textColor = clrBlack, int fontSize = 12,
                color bgColor = clrNONE, color borderColor = clrNONE,
                string font = "Arial Rounded MT Bold",
                ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                int align = ALIGN_LEFT, bool readOnly = false) {  //--- Create edit
   ResetLastError();                                         //--- Reset errors
   if (!ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0)) {      //--- Attempt creation
      Print(__FUNCTION__, ": failed to create the edit! Error code = ", _LastError); //--- Print error
      return (false);                                        //--- Failure
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance); //--- Set x distance
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance); //--- Set y distance
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xSize);       //--- Set width
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, ySize);       //--- Set height
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);     //--- Set corner
   ObjectSetString(0, objName, OBJPROP_TEXT, text);          //--- Set text
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);   //--- Set text color
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize); //--- Set font size
   ObjectSetString(0, objName, OBJPROP_FONT, font);          //--- Set font
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);   //--- Set background
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderColor); //--- Set border color
   ObjectSetInteger(0, objName, OBJPROP_ALIGN, align);       //--- Set alignment
   ObjectSetInteger(0, objName, OBJPROP_READONLY, readOnly); //--- Set read-only
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);        //--- Not back
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);       //--- Not active
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);  //--- Not selectable
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);    //--- Not selected
   ChartRedraw(0);                                           //--- Redraw
   return (true);                                            //--- Success
}
//+------------------------------------------------------------------+
//| Creates a text label object                                      |
//+------------------------------------------------------------------+
bool createLabel(string objName, int xDistance, int yDistance,
                 string text, color textColor = clrBlack, int fontSize = 12,
                 string font = "Arial Rounded MT Bold",
                 ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                 ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER) {   //--- Create label
   ResetLastError();                                         //--- Reset errors
   if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {     //--- Attempt creation
      Print(__FUNCTION__, ": failed to create the label! Error code = ", _LastError); //--- Print error
      return (false);                                        //--- Failure
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xDistance); //--- Set x distance
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance); //--- Set y distance
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);     //--- Set corner
   ObjectSetString(0, objName, OBJPROP_TEXT, text);          //--- Set text
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);   //--- Set color
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize); //--- Set font size
   ObjectSetString(0, objName, OBJPROP_FONT, font);          //--- Set font
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);        //--- Not back
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);       //--- Not active
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);  //--- Not selectable
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);    //--- Not selected
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);     //--- Set anchor
   ChartRedraw(0);                                           //--- Redraw
   return (true);                                            //--- Success
}
//+------------------------------------------------------------------+
//| Wraps text respecting newlines and max width                     |
//+------------------------------------------------------------------+
void WrapText(const string inputText, const string font, const int fontSize, const int maxWidth, string &wrappedLines[], int offset = 0) { //--- Wrap text function
   const int maxChars = 60;                                  //--- Max chars per line
   ArrayResize(wrappedLines, 0);                             //--- Clear output array
   TextSetFont(font, -fontSize * 10, 0);                     //--- Set font for measurement
   string paragraphs[];                                      //--- Array for paragraphs
   int numParagraphs = StringSplit(inputText, '\n', paragraphs); //--- Split by newline
   for (int p = 0; p < numParagraphs; p++) {                 //--- Loop paragraphs
      string para = paragraphs[p];                           //--- Get paragraph
      if (StringLen(para) == 0) continue;                    //--- Skip empty
      string words[];                                        //--- Array for words
      int numWords = StringSplit(para, ' ', words);          //--- Split by space
      string currentLine = "";                               //--- Current line builder
      for (int w = 0; w < numWords; w++) {                   //--- Loop words
         string testLine = currentLine + (StringLen(currentLine) > 0 ? " " : "") + words[w]; //--- Test add word
         uint wid, hei;                                      //--- Width, height
         TextGetSize(testLine, wid, hei);                    //--- Get size
         int textWidth = (int)wid;                          //--- Cast width
         if (textWidth + offset <= maxWidth && StringLen(testLine) <= maxChars) { //--- Fits
            currentLine = testLine;                         //--- Update line
         } else {                                           //--- Doesn't fit
            if (StringLen(currentLine) > 0) {               //--- Add current if not empty
               int size = ArraySize(wrappedLines);          //--- Get size
               ArrayResize(wrappedLines, size + 1);         //--- Resize
               wrappedLines[size] = currentLine;            //--- Add line
            }
            currentLine = words[w];                        //--- Start new with word
            TextGetSize(currentLine, wid, hei);            //--- Get size
            textWidth = (int)wid;                          //--- Cast
            if (textWidth + offset > maxWidth || StringLen(currentLine) > maxChars) { //--- Word too long
               string wrappedWord = "";                    //--- Word builder
               for (int c = 0; c < StringLen(words[w]); c++) { //--- Char loop
                  string testWord = wrappedWord + StringSubstr(words[w], c, 1); //--- Test add char
                  TextGetSize(testWord, wid, hei);         //--- Get size
                  int wordWidth = (int)wid;                //--- Cast
                  if (wordWidth + offset > maxWidth || StringLen(testWord) > maxChars) { //--- Char exceeds
                     if (StringLen(wrappedWord) > 0) {     //--- Add if not empty
                        int size = ArraySize(wrappedLines); //--- Get size
                        ArrayResize(wrappedLines, size + 1); //--- Resize
                        wrappedLines[size] = wrappedWord;  //--- Add
                     }
                     wrappedWord = StringSubstr(words[w], c, 1); //--- New with char
                  } else {                                 //--- Fits
                     wrappedWord = testWord;               //--- Update
                  }
               }
               currentLine = wrappedWord;                 //--- Set current
            }
         }
      }
      if (StringLen(currentLine) > 0) {                      //--- Add remaining line
         int size = ArraySize(wrappedLines);                 //--- Get size
         ArrayResize(wrappedLines, size + 1);                //--- Resize
         wrappedLines[size] = currentLine;                   //--- Add
      }
   }
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {                                               //--- Initialization
   button_darker_bg = DarkenColor(button_original_bg);       //--- Set darker button color
   logFileHandle = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_TXT); //--- Open log
   if(logFileHandle == INVALID_HANDLE) {                     //--- Check handle
      Print("Failed to open log file: ", GetLastError());    //--- Print error
      return(INIT_FAILED);                                   //--- Fail init
   }
   FileSeek(logFileHandle, 0, SEEK_END);                     //--- Seek end
   FileWriteString(logFileHandle, "EA Initialized at " + TimeToString(TimeCurrent()) + "\n"); //--- Log init
   CreateDashboard();                                        //--- Create UI
   UpdateResponseDisplay();                                  //--- Update display
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);         //--- Enable mouse events
   return(INIT_SUCCEEDED);                                   //--- Success
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {                            //--- Deinit
   ObjectsDeleteAll(0, "ChatGPT_");                          //--- Delete objects
   if(logFileHandle != INVALID_HANDLE) {                     //--- Check handle
      FileClose(logFileHandle);                              //--- Close log
   }
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {                                              //--- Tick handler

}
//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) { //--- Event handler
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "ChatGPT_SubmitButton") { //--- Button click
      string prompt = (string)ObjectGetString(0, "ChatGPT_InputEdit", OBJPROP_TEXT); //--- Get input
      if(StringLen(prompt) > 0) {                            //--- If not empty
         string response = GetChatGPTResponse(prompt);       //--- Get AI response
         Print("User: " + prompt);                           //--- Print user
         Print("AI: " + response);                           //--- Print AI
         conversationHistory += "You: " + prompt + "\nAI: " + response + "\n\n"; //--- Append history
         ObjectSetString(0, "ChatGPT_InputEdit", OBJPROP_TEXT, ""); //--- Clear input
         UpdateResponseDisplay();                            //--- Update display
         FileWriteString(logFileHandle, "Prompt: " + prompt + " | Response: " + response + " | Time: " + TimeToString(TimeCurrent()) + "\n"); //--- Log
         ChartRedraw();                                      //--- Redraw
      }
   } else if(id == CHARTEVENT_MOUSE_MOVE) {                  //--- Mouse move
      int mouseX = (int)lparam;                              //--- X coord
      int mouseY = (int)dparam;                              //--- Y coord
      bool isOver = (mouseX >= 430 && mouseX <= 530 && mouseY >= 20 && mouseY <= 60); //--- Check hover
      if(isOver && !button_hover) {                          //--- Enter hover
         ObjectSetInteger(0, "ChatGPT_SubmitButton", OBJPROP_BGCOLOR, button_darker_bg); //--- Darken
         button_hover = true;                                //--- Set flag
         ChartRedraw();                                      //--- Redraw
      } else if(!isOver && button_hover) {                   //--- Exit hover
         ObjectSetInteger(0, "ChatGPT_SubmitButton", OBJPROP_BGCOLOR, button_original_bg); //--- Restore
         button_hover = false;                               //--- Clear flag
         ChartRedraw();                                      //--- Redraw
      }
   }
}
//+------------------------------------------------------------------+
//| Creates the dashboard UI                                         |
//+------------------------------------------------------------------+
void CreateDashboard() {                                     //--- Create UI
   createEdit("ChatGPT_InputEdit", 20, 20, 400, 40, "", clrBlack, 12, clrWhiteSmoke, clrDarkGray, "Arial", CORNER_LEFT_UPPER, ALIGN_LEFT, false); //--- Input edit
   createButton("ChatGPT_SubmitButton", 430, 20, 100, 40, "Send", clrWhite, 12, button_original_bg, clrDarkBlue, "Arial", CORNER_LEFT_UPPER, false); //--- Submit button
   createRecLabel("ChatGPT_ResponseBg", 20, 70, 510, 300, clrWhite, 2, clrLightGray, BORDER_FLAT, STYLE_SOLID, CORNER_LEFT_UPPER); //--- Response background
   ChartRedraw();                                            //--- Redraw
}
//+------------------------------------------------------------------+
//| Updates the response display                                     |
//+------------------------------------------------------------------+
void UpdateResponseDisplay() {                               //--- Update display
   int total = ObjectsTotal(0, 0, -1);                       //--- Get total objects
   for (int j = total - 1; j >= 0; j--) {                    //--- Loop backwards
      string name = ObjectName(0, j, 0, -1);                 //--- Get name
      if (StringFind(name, "ChatGPT_ResponseLine_") == 0 || StringFind(name, "ChatGPT_MessageBg_") == 0) { //--- Check prefix
         ObjectDelete(0, name);                              //--- Delete
      }
   }
   string displayText = conversationHistory;                 //--- Get history
   if (displayText == "") {                                  //--- If empty
      string objName = "ChatGPT_ResponseLine_0";             //--- Name
      createLabel(objName, 30, 80, "Type your message above and click Send to chat with the AI.", clrGray, 10, "Arial", CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER); //--- Placeholder
      ChartRedraw();                                         //--- Redraw
      return;                                                //--- Exit
   }
   string font = "Arial";                                    //--- Font
   int fontSize = 10;                                        //--- Size
   int padding = 10;                                         //--- Padding
   int maxWidth = 510 - 2 * padding;                         //--- Max width
   string wrappedLines[];                                    //--- Wrapped lines
   WrapText(displayText, font, fontSize, maxWidth, wrappedLines, 0); //--- Wrap text
   TextSetFont(font, -fontSize * 10, 0);                     //--- Set font
   uint wid, hei;                                            //--- Size vars
   TextGetSize("A", wid, hei);                               //--- Get height
   int lineHeight = (int)hei;                                //--- Line height
   int responseHeight = 300;                                 //--- Response height
   int maxVisibleLines = (responseHeight - 2 * padding) / lineHeight; //--- Max lines
   int numLines = ArraySize(wrappedLines);                   //--- Num lines
   int startLine = MathMax(0, numLines - maxVisibleLines);   //--- Start line
   int textX = 20 + padding;                                 //--- Text x
   int textY = 70 + padding;                                 //--- Text y
   color currentColor = clrWhite;                            //--- Current color
   for (int i = startLine; i < numLines; i++) {              //--- Loop lines
      string line = wrappedLines[i];                         //--- Get line
      if (StringFind(line, "You: ") == 0) {                  //--- User color
         currentColor = clrGray;                             //--- Set gray
      } else if (StringFind(line, "AI: ") == 0) {            //--- AI color
         currentColor = clrBlue;                             //--- Set blue
      }
      string objName = "ChatGPT_ResponseLine_" + IntegerToString(i - startLine); //--- Name
      createLabel(objName, textX, textY, line, currentColor, fontSize, font, CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER); //--- Create label
      textY += lineHeight;                                   //--- Next y
   }
   ChartRedraw();                                            //--- Redraw
}
//+------------------------------------------------------------------+
//| Escapes string for JSON                                          |
//+------------------------------------------------------------------+
string JsonEscape(string value) {                            //--- JSON escape
   StringReplace(value, "\\", "\\\\");                       //--- Escape backslash
   StringReplace(value, "\"", "\\\"");                       //--- Escape quote
   StringReplace(value, "\n", "\\n");                        //--- Escape newline
   StringReplace(value, "\r", "\\r");                        //--- Escape carriage
   StringReplace(value, "\t", "\\t");                        //--- Escape tab
   StringReplace(value, "\f", "\\f");                        //--- Escape form feed
   for(int i = 0; i < StringLen(value); i++) {               //--- Loop chars
      ushort charCode = StringGetCharacter(value, i);        //--- Get char
      if(charCode < 32 || charCode == 127) {                 //--- Control chars
         string hex = StringFormat("\\u%04x", charCode);     //--- Hex escape
         string before = StringSubstr(value, 0, i);          //--- Before part
         string after = StringSubstr(value, i + 1);          //--- After part
         value = before + hex + after;                       //--- Replace
         i += 5;                                            //--- Skip added
      }
   }
   return value;                                             //--- Return escaped
}
//+------------------------------------------------------------------+
//| Logs char array as hex for debugging                             |
//+------------------------------------------------------------------+
string LogCharArray(char &data[]) {                          //--- Log char array
   string result = "";                                       //--- Result string
   for(int i = 0; i < ArraySize(data); i++) {                //--- Loop array
      result += StringFormat("%02X ", data[i]);              //--- Append hex
   }
   return result;                                            //--- Return
}
//+------------------------------------------------------------------+
//| Gets ChatGPT response via API                                    |
//+------------------------------------------------------------------+
string GetChatGPTResponse(string prompt) {                   //--- Get AI response
   string escapedPrompt = JsonEscape(prompt);                //--- Escape prompt
   string requestData = "{\"model\":\"" + OpenAI_Model + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + escapedPrompt + "\"}],\"max_tokens\":500}"; //--- Build JSON
   FileWriteString(logFileHandle, "Request Data: " + requestData + "\n"); //--- Log data
   char postData[];                                          //--- Post array
   int dataLen = StringToCharArray(requestData, postData, 0, WHOLE_ARRAY, CP_UTF8); //--- To char array
   ArrayResize(postData, dataLen - 1);                       //--- Remove terminator
   FileWriteString(logFileHandle, "Raw Post Data (Hex): " + LogCharArray(postData) + "\n"); //--- Log hex
   string headers = "Authorization: Bearer " + OpenAI_API_Key + "\r\n" + //--- Build headers
                    "Content-Type: application/json; charset=UTF-8\r\n" +
                    "Content-Length: " + IntegerToString(dataLen - 1) + "\r\n\r\n";
   FileWriteString(logFileHandle, "Request Headers: " + headers + "\n"); //--- Log headers
   char result[];                                            //--- Result array
   string resultHeaders;                                     //--- Result headers
   int res = WebRequest("POST", OpenAI_Endpoint, headers, 10000, postData, result, resultHeaders); //--- Send request
   if(res != 200) {                                          //--- Check status
      string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8); //--- To string
      string errMsg = "API request failed: HTTP Code " + IntegerToString(res) + ", Error: " + IntegerToString(GetLastError()) + ", Response: " + response; //--- Error msg
      Print(errMsg);                                         //--- Print
      FileWriteString(logFileHandle, errMsg + "\n");          //--- Log
      FileWriteString(logFileHandle, "Raw Response Data (Hex): " + LogCharArray(result) + "\n"); //--- Log hex
      return errMsg;                                         //--- Return error
   }
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8); //--- To string
   FileWriteString(logFileHandle, "API Response: " + response + "\n"); //--- Log response
   JsonValue jsonObject;                                     //--- JSON object
   int index = 0;                                            //--- Index
   char charArray[];                                         //--- Char array
   int arrayLength = StringToCharArray(response, charArray, 0, WHOLE_ARRAY, CP_UTF8); //--- To char
   if(!jsonObject.DeserializeFromArray(charArray, arrayLength, index)) { //--- Deserialize
      string errMsg = "Error: Failed to parse API response JSON: " + response; //--- Error
      Print(errMsg);                                         //--- Print
      FileWriteString(logFileHandle, errMsg + "\n");          //--- Log
      return errMsg;                                         //--- Return
   }
   JsonValue *error = jsonObject.FindChildByKey("error");    //--- Find error
   if(error != NULL) {                                       //--- If error
      string errMsg = "API Error: " + error["message"].ToString(); //--- Get message
      Print(errMsg);                                         //--- Print
      FileWriteString(logFileHandle, errMsg + "\n");          //--- Log
      return errMsg;                                         //--- Return
   }
   string content = jsonObject["choices"][0]["message"]["content"].ToString(); //--- Get content
   if(StringLen(content) > 0) {                              //--- If content
      StringReplace(content, "\\n", "\n");                   //--- Replace escapes
      StringTrimLeft(content);                               //--- Trim left
      StringTrimRight(content);                              //--- Trim right
      return content;                                        //--- Return
   }
   string errMsg = "Error: No content in API response: " + response; //--- Error
   Print(errMsg);                                            //--- Print
   FileWriteString(logFileHandle, errMsg + "\n");             //--- Log
   return errMsg;                                            //--- Return
}
//+------------------------------------------------------------------+
