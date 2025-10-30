//+------------------------------------------------------------------+
//|                                               Random Forest.mqh |
//|                                     Wrapper for ONNX RF models  |
//+------------------------------------------------------------------+
#property copyright "Random Forest Classifier for ONNX models"
#property version   "1.00"

#define ONNX_COMMON_FOLDER 1  // Flag to load from Common/Files

//+------------------------------------------------------------------+
//| CRandomForestClassifier class                                    |
//+------------------------------------------------------------------+
class CRandomForestClassifier
{
private:
    long m_model_handle;
    string m_model_path;
    int m_n_features;

public:
    //--- Constructor
    CRandomForestClassifier() : m_model_handle(INVALID_HANDLE), m_n_features(4) {}

    //--- Destructor
    ~CRandomForestClassifier()
    {
        if(m_model_handle != INVALID_HANDLE)
        {
            OnnxRelease(m_model_handle);
            m_model_handle = INVALID_HANDLE;
        }
    }

    //--- Initialize model from file
    bool Init(string model_filename, int folder_flag = 0)
    {
        // Build full path to model in Common/Files
        string terminal_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
        m_model_path = terminal_path + "\\Files\\" + model_filename;

        // Try to create ONNX model from file
        m_model_handle = OnnxCreate(m_model_path, ONNX_DEFAULT);

        if(m_model_handle == INVALID_HANDLE)
        {
            Print("Failed to load ONNX model: ", m_model_path);
            Print("Error code: ", GetLastError());
            return false;
        }

        // Set input shape [batch_size, n_features]
        // For RandomForest with OHLC: batch=1, features=4
        long input_shape[] = {1, m_n_features};
        if(!OnnxSetInputShape(m_model_handle, 0, input_shape))
        {
            Print("Failed to set input shape, Error: ", GetLastError());
            OnnxRelease(m_model_handle);
            m_model_handle = INVALID_HANDLE;
            return false;
        }

        // Set output shape [batch_size, n_classes]
        // Binary classification: batch=1, classes=2
        long output_shape[] = {1, 2};
        if(!OnnxSetOutputShape(m_model_handle, 0, output_shape))
        {
            Print("Failed to set output shape, Error: ", GetLastError());
            OnnxRelease(m_model_handle);
            m_model_handle = INVALID_HANDLE;
            return false;
        }

        Print("ONNX model loaded successfully: ", model_filename);
        return true;
    }

    //--- Predict binary class (0 or 1)
    long predict_bin(vector &features)
    {
        if(m_model_handle == INVALID_HANDLE)
        {
            Print("Model not initialized");
            return -1;
        }

        // Convert vector to array for ONNX
        float input_data[];
        ArrayResize(input_data, m_n_features);
        for(int i = 0; i < m_n_features; i++)
            input_data[i] = (float)features[i];

        // Run prediction
        float output_data[];
        ArrayResize(output_data, 2);  // 2 classes

        if(!OnnxRun(m_model_handle, ONNX_NO_CONVERSION, input_data, output_data))
        {
            Print("OnnxRun failed, Error: ", GetLastError());
            return -1;
        }

        // Return class with higher probability
        return (output_data[1] > output_data[0]) ? 1 : 0;
    }

    //--- Predict probabilities for both classes
    vector predict_proba(vector &features)
    {
        vector probabilities;
        probabilities.Init(2);

        if(m_model_handle == INVALID_HANDLE)
        {
            Print("Model not initialized");
            return probabilities;
        }

        // Convert vector to array for ONNX
        float input_data[];
        ArrayResize(input_data, m_n_features);
        for(int i = 0; i < m_n_features; i++)
            input_data[i] = (float)features[i];

        // Run prediction
        float output_data[];
        ArrayResize(output_data, 2);  // 2 classes

        if(!OnnxRun(m_model_handle, ONNX_NO_CONVERSION, input_data, output_data))
        {
            Print("OnnxRun failed, Error: ", GetLastError());
            return probabilities;
        }

        // Return probabilities as vector
        probabilities[0] = output_data[0];
        probabilities[1] = output_data[1];

        return probabilities;
    }
};
