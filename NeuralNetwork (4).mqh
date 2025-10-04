// NeuralNetwork.mqh (wraps handler)
 class CNeuralNetwork{
  private:
   COnnxHandler *h;
  public:
   CNeuralNetwork(COnnxHandler *handler){ h=handler; }
   double Predict(double &inputs[]){ return h ? h.Run(inputs) : 0.5; }
 };
 