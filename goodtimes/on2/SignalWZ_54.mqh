//+------------------------------------------------------------------+
//|                                                    SignalSAC.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\ExpertSignal.mqh>
#resource "Python/model.onnx" as uchar __ACTOR[]
#define  __STATES 6
#define  __ACTIONS 3
//+------------------------------------------------------------------+
// wizard description start
//+------------------------------------------------------------------+
//| Description of the class                                         |
//| Title=Signals based on Reinforcement-Learning with HYBRID SAC.   |
//| Type=SignalAdvanced                                              |
//| Name=Reinforcement-Learning with HYBRID SAC                      |
//| ShortName=SAC                                                    |
//| Class=CSignalSAC                                                 |
//| Page=signal_soft_actor_critic                                    |
//+------------------------------------------------------------------+
// wizard description end
//+------------------------------------------------------------------+
//| SACs CSignalSAC.                                                 |
//| Purpose: Reinforcement-Learning with HYBRID SAC.                 |
//|            Derives from class CExpertSignal.                     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSignalSAC   : public CExpertSignal
{
protected:

   long                          m_actor_handle;



public:
   void                          CSignalSAC(void);
   void                          ~CSignalSAC(void);

   //--- methods of setting adjustable parameters

   //--- method of verification of arch
   virtual bool      ValidationSettings(void);
   //--- method of creating the indicator and timeseries
   virtual bool      InitIndicators(CIndicators *indicators);
   //--- methods of checking if the market models are formed
   virtual int       LongCondition(void);
   virtual int       ShortCondition(void);

protected:
   vectorf           GetStates(void);
   vectorf           GetOutput();
   vectorf           LogProbabilities(vectorf &Mean, vectorf &Log_STD);
};
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CSignalSAC::CSignalSAC(void)

{
//--- initialization of protected data
   m_used_series = USE_SERIES_OPEN + USE_SERIES_HIGH + USE_SERIES_LOW + USE_SERIES_CLOSE + USE_SERIES_SPREAD + USE_SERIES_TIME;
   //
//--- create O model from static buffer
   m_actor_handle = OnnxCreateFromBuffer(__ACTOR, ONNX_DEFAULT);
}
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CSignalSAC::~CSignalSAC(void)
{
}
//+------------------------------------------------------------------+
//| Validation arch protected data.                                  |
//+------------------------------------------------------------------+
bool CSignalSAC::ValidationSettings(void)
{  if(!CExpertSignal::ValidationSettings())
      return(false);
//--- initial data checks
   if(m_period != PERIOD_H4)
   {  Print(" time frame should be H4 ");
      return(false);
   }
   if(m_actor_handle == INVALID_HANDLE)
   {  Print("Actor OnnxCreateFromBuffer error ", GetLastError());
      return(false);
   }
   // Set input shapes
   const long _actor_in_shape[] = {1, __STATES};
   // Set output shapes
   const long _actor_out_shape[] = {1, __ACTIONS};
   if(!OnnxSetInputShape(m_actor_handle, ONNX_DEFAULT, _actor_in_shape))
   {  Print("Actor OnnxSetInputShape error ", GetLastError());
      return(false);
   }
   if(!OnnxSetOutputShape(m_actor_handle, 0, _actor_out_shape))
   {  Print("Actor OnnxSetOutputShape error ", GetLastError());
      return(false);
   }
   if(!OnnxSetOutputShape(m_actor_handle, 1, _actor_out_shape))
   {  Print("Actor OnnxSetOutputShape error ", GetLastError());
      return(false);
   }
//read best weights
//--- ok
   return(true);
}
//+------------------------------------------------------------------+
//| Create indicators.                                               |
//+------------------------------------------------------------------+
bool CSignalSAC::InitIndicators(CIndicators *indicators)
{
//--- check pointer
   if(indicators == NULL)
      return(false);
//--- initialization of indicators and timeseries of additional filters
   if(!CExpertSignal::InitIndicators(indicators))
      return(false);
//--- ok
   return(true);
}
//+------------------------------------------------------------------+
//| "Voting" that price will grow.                                   |
//+------------------------------------------------------------------+
int CSignalSAC::LongCondition(void)
{  int result = 0;
   vectorf _x_states = GetStates();
//--- run the inference
   vectorf _y_actions(__ACTIONS),_y_logs(__ACTIONS);       // vector to get result
   _y_actions.Fill(0.5);
   _y_logs.Fill(0.5);
   ResetLastError();
   if(!OnnxRun(m_actor_handle, ONNX_NO_CONVERSION, _x_states, _y_actions, _y_logs))
   {  printf(__FUNCSIG__ + " failed to get y forecast, err: %i", GetLastError());
      return(result);
   }
   vectorf _log_probs = LogProbabilities(_y_actions, _y_logs);
   if(_log_probs[0] < _log_probs[2])
   {  result = 100;
   }
   return(result);
}
//+------------------------------------------------------------------+
//| "Voting" that price will fall.                                   |
//+------------------------------------------------------------------+
int CSignalSAC::ShortCondition(void)
{  int result = 0;
   vectorf _x_states = GetStates();
//--- run the inference
   vectorf _y_actions(__ACTIONS),_y_logs(__ACTIONS);       // vector to get result
   _y_actions.Fill(0.5);
   _y_logs.Fill(0.5);
   ResetLastError();
   if(!OnnxRun(m_actor_handle, ONNX_NO_CONVERSION, _x_states, _y_actions, _y_logs))
   {  printf(__FUNCSIG__ + " failed to get y forecast, err: %i", GetLastError());
      return(result);
   }
   vectorf _log_probs = LogProbabilities(_y_actions, _y_logs);
   if(_log_probs[0] > _log_probs[2])
   {  result = 100;
   }
   return(result);
}
//+------------------------------------------------------------------+
//| This function calculates the next actions to be selected from    |
//| the Reinforcement Learning Cycle.                                |
//+------------------------------------------------------------------+
vectorf CSignalSAC::GetStates(void)
{  vectorf _states;
   _states.Init(__STATES);
   _states.Fill(0.0);
   int _i;
   m_close.Refresh(-1);
   for(int i = 0; i < __STATES; i++)
   {  _states[i] = float((m_close.GetData(i + StartIndex()) - m_close.MinValue(i + StartIndex(),__STATES,_i)) / fmax(m_symbol.Point(), m_close.MaxValue(i + StartIndex(),__STATES,_i) - m_close.MinValue(i + StartIndex(),__STATES,_i)));
   }
   return(_states);
}
//+------------------------------------------------------------------+
// Function to compute the Gaussian probability distribution and log
// probabilities
//+------------------------------------------------------------------+
vectorf CSignalSAC::LogProbabilities(vectorf &Mean, vectorf &Log_STD)
{  vectorf _log_probs;
   // Compute standard deviations from log_std
   vectorf _std = exp(Log_STD);
   // Sample actions and compute log probabilities
   float _z = float(rand() % USHORT_MAX / USHORT_MAX); // Generate N(0, 1) sample
   // Sample action using reparameterization trick: action = mean + std * N(0, 1)
   vectorf _actions = Mean + (_std * _z);
   // Compute log probability of the sampled action
   vectorf _variance = _std * _std;
   vectorf _diff = _actions - Mean;
   _log_probs = -0.5f * (log(2.0f * M_PI * _variance) + (_diff * _diff) / _variance);
   return(_log_probs);
}
//+------------------------------------------------------------------+
