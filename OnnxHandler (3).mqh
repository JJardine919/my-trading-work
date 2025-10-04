// OnnxHandler.mqh
 #include "OnnxRuntime.mqh"
 class COnnxHandler{
  public:
   bool created;
   COnnxHandler(){ created = OnnxCreate(); }
   bool LoadModel(string path){ return OnnxLoad(path); }
   double Run(double &inputs[]){ return OnnxRun(inputs); }
 };
 