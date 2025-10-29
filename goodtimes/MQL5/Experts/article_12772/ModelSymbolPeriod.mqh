//+------------------------------------------------------------------+
//|                                            ModelSymbolPeriod.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//--- price movement prediction
#define PRICE_UP   0
#define PRICE_SAME 1
#define PRICE_DOWN 2

//+------------------------------------------------------------------+
//| Base class for models based on trained symbol and period         |
//+------------------------------------------------------------------+
class CModelSymbolPeriod
  {
protected:
   string            m_name;             // model name
   long              m_handle;           // created model session handle
   string            m_symbol;           // symbol of trained data
   ENUM_TIMEFRAMES   m_period;           // timeframe of trained data
   datetime          m_next_bar;         // time of next bar (we work at bar begin only)
   double            m_class_delta;      // delta to recognize "price the same" in regression models

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CModelSymbolPeriod(const string symbol,const ENUM_TIMEFRAMES period,const double class_delta=0.0001)
     {
      m_name="";
      m_handle=INVALID_HANDLE;
      m_symbol=symbol;
      m_period=period;
      m_next_bar=0;
      m_class_delta=class_delta;
     }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CModelSymbolPeriod(void)
     {
      Shutdown();
     }

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   string GetModelName(void)
     {
      return(m_name);
     }

   //+------------------------------------------------------------------+
   //| virtual stub for Init                                            |
   //+------------------------------------------------------------------+
   virtual bool Init(const string symbol, const ENUM_TIMEFRAMES period)
     {
      return(false);
     }

   //+------------------------------------------------------------------+
   //| Check for initialization, create model                           |
   //+------------------------------------------------------------------+
   bool CheckInit(const string symbol, const ENUM_TIMEFRAMES period,const uchar& model[])
     {
      //--- check symbol, period
      if(symbol!=m_symbol || period!=m_period)
        {
         PrintFormat("Model must work with %s,%s",m_symbol,EnumToString(m_period));
         return(false);
        }

      //--- create a model from static buffer
      m_handle=OnnxCreateFromBuffer(model,ONNX_DEFAULT);
      if(m_handle==INVALID_HANDLE)
        {
         Print("OnnxCreateFromBuffer error ",GetLastError());
         return(false);
        }

      //--- ok
      return(true);
     }

   //+------------------------------------------------------------------+
   //| Release ONNX session                                             |
   //+------------------------------------------------------------------+
   void Shutdown(void)
     {
      if(m_handle!=INVALID_HANDLE)
        {
         OnnxRelease(m_handle);
         m_handle=INVALID_HANDLE;
        }
     }

   //+------------------------------------------------------------------+
   //| Check for continue OnTick                                        |
   //+------------------------------------------------------------------+
   virtual bool CheckOnTick(void)
     {
      //--- check new bar
      if(TimeCurrent()<m_next_bar)
         return(false);
      //--- set next bar time
      m_next_bar=TimeCurrent();
      m_next_bar-=m_next_bar%PeriodSeconds(m_period);
      m_next_bar+=PeriodSeconds(m_period);

      //--- work on new day bar
      return(true);
     }

   //+------------------------------------------------------------------+
   //| virtual stub for PredictPrice (regression model)                 |
   //+------------------------------------------------------------------+
   virtual double PredictPrice(datetime date)
     {
      return(DBL_MAX);
     }

   //+------------------------------------------------------------------+
   //| Predict class (regression ~> classification)                     |
   //+------------------------------------------------------------------+
   virtual int PredictClass(datetime date,vector& probabilities)
     {
      date-=date%PeriodSeconds(m_period);
      double predicted_price=PredictPrice(date);
      if(predicted_price==DBL_MAX)
         return(-1);
      /*datetime last_date[2];
      if(CopyTime(m_symbol,m_period,date,2,last_date)!=2)
         return(-1);
      double prev_price=PredictPrice(last_date[0]);
      if(prev_price==DBL_MAX)
         return(-1);*/

      double last_close[2];
      if(CopyClose(m_symbol,m_period,date,2,last_close)!=2)
         return(-1);
      double prev_price=last_close[0];

      //--- classify predicted price movement
      int    predicted_class=-1;
      double delta=prev_price-predicted_price;
      if(fabs(delta)<=m_class_delta)
         predicted_class=PRICE_SAME;
      else
        {
         if(delta<0)
            predicted_class=PRICE_UP;
         else
            predicted_class=PRICE_DOWN;
        }

      //--- set predicted probability as 1.0
      probabilities.Fill(0);
      if(predicted_class<(int)probabilities.Size())
         probabilities[predicted_class]=1;
      //--- and return predicted class
      return(predicted_class);
     }
  };
//+------------------------------------------------------------------+
