// OnnxRuntime.mqh (mock, compile-safe)
 double Tanh_(double x){ double e = MathExp(2.0*x); return (e-1.0)/(e+1.0); }
 bool OnnxCreate(){ return true; }
 bool OnnxLoad(const string path){ return FileIsExist(path); }
 double OnnxRun(const double &inputs[]){
   double s=0.0; for(int i=0;i<ArraySize(inputs);i++) s += inputs[i]*(0.1+i*0.01);
   s = Tanh_(s);
   return 0.5 + 0.5*s; // [0,1] range
 }
 