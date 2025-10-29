//+------------------------------------------------------------------+
//|                                             ModelEurusdD1_63.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "ModelSymbolPeriod.mqh"

#resource "Python/model.eurusd.D1.63.onnx" as uchar model_eurusd_D1_63[]

//+------------------------------------------------------------------+
//| ONNX-model wrapper class                                         |
//+------------------------------------------------------------------+
class CModelEurusdD1_63 : public CModelSymbolPeriod
  {
private:
   int               m_sample_size;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CModelEurusdD1_63(void) : CModelSymbolPeriod("EURUSD",PERIOD_D1)
     {
      m_name="D1_63";
      m_sample_size=63;
     }

   //+------------------------------------------------------------------+
   //| ONNX-model initialization                                        |
   //+------------------------------------------------------------------+
   virtual bool Init(const string symbol, const ENUM_TIMEFRAMES period)
     {
      //--- check symbol, period, create model
      if(!CModelSymbolPeriod::CheckInit(symbol,period,model_eurusd_D1_63))
        {
         Print("model_eurusd_D1_63 : initialization error");
         return(false);
        }

      //--- since not all sizes defined in the input tensor we must set them explicitly
      //--- first index - batch size, second index - series size
      const long input_shape[] = {1,m_sample_size};
      if(!OnnxSetInputShape(m_handle,0,input_shape))
        {
         Print("model_eurusd_D1_63 : OnnxSetInputShape error ",GetLastError());
         return(false);
        }
   
      //--- since not all sizes defined in the output tensor we must set them explicitly
      //--- first index - batch size, must match the batch size of the input tensor
      //--- second index - number of predicted prices
      const long output_shape[] = {1,1};
      if(!OnnxSetOutputShape(m_handle,0,output_shape))
        {
         Print("model_eurusd_D1_63 : OnnxSetOutputShape error ",GetLastError());
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
      static vectorf input_data(m_sample_size);  // vector for prepared input data
      static vectorf output_data(1);             // vector to get result
   
      //--- request last bars
      date-=date%PeriodSeconds(m_period);
      if(!input_data.CopyRates(m_symbol,m_period,COPY_RATES_CLOSE,date-1,m_sample_size))
         return(DBL_MAX);
      //--- get series Mean
      float m=input_data.Mean();
      //--- get series Std
      float s=input_data.Std();
      //--- normalize prices
      input_data-=m;
      input_data/=s;
   
      //--- run the inference
      if(!OnnxRun(m_handle,ONNX_NO_CONVERSION,input_data,output_data))
         return(DBL_MAX);

      //--- denormalize the price from the output value
      double predicted=output_data[0]*s+m;
      //--- return prediction
      return(predicted);
     }
  };
//+------------------------------------------------------------------+
