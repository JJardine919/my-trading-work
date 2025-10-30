# 🧪 Testing the ML-Enhanced Bot

## Quick Setup (Do This Once)

1. **Make sure MT5 has the new files:**
   - The files in your git repo need to be in MT5's folders
   - If MT5 is on the same computer, just copy them:
     ```
     Copy: Include/Random Forest.mqh
     To:   C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Include\

     Copy: Adaptive_Bitcoin_ML_Enhanced.mq5
     To:   C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\

     Copy: Common/Files/BTCUSD.PERIOD_D1.cluster-centroids.onnx
     To:   C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
     ```

2. **Refresh MT5:**
   - In MT5, press F4 (opens MetaEditor)
   - Click "Compile" on Adaptive_Bitcoin_ML_Enhanced.mq5
   - Should compile with no errors

---

## Run the Tests (5 minutes)

### Test 1: Original Bot

1. Open MT5 Strategy Tester (View → Strategy Tester, or Ctrl+R)

2. Set these parameters:
   - **Expert Advisor:** `Adaptive_Bitcoin_Master_Bot_Final.mq5`
   - **Symbol:** `BTCUSD`
   - **Period:** `M10`
   - **Date:** `2024.10.01` to `2024.12.31` (Q4 2024)
   - **Deposit:** `100000`
   - **Optimization:** Off
   - **Visual Mode:** Off (faster)

3. Click **"Start"**

4. When done, **save results:**
   - Right-click in results area
   - "Save as Report" → HTML or
   - "Export to Excel" (better!)
   - Save as: `original_bot_Q4_2024.xlsx`

---

### Test 2: ML-Enhanced Bot

1. Same Strategy Tester window

2. Change ONLY this:
   - **Expert Advisor:** `Adaptive_Bitcoin_ML_Enhanced.mq5`
   - Everything else stays the same!

3. Click **"Start"**

4. Save results:
   - Export to Excel
   - Save as: `ml_enhanced_Q4_2024.xlsx`

---

## Compare Results (Automatic!)

1. **Put the Excel files in this repo folder**

2. **Run my comparison script:**
   ```bash
   cd C:\Users\[YourName]\Documents\my-trading-work
   python compare_bots.py original_bot_Q4_2024.xlsx ml_enhanced_Q4_2024.xlsx
   ```

3. **You'll see a full comparison like this:**
   ```
   ════════════════════════════════════════════════════════════════════════════════
   📊 ADAPTIVE BITCOIN BOT COMPARISON
   ════════════════════════════════════════════════════════════════════════════════

   Metric                         |   Original Bot |    ML Enhanced | Change
   ────────────────────────────────────────────────────────────────────────────────

   💰 PROFITABILITY:
   Net Profit                     |      $43,597   |      $52,000   | ✅ +$8,403 (+19.3%)
   Profit Factor                  |          1.82  |          2.05  | ✅ +0.23 (+12.6%)

   📈 TRADING ACTIVITY:
   Total Trades                   |           450  |           485  | ✅ +35 (+7.8%)
   Long Trades                    |           320  |           245  | ✅ More balanced
   Short Trades                   |           130  |           240  | ✅ More balanced

   ⚠️ RISK METRICS:
   Balance Drawdown               |        39.34%  |        28.50%  | ✅ -10.84%
   Equity Drawdown                |        44.61%  |        32.20%  | ✅ -12.41%

   🎯 RECOMMENDATION: 🚀 Use ML-Enhanced bot
   ```

---

## Push Results to Git (So I Can See)

```bash
git add original_bot_Q4_2024.xlsx ml_enhanced_Q4_2024.xlsx
git commit -m "Add Q4 2024 backtest comparison results"
git push
```

Then just tell me "done" and I'll analyze the results!

---

## What If It Doesn't Work?

**ML model not loading?**
- Check log in MT5 Experts tab
- Should say "✓ ML model loaded successfully!"
- If not, the ONNX file isn't in Common/Files

**Bot not trading?**
- Same as before - check PatternStrengthThreshold, lot size, emergency stops
- The ML model only changes TREND DETECTION, everything else is the same

**Want to disable ML and use old EMA?**
- In Expert properties, set: `UseMLTrendDetection = false`

---

## Quick Comparison Without Running Backtests

If you already have old quarterly backtest files, I can compare those too:

```bash
python compare_bots.py "Q4_2024_Original.xlsx" "ml_enhanced_Q4_2024.xlsx"
```

Just need one Excel file from each bot!
