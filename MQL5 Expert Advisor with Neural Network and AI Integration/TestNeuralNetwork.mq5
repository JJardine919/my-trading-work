//+------------------------------------------------------------------+
//|                                           TestNeuralNetwork.mq5 |
//|                                                        Manus AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "DeepNeuralNetwork.mqh"

//--- Input parameters
input bool TestBasicFunctionality = true;    // Test basic neural network functionality
input bool TestMarketFeatures = true;        // Test market feature extraction
input bool TestSignalGeneration = true;      // Test trading signal generation
input bool TestPerformanceTracking = true;   // Test performance tracking
input int  TestIterations = 100;             // Number of test iterations

//--- Global variables
DeepNeuralNetwork* neuralNet;

//+------------------------------------------------------------------+
//| Script program start function                                   |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== Neural Network Test Suite ===");
   
   // Initialize neural network
   neuralNet = new DeepNeuralNetwork();
   
   if(!neuralNet.Initialize())
   {
      Print("ERROR: Failed to initialize neural network");
      Print("Error: ", neuralNet.GetLastError());
      delete neuralNet;
      return;
   }
   
   Print("Neural network initialized successfully");
   
   // Run tests
   if(TestBasicFunctionality)
      RunBasicFunctionalityTest();
   
   if(TestMarketFeatures)
      RunMarketFeaturesTest();
   
   if(TestSignalGeneration)
      RunSignalGenerationTest();
   
   if(TestPerformanceTracking)
      RunPerformanceTrackingTest();
   
   // Print final network information
   neuralNet.PrintNetworkInfo();
   
   // Cleanup
   delete neuralNet;
   
   Print("=== Test Suite Completed ===");
}

//+------------------------------------------------------------------+
//| Test basic neural network functionality                        |
//+------------------------------------------------------------------+
void RunBasicFunctionalityTest()
{
   Print("\n--- Testing Basic Functionality ---");
   
   // Test with sample input data
   double testInputs[SIZEI];
   
   // Initialize test inputs with realistic market data
   testInputs[FEATURE_PRICE_CHANGE_1] = 0.001;    // 0.1% price change
   testInputs[FEATURE_PRICE_CHANGE_5] = 0.005;    // 0.5% price change
   testInputs[FEATURE_PRICE_CHANGE_20] = 0.02;    // 2% price change
   testInputs[FEATURE_VOLUME_RATIO] = 1.2;        // 20% above average volume
   testInputs[FEATURE_RSI] = 65.0;                // Slightly overbought
   testInputs[FEATURE_MACD_MAIN] = 0.0001;        // Positive MACD
   testInputs[FEATURE_MACD_SIGNAL] = 0.00005;     // MACD signal
   testInputs[FEATURE_BB_POSITION] = 0.7;         // Upper BB region
   testInputs[FEATURE_ATR_RATIO] = 0.015;         // 1.5% ATR
   testInputs[FEATURE_MOMENTUM] = 0.008;          // Positive momentum
   testInputs[FEATURE_VOLATILITY] = 0.012;        // Moderate volatility
   testInputs[FEATURE_TREND_STRENGTH] = 0.003;    // Weak uptrend
   
   // Compute outputs
   neuralNet.ComputeOutputs(testInputs);
   
   // Print results
   neuralNet.PrintOutputs();
   
   int signal = neuralNet.GetTradingSignal();
   double confidence = neuralNet.GetSignalConfidence();
   
   Print("Generated Signal: ", neuralNet.GetSignalDescription(signal));
   Print("Signal Confidence: ", DoubleToString(confidence, 4));
   
   if(confidence > 0.0 && confidence <= 1.0)
      Print("✓ Basic functionality test PASSED");
   else
      Print("✗ Basic functionality test FAILED - Invalid confidence");
}

//+------------------------------------------------------------------+
//| Test market feature extraction                                 |
//+------------------------------------------------------------------+
void RunMarketFeaturesTest()
{
   Print("\n--- Testing Market Feature Extraction ---");
   
   // Test if we have sufficient market data
   int bars = Bars(_Symbol, _Period);
   if(bars < 50)
   {
      Print("✗ Insufficient market data for testing (", bars, " bars)");
      return;
   }
   
   double features[SIZEI];
   neuralNet.PrepareMarketFeatures(features);
   
   if(neuralNet.GetLastError() != "")
   {
      Print("✗ Market feature extraction FAILED: ", neuralNet.GetLastError());
      neuralNet.ClearError();
      return;
   }
   
   // Validate extracted features
   bool allValid = true;
   for(int i = 0; i < SIZEI; i++)
   {
      if(!MathIsValidNumber(features[i]))
      {
         Print("✗ Invalid feature at index ", i, ": ", features[i]);
         allValid = false;
      }
   }
   
   if(allValid)
   {
      Print("✓ Market feature extraction test PASSED");
      Print("Sample features:");
      Print("  Price Change (1): ", DoubleToString(features[FEATURE_PRICE_CHANGE_1], 6));
      Print("  RSI: ", DoubleToString(features[FEATURE_RSI], 2));
      Print("  Volume Ratio: ", DoubleToString(features[FEATURE_VOLUME_RATIO], 3));
      Print("  Volatility: ", DoubleToString(features[FEATURE_VOLATILITY], 6));
   }
   else
   {
      Print("✗ Market feature extraction test FAILED");
   }
}

//+------------------------------------------------------------------+
//| Test signal generation with multiple scenarios                 |
//+------------------------------------------------------------------+
void RunSignalGenerationTest()
{
   Print("\n--- Testing Signal Generation ---");
   
   int signalCounts[3] = {0, 0, 0}; // HOLD, BUY, SELL
   double totalConfidence = 0.0;
   int validSignals = 0;
   
   // Test with various market scenarios
   for(int test = 0; test < TestIterations; test++)
   {
      double testInputs[SIZEI];
      
      // Generate random but realistic market data
      testInputs[FEATURE_PRICE_CHANGE_1] = (MathRand() / 32767.0 - 0.5) * 0.02;  // ±1%
      testInputs[FEATURE_PRICE_CHANGE_5] = (MathRand() / 32767.0 - 0.5) * 0.06;  // ±3%
      testInputs[FEATURE_PRICE_CHANGE_20] = (MathRand() / 32767.0 - 0.5) * 0.16; // ±8%
      testInputs[FEATURE_VOLUME_RATIO] = 0.5 + MathRand() / 32767.0 * 2.0;       // 0.5-2.5
      testInputs[FEATURE_RSI] = 20.0 + MathRand() / 32767.0 * 60.0;              // 20-80
      testInputs[FEATURE_MACD_MAIN] = (MathRand() / 32767.0 - 0.5) * 0.002;      // ±0.001
      testInputs[FEATURE_MACD_SIGNAL] = (MathRand() / 32767.0 - 0.5) * 0.002;    // ±0.001
      testInputs[FEATURE_BB_POSITION] = MathRand() / 32767.0;                     // 0-1
      testInputs[FEATURE_ATR_RATIO] = 0.005 + MathRand() / 32767.0 * 0.03;       // 0.5%-3.5%
      testInputs[FEATURE_MOMENTUM] = (MathRand() / 32767.0 - 0.5) * 0.04;        // ±2%
      testInputs[FEATURE_VOLATILITY] = 0.005 + MathRand() / 32767.0 * 0.02;      // 0.5%-2.5%
      testInputs[FEATURE_TREND_STRENGTH] = (MathRand() / 32767.0 - 0.5) * 0.02;  // ±1%
      
      neuralNet.ComputeOutputs(testInputs);
      
      int signal = neuralNet.GetTradingSignal();
      double confidence = neuralNet.GetSignalConfidence();
      
      if(signal >= 0 && signal < 3)
      {
         signalCounts[signal]++;
         totalConfidence += confidence;
         validSignals++;
      }
   }
   
   if(validSignals > 0)
   {
      Print("✓ Signal generation test PASSED");
      Print("Signal distribution over ", TestIterations, " tests:");
      Print("  HOLD: ", signalCounts[SIGNAL_HOLD], " (", 
            DoubleToString(signalCounts[SIGNAL_HOLD] * 100.0 / TestIterations, 1), "%)");
      Print("  BUY:  ", signalCounts[SIGNAL_BUY], " (", 
            DoubleToString(signalCounts[SIGNAL_BUY] * 100.0 / TestIterations, 1), "%)");
      Print("  SELL: ", signalCounts[SIGNAL_SELL], " (", 
            DoubleToString(signalCounts[SIGNAL_SELL] * 100.0 / TestIterations, 1), "%)");
      Print("Average confidence: ", DoubleToString(totalConfidence / validSignals, 4));
   }
   else
   {
      Print("✗ Signal generation test FAILED - No valid signals generated");
   }
}

//+------------------------------------------------------------------+
//| Test performance tracking functionality                        |
//+------------------------------------------------------------------+
void RunPerformanceTrackingTest()
{
   Print("\n--- Testing Performance Tracking ---");
   
   // Reset performance counters
   neuralNet.ResetPerformance();
   
   // Simulate some predictions and outcomes
   double testInputs[SIZEI];
   ArrayInitialize(testInputs, 0.0);
   
   for(int i = 0; i < 10; i++)
   {
      // Generate test prediction
      neuralNet.ComputeOutputs(testInputs);
      int predictedSignal = neuralNet.GetTradingSignal();
      
      // Simulate random actual outcome
      int actualOutcome = MathRand() % 3;
      
      // Update performance
      neuralNet.UpdatePerformance(actualOutcome);
      
      // Modify inputs slightly for next iteration
      testInputs[0] += 0.001;
   }
   
   double accuracy = neuralNet.GetAccuracy();
   
   if(accuracy >= 0.0 && accuracy <= 100.0)
   {
      Print("✓ Performance tracking test PASSED");
      Print("Simulated accuracy: ", DoubleToString(accuracy, 2), "%");
   }
   else
   {
      Print("✗ Performance tracking test FAILED - Invalid accuracy: ", accuracy);
   }
}

//+------------------------------------------------------------------+
//| Test error handling                                            |
//+------------------------------------------------------------------+
void TestErrorHandling()
{
   Print("\n--- Testing Error Handling ---");
   
   // Test with invalid input size
   double invalidInputs[5]; // Wrong size
   ArrayInitialize(invalidInputs, 0.0);
   
   neuralNet.ComputeOutputs(invalidInputs);
   
   if(neuralNet.GetLastError() != "")
   {
      Print("✓ Error handling test PASSED - Caught invalid input size");
      Print("Error message: ", neuralNet.GetLastError());
      neuralNet.ClearError();
   }
   else
   {
      Print("✗ Error handling test FAILED - Did not catch invalid input");
   }
}

