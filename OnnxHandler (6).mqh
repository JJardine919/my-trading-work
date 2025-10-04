//+------------------------------------------------------------------+
//|                                                  OnnxHandler.mqh |
//|                    REAL ONNX Handler - No More Random Numbers    |
//+------------------------------------------------------------------+
#ifndef ONNXHANDLER_MQH
#define ONNXHANDLER_MQH

#include "OnnxRuntime.mqh"
#include <Object.mqh>

class COnnxHandler : public CObject {
private:
   int m_handle;
   bool m_is_loaded;
   string m_model_path;

public:
   COnnxHandler(void) : m_handle(INVALID_HANDLE), m_is_loaded(false) {}
   ~COnnxHandler(void) { UnloadModel(); }

   bool LoadModel(const string model_path) {
      if(m_is_loaded) UnloadModel();
      
      m_model_path = model_path;
      m_handle = OnnxCreate(model_path, ONNX_DEFAULT);
      
      if(m_handle == INVALID_HANDLE) {
         Print("COnnxHandler Error: Failed to load ONNX model from ", model_path);
         m_is_loaded = false;
         return false;
      }
      
      Print("COnnxHandler: Successfully loaded ONNX model from ", model_path);
      m_is_loaded = true;
      return true;
   }

   void UnloadModel(void) {
      if(m_is_loaded && m_handle != INVALID_HANDLE) {
         OnnxRelease(m_handle);
         Print("COnnxHandler: Released ONNX model: ", m_model_path);
         m_is_loaded = false;
         m_handle = INVALID_HANDLE;
      }
   }

   bool RunInference(const double &features[], double &result[]) {
      if(!m_is_loaded) {
         Print("COnnxHandler Error: Cannot run inference, model not loaded.");
         return false;
      }
      
      int input_size = ArraySize(features);
      int output_size = ArraySize(result);
      
      if(input_size == 0 || output_size == 0) {
         Print("COnnxHandler Error: Invalid array sizes");
         return false;
      }
      
      // Convert to float arrays
      float input_float[], output_float[];
      ArrayResize(input_float, input_size);
      ArrayResize(output_float, output_size);
      
      // Copy input data
      for(int i = 0; i < input_size; i++)
         input_float[i] = (float)features[i];
      
      // Run REAL ONNX inference
      bool success = OnnxRun(m_handle, ONNX_DEFAULT, input_float, output_float);
      
      if(!success) {
         Print("COnnxHandler Error: ONNX inference failed");
         return false;
      }
      
      // Copy output back
      for(int i = 0; i < output_size; i++)
         result[i] = (double)output_float[i];

      return true;
   }

   bool IsLoaded(void) const { return m_is_loaded; }
};

#endif