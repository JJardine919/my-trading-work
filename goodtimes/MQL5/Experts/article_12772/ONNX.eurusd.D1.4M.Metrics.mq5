//+------------------------------------------------------------------+
//|                                    ONNX.eurusd.D1.4M.Metrics.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Graphics\Graphic.mqh>

#define GRAPH_WIDTH  750
#define GRAPH_HEIGHT 350

#define MODELS 4
#include "ModelEurusdD1_10.mqh"
#include "ModelEurusdD1_30.mqh"
#include "ModelEurusdD1_52.mqh"
#include "ModelEurusdD1_63.mqh"

#property script_show_inputs
input datetime InpStartDate = D'2023.01.01';
input datetime InpStopDate  = D'2023.01.31';
input bool     InpPlotAll   = true;
input int      InpPlotModel = 0;

CModelSymbolPeriod *ExtModels[MODELS];

struct PredictedPrices
  {
   string            model;
   double            pred[];
  };
PredictedPrices ExtPredicted[MODELS];

double ExtClose[];

struct Metrics
  {
   string            model;
   double            mae;
   double            mse;
   double            rmse;
   double            r2;
   double            mape;
   double            mspe;
   double            rmsle;
  };
Metrics ExtMetrics[MODELS];

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- init section
   if(!Init())
      return;

//--- predictions test loop
   datetime dates[];
   if(CopyTime(_Symbol,_Period,InpStartDate,InpStopDate,dates)<=0)
     {
      Print("Cannot get data from ",InpStartDate," to ",InpStopDate);
      return;
     }
   for(uint n=0; n<dates.Size(); n++)
      GetPredictions(dates[n]);
      
   CopyClose(_Symbol,_Period,InpStartDate,InpStopDate,ExtClose);
   CalculateMetrics();
   VisualizePredictions();

//--- deinit section
   Deinit();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Init()
  {
   ExtModels[0]=new CModelEurusdD1_10;
   ExtModels[1]=new CModelEurusdD1_30;
   ExtModels[2]=new CModelEurusdD1_52;
   ExtModels[3]=new CModelEurusdD1_63;

   for(long i=0; i<ExtModels.Size(); i++)
     {
      if(!ExtModels[i].Init(_Symbol,_Period))
        {
         Deinit();
         return(false);
        }
     }

   for(long i=0; i<ExtModels.Size(); i++)
      ExtPredicted[i].model=ExtModels[i].GetModelName();

   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Deinit()
  {
   for(uint i=0; i<ExtModels.Size(); i++)
      delete ExtModels[i];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetPredictions(datetime date)
  {
//--- collect predicted prices
   for(uint i=0; i<ExtModels.Size(); i++)
      ExtPredicted[i].pred.Push(ExtModels[i].PredictPrice(date));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateMetrics()
  {
   vector vector_pred,vector_true;
   vector_true.Assign(ExtClose);

   for(uint i=0; i<ExtModels.Size(); i++)
     {
      ExtMetrics[i].model=ExtPredicted[i].model;
      vector_pred.Assign(ExtPredicted[i].pred);
      ExtMetrics[i].mae  =vector_pred.RegressionMetric(vector_true,REGRESSION_MAE);
      ExtMetrics[i].mse  =vector_pred.RegressionMetric(vector_true,REGRESSION_MSE);
      ExtMetrics[i].rmse =vector_pred.RegressionMetric(vector_true,REGRESSION_RMSE);
      ExtMetrics[i].r2   =vector_pred.RegressionMetric(vector_true,REGRESSION_R2);
      ExtMetrics[i].mape =vector_pred.RegressionMetric(vector_true,REGRESSION_MAPE);
      ExtMetrics[i].mspe =vector_pred.RegressionMetric(vector_true,REGRESSION_MSPE);
      ExtMetrics[i].rmsle=vector_pred.RegressionMetric(vector_true,REGRESSION_RMSLE);
     }

   ArrayPrint(ExtMetrics);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void VisualizePredictions()
  {
   string   title="Predictions "+_Symbol+","+EnumToString(_Period);
   long     chart=0;
   string   name="Predictions";
   CCurve  *curves[MODELS+1];
   CGraphic graphic;

//--- switch off chart show
   ChartSetInteger(0,CHART_SHOW,false);

//--- arrays for drawing a graph
   double x[];
   ArrayResize(x,ExtClose.Size());
   for(uint i=0; i<ExtClose.Size(); i++)
      x[i]=i;
      
//--- create graph
   graphic.Create(chart,name,0,0,0,GRAPH_WIDTH,GRAPH_HEIGHT);
   graphic.BackgroundMain(title);
   graphic.BackgroundMainSize(12);

   curves[0]=graphic.CurveAdd(x,ExtClose,CURVE_POINTS_AND_LINES);
   curves[0].Name("Close");
   curves[0].LinesWidth(3);
   
   if(InpPlotAll)
     {
      for(int i=0; i<MODELS; i++)
        {
         curves[i+1]=graphic.CurveAdd(x,ExtPredicted[i].pred,CURVE_POINTS_AND_LINES);
         curves[i+1].Name(ExtPredicted[i].model);
         curves[i+1].LinesWidth(2);
        }
     }
   else
     {
      int num=InpPlotModel;
      if(num<0)
         num=0;
      if(num>=MODELS)
         num=MODELS-1;
      curves[1]=graphic.CurveAdd(x,ExtPredicted[num].pred,CURVE_POINTS_AND_LINES);
      curves[1].Name(ExtPredicted[num].model);
      curves[1].LinesWidth(2);
     }

   graphic.CurvePlotAll();
   graphic.Update();

//--- endless loop to recognize pressed keyboard buttons
   while(!IsStopped())
     {
      //--- press escape button to quit program
      if(TerminalInfoInteger(TERMINAL_KEYSTATE_ESCAPE)!=0)
         break;
      //--- press PgDn to save graph picture
      if(TerminalInfoInteger(TERMINAL_KEYSTATE_PAGEDOWN)!=0)
        {
         string file_names[];
         if(FileSelectDialog("Save Picture",NULL,"All files (*.*)|*.*",FSD_WRITE_FILE,file_names,"Predictions.png")<1)
            continue;
         ChartScreenShot(0,file_names[0],GRAPH_WIDTH,GRAPH_HEIGHT);
        }
      Sleep(10);
     }

//--- clean up
   graphic.Destroy();
   ObjectDelete(chart,name);
   ChartSetInteger(0,CHART_SHOW,true);
  }
//+------------------------------------------------------------------+
