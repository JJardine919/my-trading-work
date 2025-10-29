# Week 1 Start Guide - Execute TODAY
**Date:** 2025-10-29
**Timeline:** 10-Week Professional Optimization Protocol
**Target:** Prop Firm Challenge Success

---

## YOUR SITUATION (Context Check)

✅ **6 months invested** - 80 hrs/week
✅ **2 production bots** - Adaptive Bitcoin Master + StrikeBot AI3
✅ **Goal** - Financial breathing room via prop firm success
✅ **Approach** - Do it right, 10 weeks is acceptable

**Bottom line:** You've already paid the price in time. Now we execute properly.

---

## TODAY'S MISSION: Week 1, Day 1

### Part 1: Pre-Flight Check (15 minutes)

**1.1 Verify MT5 Setup**
- Open MetaTrader 5
- Tools → Options → Expert Advisors
- ✅ Check "Allow algorithmic trading"
- ✅ Check "Allow DLL imports"
- ✅ Check "Allow WebRequest for listed URL" (for Nexa relay bot if testing)

**1.2 Verify Both Bots Compile**
- Open MetaEditor (F4 in MT5)
- Open: `Adaptive_Bitcoin_Master_Bot_Final.mq5`
- Hit F7 (Compile)
- Should see: "0 error(s), X warning(s)"
- Repeat for: `StrikeBot_AI3.mq5`

**1.3 Download Historical Data**

In MT5 Strategy Tester:
```
Symbol: BTCUSD (or your preferred pair)
Period: M15 (15-minute)
Date Range: 2024-01-01 to 2024-12-31
Model: Every tick (most accurate)
```

Click "Start" once to trigger download, then stop it. This caches the data.

---

### Part 2: Add Emergency Stops (30-45 minutes)

**Critical:** These stops will prevent your bots from blowing prop firm accounts.

**2.1 For Adaptive_Bitcoin_Master_Bot_Final.mq5**

Open the file in MetaEditor and add this code:

**Step A:** Add to global variables section (around line 30):
```cpp
//--- Emergency Stop System
datetime g_currentDay = 0;
double   g_dayStartEquity = 0;
double   g_peakEquity = 0;
bool     g_emergencyStop = false;

// Emergency limits (will be made input parameters later)
double MaxDailyDrawdownPercent = 3.0;   // 3% daily DD limit
double MaxTotalDrawdownPercent = 8.0;   // 8% total DD limit
int    MaxConsecutiveLosses = 5;       // Stop after 5 losses in a row
int    g_consecutiveLosses = 0;
```

**Step B:** Add this function before `OnTick()` (around line 55):
```cpp
//+------------------------------------------------------------------+
//| Emergency Stop Check Function                                     |
//+------------------------------------------------------------------+
bool CheckEmergencyStop()
{
   if(g_emergencyStop) return true;

   // Check for new day
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(g_currentDay != today)
   {
      g_currentDay = today;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_consecutiveLosses = 0; // Reset daily
   }

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Track peak equity for total drawdown
   if(currentEquity > g_peakEquity)
      g_peakEquity = currentEquity;

   // Calculate drawdowns
   double dailyDD = 0;
   if(g_dayStartEquity > 0)
      dailyDD = ((g_dayStartEquity - currentEquity) / g_dayStartEquity) * 100;

   double totalDD = 0;
   if(g_peakEquity > 0)
      totalDD = ((g_peakEquity - currentEquity) / g_peakEquity) * 100;

   // Check daily drawdown limit
   if(dailyDD >= MaxDailyDrawdownPercent)
   {
      g_emergencyStop = true;
      Print("🚨 EMERGENCY STOP: Daily drawdown ", DoubleToString(dailyDD, 2), "%");
      CloseAllPositions();
      return true;
   }

   // Check total drawdown limit
   if(totalDD >= MaxTotalDrawdownPercent)
   {
      g_emergencyStop = true;
      Print("🚨 EMERGENCY STOP: Total drawdown ", DoubleToString(totalDD, 2), "%");
      CloseAllPositions();
      return true;
   }

   // Check consecutive losses
   if(g_consecutiveLosses >= MaxConsecutiveLosses)
   {
      g_emergencyStop = true;
      Print("🚨 EMERGENCY STOP: ", g_consecutiveLosses, " consecutive losses");
      CloseAllPositions();
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Close All Positions Function                                     |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}
```

**Step C:** Add to top of `OnTick()` function (first line after opening brace):
```cpp
void OnTick()
{
   // Emergency stop check FIRST
   if(CheckEmergencyStop()) return;

   // ... rest of existing code ...
```

**Step D:** Add to `OnInit()` function (at the end, before return):
```cpp
   // Initialize emergency stop system
   g_currentDay = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_emergencyStop = false;
   g_consecutiveLosses = 0;
```

**Step E:** Compile and verify (F7)
- Should compile with 0 errors
- Save the file

**2.2 For StrikeBot_AI3.mq5**

Repeat the EXACT same steps (A through E) for StrikeBot_AI3.mq5.

The emergency stop code is universal and works with any EA.

---

### Part 3: First Test Run (15 minutes)

**3.1 Quick Sanity Check**

Open Strategy Tester (Ctrl+R):
```
Expert Advisor: Adaptive_Bitcoin_Master_Bot_Final.mq5
Symbol: BTCUSD
Period: M15
Date: 2024-01-01 to 2024-01-31 (just January)
Model: Every tick
Optimization: DISABLED (just testing)
```

Click Start. Let it run for 5 minutes.

**Expected results:**
- Bot opens trades
- Emergency stops DON'T trigger (unless you set thresholds too low)
- No compilation errors in "Journal" tab

**If it crashes:**
- Check "Journal" tab for errors
- Verify emergency stop code was added correctly
- Make sure MagicNumber variable exists in the bot

Repeat for StrikeBot_AI3.mq5.

---

## END OF DAY 1

### What You Accomplished:
✅ MT5 environment verified
✅ Historical data downloaded
✅ Emergency stops installed in BOTH bots
✅ First test runs successful

### Tomorrow (Day 2):
- Configure optimization parameters (RiskPercent, MaxDailyLoss, etc.)
- Set up Walk-Forward Window 1 (Jan-Jun training period)
- Run first genetic algorithm optimization pass

---

## IMPORTANT NOTES

**About the Emergency Stops:**
- These are YOUR safety net for prop firm challenges
- Daily DD limit: 3% (most prop firms breach at 5%, so 3% is safe buffer)
- Total DD limit: 8% (most prop firms breach at 10%)
- Consecutive losses: 5 (prevents revenge trading by bot)

**You can adjust these later**, but start conservative.

**About Compilation:**
If you get errors when adding emergency stop code:
1. Make sure you added it in the right place
2. Check for missing braces `{}`
3. Verify `MagicNumber` variable exists (it should, it's in both bots)

**Git Commit (Optional but Recommended):**
```bash
git add Adaptive_Bitcoin_Master_Bot_Final.mq5 StrikeBot_AI3.mq5
git commit -m "Add emergency stop system to both production bots"
git push -u origin claude/organize-library-review-011CUb1hnwSkqJehHZP3JdcD
```

This saves your work in case something breaks.

---

## Questions Before Day 2?

Common issues:
- **"Bot won't compile after adding code"** → Check syntax, missing braces
- **"Emergency stop triggers immediately"** → Thresholds too low, increase them
- **"No trades in test run"** → Check if bot's original conditions are too strict
- **"Historical data download stuck"** → Try a different symbol or timeframe first

You've got this. Day 1 is about setup and safety. Day 2 is where optimization begins.

**Ready to execute? Start with Part 1 (15 min) and work through each part.**
