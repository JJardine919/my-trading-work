//+------------------------------------------------------------------+
//|                                       VectorRegressionMetric.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
double VectorRegressionMetric(const vector& vec_pred,const vector& vec_true,const ENUM_REGRESSION_METRIC metric)
  {
   if(metric==REGRESSION_R2)
      return(VectorRegressionR2(vec_pred,vec_true));

   ulong  size=vec_pred.Size();
   double sum_e=0;
   for(ulong i=0; i<size; i++)
      sum_e+=RegressionMetric(metric,vec_pred[i],vec_true[i]);

//--- Squared Mean Error
   if(metric==REGRESSION_RMSE || metric==REGRESSION_RMSLE)
      return(sqrt(sum_e/size));

//--- Mean Error
   return(sum_e/size);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RegressionMetric(const ENUM_REGRESSION_METRIC metric,double value_pred,double value_true)
  {
   double err=value_true-value_pred;
   double tmp;

   switch(metric)
     {
      case REGRESSION_MAE :
         return(fabs(err));
      case REGRESSION_MSE :
      case REGRESSION_RMSE :
         return(err*err);
      case REGRESSION_MAPE :
         if(value_true==0)
            value_true=DBL_EPSILON;
         return(fabs(err/value_true));
      case REGRESSION_MSPE :
         if(value_true==0)
            value_true=DBL_EPSILON;
         tmp=err/value_true;
         return(tmp*tmp);
      case REGRESSION_RMSLE :
         tmp=log(value_true+1)-log(value_pred+1);
         return(tmp*tmp);
     }

   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double VectorRegressionR2(const vector& vec_pred,const vector& vec_true)
  {
//--- calculate MSE
   double mse=VectorRegressionMetric(vec_pred,vec_true,REGRESSION_MSE);
   if(mse==0)
      return(1);
//--- calculate mean
   double mean=vec_true.Mean();
//--- calculate naive MSE
   ulong  size=vec_pred.Size();
   double sum_e=0;
   for(ulong i=0; i<size; i++)
      sum_e+=RegressionMetric(REGRESSION_MSE,vec_true[i],mean);
   sum_e/=double(size);
   if(sum_e==0)
      return(0);
//--- r squared
   return(1-mse/sum_e);
  }
//+------------------------------------------------------------------+
