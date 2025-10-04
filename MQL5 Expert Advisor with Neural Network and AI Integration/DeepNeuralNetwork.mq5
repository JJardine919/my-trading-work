//+------------------------------------------------------------------+
//|                                           DeepNeuralNetwork.mq5 |
//|                                                        Manus AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      ""
#property version   "1.00"

#include "DeepNeuralNetwork.mqh"

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
DeepNeuralNetwork::DeepNeuralNetwork(void)
{
   numInput = SIZEI;
   numHiddenA = SIZEA;
   numHiddenB = SIZEB;
   numOutput = SIZEO;
   
   lastConfidence = 0.0;
   predictionCount = 0;
   correctPredictions = 0;
   hasError = false;
   lastError = "";
   
   // Initialize arrays to zero
   ArrayInitialize(inputs, 0.0);
   ArrayInitialize(aBiases, 0.0);
   ArrayInitialize(bBiases, 0.0);
   ArrayInitialize(oBiases, 0.0);
   ArrayInitialize(aOutputs, 0.0);
   ArrayInitialize(bOutputs, 0.0);
   ArrayInitialize(outputs, 0.0);
   ArrayInitialize(aSums, 0.0);
   ArrayInitialize(bSums, 0.0);
   ArrayInitialize(oSums, 0.0);
   ArrayInitialize(inputMeans, 0.0);
   ArrayInitialize(inputStds, 1.0);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
DeepNeuralNetwork::~DeepNeuralNetwork(void)
{
   // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize the neural network                                   |
//+------------------------------------------------------------------+
bool DeepNeuralNetwork::Initialize(void)
{
   try
   {
      InitializeWeights();
      InitializeBiases();
      InitializeNormalization();
      
      Print("Neural Network initialized successfully");
      Print("Architecture: ", numInput, "-", numHiddenA, "-", numHiddenB, "-", numOutput);
      
      return true;
   }
   catch(string error)
   {
      lastError = "Initialization failed: " + error;
      hasError = true;
      Print("Neural Network initialization failed: ", error);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Initialize network weights using Xavier initialization          |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::InitializeWeights(void)
{
   // Initialize input to hidden A weights
   double fanIn = (double)numInput;
   double fanOut = (double)numHiddenA;
   double limit = MathSqrt(6.0 / (fanIn + fanOut));
   
   for(int i = 0; i < numHiddenA; i++)
   {
      for(int j = 0; j < numInput; j++)
      {
         iaWeights[i][j] = (MathRand() / 32767.0 * 2.0 - 1.0) * limit;
      }
   }
   
   // Initialize hidden A to hidden B weights
   fanIn = (double)numHiddenA;
   fanOut = (double)numHiddenB;
   limit = MathSqrt(6.0 / (fanIn + fanOut));
   
   for(int i = 0; i < numHiddenB; i++)
   {
      for(int j = 0; j < numHiddenA; j++)
      {
         abWeights[i][j] = (MathRand() / 32767.0 * 2.0 - 1.0) * limit;
      }
   }
   
   // Initialize hidden B to output weights
   fanIn = (double)numHiddenB;
   fanOut = (double)numOutput;
   limit = MathSqrt(6.0 / (fanIn + fanOut));
   
   for(int i = 0; i < numOutput; i++)
   {
      for(int j = 0; j < numHiddenB; j++)
      {
         boWeights[i][j] = (MathRand() / 32767.0 * 2.0 - 1.0) * limit;
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize network biases                                       |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::InitializeBiases(void)
{
   // Initialize biases to small random values
   for(int i = 0; i < numHiddenA; i++)
   {
      aBiases[i] = (MathRand() / 32767.0 * 2.0 - 1.0) * 0.1;
   }
   
   for(int i = 0; i < numHiddenB; i++)
   {
      bBiases[i] = (MathRand() / 32767.0 * 2.0 - 1.0) * 0.1;
   }
   
   for(int i = 0; i < numOutput; i++)
   {
      oBiases[i] = (MathRand() / 32767.0 * 2.0 - 1.0) * 0.1;
   }
}

//+------------------------------------------------------------------+
//| Initialize input normalization parameters                       |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::InitializeNormalization(void)
{
   // Set default normalization parameters
   // These should be updated based on historical data analysis
   
   inputMeans[FEATURE_PRICE_CHANGE_1] = 0.0;
   inputMeans[FEATURE_PRICE_CHANGE_5] = 0.0;
   inputMeans[FEATURE_PRICE_CHANGE_20] = 0.0;
   inputMeans[FEATURE_VOLUME_RATIO] = 1.0;
   inputMeans[FEATURE_RSI] = 50.0;
   inputMeans[FEATURE_MACD_MAIN] = 0.0;
   inputMeans[FEATURE_MACD_SIGNAL] = 0.0;
   inputMeans[FEATURE_BB_POSITION] = 0.5;
   inputMeans[FEATURE_ATR_RATIO] = 0.02;
   inputMeans[FEATURE_MOMENTUM] = 0.0;
   inputMeans[FEATURE_VOLATILITY] = 0.01;
   inputMeans[FEATURE_TREND_STRENGTH] = 0.0;
   
   inputStds[FEATURE_PRICE_CHANGE_1] = 0.01;
   inputStds[FEATURE_PRICE_CHANGE_5] = 0.03;
   inputStds[FEATURE_PRICE_CHANGE_20] = 0.08;
   inputStds[FEATURE_VOLUME_RATIO] = 0.5;
   inputStds[FEATURE_RSI] = 20.0;
   inputStds[FEATURE_MACD_MAIN] = 0.001;
   inputStds[FEATURE_MACD_SIGNAL] = 0.001;
   inputStds[FEATURE_BB_POSITION] = 0.3;
   inputStds[FEATURE_ATR_RATIO] = 0.01;
   inputStds[FEATURE_MOMENTUM] = 0.02;
   inputStds[FEATURE_VOLATILITY] = 0.005;
   inputStds[FEATURE_TREND_STRENGTH] = 0.5;
}

//+------------------------------------------------------------------+
//| Normalize input features                                        |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::NormalizeInputs(double &rawInputs[])
{
   if(ArraySize(rawInputs) != numInput)
   {
      lastError = "Input array size mismatch";
      hasError = true;
      return;
   }
   
   for(int i = 0; i < numInput; i++)
   {
      if(inputStds[i] > 0.0)
      {
         inputs[i] = (rawInputs[i] - inputMeans[i]) / inputStds[i];
         
         // Clamp to reasonable range
         if(inputs[i] > 3.0) inputs[i] = 3.0;
         if(inputs[i] < -3.0) inputs[i] = -3.0;
      }
      else
      {
         inputs[i] = rawInputs[i];
      }
   }
}

//+------------------------------------------------------------------+
//| Prepare market features from current market data               |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::PrepareMarketFeatures(double &features[])
{
   ArrayResize(features, numInput);
   
   // Get current market data
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      lastError = "Failed to get tick data";
      hasError = true;
      return;
   }
   
   double currentPrice = (tick.bid + tick.ask) / 2.0;
   
   // Calculate price changes
   double prices[21];
   for(int i = 0; i < 21; i++)
   {
      prices[i] = iClose(_Symbol, _Period, i);
   }
   
   if(prices[0] > 0 && prices[1] > 0 && prices[5] > 0 && prices[20] > 0)
   {
      features[FEATURE_PRICE_CHANGE_1] = (prices[0] - prices[1]) / prices[1];
      features[FEATURE_PRICE_CHANGE_5] = (prices[0] - prices[5]) / prices[5];
      features[FEATURE_PRICE_CHANGE_20] = (prices[0] - prices[20]) / prices[20];
   }
   else
   {
      features[FEATURE_PRICE_CHANGE_1] = 0.0;
      features[FEATURE_PRICE_CHANGE_5] = 0.0;
      features[FEATURE_PRICE_CHANGE_20] = 0.0;
   }
   
   // Calculate volume ratio
   long currentVolume = iVolume(_Symbol, _Period, 0);
   long avgVolume = 0;
   for(int i = 1; i <= 20; i++)
   {
      avgVolume += iVolume(_Symbol, _Period, i);
   }
   avgVolume /= 20;
   
   if(avgVolume > 0)
      features[FEATURE_VOLUME_RATIO] = (double)currentVolume / (double)avgVolume;
   else
      features[FEATURE_VOLUME_RATIO] = 1.0;
   
   // Calculate RSI
   int rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   if(rsiHandle != INVALID_HANDLE)
   {
      double rsiValues[1];
      if(CopyBuffer(rsiHandle, 0, 0, 1, rsiValues) > 0)
         features[FEATURE_RSI] = rsiValues[0];
      else
         features[FEATURE_RSI] = 50.0;
      IndicatorRelease(rsiHandle);
   }
   else
   {
      features[FEATURE_RSI] = 50.0;
   }
   
   // Calculate MACD
   int macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   if(macdHandle != INVALID_HANDLE)
   {
      double macdMain[1], macdSignal[1];
      if(CopyBuffer(macdHandle, 0, 0, 1, macdMain) > 0 && 
         CopyBuffer(macdHandle, 1, 0, 1, macdSignal) > 0)
      {
         features[FEATURE_MACD_MAIN] = macdMain[0];
         features[FEATURE_MACD_SIGNAL] = macdSignal[0];
      }
      else
      {
         features[FEATURE_MACD_MAIN] = 0.0;
         features[FEATURE_MACD_SIGNAL] = 0.0;
      }
      IndicatorRelease(macdHandle);
   }
   else
   {
      features[FEATURE_MACD_MAIN] = 0.0;
      features[FEATURE_MACD_SIGNAL] = 0.0;
   }
   
   // Calculate Bollinger Bands position
   int bbHandle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
   if(bbHandle != INVALID_HANDLE)
   {
      double bbUpper[1], bbLower[1];
      if(CopyBuffer(bbHandle, 1, 0, 1, bbUpper) > 0 && 
         CopyBuffer(bbHandle, 2, 0, 1, bbLower) > 0)
      {
         if(bbUpper[0] > bbLower[0])
            features[FEATURE_BB_POSITION] = (currentPrice - bbLower[0]) / (bbUpper[0] - bbLower[0]);
         else
            features[FEATURE_BB_POSITION] = 0.5;
      }
      else
      {
         features[FEATURE_BB_POSITION] = 0.5;
      }
      IndicatorRelease(bbHandle);
   }
   else
   {
      features[FEATURE_BB_POSITION] = 0.5;
   }
   
   // Calculate ATR ratio
   int atrHandle = iATR(_Symbol, _Period, 14);
   if(atrHandle != INVALID_HANDLE)
   {
      double atrValues[1];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) > 0 && currentPrice > 0)
         features[FEATURE_ATR_RATIO] = atrValues[0] / currentPrice;
      else
         features[FEATURE_ATR_RATIO] = 0.02;
      IndicatorRelease(atrHandle);
   }
   else
   {
      features[FEATURE_ATR_RATIO] = 0.02;
   }
   
   // Calculate momentum
   if(prices[0] > 0 && prices[10] > 0)
      features[FEATURE_MOMENTUM] = (prices[0] - prices[10]) / prices[10];
   else
      features[FEATURE_MOMENTUM] = 0.0;
   
   // Calculate volatility
   double priceSum = 0.0;
   for(int i = 0; i < 10; i++)
   {
      if(i < 9 && prices[i] > 0 && prices[i+1] > 0)
      {
         double change = MathAbs(prices[i] - prices[i+1]) / prices[i+1];
         priceSum += change;
      }
   }
   features[FEATURE_VOLATILITY] = priceSum / 9.0;
   
   // Calculate trend strength
   double ma5 = 0.0, ma20 = 0.0;
   for(int i = 0; i < 5; i++) ma5 += prices[i];
   for(int i = 0; i < 20; i++) ma20 += prices[i];
   ma5 /= 5.0;
   ma20 /= 20.0;
   
   if(ma20 > 0)
      features[FEATURE_TREND_STRENGTH] = (ma5 - ma20) / ma20;
   else
      features[FEATURE_TREND_STRENGTH] = 0.0;
}

//+------------------------------------------------------------------+
//| Compute neural network outputs                                  |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::ComputeOutputs(double &xValues[])
{
   if(!ValidateInputs(xValues))
   {
      lastError = "Invalid input values";
      hasError = true;
      return;
   }
   
   NormalizeInputs(xValues);
   ForwardPass();
   
   predictionCount++;
}

//+------------------------------------------------------------------+
//| Forward propagation through the network                        |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::ForwardPass(void)
{
   // Input to Hidden Layer A
   for(int i = 0; i < numHiddenA; i++)
   {
      aSums[i] = aBiases[i];
      for(int j = 0; j < numInput; j++)
      {
         aSums[i] += inputs[j] * iaWeights[i][j];
      }
      aOutputs[i] = HyperTanFunction(aSums[i]);
   }
   
   // Hidden Layer A to Hidden Layer B
   for(int i = 0; i < numHiddenB; i++)
   {
      bSums[i] = bBiases[i];
      for(int j = 0; j < numHiddenA; j++)
      {
         bSums[i] += aOutputs[j] * abWeights[i][j];
      }
      bOutputs[i] = HyperTanFunction(bSums[i]);
   }
   
   // Hidden Layer B to Output
   for(int i = 0; i < numOutput; i++)
   {
      oSums[i] = oBiases[i];
      for(int j = 0; j < numHiddenB; j++)
      {
         oSums[i] += bOutputs[j] * boWeights[i][j];
      }
   }
   
   // Apply softmax to output layer
   Softmax(oSums, outputs);
   
   // Calculate confidence as the maximum output probability
   lastConfidence = 0.0;
   for(int i = 0; i < numOutput; i++)
   {
      if(outputs[i] > lastConfidence)
         lastConfidence = outputs[i];
   }
}

//+------------------------------------------------------------------+
//| Hyperbolic tangent activation function                         |
//+------------------------------------------------------------------+
double DeepNeuralNetwork::HyperTanFunction(double x)
{
   if(x < -20.0) return -1.0;
   if(x > 20.0) return 1.0;
   return MathTanh(x);
}

//+------------------------------------------------------------------+
//| Softmax activation function for output layer                   |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::Softmax(double &sums[], double &softOut[])
{
   // Find maximum for numerical stability
   double maxVal = sums[0];
   for(int i = 1; i < numOutput; i++)
   {
      if(sums[i] > maxVal)
         maxVal = sums[i];
   }
   
   // Calculate exponentials and sum
   double sum = 0.0;
   for(int i = 0; i < numOutput; i++)
   {
      softOut[i] = MathExp(sums[i] - maxVal);
      sum += softOut[i];
   }
   
   // Normalize
   if(sum > 0.0)
   {
      for(int i = 0; i < numOutput; i++)
      {
         softOut[i] /= sum;
      }
   }
   else
   {
      // Fallback to uniform distribution
      for(int i = 0; i < numOutput; i++)
      {
         softOut[i] = 1.0 / numOutput;
      }
   }
}

//+------------------------------------------------------------------+
//| Get trading signal from neural network output                  |
//+------------------------------------------------------------------+
int DeepNeuralNetwork::GetTradingSignal(void)
{
   if(lastConfidence < NN_MIN_CONFIDENCE)
      return SIGNAL_HOLD;
   
   int maxIndex = 0;
   double maxValue = outputs[0];
   
   for(int i = 1; i < numOutput; i++)
   {
      if(outputs[i] > maxValue)
      {
         maxValue = outputs[i];
         maxIndex = i;
      }
   }
   
   return maxIndex;
}

//+------------------------------------------------------------------+
//| Get signal confidence                                           |
//+------------------------------------------------------------------+
double DeepNeuralNetwork::GetSignalConfidence(void)
{
   return lastConfidence;
}

//+------------------------------------------------------------------+
//| Get signal description                                          |
//+------------------------------------------------------------------+
string DeepNeuralNetwork::GetSignalDescription(int signal)
{
   switch(signal)
   {
      case SIGNAL_HOLD: return "HOLD";
      case SIGNAL_BUY:  return "BUY";
      case SIGNAL_SELL: return "SELL";
      default:          return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Validate input values                                           |
//+------------------------------------------------------------------+
bool DeepNeuralNetwork::ValidateInputs(double &inputs[])
{
   if(ArraySize(inputs) != numInput)
      return false;
   
   for(int i = 0; i < numInput; i++)
   {
      if(!MathIsValidNumber(inputs[i]))
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Print network information                                       |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::PrintNetworkInfo(void)
{
   Print("=== Neural Network Information ===");
   Print("Architecture: ", numInput, "-", numHiddenA, "-", numHiddenB, "-", numOutput);
   Print("Predictions made: ", predictionCount);
   Print("Accuracy: ", GetAccuracy(), "%");
   Print("Last confidence: ", lastConfidence);
   Print("================================");
}

//+------------------------------------------------------------------+
//| Print current outputs                                           |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::PrintOutputs(void)
{
   Print("Neural Network Outputs:");
   Print("HOLD: ", DoubleToString(outputs[SIGNAL_HOLD], 4));
   Print("BUY:  ", DoubleToString(outputs[SIGNAL_BUY], 4));
   Print("SELL: ", DoubleToString(outputs[SIGNAL_SELL], 4));
   Print("Confidence: ", DoubleToString(lastConfidence, 4));
   Print("Signal: ", GetSignalDescription(GetTradingSignal()));
}

//+------------------------------------------------------------------+
//| Get prediction accuracy                                         |
//+------------------------------------------------------------------+
double DeepNeuralNetwork::GetAccuracy(void)
{
   if(predictionCount == 0)
      return 0.0;
   
   return (double)correctPredictions / (double)predictionCount * 100.0;
}

//+------------------------------------------------------------------+
//| Update performance tracking                                     |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::UpdatePerformance(int actualOutcome)
{
   int predictedSignal = GetTradingSignal();
   
   if(predictedSignal == actualOutcome)
      correctPredictions++;
}

//+------------------------------------------------------------------+
//| Reset performance counters                                      |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::ResetPerformance(void)
{
   predictionCount = 0;
   correctPredictions = 0;
}

//+------------------------------------------------------------------+
//| Get last error message                                          |
//+------------------------------------------------------------------+
string DeepNeuralNetwork::GetLastError(void)
{
   return lastError;
}

//+------------------------------------------------------------------+
//| Clear error state                                               |
//+------------------------------------------------------------------+
void DeepNeuralNetwork::ClearError(void)
{
   hasError = false;
   lastError = "";
}

