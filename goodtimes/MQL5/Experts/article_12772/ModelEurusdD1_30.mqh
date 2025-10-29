//+------------------------------------------------------------------+
//|                                             ModelEurusdD1_30.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "ModelSymbolPeriod.mqh"

#resource "Python/model.eurusd.D1.30.onnx" as uchar model_eurusd_D1_30[]

//+------------------------------------------------------------------+
//| ONNX-model wrapper class                                         |
//+------------------------------------------------------------------+
class CModelEurusdD1_30 : public CModelSymbolPeriod
  {
private:
   int               m_sample_size;
   int               m_fast_period;
   int               m_slow_period;
   int               m_sma_fast;
   int               m_sma_slow;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CModelEurusdD1_30(void) : CModelSymbolPeriod("EURUSD",PERIOD_D1)
     {
      m_name="D1_30";
      m_sample_size=30;
      m_fast_period=21;
      m_slow_period=34;
      m_sma_fast=INVALID_HANDLE;
      m_sma_slow=INVALID_HANDLE;
     }

   //+------------------------------------------------------------------+
   //| ONNX-model initialization                                        |
   //+------------------------------------------------------------------+
   virtual bool Init(const string symbol, const ENUM_TIMEFRAMES period)
     {
      //--- check symbol, period, create model
      if(!CModelSymbolPeriod::CheckInit(symbol,period,model_eurusd_D1_30))
        {
         Print("model_eurusd_D1_30 : initialization error");
         return(false);
        }

      //--- since not all sizes defined in the input tensor we must set them explicitly
      //--- first index - batch size, second index - series size, third index - number of series (Close, MA fast, MA slow)
      const long input_shape[] = {1,m_sample_size,3};
      if(!OnnxSetInputShape(m_handle,0,input_shape))
        {
         Print("model_eurusd_D1_30 : OnnxSetInputShape error ",GetLastError());
         return(false);
        }
   
      //--- since not all sizes defined in the output tensor we must set them explicitly
      //--- first index - batch size, must match the batch size of the input tensor
      //--- second index - number of predicted prices
      const long output_shape[] = {1,1};
      if(!OnnxSetOutputShape(m_handle,0,output_shape))
        {
         Print("model_eurusd_D1_30 : OnnxSetOutputShape error ",GetLastError());
         return(false);
        }
      //--- indicators
      m_sma_fast=iMA(m_symbol,m_period,m_fast_period,0,MODE_SMA,PRICE_CLOSE);
      m_sma_slow=iMA(m_symbol,m_period,m_slow_period,0,MODE_SMA,PRICE_CLOSE);
      if(m_sma_fast==INVALID_HANDLE || m_sma_slow==INVALID_HANDLE)
        {
         Print("model_eurusd_D1_30 : cannot create indicator");
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
      static matrixf input_data(m_sample_size,3);    // matrix for prepared input data
      static vectorf output_data(1);                 // vector to get result
      static matrix  x_norm(m_sample_size,3);        // matrix for prices normalize
      static vector  vtemp(m_sample_size);
      static double  ma_buffer[];
   
      //--- request last bars
      date-=date%PeriodSeconds(m_period);
      if(!vtemp.CopyRates(m_symbol,m_period,COPY_RATES_CLOSE,date-1,m_sample_size))
         return(DBL_MAX);
      //--- get series Mean
      double m=vtemp.Mean();
      //--- get series Std
      double s=vtemp.Std();
      //--- normalize
      vtemp-=m;
      vtemp/=s;
      x_norm.Col(vtemp,0);
      //--- fast sma
      if(CopyBuffer(m_sma_fast,0,date-1,m_sample_size,ma_buffer)!=m_sample_size)
         return(-1);
      vtemp.Assign(ma_buffer);
      m=vtemp.Mean();
      s=vtemp.Std();
      vtemp-=m;
      vtemp/=s;
      x_norm.Col(vtemp,1);
      //--- slow sma
      if(CopyBuffer(m_sma_slow,0,date-1,m_sample_size,ma_buffer)!=m_sample_size)
         return(-1);
      vtemp.Assign(ma_buffer);
      m=vtemp.Mean();
      s=vtemp.Std();
      vtemp-=m;
      vtemp/=s;
      x_norm.Col(vtemp,2);
   
      //--- run the inference
      input_data.Assign(x_norm);
      if(!OnnxRun(m_handle,ONNX_NO_CONVERSION,input_data,output_data))
         return(DBL_MAX);

      //--- denormalize the price from the output value
      double predicted=output_data[0]*s+m;
      //--- return prediction
      return(predicted);
     }
  };
//+------------------------------------------------------------------+
