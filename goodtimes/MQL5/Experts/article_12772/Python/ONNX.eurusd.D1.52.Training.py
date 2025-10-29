# Copyright 2023, MetaQuotes Ltd.
# https://www.mql5.com

# python libraries
import MetaTrader5 as mt5
import tensorflow as tf
import numpy as np
import pandas as pd
import tf2onnx

# input parameters
inp_model_name = "model.eurusd.D1.52.onnx"
inp_symbol = "EURUSD"
inp_period = mt5.TIMEFRAME_D1
inp_history_size = 52

if not mt5.initialize():
    print("initialize() failed, error code =",mt5.last_error())
    quit()

# we will save generated onnx-file near the our script to use as resource
from sys import argv
data_path=argv[0]
last_index=data_path.rfind("\\")+1
data_path=data_path[0:last_index]
print("data path to save onnx model",data_path)

# set start and end dates for history data
from datetime import timedelta, datetime
#end_date = datetime.now()
end_date = datetime(2023, 1, 1, 0)
start_date = end_date - timedelta(weeks=inp_history_size)

# print start and end dates
print("data start date =",start_date)
print("data end date =",end_date)

# get rates
eurusd_rates = mt5.copy_rates_range(inp_symbol, inp_period, start_date, end_date)

# create dataframe
df = pd.DataFrame(eurusd_rates)

# get close prices only
data = df.filter(['close']).values

# scale data
from sklearn.preprocessing import MinMaxScaler
scaler=MinMaxScaler(feature_range=(0,1))
scaled_data = scaler.fit_transform(data)

# training size is 90% of the data
training_size = int(len(scaled_data)*0.90) 
print("Training_size:",training_size)
train_data_initial = scaled_data[0:training_size,:]
test_data_initial = scaled_data[training_size:,:1]

# split a univariate sequence into samples
def split_sequence(sequence, n_steps):
    X, y = list(), list()
    for i in range(len(sequence)):
       # find the end of this pattern
       end_ix = i + n_steps
       # check if we are beyond the sequence
       if end_ix > len(sequence)-1:
          break
       # gather input and output parts of the pattern
       seq_x, seq_y = sequence[i:end_ix], sequence[end_ix]
       X.append(seq_x)
       y.append(seq_y)
    return np.array(X), np.array(y)

# split into samples
time_step = inp_history_size
x_train, y_train = split_sequence(train_data_initial, time_step)
x_test, y_test = split_sequence(test_data_initial, time_step)

# define model
from keras.models import Sequential
from keras.layers import Dense, Activation, Conv1D, MaxPooling1D, Dropout, Flatten, LSTM
from keras.metrics import RootMeanSquaredError as rmse
model = Sequential()
model.add(Conv1D(filters=256, kernel_size=2, activation='relu',padding = 'same',input_shape=(inp_history_size,1)))
model.add(MaxPooling1D(pool_size=2))
model.add(LSTM(100, return_sequences = True))
model.add(Dropout(0.3))
model.add(LSTM(100, return_sequences = False))
model.add(Dropout(0.3))
model.add(Dense(units=1, activation = 'sigmoid'))
model.compile(optimizer='adam', loss= 'mse' , metrics = [rmse()])

# model training for 300 epochs
history = model.fit(x_train, y_train, epochs = 300 , validation_data = (x_test,y_test), batch_size=32, verbose=2)

# evaluate training data
train_loss, train_rmse = model.evaluate(x_train,y_train)
print(f"train_loss={train_loss:.3f}")
print(f"train_rmse={train_rmse:.3f}")

# evaluate testing data
#test_loss, test_rmse = model.evaluate(x_test,y_test)
#print(f"test_loss={test_loss:.3f}")
#print(f"test_rmse={test_rmse:.3f}")

# save model to ONNX
output_path = data_path+inp_model_name
onnx_model = tf2onnx.convert.from_keras(model, output_path=output_path)
print(f"saved model to {output_path}")

# finish
mt5.shutdown()
