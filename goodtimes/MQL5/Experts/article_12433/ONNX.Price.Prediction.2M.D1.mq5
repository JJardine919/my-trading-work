//+------------------------------------------------------------------+
//|                                  ONNX.Price.Prediction.2M.D1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, MetaQuotes Ltd."
#property link        "https://www.mql5.com"
#property version     "1.00"
#property description "Ensemble of 2 ONNX models \"Voting classifier\""

#include <Trade\Trade.mqh>

enum EnModels
  {
   USE_FIRST_MODEL,    // Use first model only
   USE_SECOND_MODEL,   // Use second model only
   USE_BOTH_MODELS     // Use both models
  };
input EnModels InpModels = USE_BOTH_MODELS;  // Models using
input double   InpLots   = 1.0;              // Lots amount to open position

#resource "Python/model.eurusd.D1.10.onnx" as uchar ExtModel1[]
#resource "Python/model.eurusd.D1.63.onnx" as uchar ExtModel2[]

#define SAMPLE_SIZE1 10
#define SAMPLE_SIZE2 63

long     ExtHandle1=INVALID_HANDLE;
long     ExtHandle2=INVALID_HANDLE;
int      ExtPredictedClass1=-1;
int      ExtPredictedClass2=-1;
int      ExtPredictedClass=-1;
datetime ExtNextBar=0;
CTrade   ExtTrade;

//--- price movement prediction
#define PRICE_UP   0
#define PRICE_SAME 1
#define PRICE_DOWN 2

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(_Symbol!="EURUSD" || _Period!=PERIOD_D1)
     {
      Print("model must work with EURUSD,D1");
      return(INIT_FAILED);
     }

//--- create first model from static buffer
   if(InpModels==USE_BOTH_MODELS || InpModels==USE_FIRST_MODEL)
     {
      ExtHandle1=OnnxCreateFromBuffer(ExtModel1,ONNX_DEFAULT);
      if(ExtHandle1==INVALID_HANDLE)
        {
         Print("First model OnnxCreateFromBuffer error ",GetLastError());
         return(INIT_FAILED);
        }
      //--- since not all sizes defined in the input tensor we must set them explicitly
      //--- first index - batch size, second index - series size, third index - number of series (OHLC)
      const long input_shape1[] = {1,SAMPLE_SIZE1,4};
      if(!OnnxSetInputShape(ExtHandle1,ONNX_DEFAULT,input_shape1))
        {
         Print("First model OnnxSetInputShape error ",GetLastError());
         return(INIT_FAILED);
        }
   
      //--- since not all sizes defined in the output tensor we must set them explicitly
      //--- first index - batch size, must match the batch size of the input tensor
      //--- second index - number of predicted prices (we only predict Close)
      const long output_shape1[] = {1,1};
      if(!OnnxSetOutputShape(ExtHandle1,0,output_shape1))
        {
         Print("First model OnnxSetOutputShape error ",GetLastError());
         return(INIT_FAILED);
        }
     }

//--- create second model from static buffer
   if(InpModels==USE_BOTH_MODELS || InpModels==USE_SECOND_MODEL)
     {
      ExtHandle2=OnnxCreateFromBuffer(ExtModel2,ONNX_DEFAULT);
      if(ExtHandle2==INVALID_HANDLE)
        {
         Print("Second model OnnxCreateFromBuffer error ",GetLastError());
         return(INIT_FAILED);
        }
   
   
      //--- since not all sizes defined in the input tensor we must set them explicitly
      //--- first index - batch size, second index - series size
      const long input_shape2[] = {1,SAMPLE_SIZE2};
      if(!OnnxSetInputShape(ExtHandle2,ONNX_DEFAULT,input_shape2))
        {
         Print("Second model OnnxSetInputShape error ",GetLastError());
         return(INIT_FAILED);
        }

      //--- since not all sizes defined in the output tensor we must set them explicitly
      //--- first index - batch size, must match the batch size of the input tensor
      //--- second index - number of classes (up, same or down)
      const long output_shape2[] = {1,3};
      if(!OnnxSetOutputShape(ExtHandle2,0,output_shape2))
        {
         Print("Second model OnnxSetOutputShape error ",GetLastError());
         return(INIT_FAILED);
        }
     }
//--- ok
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(ExtHandle1!=INVALID_HANDLE)
     {
      OnnxRelease(ExtHandle1);
      ExtHandle1=INVALID_HANDLE;
     }
   if(ExtHandle2!=INVALID_HANDLE)
     {
      OnnxRelease(ExtHandle2);
      ExtHandle2=INVALID_HANDLE;
     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check new bar
   if(TimeCurrent()<ExtNextBar)
      return;
//--- set next bar time
   ExtNextBar=TimeCurrent();
   ExtNextBar-=ExtNextBar%PeriodSeconds();
   ExtNextBar+=PeriodSeconds();

//--- predict price movement
   Predict();
//--- check trading according to prediction
   if(ExtPredictedClass>=0)
      if(PositionSelect(_Symbol))
         CheckForClose();
      else
         CheckForOpen();
  }
//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
  {
   ENUM_ORDER_TYPE signal=WRONG_VALUE;
//--- check signals
   if(ExtPredictedClass==PRICE_DOWN)
      signal=ORDER_TYPE_SELL;    // sell condition
   else
     {
      if(ExtPredictedClass==PRICE_UP)
         signal=ORDER_TYPE_BUY;  // buy condition
     }

//--- open position if possible according to signal
   if(signal!=WRONG_VALUE && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      ExtTrade.PositionOpen(_Symbol,signal,InpLots,
                            SymbolInfoDouble(_Symbol,signal==ORDER_TYPE_SELL ? SYMBOL_BID:SYMBOL_ASK),
                            0,0);
  }
//+------------------------------------------------------------------+
//| Check for close position conditions                              |
//+------------------------------------------------------------------+
void CheckForClose(void)
  {
   bool bsignal=false;
//--- position already selected before
   long type=PositionGetInteger(POSITION_TYPE);
//--- check signals
   if(type==POSITION_TYPE_BUY && ExtPredictedClass==PRICE_DOWN)
      bsignal=true;
   if(type==POSITION_TYPE_SELL && ExtPredictedClass==PRICE_UP)
      bsignal=true;

//--- close position if possible
   if(bsignal && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      ExtTrade.PositionClose(_Symbol,3);
      //--- open opposite
      CheckForOpen();
     }
  }
//+------------------------------------------------------------------+
//| Voting classification                                            |
//+------------------------------------------------------------------+
void Predict(void)
  {
//--- evaluate first model
   if(InpModels==USE_BOTH_MODELS || InpModels==USE_FIRST_MODEL)
      ExtPredictedClass1=PredictPrice(ExtHandle1,SAMPLE_SIZE1);
//--- evaluate second model
   if(InpModels==USE_BOTH_MODELS || InpModels==USE_SECOND_MODEL)
      ExtPredictedClass2=PredictPriceMovement(ExtHandle2,SAMPLE_SIZE2);

//--- check predictions
   switch(InpModels)
     {
      case USE_FIRST_MODEL :
         ExtPredictedClass=ExtPredictedClass1;
         break;
      case USE_SECOND_MODEL :
         ExtPredictedClass=ExtPredictedClass2;
         break;
      case USE_BOTH_MODELS :
         if(ExtPredictedClass1==ExtPredictedClass2)
            ExtPredictedClass=ExtPredictedClass1;
         else
            ExtPredictedClass=-1;
     }
  }
//+------------------------------------------------------------------+
//| Predict next price (first model)                                 |
//+------------------------------------------------------------------+
int PredictPrice(const long handle,const int sample_size)
  {
   static matrixf input_data(sample_size,4);    // matrix for prepared input data
   static vectorf output_data(1);               // vector to get result
   static matrix  mm(sample_size,4);            // matrix of horizontal vectors Mean
   static matrix  ms(sample_size,4);            // matrix of horizontal vectors Std
   static matrix  x_norm(sample_size,4);        // matrix for prices normalize

//--- prepare input data
   matrix rates;
//--- request last bars
   if(!rates.CopyRates(_Symbol,_Period,COPY_RATES_OHLC,1,sample_size))
      return(-1);
//--- get series Mean
   vector m=rates.Mean(1);
//--- get series Std
   vector s=rates.Std(1);
//--- prepare matrices for prices normalization
   for(int i=0; i<sample_size; i++)
     {
      mm.Row(m,i);
      ms.Row(s,i);
     }
//--- the input of the model must be a set of vertical OHLC vectors
   x_norm=rates.Transpose();
//--- normalize prices
   x_norm-=mm;
   x_norm/=ms;

//--- run the inference
   input_data.Assign(x_norm);
   if(!OnnxRun(handle,ONNX_NO_CONVERSION,input_data,output_data))
      return(-1);
//--- denormalize the price from the output value
   double predicted=output_data[0]*s[3]+m[3];
//--- classify predicted price movement
   int    predicted_class=-1;
   double delta=rates[3][sample_size-1]-predicted;
   if(fabs(delta)<=0.0001)
      predicted_class=PRICE_SAME;
   else
     {
      if(delta<0)
         predicted_class=PRICE_UP;
      else
         predicted_class=PRICE_DOWN;
     }

   return(predicted_class);
  }
//+------------------------------------------------------------------+
//| Predict price movement (second model)                            |
//+------------------------------------------------------------------+
int PredictPriceMovement(const long handle,const int sample_size)
  {
   static vectorf input_data(sample_size);    // vector for prepared input data
   static vectorf output_data(3);             // vector to get result

//--- request last bars
   if(!input_data.CopyRates(_Symbol,_Period,COPY_RATES_CLOSE,1,sample_size))
      return(-1);
//--- get series Mean
   float m=input_data.Mean();
//--- get series Std
   float s=input_data.Std();
//--- normalize prices
   input_data-=m;
   input_data/=s;

//--- run the inference
   if(!OnnxRun(handle,ONNX_NO_CONVERSION,input_data,output_data))
      return(-1);
//--- evaluate prediction
   return(int(output_data.ArgMax()));
  }
//+------------------------------------------------------------------+
