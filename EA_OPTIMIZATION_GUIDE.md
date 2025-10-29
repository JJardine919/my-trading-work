# EA OPTIMIZATION GUIDE FOR PROP FIRM SUCCESS
**For: Adaptive_Bitcoin_Master_Bot_Final.mq5 & StrikeBot_AI3.mq5**

---

## 🎯 GOAL: Optimize your bots for prop firm challenges

### What We're Optimizing For:
1. **Maximum profit factor** (> 1.5)
2. **Minimum drawdown** (< 8%)
3. **High win rate** (> 45%)
4. **Consistent returns** (positive every week)
5. **Respect daily loss limits** (never > 5% in one day)

---

## 📊 STEP 1: PREPARE YOUR DATA

### **Download Recent Market Data:**

1. Open MT5
2. Go to **Tools → History Center** (or press F2)
3. Select your trading pair (e.g., **EURUSD**, **BTCUSD**)
4. Download **at least 6 months** of M1 data (2024-2025)
5. This ensures you have recent market conditions

---

## 🔧 STEP 2: OPTIMIZE ADAPTIVE BITCOIN BOT

### **Parameters to Optimize:**

Open MT5 Strategy Tester (Ctrl+R or View → Strategy Tester)

#### **A. Risk Management Parameters:**
```
Parameter                  | Current | Min  | Max  | Step | Priority
---------------------------|---------|------|------|------|----------
RiskPercent                | 1.0     | 0.5  | 2.0  | 0.25 | HIGH
MaxDailyLossPercent        | 2.0     | 1.0  | 5.0  | 0.5  | CRITICAL
ATR_Multiplier_TP          | 3.0     | 2.0  | 5.0  | 0.5  | HIGH
ATR_Multiplier_SL          | 2.0     | 1.5  | 3.0  | 0.25 | HIGH
MaxOpenPositions           | 1       | 1    | 3    | 1    | MEDIUM
```

#### **B. Indicator Parameters:**
```
Parameter                  | Current | Min  | Max  | Step | Priority
---------------------------|---------|------|------|------|----------
RSI_Period                 | 14      | 10   | 20   | 2    | MEDIUM
RSI_UpperLevel             | 70.0    | 65   | 80   | 5    | MEDIUM
RSI_LowerLevel             | 30.0    | 20   | 35   | 5    | MEDIUM
Stoch_K_Period             | 5       | 3    | 10   | 1    | LOW
PatternStrengthThreshold   | 60      | 50   | 80   | 5    | MEDIUM
```

### **How to Run Optimization:**

1. **Strategy Tester Settings:**
   - Symbol: Your trading pair (EURUSD, BTCUSD, etc.)
   - Period: M5 or M15 (faster testing)
   - Date: Last 6 months (2024-2025 data)
   - Deposit: $10,000 (typical prop firm amount)
   - Leverage: 1:30 or 1:100 (prop firm standard)

2. **Inputs Tab:**
   - Check boxes next to parameters you want to optimize
   - Set Min, Max, and Step values from table above

3. **Settings Tab:**
   - Optimization: **Genetic Algorithm** (faster than complete)
   - Optimization criterion: **Custom** or **Sharpe Ratio**
   - Forward period: 25% (to validate results)

4. **START → Run Optimization**
   - Will take 30 minutes to 2 hours depending on parameters
   - MT5 will test thousands of combinations

### **What to Look For in Results:**

After optimization completes:

1. **Optimization Results Tab:**
   - Sort by **Profit Factor** (should be > 1.5)
   - Look for **low drawdown** (< 10%)
   - Check **total trades** (should be > 30 for statistical significance)

2. **Forward Testing Tab:**
   - This tests the best parameters on unseen data
   - **Critical:** If forward test is also profitable → parameters are valid
   - If forward test fails → parameters are overfit (BAD!)

3. **Graph Tab:**
   - Look for **smooth equity curve**
   - **No sudden drops** (would fail prop firm)
   - **Consistent upward trend**

---

## 🤖 STEP 3: OPTIMIZE STRIKEBOT AI3

### **Parameters to Optimize:**

#### **A. Risk Management:**
```
Parameter                  | Current | Min  | Max  | Step | Priority
---------------------------|---------|------|------|------|----------
RiskPercent                | 1.0     | 0.5  | 2.0  | 0.25 | HIGH
MaxDailyRisk               | 5.0     | 2.0  | 5.0  | 0.5  | CRITICAL
MaxDrawdown                | 15.0    | 8.0  | 15.0 | 1.0  | CRITICAL
TrailingDistance           | 20.0    | 15   | 50   | 5    | MEDIUM
```

#### **B. AI Parameters:**
```
Parameter                  | Current | Min  | Max  | Step | Priority
---------------------------|---------|------|------|------|----------
AIConfidenceThreshold      | 0.70    | 0.60 | 0.85 | 0.05 | HIGH
Signal_ThresholdOpen       | 10      | 5    | 20   | 5    | MEDIUM
Signal_StopLevel           | 50      | 30   | 100  | 10   | HIGH
Signal_TakeLevel           | 50      | 50   | 150  | 20   | HIGH
TakeProfitRR               | 2.0     | 1.5  | 3.0  | 0.25 | MEDIUM
```

#### **C. Indicator Parameters:**
```
Parameter                  | Current | Min  | Max  | Step | Priority
---------------------------|---------|------|------|------|----------
RSI_Period                 | 14      | 10   | 20   | 2    | LOW
RSI_Overbought             | 70.0    | 65   | 80   | 5    | LOW
RSI_Oversold               | 30.0    | 20   | 35   | 5    | LOW
```

### **Run Same Process as Above**

Follow the same steps as Adaptive Bitcoin Bot optimization.

---

## 🏆 STEP 4: COMPARE RESULTS

### **Create Comparison Spreadsheet:**

| Metric | Adaptive Bitcoin (Original) | Adaptive Bitcoin (Optimized) | StrikeBot (Original) | StrikeBot (Optimized) |
|--------|----------------------------|------------------------------|---------------------|---------------------|
| **Net Profit** | | | | |
| **Profit Factor** | | | | |
| **Max Drawdown %** | | | | |
| **Win Rate %** | | | | |
| **Total Trades** | | | | |
| **Sharpe Ratio** | | | | |
| **Worst Day Loss %** | | | | |
| **Best Day Gain %** | | | | |
| **Avg Trade** | | | | |
| **Recovery Factor** | | | | |

### **Decision Criteria:**

✅ **PASS** if:
- Profit Factor > 1.5
- Max Drawdown < 8%
- Win Rate > 45%
- Worst Day Loss < 5%
- Forward test also profitable

❌ **FAIL** if:
- Profit Factor < 1.3
- Max Drawdown > 10%
- Win Rate < 40%
- Worst Day Loss > 7%
- Forward test shows losses

---

## ⚠️ CRITICAL: VALIDATE WITH DEMO

**Even after optimization, STILL run on demo for 2-4 weeks!**

### **Why?**
- Backtest ≠ Real market
- Slippage and latency matter
- Market conditions change
- Need to verify parameters work live

### **Demo Testing Checklist:**

Week 1-2:
- [ ] Bot runs without errors
- [ ] Orders execute correctly
- [ ] Stop loss / take profit levels are respected
- [ ] No unexpected behavior

Week 3-4:
- [ ] Positive returns
- [ ] Daily loss never exceeds 3-5%
- [ ] Drawdown stays under 8%
- [ ] Win rate matches backtest (±10%)

---

## 🎯 STEP 5: ADD PROP FIRM SAFETY CONTROLS

### **CRITICAL:** Before going to prop firm, add these to BOTH bots:

```cpp
// Add to OnInit() function:

// Prop firm safety settings
input double MaxDailyDrawdownPercent = 3.0;  // Never exceed 3% daily loss
input double EmergencyStopDrawdown = 7.5;    // Emergency stop at 7.5% total drawdown

// Global variables
double DayStartEquity = 0;
datetime CurrentDay = 0;

// Add to OnTick() function (at the very start):

// Check for new day
if(CurrentDay != iTime(_Symbol, PERIOD_D1, 0))
{
    CurrentDay = iTime(_Symbol, PERIOD_D1, 0);
    DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
}

// Emergency stop: Check daily drawdown
double DailyDD = ((DayStartEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / DayStartEquity) * 100;
if(DailyDD >= MaxDailyDrawdownPercent)
{
    CloseAllPositions();
    Print("EMERGENCY STOP: Daily drawdown limit hit: ", DailyDD, "%");
    ExpertRemove();  // Stop trading completely
    return;
}

// Emergency stop: Check total drawdown
double TotalDD = risk_metrics.current_drawdown;  // Use existing drawdown calculation
if(TotalDD >= EmergencyStopDrawdown)
{
    CloseAllPositions();
    Print("EMERGENCY STOP: Total drawdown limit hit: ", TotalDD, "%");
    ExpertRemove();
    return;
}
```

---

## 📊 STEP 6: FINAL DECISION

### **After Optimization + Demo Testing:**

| Bot | Backtest Profit Factor | Demo Win Rate | Max DD | Daily Loss | VERDICT |
|-----|----------------------|---------------|--------|------------|---------|
| Adaptive Bitcoin (Optimized) | | | | | ? |
| StrikeBot AI3 (Optimized) | | | | | ? |

**Choose the bot that:**
1. Has best profit factor in backtest
2. Maintains performance in demo
3. Never hit daily loss limits
4. Stayed under 8% drawdown
5. Feels stable and predictable

**THEN → Start prop firm challenge with that bot!**

---

## 🎓 OPTIMIZATION TIPS

### **DO:**
✅ Optimize on at least 6 months of data
✅ Use forward testing (25-30% of data)
✅ Test on multiple timeframes
✅ Prioritize drawdown over profit
✅ Focus on consistency, not max profit
✅ Validate on demo after optimization

### **DON'T:**
❌ Over-optimize (too many parameters)
❌ Use data older than 2024
❌ Ignore forward testing results
❌ Skip demo validation
❌ Trust parameters that only work on one symbol
❌ Optimize on less than 100 trades

---

## 📞 NEXT STEPS

**This Week:**
1. Optimize Adaptive Bitcoin Bot (2-3 hours)
2. Optimize StrikeBot AI3 (2-3 hours)
3. Set up demo accounts for both

**Next 2-4 Weeks:**
4. Run both bots on demo in parallel
5. Track daily results in spreadsheet
6. Add prop firm safety controls
7. Choose winner

**After Demo Success:**
8. Start with smallest/cheapest prop firm challenge
9. Run with optimized parameters
10. Monitor daily
11. Scale up if successful!

---

## 💡 COMMON QUESTIONS

**Q: How long does optimization take?**
A: 30 minutes to 2 hours per bot, depending on parameters.

**Q: Can I optimize both bots at the same time?**
A: Yes! Open two MT5 instances or run them sequentially.

**Q: What if optimization makes performance worse?**
A: Keep original parameters. Sometimes defaults are already optimized.

**Q: Should I optimize on M1, M5, or M15?**
A: M5 or M15 is best balance of accuracy and speed.

**Q: What's the most important parameter to optimize?**
A: **MaxDailyLossPercent** and **ATR multipliers** for risk control.

---

## ✅ SUCCESS CRITERIA

**Your optimization is successful if:**

1. **Backtest Results:**
   - Profit factor: 1.5 - 3.0 (realistic range)
   - Max drawdown: 5-8%
   - Win rate: 45-60%
   - 100+ trades tested

2. **Forward Test:**
   - Still profitable (even if less than backtest)
   - Drawdown similar to backtest
   - No catastrophic losses

3. **Demo Results (2-4 weeks):**
   - Positive returns
   - Never hit daily loss limit
   - Drawdown < 8%
   - Consistent performance

**If all three pass → YOU'RE READY FOR PROP FIRM!**

---

**GOOD LUCK! 🚀**
