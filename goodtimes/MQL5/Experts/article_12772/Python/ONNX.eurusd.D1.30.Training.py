# Copyright 2023, MetaQuotes Ltd.
# https://www.mql5.com

import MetaTrader5 as mt5
import tensorflow as tf
import numpy as np
import pandas as pd
import tf2onnx
from datetime import datetime
from tqdm import tqdm

# input parameters
inp_model_name = "model.eurusd.D1.30.onnx"
inp_symbol = "EURUSD"
inp_period=mt5.TIMEFRAME_D1
inp_sample_size = 30
inp_start_date = datetime(2010, 1, 1, 0)
inp_end_date = datetime(2023, 1, 1, 0)
inp_ma_fast = 21
inp_ma_slow = 34

if not mt5.initialize():
    print("initialize() failed, error code =",mt5.last_error())
    quit()

# we will save generated onnx-file near the our script
from sys import argv
data_path=argv[0]
last_index=data_path.rfind("\\")+1
data_path=data_path[0:last_index]
print("data path to save onnx model",data_path)

# get data from client terminal
rates = mt5.copy_rates_range(inp_symbol, inp_period, inp_start_date, inp_end_date)
df = pd.DataFrame(rates)
df['ma_fast'] = df['close'].rolling(window=inp_ma_fast).mean()
df['ma_slow'] = df['close'].rolling(window=inp_ma_slow).mean()


#
# collect dataset subroutine
#
def collect_dataset(df: pd.DataFrame, data_shift: int, sample_size: int):
    df = df.iloc[data_shift:]
    n = len(df)
    xs = []
    ys = []
    for i in tqdm(range(n - sample_size)):
        w = df.iloc[i: i + sample_size + 1]
        x = w[['close', 'ma_fast', 'ma_slow']].iloc[:-1].values
        y = w.iloc[-1]['close']

        xs.append(x)
        ys.append(y)

    X = np.array(xs)
    Y = np.array(ys)
    return X, Y
###


# get prices
X, y = collect_dataset(df, data_shift=inp_ma_slow-1, sample_size=inp_sample_size)

# normalize prices
m = X.mean(axis=1, keepdims=True)
s = X.std(axis=1, keepdims=True)
X_norm = (X - m) / s
y_norm = (y - m[:, 0, 0]) / s[:, 0, 0]

# split data to train and test sets
from sklearn.model_selection import train_test_split
X_train, X_test, Y_train, Y_test = train_test_split(X_norm, y_norm, test_size=0.2, random_state=0)

# define model
from keras.models import Sequential
from keras.layers import Dense, Activation, Dropout, BatchNormalization, LeakyReLU, LSTM
from keras.optimizers import SGD

model = Sequential()
model.add(LSTM(64, input_shape=(inp_sample_size, 3)))
model.add(BatchNormalization())
model.add(Dropout(0.1))
model.add(Dense(32, activation = 'relu'))
model.add(BatchNormalization())
model.add(Dropout(0.1))
model.add(Dense(32, activation = 'relu'))
model.add(BatchNormalization())
model.add(LeakyReLU())
model.add(Dense(1))

model.compile(optimizer='adam', loss='mse', metrics=['mae'])

# model training for 50 epochs
lr_reduction = tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.1, patience=3, min_lr=0.000001)
history = model.fit(X_train, Y_train, epochs=100, verbose=2, validation_split=0.15, callbacks=[lr_reduction])

# model evaluation
test_loss, test_mae = model.evaluate(X_test, Y_test)
#print(f"test_loss={test_loss:.3f}")
#print(f"test_mae={test_mae:.3f}")

# save model to onnx
output_path = data_path+inp_model_name
onnx_model = tf2onnx.convert.from_keras(model, output_path=output_path)
print(f"saved model to {output_path}")

# finish
mt5.shutdown()
