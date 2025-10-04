//+------------------------------------------------------------------+
//|                                           DeepNeuralNetwork.mqh |
//|                                                        Manus AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      ""
#property version   "1.00"

//--- Neural network architecture constants
#define SIZEI 12  // Input layer size (market features)
#define SIZEA 16  // Hidden layer A size
#define SIZEB 8   // Hidden layer B size
#define SIZEO 3   // Output layer size (BUY/SELL/HOLD)

//+------------------------------------------------------------------+
//| Deep Neural Network Class for Trading Signal Generation         |
//+------------------------------------------------------------------+
class DeepNeuralNetwork
{
private:
   // Network architecture parameters
   int               numInput;
   int               numHiddenA;
   int               numHiddenB;
   int               numOutput;
   
   // Input data
   double            inputs[SIZEI];
   
   // Weight matrices
   double            iaWeights[SIZEA][SIZEI];  // Input to Hidden A weights
   double            abWeights[SIZEB][SIZEA];  // Hidden A to Hidden B weights
   double            boWeights[SIZEO][SIZEB];  // Hidden B to Output weights
   
   // Bias arrays
   double            aBiases[SIZEA];           // Hidden layer A biases
   double            bBiases[SIZEB];           // Hidden layer B biases
   double            oBiases[SIZEO];           // Output layer biases
   
   // Output arrays
   double            aOutputs[SIZEA];          // Hidden layer A outputs
   double            bOutputs[SIZEB];          // Hidden layer B outputs
   double            outputs[SIZEO];           // Final outputs
   
   // Internal computation arrays
   double            aSums[SIZEA];             // Hidden layer A pre-activation sums
   double            bSums[SIZEB];             // Hidden layer B pre-activation sums
   double            oSums[SIZEO];             // Output layer pre-activation sums
   
   // Market data preprocessing
   double            inputMeans[SIZEI];        // Input normalization means
   double            inputStds[SIZEI];         // Input normalization standard deviations
   
   // Performance tracking
   double            lastConfidence;           // Confidence of last prediction
   int               predictionCount;          // Number of predictions made
   int               correctPredictions;       // Number of correct predictions
   
public:
   // Constructor and destructor
                     DeepNeuralNetwork(void);
                    ~DeepNeuralNetwork(void);
   
   // Initialization methods
   bool              Initialize(void);
   void              InitializeWeights(void);
   void              InitializeBiases(void);
   void              InitializeNormalization(void);
   
   // Weight management
   bool              SetWeights(double &weights[]);
   bool              LoadWeights(string filename);
   bool              SaveWeights(string filename);
   
   // Data preprocessing
   void              NormalizeInputs(double &rawInputs[]);
   void              PrepareMarketFeatures(double &features[]);
   
   // Forward propagation
   void              ComputeOutputs(double &xValues[]);
   void              ForwardPass(void);
   
   // Activation functions
   double            HyperTanFunction(double x);
   void              Softmax(double &sums[], double &softOut[]);
   double            ReLUFunction(double x);
   double            SigmoidFunction(double x);
   
   // Signal generation
   int               GetTradingSignal(void);
   double            GetSignalConfidence(void);
   string            GetSignalDescription(int signal);
   
   // Performance monitoring
   double            GetAccuracy(void);
   void              UpdatePerformance(int actualOutcome);
   void              ResetPerformance(void);
   
   // Utility methods
   void              PrintNetworkInfo(void);
   void              PrintOutputs(void);
   bool              ValidateInputs(double &inputs[]);
   
   // Adaptive learning
   void              AdaptToMarketConditions(void);
   bool              ShouldRetrain(void);
   
   // Error handling
   string            GetLastError(void);
   void              ClearError(void);
   
private:
   // Internal helper methods
   void              InitializeRandomWeights(void);
   double            GenerateRandomWeight(void);
   void              ClampOutputs(void);
   bool              ValidateNetworkState(void);
   
   // Error tracking
   string            lastError;
   bool              hasError;
};

//+------------------------------------------------------------------+
//| Market feature indices for input array                          |
//+------------------------------------------------------------------+
enum ENUM_MARKET_FEATURES
{
   FEATURE_PRICE_CHANGE_1 = 0,     // 1-period price change
   FEATURE_PRICE_CHANGE_5 = 1,     // 5-period price change
   FEATURE_PRICE_CHANGE_20 = 2,    // 20-period price change
   FEATURE_VOLUME_RATIO = 3,       // Current volume / average volume
   FEATURE_RSI = 4,                // Relative Strength Index
   FEATURE_MACD_MAIN = 5,          // MACD main line
   FEATURE_MACD_SIGNAL = 6,        // MACD signal line
   FEATURE_BB_POSITION = 7,        // Bollinger Bands position
   FEATURE_ATR_RATIO = 8,          // ATR / price ratio
   FEATURE_MOMENTUM = 9,           // Price momentum
   FEATURE_VOLATILITY = 10,        // Recent volatility
   FEATURE_TREND_STRENGTH = 11     // Trend strength indicator
};

//+------------------------------------------------------------------+
//| Trading signal enumeration                                      |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SIGNAL
{
   SIGNAL_HOLD = 0,    // Hold position / no action
   SIGNAL_BUY = 1,     // Buy signal
   SIGNAL_SELL = 2     // Sell signal
};

//+------------------------------------------------------------------+
//| Neural network configuration constants                          |
//+------------------------------------------------------------------+
#define NN_MIN_CONFIDENCE 0.6      // Minimum confidence for trading
#define NN_LEARNING_RATE 0.001     // Learning rate for adaptation
#define NN_WEIGHT_DECAY 0.0001     // Weight decay for regularization
#define NN_MAX_WEIGHT 5.0          // Maximum weight value
#define NN_MIN_WEIGHT -5.0         // Minimum weight value

