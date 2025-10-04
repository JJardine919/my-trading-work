//+------------------------------------------------------------------+
//|                               Neural Networks Propagation EA.mq5  |
//|                           Copyright 2025, Allan Munene Mutiiria.  |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link      "https://t.me/Forex_Algo_Trader"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade tradeObject; //--- Instantiate trade object for executing trades

// Input parameters with clear, meaningful names
input double LotSize            = 0.1;      // Lot Size
input int    StopLossPoints     = 100;      // Stop Loss (points)
input int    TakeProfitPoints   = 100;      // Take Profit (points)
input int    MinHiddenNeurons   = 10;       // Minimum Hidden Neurons
input int    MaxHiddenNeurons   = 50;       // Maximum Hidden Neurons
input int    TrainingBarCount   = 1000;     // Training Bars
input double MinPredictionAccuracy = 0.7;   // Minimum Prediction Accuracy
input double MinLearningRate    = 0.01;     // Minimum Learning Rate
input double MaxLearningRate    = 0.5;      // Maximum Learning Rate
input string InputToHiddenWeights = "0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1"; // Input-to-Hidden Weights
input string HiddenToOutputWeights = "0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1"; // Hidden-to-Output Weights
input string HiddenBiases       = "0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1,0.1,-0.1"; // Hidden Biases
input string OutputBiases       = "0.1,-0.1"; // Output Biases

// Neural Network Structure Constants
const int INPUT_NEURON_COUNT = 10; //--- Define number of input neurons
const int OUTPUT_NEURON_COUNT = 2; //--- Define number of output neurons
const int MAX_HISTORY_SIZE = 10;   //--- Define maximum history size for accuracy and error tracking

// Indicator handles
int ma20IndicatorHandle; //--- Handle for 20-period moving average
int ma50IndicatorHandle; //--- Handle for 50-period moving average
int rsiIndicatorHandle;  //--- Handle for RSI indicator
int atrIndicatorHandle;  //--- Handle for ATR indicator

// Training related structures
struct TrainingData {
   double inputValues[]; //--- Array to store input values for training
   double targetValues[]; //--- Array to store target values for training
};

// Neural Network Class
class CNeuralNetwork {
private:
   int inputNeuronCount;      //--- Number of input neurons
   int hiddenNeuronCount;     //--- Number of hidden neurons
   int outputNeuronCount;     //--- Number of output neurons
   double inputLayer[];       //--- Array for input layer values
   double hiddenLayer[];      //--- Array for hidden layer values
   double outputLayer[];      //--- Array for output layer values
   double inputToHiddenWeights[]; //--- Weights between input and hidden layers
   double hiddenToOutputWeights[]; //--- Weights between hidden and output layers
   double hiddenLayerBiases[];    //--- Biases for hidden layer
   double outputLayerBiases[];    //--- Biases for output layer
   double outputDeltas[];         //--- Delta values for output layer
   double hiddenDeltas[];         //--- Delta values for hidden layer
   double trainingError;          //--- Current training error
   double currentLearningRate;    //--- Current learning rate
   double accuracyHistory[];      //--- History of training accuracy
   double errorHistory[];         //--- History of training errors
   int historyRecordCount;        //--- Number of recorded history entries

   // Parse comma-separated string to array
   bool ParseStringToArray(string inputString, double &output[], int expectedSize) {
      //--- Check if input string is empty
      if(inputString == "") return false;
      string values[];
      //--- Initialize array for parsed values
      ArrayResize(values, 0);
      //--- Split input string by comma
      int count = StringSplit(inputString, 44, values);
      //--- Check if string splitting failed
      if(count <= 0) {
         Print("Error: StringSplit failed for input: ", inputString, ". Error code: ", GetLastError());
         return false;
      }
      //--- Verify correct number of values
      if(count != expectedSize) {
         Print("Error: Invalid number of values in input string. Expected: ", expectedSize, ", Got: ", count);
         return false;
      }
      //--- Resize output array to expected size
      ArrayResize(output, expectedSize);
      //--- Convert string values to doubles and normalize
      for(int i = 0; i < count; i++) {
         output[i] = StringToDouble(values[i]);
         //--- Clamp values between -1.0 and 1.0
         if(MathAbs(output[i]) > 1.0) output[i] = MathMax(-1.0, MathMin(1.0, output[i]));
      }
      return true;
   }

public:
   CNeuralNetwork(int inputs, int hidden, int outputs); //--- Constructor
   void InitializeWeights(); //--- Initialize network weights
   double Sigmoid(double x); //--- Apply sigmoid activation function
   void ForwardPropagate(); //--- Perform forward propagation
   void Backpropagate(const double &targets[]); //--- Perform backpropagation
   void SetInput(double &inputs[]); //--- Set input values
   void GetOutput(double &outputs[]); //--- Retrieve output values
   double TrainOnHistoricalData(TrainingData &data[]); //--- Train on historical data
   void UpdateNetworkWithRecentData(); //--- Update with recent data
   void InitializeTraining(); //--- Initialize training arrays
   void ResizeNetwork(int newHiddenNeurons); //--- Resize network
   void AdjustLearningRate(); //--- Adjust learning rate dynamically
   double GetRecentAccuracy(); //--- Get recent training accuracy
   double GetRecentError(); //--- Get recent training error
   bool ShouldRetrain(); //--- Check if retraining is needed
   double CalculateDynamicNeurons(); //--- Calculate dynamic neuron count
   int GetHiddenNeurons() {
      return hiddenNeuronCount;   //--- Get current hidden neuron count
   }
};

// Constructor
CNeuralNetwork::CNeuralNetwork(int inputs, int hidden, int outputs) {
   //--- Set input neuron count
   inputNeuronCount = inputs;
   //--- Set output neuron count
   outputNeuronCount = outputs;
   //--- Initialize learning rate to minimum
   currentLearningRate = MinLearningRate;
   //--- Set hidden neuron count
   hiddenNeuronCount = hidden;
   //--- Ensure hidden neurons within bounds
   if(hiddenNeuronCount < MinHiddenNeurons) hiddenNeuronCount = MinHiddenNeurons;
   if(hiddenNeuronCount > MaxHiddenNeurons) hiddenNeuronCount = MaxHiddenNeurons;
   //--- Resize input layer array
   ArrayResize(inputLayer, inputs);
   //--- Resize hidden layer array
   ArrayResize(hiddenLayer, hiddenNeuronCount);
   //--- Resize output layer array
   ArrayResize(outputLayer, outputs);
   //--- Resize input-to-hidden weights array
   ArrayResize(inputToHiddenWeights, inputs * hiddenNeuronCount);
   //--- Resize hidden-to-output weights array
   ArrayResize(hiddenToOutputWeights, hiddenNeuronCount * outputs);
   //--- Resize hidden biases array
   ArrayResize(hiddenLayerBiases, hiddenNeuronCount);
   //--- Resize output biases array
   ArrayResize(outputLayerBiases, outputs);
   //--- Resize accuracy history array
   ArrayResize(accuracyHistory, MAX_HISTORY_SIZE);
   //--- Resize error history array
   ArrayResize(errorHistory, MAX_HISTORY_SIZE);
   //--- Initialize history record count
   historyRecordCount = 0;
   //--- Initialize training error
   trainingError = 0.0;
   //--- Initialize network weights
   InitializeWeights();
   //--- Initialize training arrays
   InitializeTraining();
}

// Initialize training arrays
void CNeuralNetwork::InitializeTraining() {
   //--- Resize output deltas array
   ArrayResize(outputDeltas, outputNeuronCount);
   //--- Resize hidden deltas array
   ArrayResize(hiddenDeltas, hiddenNeuronCount);
}

// Initialize weights
void CNeuralNetwork::InitializeWeights() {
   //--- Track if weights and biases are set
   bool isInputToHiddenWeightsSet = false;
   bool isHiddenToOutputWeightsSet = false;
   bool isHiddenBiasesSet = false;
   bool isOutputBiasesSet = false;
   double tempInputToHiddenWeights[];
   double tempHiddenToOutputWeights[];
   double tempHiddenBiases[];
   double tempOutputBiases[];

   //--- Parse and set input-to-hidden weights if provided
   if(InputToHiddenWeights != "" && ParseStringToArray(InputToHiddenWeights, tempInputToHiddenWeights, inputNeuronCount * hiddenNeuronCount)) {
      //--- Copy parsed weights to main array
      ArrayCopy(inputToHiddenWeights, tempInputToHiddenWeights);
      isInputToHiddenWeightsSet = true;
      //--- Log weight initialization
      Print("Initialized input-to-hidden weights from input: ", InputToHiddenWeights);
   }
   //--- Parse and set hidden-to-output weights if provided
   if(HiddenToOutputWeights != "" && ParseStringToArray(HiddenToOutputWeights, tempHiddenToOutputWeights, hiddenNeuronCount * outputNeuronCount)) {
      //--- Copy parsed weights to main array
      ArrayCopy(hiddenToOutputWeights, tempHiddenToOutputWeights);
      isHiddenToOutputWeightsSet = true;
      //--- Log weight initialization
      Print("Initialized hidden-to-output weights from input: ", HiddenToOutputWeights);
   }
   //--- Parse and set hidden biases if provided
   if(HiddenBiases != "" && ParseStringToArray(HiddenBiases, tempHiddenBiases, hiddenNeuronCount)) {
      //--- Copy parsed biases to main array
      ArrayCopy(hiddenLayerBiases, tempHiddenBiases);
      isHiddenBiasesSet = true;
      //--- Log bias initialization
      Print("Initialized hidden biases from input: ", HiddenBiases);
   }
   //--- Parse and set output biases if provided
   if(OutputBiases != "" && ParseStringToArray(OutputBiases, tempOutputBiases, outputNeuronCount)) {
      //--- Copy parsed biases to main array
      ArrayCopy(outputLayerBiases, tempOutputBiases);
      isOutputBiasesSet = true;
      //--- Log bias initialization
      Print("Initialized output biases from input: ", OutputBiases);
   }

   //--- Initialize input-to-hidden weights randomly if not set
   if(!isInputToHiddenWeightsSet) {
      for(int i = 0; i < ArraySize(inputToHiddenWeights); i++)
         inputToHiddenWeights[i] = (MathRand() / 32767.0) * 2 - 1;
   }
   //--- Initialize hidden-to-output weights randomly if not set
   if(!isHiddenToOutputWeightsSet) {
      for(int i = 0; i < ArraySize(hiddenToOutputWeights); i++)
         hiddenToOutputWeights[i] = (MathRand() / 32767.0) * 2 - 1;
   }
   //--- Initialize hidden biases randomly if not set
   if(!isHiddenBiasesSet) {
      for(int i = 0; i < ArraySize(hiddenLayerBiases); i++)
         hiddenLayerBiases[i] = (MathRand() / 32767.0) * 2 - 1;
   }
   //--- Initialize output biases randomly if not set
   if(!isOutputBiasesSet) {
      for(int i = 0; i < ArraySize(outputLayerBiases); i++)
         outputLayerBiases[i] = (MathRand() / 32767.0) * 2 - 1;
   }
}

// Sigmoid activation function
double CNeuralNetwork::Sigmoid(double x) {
   //--- Compute and return sigmoid value
   return 1.0 / (1.0 + MathExp(-x));
}

// Set input
void CNeuralNetwork::SetInput(double &inputs[]) {
   //--- Check for input array size mismatch
   if(ArraySize(inputs) != inputNeuronCount) {
      Print("Error: Input array size mismatch. Expected: ", inputNeuronCount, ", Got: ", ArraySize(inputs));
      return;
   }
   //--- Copy inputs to input layer
   ArrayCopy(inputLayer, inputs);
}

// Forward propagation
void CNeuralNetwork::ForwardPropagate() {
   //--- Compute hidden layer values
   for(int j = 0; j < hiddenNeuronCount; j++) {
      double sum = 0;
      //--- Calculate weighted sum for hidden neuron
      for(int i = 0; i < inputNeuronCount; i++)
         sum += inputLayer[i] * inputToHiddenWeights[i * hiddenNeuronCount + j];
      //--- Apply sigmoid activation
      hiddenLayer[j] = Sigmoid(sum + hiddenLayerBiases[j]);
   }
   //--- Compute output layer values
   for(int j = 0; j < outputNeuronCount; j++) {
      double sum = 0;
      //--- Calculate weighted sum for output neuron
      for(int i = 0; i < hiddenNeuronCount; i++)
         sum += hiddenLayer[i] * hiddenToOutputWeights[i * outputNeuronCount + j];
      //--- Apply sigmoid activation
      outputLayer[j] = Sigmoid(sum + outputLayerBiases[j]);
   }
}

// Get output
void CNeuralNetwork::GetOutput(double &outputs[]) {
   //--- Resize output array
   ArrayResize(outputs, outputNeuronCount);
   //--- Copy output layer to outputs
   ArrayCopy(outputs, outputLayer);
}

// Backpropagation
void CNeuralNetwork::Backpropagate(const double &targets[]) {
   //--- Calculate output layer deltas
   for(int i = 0; i < outputNeuronCount; i++) {
      double output = outputLayer[i];
      //--- Compute delta for output neuron
      outputDeltas[i] = output * (1 - output) * (targets[i] - output);
   }
   //--- Calculate hidden layer deltas
   for(int i = 0; i < hiddenNeuronCount; i++) {
      double error = 0;
      //--- Sum weighted errors from output layer
      for(int j = 0; j < outputNeuronCount; j++)
         error += outputDeltas[j] * hiddenToOutputWeights[i * outputNeuronCount + j];
      double output = hiddenLayer[i];
      //--- Compute delta for hidden neuron
      hiddenDeltas[i] = output * (1 - output) * error;
   }
   //--- Update hidden-to-output weights
   for(int i = 0; i < hiddenNeuronCount; i++) {
      for(int j = 0; j < outputNeuronCount; j++) {
         int idx = i * outputNeuronCount + j;
         //--- Adjust weight based on learning rate and delta
         hiddenToOutputWeights[idx] += currentLearningRate * outputDeltas[j] * hiddenLayer[i];
      }
   }
   //--- Update input-to-hidden weights
   for(int i = 0; i < inputNeuronCount; i++) {
      for(int j = 0; j < hiddenNeuronCount; j++) {
         int idx = i * hiddenNeuronCount + j;
         //--- Adjust weight based on learning rate and delta
         inputToHiddenWeights[idx] += currentLearningRate * hiddenDeltas[j] * inputLayer[i];
      }
   }
   //--- Update hidden biases
   for(int i = 0; i < hiddenNeuronCount; i++)
      //--- Adjust bias based on learning rate and delta
      hiddenLayerBiases[i] += currentLearningRate * hiddenDeltas[i];
   //--- Update output biases
   for(int i = 0; i < outputNeuronCount; i++)
      //--- Adjust bias based on learning rate and delta
      outputLayerBiases[i] += currentLearningRate * outputDeltas[i];
}

// Resize network (adjust hidden neurons)
void CNeuralNetwork::ResizeNetwork(int newHiddenNeurons) {
   //--- Clamp new neuron count within bounds
   newHiddenNeurons = MathMax(MinHiddenNeurons, MathMin(newHiddenNeurons, MaxHiddenNeurons));
   //--- Check if resizing is necessary
   if(newHiddenNeurons == hiddenNeuronCount)
      return;
   //--- Log resizing information
   Print("Resizing network. New hidden neurons: ", newHiddenNeurons, ", Previous: ", hiddenNeuronCount);
   //--- Update hidden neuron count
   hiddenNeuronCount = newHiddenNeurons;
   //--- Resize hidden layer array
   ArrayResize(hiddenLayer, hiddenNeuronCount);
   //--- Resize input-to-hidden weights array
   ArrayResize(inputToHiddenWeights, inputNeuronCount * hiddenNeuronCount);
   //--- Resize hidden-to-output weights array
   ArrayResize(hiddenToOutputWeights, hiddenNeuronCount * outputNeuronCount);
   //--- Resize hidden biases array
   ArrayResize(hiddenLayerBiases, hiddenNeuronCount);
   //--- Resize hidden deltas array
   ArrayResize(hiddenDeltas, hiddenNeuronCount);
   //--- Reinitialize weights
   InitializeWeights();
}

// Adjust learning rate based on error trend
void CNeuralNetwork::AdjustLearningRate() {
   //--- Check if enough history exists
   if(historyRecordCount < 2) return;
   //--- Get last and previous errors
   double lastError = errorHistory[historyRecordCount - 1];
   double prevError = errorHistory[historyRecordCount - 2];
   //--- Calculate error difference
   double errorDiff = lastError - prevError;
   //--- Increase learning rate if error decreased
   if(lastError < prevError)
      currentLearningRate = MathMin(currentLearningRate * 1.05, MaxLearningRate);
   //--- Decrease learning rate if error increased significantly
   else if(lastError > prevError * 1.2)
      currentLearningRate = MathMax(currentLearningRate * 0.9, MinLearningRate);
   //--- Slightly decrease learning rate otherwise
   else
      currentLearningRate = MathMax(currentLearningRate * 0.99, MinLearningRate);
   //--- Log learning rate adjustment
   Print("Adjusted learning rate to: ", currentLearningRate, ", Last Error: ", lastError, ", Prev Error: ", prevError, ", Error Diff: ", errorDiff);
}

// Calculate dynamic number of hidden neurons based on ATR
double CNeuralNetwork::CalculateDynamicNeurons() {
   double atrValues[];
   //--- Set ATR array as series
   ArraySetAsSeries(atrValues, true);
   //--- Copy ATR buffer
   if(CopyBuffer(atrIndicatorHandle, 0, 0, 10, atrValues) < 10) {
      Print("Error: Failed to copy ATR for dynamic neurons. Using default: ", hiddenNeuronCount);
      return hiddenNeuronCount;
   }
   //--- Calculate average ATR
   double avgATR = 0;
   for(int i = 0; i < 10; i++)
      avgATR += atrValues[i];
   avgATR /= 10;
   //--- Get current close price
   double closePrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   //--- Check for valid close price
   if(MathAbs(closePrice) < 0.000001) {
      Print("Error: Invalid close price for ATR ratio. Using default: ", hiddenNeuronCount);
      return hiddenNeuronCount;
   }
   //--- Calculate ATR ratio
   double atrRatio = atrValues[0] / closePrice;
   //--- Compute new neuron count
   int newNeurons = MinHiddenNeurons + (int)((MaxHiddenNeurons - MinHiddenNeurons) * MathMin(atrRatio * 100, 1.0));
   //--- Return clamped neuron count
   return MathMax(MinHiddenNeurons, MathMin(newNeurons, MaxHiddenNeurons));
}

// Train network on historical data
double CNeuralNetwork::TrainOnHistoricalData(TrainingData &data[]) {
   const int maxEpochs = 100; //--- Maximum training epochs
   const double targetError = 0.01; //--- Target error threshold
   double accuracy = 0; //--- Training accuracy
   //--- Reset learning rate
   currentLearningRate = MinLearningRate;
   //--- Iterate through epochs
   for(int epoch = 0; epoch < maxEpochs; epoch++) {
      double totalError = 0; //--- Total error for epoch
      int correctPredictions = 0; //--- Count of correct predictions
      //--- Process each training sample
      for(int i = 0; i < ArraySize(data); i++) {
         //--- Check target array size
         if(ArraySize(data[i].targetValues) != outputNeuronCount) {
            Print("Error: Mismatch in targets size for training data at index ", i);
            continue;
         }
         //--- Set input values
         SetInput(data[i].inputValues);
         //--- Perform forward propagation
         ForwardPropagate();
         double error = 0;
         //--- Calculate error
         for(int j = 0; j < outputNeuronCount; j++)
            error += MathPow(data[i].targetValues[j] - outputLayer[j], 2);
         totalError += error;
         //--- Check prediction correctness
         if((outputLayer[0] > outputLayer[1] && data[i].targetValues[0] > data[i].targetValues[1]) ||
               (outputLayer[0] < outputLayer[1] && data[i].targetValues[0] < data[i].targetValues[1]))
            correctPredictions++;
         //--- Perform backpropagation
         Backpropagate(data[i].targetValues);
      }
      //--- Calculate accuracy
      accuracy = (double)correctPredictions / ArraySize(data);
      //--- Update training error
      trainingError = totalError / ArraySize(data);
      //--- Update history
      if(historyRecordCount < MAX_HISTORY_SIZE) {
         accuracyHistory[historyRecordCount] = accuracy;
         errorHistory[historyRecordCount] = trainingError;
         historyRecordCount++;
      } else {
         //--- Shift history arrays
         for(int i = 1; i < MAX_HISTORY_SIZE; i++) {
            accuracyHistory[i - 1] = accuracyHistory[i];
            errorHistory[i - 1] = errorHistory[i];
         }
         //--- Add new values
         accuracyHistory[MAX_HISTORY_SIZE - 1] = accuracy;
         errorHistory[MAX_HISTORY_SIZE - 1] = trainingError;
      }
      //--- Log error history update
      Print("Error history updated: ", errorHistory[historyRecordCount - 1]);
      //--- Adjust learning rate
      AdjustLearningRate();
      //--- Log progress every 10 epochs
      if(epoch % 10 == 0)
         Print("Epoch ", epoch, ": Error = ", trainingError, ", Accuracy = ", accuracy);
      //--- Check for early stopping
      if(trainingError < targetError && accuracy >= MinPredictionAccuracy)
         break;
   }
   //--- Return final accuracy
   return accuracy;
}

// Update network with recent data
void CNeuralNetwork::UpdateNetworkWithRecentData() {
   const int recentBarCount = 10; //--- Number of recent bars to process
   TrainingData recentData[];
   //--- Collect recent training data
   if(!CollectTrainingData(recentData, recentBarCount))
      return;
   //--- Process each recent data sample
   for(int i = 0; i < ArraySize(recentData); i++) {
      //--- Set input values
      SetInput(recentData[i].inputValues);
      //--- Perform forward propagation
      ForwardPropagate();
      //--- Perform backpropagation
      Backpropagate(recentData[i].targetValues);
   }
}

// Get recent accuracy
double CNeuralNetwork::GetRecentAccuracy() {
   //--- Check if history exists
   if(historyRecordCount == 0) return 0.0;
   //--- Return most recent accuracy
   return accuracyHistory[historyRecordCount - 1];
}

// Get recent error
double CNeuralNetwork::GetRecentError() {
   //--- Check if history exists
   if(historyRecordCount == 0) return 0.0;
   //--- Return most recent error
   return errorHistory[historyRecordCount - 1];
}

// Check if retraining is needed
bool CNeuralNetwork::ShouldRetrain() {
   //--- Check if enough history exists
   if(historyRecordCount < 2) return false;
   //--- Get recent metrics
   double recentAccuracy = GetRecentAccuracy();
   double recentError = GetRecentError();
   double prevError = errorHistory[historyRecordCount - 2];
   //--- Determine if retraining is needed
   return (recentAccuracy < MinPredictionAccuracy || recentError > prevError * 1.5);
}

// Global neural network instance
CNeuralNetwork *neuralNetwork; //--- Global neural network object

// Prepare inputs from market data
void PrepareInputs(double &inputs[]) {
   //--- Resize inputs array if necessary
   if(ArraySize(inputs) != INPUT_NEURON_COUNT)
      ArrayResize(inputs, INPUT_NEURON_COUNT);
   double ma20Values[], ma50Values[], rsiValues[], atrValues[];
   //--- Set arrays as series
   ArraySetAsSeries(ma20Values, true);
   ArraySetAsSeries(ma50Values, true);
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(atrValues, true);
   //--- Copy MA20 buffer
   if(CopyBuffer(ma20IndicatorHandle, 0, 0, 2, ma20Values) <= 0) {
      Print("Error: Failed to copy MA20 buffer. Error code: ", GetLastError());
      return;
   }
   //--- Copy MA50 buffer
   if(CopyBuffer(ma50IndicatorHandle, 0, 0, 2, ma50Values) <= 0) {
      Print("Error: Failed to copy MA50 buffer. Error code: ", GetLastError());
      return;
   }
   //--- Copy RSI buffer
   if(CopyBuffer(rsiIndicatorHandle, 0, 0, 2, rsiValues) <= 0) {
      Print("Error: Failed to copy RSI buffer. Error code: ", GetLastError());
      return;
   }
   //--- Copy ATR buffer
   if(CopyBuffer(atrIndicatorHandle, 0, 0, 2, atrValues) <= 0) {
      Print("Error: Failed to copy ATR buffer. Error code: ", GetLastError());
      return;
   }
   //--- Check array sizes
   if(ArraySize(ma20Values) < 2 || ArraySize(ma50Values) < 2 || ArraySize(rsiValues) < 2 || ArraySize(atrValues) < 2) {
      Print("Error: Insufficient data in indicator arrays");
      return;
   }
   //--- Get current market prices
   double closePrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double openPrice = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double highPrice = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double lowPrice = iLow(_Symbol, PERIOD_CURRENT, 0);
   //--- Calculate input features
   inputs[0] = (MathAbs(openPrice) > 0.000001) ? (closePrice - openPrice) / openPrice : 0;
   inputs[1] = (MathAbs(lowPrice) > 0.000001) ? (highPrice - lowPrice) / lowPrice : 0;
   inputs[2] = (MathAbs(ma20Values[0]) > 0.000001) ? (closePrice - ma20Values[0]) / ma20Values[0] : 0;
   inputs[3] = (MathAbs(ma50Values[0]) > 0.000001) ? (ma20Values[0] - ma50Values[0]) / ma50Values[0] : 0;
   inputs[4] = rsiValues[0] / 100.0;
   double highLowRange = highPrice - lowPrice;
   if(MathAbs(highLowRange) > 0.000001) {
      inputs[5] = (closePrice - lowPrice) / highLowRange;
      inputs[7] = MathAbs(closePrice - openPrice) / highLowRange;
      inputs[8] = (highPrice - closePrice) / highLowRange;
      inputs[9] = (closePrice - lowPrice) / highLowRange;
   } else {
      inputs[5] = 0;
      inputs[7] = 0;
      inputs[8] = 0;
      inputs[9] = 0;
   }
   inputs[6] = (MathAbs(closePrice) > 0.000001) ? atrValues[0] / closePrice : 0;
   //--- Log input preparation
   Print("Prepared inputs. Size: ", ArraySize(inputs));
}

// Collect training data
bool CollectTrainingData(TrainingData &data[], int barCount) {
   //--- Check output neuron count
   if(OUTPUT_NEURON_COUNT != 2) {
      Print("Error: OUTPUT_NEURON_COUNT must be 2 for binary classification.");
      return false;
   }
   //--- Resize data array
   ArrayResize(data, barCount);
   double ma20Values[], ma50Values[], rsiValues[], atrValues[];
   //--- Set arrays as series
   ArraySetAsSeries(ma20Values, true);
   ArraySetAsSeries(ma50Values, true);
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(atrValues, true);
   //--- Copy MA20 buffer
   if(CopyBuffer(ma20IndicatorHandle, 0, 0, barCount + 1, ma20Values) < barCount + 1) {
      Print("Error: Failed to copy MA20 buffer for training. Error code: ", GetLastError());
      return false;
   }
   //--- Copy MA50 buffer
   if(CopyBuffer(ma50IndicatorHandle, 0, 0, barCount + 1, ma50Values) < barCount + 1) {
      Print("Error: Failed to copy MA50 buffer for training. Error code: ", GetLastError());
      return false;
   }
   //--- Copy RSI buffer
   if(CopyBuffer(rsiIndicatorHandle, 0, 0, barCount + 1, rsiValues) < barCount + 1) {
      Print("Error: Failed to copy RSI buffer for training. Error code: ", GetLastError());
      return false;
   }
   //--- Copy ATR buffer
   if(CopyBuffer(atrIndicatorHandle, 0, 0, barCount + 1, atrValues) < barCount + 1) {
      Print("Error: Failed to copy ATR buffer for training. Error code: ", GetLastError());
      return false;
   }
   MqlRates priceData[];
   //--- Set rates array as series
   ArraySetAsSeries(priceData, true);
   //--- Copy price data
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, barCount + 1, priceData) < barCount + 1) {
      Print("Error: Failed to copy rates for training. Error code: ", GetLastError());
      return false;
   }
   //--- Process each bar
   for(int i = 0; i < barCount; i++) {
      //--- Resize input and target arrays
      ArrayResize(data[i].inputValues, INPUT_NEURON_COUNT);
      ArrayResize(data[i].targetValues, OUTPUT_NEURON_COUNT);
      //--- Get price data
      double closePrice = priceData[i].close;
      double openPrice = priceData[i].open;
      double highPrice = priceData[i].high;
      double lowPrice = priceData[i].low;
      double highLowRange = highPrice - lowPrice;
      //--- Calculate input features
      data[i].inputValues[0] = (MathAbs(openPrice) > 0.000001) ? (closePrice - openPrice) / openPrice : 0;
      data[i].inputValues[1] = (MathAbs(lowPrice) > 0.000001) ? (highPrice - lowPrice) / lowPrice : 0;
      data[i].inputValues[2] = (MathAbs(ma20Values[i]) > 0.000001) ? (closePrice - ma20Values[i]) / ma20Values[i] : 0;
      data[i].inputValues[3] = (MathAbs(ma50Values[i]) > 0.000001) ? (ma20Values[i] - ma50Values[i]) / ma50Values[i] : 0;
      data[i].inputValues[4] = rsiValues[i] / 100.0;
      if(MathAbs(highLowRange) > 0.000001) {
         data[i].inputValues[5] = (closePrice - lowPrice) / highLowRange;
         data[i].inputValues[7] = MathAbs(closePrice - openPrice) / highLowRange;
         data[i].inputValues[8] = (highPrice - closePrice) / highLowRange;
         data[i].inputValues[9] = (closePrice - lowPrice) / highLowRange;
      }
      data[i].inputValues[6] = (MathAbs(closePrice) > 0.000001) ? atrValues[i] / closePrice : 0;
      //--- Set target values based on price movement
      if(i < barCount - 1) {
         double futureClose = priceData[i + 1].close;
         double priceChange = futureClose - closePrice;
         if(priceChange > 0) {
            data[i].targetValues[0] = 1;
            data[i].targetValues[1] = 0;
         } else {
            data[i].targetValues[0] = 0;
            data[i].targetValues[1] = 1;
         }
      } else {
         data[i].targetValues[0] = 0;
         data[i].targetValues[1] = 0;
      }
   }
   //--- Return success
   return true;
}

// Train the neural network
bool TrainNetwork() {
   //--- Log training start
   Print("Starting neural network training...");
   TrainingData trainingData[];
   //--- Collect training data
   if(!CollectTrainingData(trainingData, TrainingBarCount)) {
      Print("Failed to collect training data");
      return false;
   }
   //--- Train network
   double accuracy = neuralNetwork.TrainOnHistoricalData(trainingData);
   //--- Log training completion
   Print("Training completed. Final accuracy: ", accuracy);
   //--- Return training success
   return (accuracy >= MinPredictionAccuracy);
}

// Validate Stop Loss and Take Profit levels
bool CheckStopLossTakeprofit(ENUM_ORDER_TYPE orderType, double price, double stopLoss, double takeProfit) {
   //--- Get minimum stop level
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   //--- Validate buy order
   if(orderType == ORDER_TYPE_BUY) {
      //--- Check stop loss distance
      if(MathAbs(price - stopLoss) < stopLevel) {
         Print("Buy Stop Loss too close. Minimum distance: ", stopLevel);
         return false;
      }
      //--- Check take profit distance
      if(MathAbs(takeProfit - price) < stopLevel) {
         Print("Buy Take Profit too close. Minimum distance: ", stopLevel);
         return false;
      }
   }
   //--- Validate sell order
   else if(orderType == ORDER_TYPE_SELL) {
      //--- Check stop loss distance
      if(MathAbs(stopLoss - price) < stopLevel) {
         Print("Sell Stop Loss too close. Minimum distance: ", stopLevel);
         return false;
      }
      //--- Check take profit distance
      if(MathAbs(price - takeProfit) < stopLevel) {
         Print("Sell Take Profit too close. Minimum distance: ", stopLevel);
         return false;
      }
   }
   //--- Return validation success
   return true;
}

// Expert initialization function
int OnInit() {
   //--- Initialize 20-period MA indicator
   ma20IndicatorHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   //--- Initialize 50-period MA indicator
   ma50IndicatorHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
   //--- Initialize RSI indicator
   rsiIndicatorHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   //--- Initialize ATR indicator
   atrIndicatorHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   //--- Check MA20 handle
   if(ma20IndicatorHandle == INVALID_HANDLE)
      Print("Error: Failed to initialize MA20 handle. Error code: ", GetLastError());
   //--- Check MA50 handle
   if(ma50IndicatorHandle == INVALID_HANDLE)
      Print("Error: Failed to initialize MA50 handle. Error code: ", GetLastError());
   //--- Check RSI handle
   if(rsiIndicatorHandle == INVALID_HANDLE)
      Print("Error: Failed to initialize RSI handle. Error code: ", GetLastError());
   //--- Check ATR handle
   if(atrIndicatorHandle == INVALID_HANDLE)
      Print("Error: Failed to initialize ATR handle. Error code: ", GetLastError());
   //--- Check for any invalid handles
   if(ma20IndicatorHandle == INVALID_HANDLE || ma50IndicatorHandle == INVALID_HANDLE ||
         rsiIndicatorHandle == INVALID_HANDLE || atrIndicatorHandle == INVALID_HANDLE) {
      Print("Error initializing indicators");
      return INIT_FAILED;
   }
   //--- Create neural network instance
   neuralNetwork = new CNeuralNetwork(INPUT_NEURON_COUNT, MinHiddenNeurons, OUTPUT_NEURON_COUNT);
   //--- Check neural network creation
   if(neuralNetwork == NULL) {
      Print("Failed to create neural network");
      return INIT_FAILED;
   }
   //--- Log initialization
   Print("Initializing neural network...");
   //--- Return success
   return(INIT_SUCCEEDED);
}

// Expert deinitialization function
void OnDeinit(const int reason) {
   //--- Release MA20 indicator handle
   if(ma20IndicatorHandle != INVALID_HANDLE) IndicatorRelease(ma20IndicatorHandle);
   //--- Release MA50 indicator handle
   if(ma50IndicatorHandle != INVALID_HANDLE) IndicatorRelease(ma50IndicatorHandle);
   //--- Release RSI indicator handle
   if(rsiIndicatorHandle != INVALID_HANDLE) IndicatorRelease(rsiIndicatorHandle);
   //--- Release ATR indicator handle
   if(atrIndicatorHandle != INVALID_HANDLE) IndicatorRelease(atrIndicatorHandle);
   //--- Delete neural network instance
   if(neuralNetwork != NULL) delete neuralNetwork;
   //--- Log deinitialization
   Print("Expert Advisor deinitialized - ", EnumToString((ENUM_INIT_RETCODE)reason));
}

// Expert tick function
void OnTick() {
   static datetime lastBarTime = 0; //--- Track last processed bar time
   //--- Get current bar time
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   //--- Skip if same bar
   if(lastBarTime == currentBarTime)
      return;
   //--- Update last bar time
   lastBarTime = currentBarTime;

   //--- Calculate dynamic neuron count
   int newNeuronCount = (int)neuralNetwork.CalculateDynamicNeurons();
   //--- Resize network if necessary
   if(newNeuronCount != neuralNetwork.GetHiddenNeurons())
      neuralNetwork.ResizeNetwork(newNeuronCount);

   //--- Check if retraining is needed
   if(TimeCurrent() - iTime(_Symbol, PERIOD_CURRENT, TrainingBarCount) >= 12 * 3600 || neuralNetwork.ShouldRetrain()) {
      //--- Log training start
      Print("Starting network training...");
      //--- Train network
      if(!TrainNetwork()) {
         Print("Training failed or insufficient accuracy");
         return;
      }
   }

   //--- Update network with recent data
   neuralNetwork.UpdateNetworkWithRecentData();

   //--- Check for open positions
   if(PositionsTotal() > 0) {
      //--- Iterate through positions
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         //--- Skip if position is for current symbol
         if(PositionGetSymbol(i) == _Symbol)
            return;
      }
   }

   //--- Prepare input data
   double currentInputs[];
   ArrayResize(currentInputs, INPUT_NEURON_COUNT);
   PrepareInputs(currentInputs);
   //--- Verify input array size
   if(ArraySize(currentInputs) != INPUT_NEURON_COUNT) {
      Print("Error: Inputs array not properly initialized. Size: ", ArraySize(currentInputs));
      return;
   }
   //--- Set network inputs
   neuralNetwork.SetInput(currentInputs);
   //--- Perform forward propagation
   neuralNetwork.ForwardPropagate();
   double outputValues[];
   //--- Resize output array
   ArrayResize(outputValues, OUTPUT_NEURON_COUNT);
   //--- Get network outputs
   neuralNetwork.GetOutput(outputValues);
   //--- Verify output array size
   if(ArraySize(outputValues) != OUTPUT_NEURON_COUNT) {
      Print("Error: Outputs array not properly initialized. Size: ", ArraySize(outputValues));
      return;
   }

   //--- Get market prices
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   //--- Calculate stop loss and take profit levels
   double buyStopLoss = NormalizeDouble(askPrice - StopLossPoints * _Point, _Digits);
   double buyTakeProfit = NormalizeDouble(askPrice + TakeProfitPoints * _Point, _Digits);
   double sellStopLoss = NormalizeDouble(bidPrice + StopLossPoints * _Point, _Digits);
   double sellTakeProfit = NormalizeDouble(bidPrice - TakeProfitPoints * _Point, _Digits);

   //--- Validate stop loss and take profit
   if(!CheckStopLossTakeprofit(ORDER_TYPE_BUY, askPrice, buyStopLoss, buyTakeProfit) ||
         !CheckStopLossTakeprofit(ORDER_TYPE_SELL, bidPrice, sellStopLoss, sellTakeProfit)) {
      return;
   }

   // Trading logic
   const double CONFIDENCE_THRESHOLD = 0.8; //--- Confidence threshold for trading
   //--- Check for buy signal
   if(outputValues[0] > CONFIDENCE_THRESHOLD && outputValues[1] < (1 - CONFIDENCE_THRESHOLD)) {
      //--- Set trade magic number
      tradeObject.SetExpertMagicNumber(123456);
      //--- Place buy order
      if(tradeObject.Buy(LotSize, _Symbol, askPrice, buyStopLoss, buyTakeProfit, "Neural Buy")) {
         //--- Log successful buy order
         Print("Buy order placed - Signal Strength: ", outputValues[0]);
      } else {
         //--- Log buy order failure
         Print("Buy order failed. Error: ", GetLastError());
      }
   }
   //--- Check for sell signal
   else if(outputValues[0] < (1 - CONFIDENCE_THRESHOLD) && outputValues[1] > CONFIDENCE_THRESHOLD) {
      //--- Set trade magic number
      tradeObject.SetExpertMagicNumber(123456);
      //--- Place sell order
      if(tradeObject.Sell(LotSize, _Symbol, bidPrice, sellStopLoss, sellTakeProfit, "Neural Sell")) {
         //--- Log successful sell order
         Print("Sell order placed - Signal Strength: ", outputValues[1]);
      } else {
         //--- Log sell order failure
         Print("Sell order failed. Error: ", GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
