//+------------------------------------------------------------------+
//|                                             ModelEurusdD1_52.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "ModelSymbolPeriod.mqh"

#resource "Python/model.eurusd.D1.52.onnx" as uchar model_eurusd_D1_52[]

//+------------------------------------------------------------------+
//| ONNX-model wrapper class                                         |
//+------------------------------------------------------------------+
class CModelEurusdD1_52 : public CModelSymbolPeriod
  {
private:
   int               m_sample_size;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CModelEurusdD1_52(void) : CModelSymbolPeriod("EURUSD",PERIOD_D1,0.0001)
     {
      m_name="D1_52";
      m_sample_size=52;
     }

   //+------------------------------------------------------------------+
   //| ONNX-model initialization                                        |
   //+------------------------------------------------------------------+
   virtual bool Init(const string symbol, const ENUM_TIMEFRAMES period)
     {
      //--- check symbol, period, create model
      if(!CModelSymbolPeriod::CheckInit(symbol,period,model_eurusd_D1_52))
        {
         Print("model_eurusd_D1_52 : initialization error");
         return(false);
        }

      //--- since not all sizes defined in the input tensor we must set them explicitly
      //--- first index - batch size, second index - series size, third index - number of series (only Close)
      const long input_shape[] = {1,m_sample_size,1};
      if(!OnnxSetInputShape(m_handle,0,input_shape))
        {
         Print("model_eurusd_D1_52 : OnnxSetInputShape error ",GetLastError());
         return(false);
        }
   
      //--- since not all sizes defined in the output tensor we must set them explicitly
      //--- first index - batch size, must match the batch size of the input tensor
      //--- second index - number of predicted prices (we only predict Close)
      const long output_shape[] = {1,1};
      if(!OnnxSetOutputShape(m_handle,0,output_shape))
        {
         Print("model_eurusd_D1_52 : OnnxSetOutputShape error ",GetLastError());
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
      static vectorf output_data(1);            // vector to get result
      static vector  x_norm(m_sample_size);     // vector for prices normalize
   
      //--- set date to day begin
      date-=date%PeriodSeconds(m_period);
      //--- check for calculate min and max
      double price_min=0;
      double price_max=0;
      GetMinMaxClose(date,price_min,price_max);
      //--- check for normalization possibility
      if(price_min>=price_max)
         return(DBL_MAX);
      //--- request last bars
      if(!x_norm.CopyRates(m_symbol,m_period,COPY_RATES_CLOSE,date-1,m_sample_size))
         return(DBL_MAX);
      //--- normalize prices
      x_norm-=price_min;
      x_norm/=(price_max-price_min);
      //--- run the inference
      if(!OnnxRun(m_handle,ONNX_DEFAULT,x_norm,output_data))
         return(DBL_MAX);

      //--- denormalize the price from the output value
      double predicted=output_data[0]*(price_max-price_min)+price_min;
      //--- return prediction
      return(predicted);
     }

private:
   //+------------------------------------------------------------------+
   //| Get minimal and maximal Close for last 52 weeks                  |
   //+------------------------------------------------------------------+
   void GetMinMaxClose(const datetime date,double& price_min,double& price_max)
     {
      static vector close;

      close.CopyRates(m_symbol,m_period,COPY_RATES_CLOSE,date,m_sample_size*7+1);
      price_min=close.Min();
      price_max=close.Max();
     }
  };
//+------------------------------------------------------------------+
