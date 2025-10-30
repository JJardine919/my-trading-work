#!/usr/bin/env python3
"""
Automatic Bot Comparison Script
Compares Original vs ML-Enhanced Adaptive Bitcoin bot performance
"""
import pandas as pd
import sys
import os

def extract_metrics(excel_file):
    """Extract key metrics from MT5 backtest Excel file"""
    try:
        # Read Excel file
        df = pd.read_excel(excel_file, sheet_name=0, engine='openpyxl')

        metrics = {
            'file': os.path.basename(excel_file),
            'net_profit': None,
            'profit_factor': None,
            'total_trades': None,
            'win_rate': None,
            'long_trades': None,
            'short_trades': None,
            'balance_dd': None,
            'equity_dd': None,
            'sharpe_ratio': None
        }

        # Search for metrics in the Excel file
        for idx, row in df.iterrows():
            row_str = ' '.join([str(x) for x in row if pd.notna(x)])

            # Net Profit
            if 'Total Net Profit' in row_str and metrics['net_profit'] is None:
                for val in row:
                    if isinstance(val, (int, float)) and val != 0:
                        metrics['net_profit'] = val
                        break

            # Profit Factor
            if 'Profit Factor' in row_str and metrics['profit_factor'] is None:
                for val in row:
                    if isinstance(val, (int, float)) and val > 0 and val < 100:
                        metrics['profit_factor'] = val
                        break

            # Total Trades
            if 'Total Deals' in row_str or 'Total Trades' in row_str:
                for val in row:
                    if isinstance(val, (int, float)) and val > 0:
                        metrics['total_trades'] = int(val)
                        break

            # Win Rate
            if 'Profit Trades (% of total)' in row_str:
                for val in row:
                    if isinstance(val, str) and '%' in str(val):
                        try:
                            pct = float(str(val).replace('%', '').strip())
                            metrics['win_rate'] = pct
                        except:
                            pass
                        break

            # Long Trades
            if 'Long Trades (won %)' in row_str or 'Buy trades' in row_str:
                for val in row:
                    if isinstance(val, (int, float)) and val > 0:
                        metrics['long_trades'] = int(val)
                        break

            # Short Trades
            if 'Short Trades (won %)' in row_str or 'Sell trades' in row_str:
                for val in row:
                    if isinstance(val, (int, float)) and val > 0:
                        metrics['short_trades'] = int(val)
                        break

            # Balance Drawdown
            if 'Balance Drawdown Maximal' in row_str:
                for val in row:
                    if isinstance(val, str) and '%' in str(val):
                        try:
                            pct = str(val).split('(')[1].split(')')[0].replace('%', '').strip()
                            metrics['balance_dd'] = float(pct)
                        except:
                            pass
                        break

            # Equity Drawdown
            if 'Equity Drawdown Maximal' in row_str:
                for val in row:
                    if isinstance(val, str) and '%' in str(val):
                        try:
                            pct = str(val).split('(')[1].split(')')[0].replace('%', '').strip()
                            metrics['equity_dd'] = float(pct)
                        except:
                            pass
                        break

            # Sharpe Ratio
            if 'Sharpe Ratio' in row_str:
                for val in row:
                    if isinstance(val, (int, float)) and val != 0:
                        metrics['sharpe_ratio'] = val
                        break

        return metrics

    except Exception as e:
        print(f"Error reading {excel_file}: {e}")
        return None

def compare_bots(original_file, ml_file):
    """Compare Original vs ML-Enhanced bot"""

    print("=" * 80)
    print("📊 ADAPTIVE BITCOIN BOT COMPARISON")
    print("=" * 80)
    print()

    # Extract metrics
    print("Reading original bot results...")
    original = extract_metrics(original_file)

    print("Reading ML-enhanced bot results...")
    ml_enhanced = extract_metrics(ml_file)

    if not original or not ml_enhanced:
        print("\n❌ Error: Could not read one or both Excel files")
        return

    print("\n" + "=" * 80)
    print("RESULTS COMPARISON")
    print("=" * 80)

    # Helper function to format comparison
    def compare_metric(name, orig_val, ml_val, higher_is_better=True, is_pct=False):
        if orig_val is None or ml_val is None:
            return f"{name:30s} | {'N/A':>15s} | {'N/A':>15s} | N/A"

        if is_pct:
            orig_str = f"{orig_val:.2f}%"
            ml_str = f"{ml_val:.2f}%"
        else:
            orig_str = f"{orig_val:,.2f}" if isinstance(orig_val, float) else f"{orig_val:,}"
            ml_str = f"{ml_val:,.2f}" if isinstance(ml_val, float) else f"{ml_val:,}"

        diff = ml_val - orig_val
        if higher_is_better:
            symbol = "✅" if diff > 0 else "❌" if diff < 0 else "➖"
        else:
            symbol = "✅" if diff < 0 else "❌" if diff > 0 else "➖"

        if is_pct:
            diff_str = f"{diff:+.2f}%"
        else:
            pct_change = (diff / orig_val * 100) if orig_val != 0 else 0
            diff_str = f"{diff:+,.2f} ({pct_change:+.1f}%)"

        return f"{name:30s} | {orig_str:>15s} | {ml_str:>15s} | {symbol} {diff_str}"

    print()
    print(f"{'Metric':30s} | {'Original Bot':>15s} | {'ML Enhanced':>15s} | Change")
    print("-" * 80)

    # Profitability
    print("\n💰 PROFITABILITY:")
    print(compare_metric("Net Profit", original['net_profit'], ml_enhanced['net_profit'], higher_is_better=True))
    print(compare_metric("Profit Factor", original['profit_factor'], ml_enhanced['profit_factor'], higher_is_better=True))

    # Trading Activity
    print("\n📈 TRADING ACTIVITY:")
    print(compare_metric("Total Trades", original['total_trades'], ml_enhanced['total_trades'], higher_is_better=True))
    print(compare_metric("Long Trades", original['long_trades'], ml_enhanced['long_trades'], higher_is_better=False))
    print(compare_metric("Short Trades", original['short_trades'], ml_enhanced['short_trades'], higher_is_better=False))

    # Balance Analysis
    if original['long_trades'] and original['short_trades'] and ml_enhanced['long_trades'] and ml_enhanced['short_trades']:
        orig_ratio = original['long_trades'] / max(original['short_trades'], 1)
        ml_ratio = ml_enhanced['long_trades'] / max(ml_enhanced['short_trades'], 1)
        print(f"\n{'Long/Short Ratio':30s} | {orig_ratio:>15.2f} | {ml_ratio:>15.2f} | ", end="")
        if abs(ml_ratio - 1.0) < abs(orig_ratio - 1.0):
            print(f"✅ More balanced ({abs(1.0 - ml_ratio):.2f} vs {abs(1.0 - orig_ratio):.2f})")
        else:
            print(f"❌ Less balanced ({abs(1.0 - ml_ratio):.2f} vs {abs(1.0 - orig_ratio):.2f})")

    # Risk Metrics
    print("\n⚠️ RISK METRICS:")
    print(compare_metric("Balance Drawdown", original['balance_dd'], ml_enhanced['balance_dd'], higher_is_better=False, is_pct=True))
    print(compare_metric("Equity Drawdown", original['equity_dd'], ml_enhanced['equity_dd'], higher_is_better=False, is_pct=True))
    print(compare_metric("Win Rate", original['win_rate'], ml_enhanced['win_rate'], higher_is_better=True, is_pct=True))

    # Sharpe Ratio
    if original['sharpe_ratio'] and ml_enhanced['sharpe_ratio']:
        print(compare_metric("Sharpe Ratio", original['sharpe_ratio'], ml_enhanced['sharpe_ratio'], higher_is_better=True))

    # Summary
    print("\n" + "=" * 80)
    print("📋 SUMMARY")
    print("=" * 80)

    improvements = []
    concerns = []

    if ml_enhanced['net_profit'] and original['net_profit']:
        if ml_enhanced['net_profit'] > original['net_profit']:
            improvements.append(f"Higher profit: ${ml_enhanced['net_profit']:,.2f} vs ${original['net_profit']:,.2f}")
        else:
            concerns.append(f"Lower profit: ${ml_enhanced['net_profit']:,.2f} vs ${original['net_profit']:,.2f}")

    if ml_enhanced['long_trades'] and ml_enhanced['short_trades']:
        ratio = ml_enhanced['long_trades'] / max(ml_enhanced['short_trades'], 1)
        if 0.7 <= ratio <= 1.3:
            improvements.append(f"Balanced trading: {ml_enhanced['long_trades']} longs vs {ml_enhanced['short_trades']} shorts")
        else:
            concerns.append(f"Imbalanced trading: {ml_enhanced['long_trades']} longs vs {ml_enhanced['short_trades']} shorts")

    if ml_enhanced['equity_dd'] and original['equity_dd']:
        if ml_enhanced['equity_dd'] < original['equity_dd']:
            improvements.append(f"Lower drawdown: {ml_enhanced['equity_dd']:.2f}% vs {original['equity_dd']:.2f}%")
        else:
            concerns.append(f"Higher drawdown: {ml_enhanced['equity_dd']:.2f}% vs {original['equity_dd']:.2f}%")

    if improvements:
        print("\n✅ IMPROVEMENTS:")
        for imp in improvements:
            print(f"   • {imp}")

    if concerns:
        print("\n⚠️ CONCERNS:")
        for con in concerns:
            print(f"   • {con}")

    print("\n" + "=" * 80)
    print("🎯 RECOMMENDATION")
    print("=" * 80)

    # Calculate score
    score = 0
    if ml_enhanced['net_profit'] and original['net_profit']:
        if ml_enhanced['net_profit'] > original['net_profit']:
            score += 2

    if ml_enhanced['long_trades'] and ml_enhanced['short_trades']:
        ratio = ml_enhanced['long_trades'] / max(ml_enhanced['short_trades'], 1)
        if 0.7 <= ratio <= 1.3:
            score += 2

    if ml_enhanced['equity_dd'] and original['equity_dd']:
        if ml_enhanced['equity_dd'] < original['equity_dd']:
            score += 1

    if ml_enhanced['profit_factor'] and original['profit_factor']:
        if ml_enhanced['profit_factor'] > original['profit_factor']:
            score += 1

    print()
    if score >= 4:
        print("🚀 STRONG RECOMMENDATION: Use ML-Enhanced bot")
        print("   The ML model shows clear improvements in key metrics.")
    elif score >= 2:
        print("✅ RECOMMENDATION: Use ML-Enhanced bot")
        print("   The ML model shows promising improvements.")
    else:
        print("⚠️ MIXED RESULTS: Test more quarters")
        print("   Results are inconclusive. Run more backtests to verify.")

    print("\n" + "=" * 80)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python compare_bots.py <original_excel> <ml_enhanced_excel>")
        print()
        print("Example:")
        print("  python compare_bots.py original_Q4.xlsx ml_enhanced_Q4.xlsx")
        sys.exit(1)

    original_file = sys.argv[1]
    ml_file = sys.argv[2]

    if not os.path.exists(original_file):
        print(f"Error: File not found: {original_file}")
        sys.exit(1)

    if not os.path.exists(ml_file):
        print(f"Error: File not found: {ml_file}")
        sys.exit(1)

    compare_bots(original_file, ml_file)
