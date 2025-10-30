# 🚀 Install ML-Enhanced Bot in MT5

## Easy Way (Double-Click)

1. **Double-click:** `install_ml_bot.bat`
2. It will automatically copy all files to MT5
3. Open MT5 and compile (see step 4 below)

---

## Manual Way (If Script Doesn't Work)

### Step 1: Find Your MT5 Data Folder

Press `Win+R` and paste this:
```
%APPDATA%\MetaQuotes\Terminal
```

You'll see folders like `Common` and random folder names with letters/numbers.

### Step 2: Copy Files

**File 1: The Bot**
```
FROM: my-trading-work\Adaptive_Bitcoin_ML_Enhanced.mq5
TO:   [YourMT5Folder]\MQL5\Experts\Adaptive_Bitcoin_ML_Enhanced.mq5
```

**File 2: The Include**
```
FROM: my-trading-work\Include\Random Forest.mqh
TO:   [YourMT5Folder]\MQL5\Include\Random Forest.mqh
```

**File 3: The Model**
```
FROM: my-trading-work\Common\Files\BTCUSD.PERIOD_D1.cluster-centroids.onnx
TO:   Common\Files\BTCUSD.PERIOD_D1.cluster-centroids.onnx
```

### Step 3: Find the Right MT5 Folder

If you see multiple folders (like `D0E8209F77C8CF37AD8BF550E51FF075`):

1. Open MT5
2. Click: `File → Open Data Folder`
3. That's your folder! Copy files there.

### Step 4: Compile in MT5

1. In MT5, press `F4` (opens MetaEditor)
2. In left panel, expand: `Experts`
3. Double-click: `Adaptive_Bitcoin_ML_Enhanced.mq5`
4. Click the "Compile" button (green play button) or press `F7`
5. Should say: "0 errors, 0 warnings"

### Step 5: Find It in MT5

1. In MT5 main window (not MetaEditor)
2. Look at left side: `Navigator` panel
3. Expand: `Expert Advisors`
4. You should see: **`Adaptive_Bitcoin_ML_Enhanced`**

---

## Super Fast Way (From MT5)

1. **In MT5:** File → Open Data Folder
2. **This opens your MT5 folder**
3. **Copy files into:**
   - `MQL5\Experts\` ← Put the .mq5 file here
   - `MQL5\Include\` ← Put Random Forest.mqh here
   - Go back, then `Common\Files\` ← Put the .onnx file here
4. **Press F4 in MT5, compile the bot**

---

## Where Are The Files?

In your git repo at:
```
C:\Users\[YourName]\Documents\my-trading-work\

Files you need:
├── Adaptive_Bitcoin_ML_Enhanced.mq5          ← The bot
├── Include\
│   └── Random Forest.mqh                      ← Include file
└── Common\Files\
    └── BTCUSD.PERIOD_D1.cluster-centroids.onnx ← ML model
```

---

## Still Can't Find It?

Tell me what you see and I'll help! Common issues:

**"I don't see Expert Advisors folder"**
- Press F4 in MT5 to open MetaEditor first

**"Compile gives errors"**
- Make sure Random Forest.mqh is in Include folder

**"Model not loading in backtest"**
- Check the .onnx file is in Common\Files (not the MQL5 folder!)

**"I have multiple MT5 installations"**
- Use File → Open Data Folder to find the right one

---

## Quick Test

Once installed, open MT5 Strategy Tester:
1. In Expert Advisor dropdown, look for: `Adaptive_Bitcoin_ML_Enhanced`
2. If you see it: ✅ Installation worked!
3. If not: Run `install_ml_bot.bat` or follow manual steps above
