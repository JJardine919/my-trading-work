# Copyright 2023, MetaQuotes Ltd.
# https://www.mql5.com
#
# Classification model
# 0,0,1 - predict price down
# 0,1,0 - predict price same
# 1,0,0 - predict price up
#

from datetime import datetime
import MetaTrader5 as mt5
import tensorflow as tf
import numpy as np
import pandas as pd
import tf2onnx
from sklearn.model_selection import train_test_split
from tqdm import tqdm
from keras.models import Sequential
from keras.layers import Dense, Activation,Dropout, BatchNormalization, LeakyReLU
from keras.optimizers import SGD
from keras import regularizers
from sys import argv

# input parameters
inp_model_name = "model.eurusd.D1.63.onnx"
inp_symbol = "EURUSD"
inp_period = mt5.TIMEFRAME_D1
inp_history_size = 63
inp_start_date = datetime(2010, 1, 1, 0)
inp_end_date = datetime(2023, 1, 1, 0)

# initialize MetaTrader 5 client terminal
if not mt5.initialize():
    print("initialize() failed, error code =",mt5.last_error())
    quit()

# we will save generated onnx-file near the our script
data_path=argv[0]
last_index=data_path.rfind("\\")+1
data_path=data_path[0:last_index]
print("data path to save onnx model",data_path)

# get data from client terminal
eurusd_rates = mt5.copy_rates_range(inp_symbol, inp_period, inp_start_date, inp_end_date)
df = pd.DataFrame(eurusd_rates)


#
# collect dataset subroutine
#
def collect_dataset(df: pd.DataFrame, history_size: int):
    """
    Collect dataset for the following regression problem:
    - input: history_size consecutive H1 bars;
    - output: close price for the next bar.

    :param df: H1 bars for a range of dates
    :param history_size: how many bars should be considered for making a prediction
    :return: features and labels
    """
    n = len(df)
    xs = []
    ys = []
    for i in tqdm(range(n - history_size)):
        w = df.iloc[i: i + history_size + 1]
        x = w[['close']].iloc[:-1].values
        y = w.iloc[-1]['close']

        xs.append(x)
        ys.append(y)

    X = np.array(xs)
    Y = np.array(ys)
    return X, Y
###


# get prices
X, y = collect_dataset(df, history_size=inp_history_size)

# normalize prices
m = X.mean(axis=1, keepdims=True)
s = X.std(axis=1, keepdims=True)
X_norm = (X - m) / s
y_norm = (y - m[:, 0, 0]) / s[:, 0, 0]

# split data to train and test sets
X_train, X_test, Y_train, Y_test = train_test_split(X_norm, y_norm, test_size=0.1, random_state=0)

# define model
model = Sequential()
model.add(Dense(64, input_dim=inp_history_size, activity_regularizer=regularizers.l2(0.01)))
model.add(BatchNormalization())
model.add(LeakyReLU())
model.add(Dropout(0.3))
model.add(Dense(16, activity_regularizer=regularizers.l2(0.01)))
model.add(BatchNormalization())
model.add(LeakyReLU())
model.add(Dense(1))

model.compile(optimizer='adam', loss='mse', metrics=['mae'])

# display model summary
#model.summary()

# model training for 300 epochs
lr_reduction = tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.9, patience=5, min_lr=0.00001)
history = model.fit(X_train, Y_train, epochs=300, validation_data=(X_test, Y_test), shuffle = True, batch_size=128, verbose=2, callbacks=[lr_reduction])

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
