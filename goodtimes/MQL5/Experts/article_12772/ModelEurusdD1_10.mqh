//+------------------------------------------------------------------+
//|                                             ModelEurusdD1_10.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "ModelSymbolPeriod.mqh"

#resource "Python/model.eurusd.D1.10.onnx" as uchar model_eurusd_D1_10[]

//+------------------------------------------------------------------+
//| ONNX-model wrapper class                                         |
//+------------------------------------------------------------------+
class CModelEurusdD1_10 : public CModelSymbolPeriod
  {
private:
   int               m_sample_size;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CModelEurusdD1_10(void) : CModelSymbolPeriod("EURUSD",PERIOD_D1)
     {
      m_name="D1_10";
      m_sample_size=10;
     }

   //+------------------------------------------------------------------+
   //| ONNX-model initialization                                        |
   //+------------------------------------------------------------------+
   virtual bool Init(const string symbol, const ENUM_TIMEFRAMES period)
     {
      //--- check symbol, period, create model
      if(!CModelSymbolPeriod::CheckInit(symbol,period,model_eurusd_D1_10))
        {
         Print("model_eurusd_D1_10 : initialization error");
         return(false);
        }

      //--- since not all sizes defined in the input tensor we must set them explicitly
      //--- first index - batch size, second index - series size, third index - number of series (OHLC)
      const long input_shape[] = {1,m_sample_size,4};
      if(!OnnxSetInputShape(m_handle,0,input_shape))
        {
         Print("model_eurusd_D1_10 : OnnxSetInputShape error ",GetLastError());
         return(false);
        }
   
      //--- since not all sizes defined in the output tensor we must set them explicitly
      //--- first index - batch size, must match the batch size of the input tensor
      //--- second index - number of predicted prices
      const long output_shape[] = {1,1};
      if(!OnnxSetOutputShape(m_handle,0,output_shape))
        {
         Print("model_eurusd_D1_10 : OnnxSetOutputShape error ",GetLastError());
         return(false);
        }
      //--- ok
      return(true);
     }

   //+------------------------------------------------------------------+
   //| Predict price                                                    |
   //+------------------------------------------------------------------+
   virtual double PredictPrice(datetime date)
     {
      static matrixf input_data(m_sample_size,4);    // matrix for prepared input data
      static vectorf output_data(1);                 // vector to get result
      static matrix  mm(m_sample_size,4);            // matrix of horizontal vectors Mean
      static matrix  ms(m_sample_size,4);            // matrix of horizontal vectors Std
      static matrix  x_norm(m_sample_size,4);        // matrix for prices normalize
   
      //--- prepare input data
      matrix rates;
      //--- request last bars
      date-=date%PeriodSeconds(m_period);
      if(!rates.CopyRates(m_symbol,m_period,COPY_RATES_OHLC,date-1,m_sample_size))
         return(DBL_MAX);
      //--- get series Mean
      vector m=rates.Mean(1);
      //--- get series Std
      vector s=rates.Std(1);
      //--- prepare matrices for prices normalization
      for(int i=0; i<m_sample_size; i++)
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
      if(!OnnxRun(m_handle,ONNX_NO_CONVERSION,input_data,output_data))
         return(DBL_MAX);

      //--- denormalize the price from the output value
      double predicted=output_data[0]*s[3]+m[3];
      //--- return prediction
      return(predicted);
     }
  };
//+------------------------------------------------------------------+
