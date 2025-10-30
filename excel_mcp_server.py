#!/usr/bin/env python3
"""
MCP Server for reading Excel/CSV backtest results
"""
import json
import sys
import os
from pathlib import Path

try:
    import openpyxl
    EXCEL_AVAILABLE = True
except ImportError:
    EXCEL_AVAILABLE = False

def read_excel_summary(filepath):
    """Read key metrics from MT5 backtest Excel file"""
    if not EXCEL_AVAILABLE:
        return {"error": "openpyxl not installed. Run: pip install openpyxl"}

    try:
        wb = openpyxl.load_workbook(filepath, read_only=True, data_only=True)
        sheet = wb.active

        results = {
            "file": os.path.basename(filepath),
            "metrics": {}
        }

        # MT5 backtest files have metrics in specific rows
        # Scan for key metrics
        for row in sheet.iter_rows(min_row=1, max_row=100, values_only=True):
            if not row or not row[0]:
                continue

            key = str(row[0]).strip()

            # Extract key metrics
            if "Total Net Profit" in key and len(row) > 3:
                results["metrics"]["net_profit"] = row[3]
            elif "Equity Drawdown Maximal" in key and len(row) > 3:
                # Format: "42 144.33 (31.52%)"
                dd_str = str(row[3])
                if "(" in dd_str:
                    pct = dd_str.split("(")[1].split(")")[0]
                    results["metrics"]["max_drawdown_pct"] = pct
            elif "Profit Factor" in key and len(row) > 3:
                results["metrics"]["profit_factor"] = row[3]
            elif "Total Trades" in key and len(row) > 3:
                results["metrics"]["total_trades"] = row[3]
            elif "Profit Trades" in key and "% of total" in key and len(row) > 3:
                # Format: "20 (28.17%)"
                trades_str = str(row[3])
                results["metrics"]["win_count"] = trades_str.split("(")[0].strip() if "(" in trades_str else trades_str
                if "(" in trades_str:
                    results["metrics"]["win_rate_pct"] = trades_str.split("(")[1].split(")")[0]

        wb.close()
        return results

    except Exception as e:
        return {"error": f"Failed to read Excel: {str(e)}"}

def list_backtest_files(directory):
    """List all Excel backtest files"""
    path = Path(directory)
    files = []

    for ext in ['*.xlsx', '*.xls', '*.csv']:
        for file in path.glob(ext):
            # Skip temp files
            if not file.name.startswith('~'):
                files.append({
                    "name": file.name,
                    "path": str(file),
                    "size": file.stat().st_size,
                    "modified": file.stat().st_mtime
                })

    return sorted(files, key=lambda x: x['modified'], reverse=True)

def organize_files(directory):
    """Organize backtest files into folders"""
    path = Path(directory)

    # Create folders
    quarters_dir = path / "quarterly_tests"
    screenshots_dir = path / "screenshots"
    other_tests_dir = path / "other_tests"

    quarters_dir.mkdir(exist_ok=True)
    screenshots_dir.mkdir(exist_ok=True)
    other_tests_dir.mkdir(exist_ok=True)

    moves = []

    # Organize quarterly tests
    quarterly_patterns = ["jan1", "mar1", "july1", "oct1"]
    for pattern in quarterly_patterns:
        for file in path.glob(f"*{pattern}*.xlsx"):
            new_path = quarters_dir / file.name
            moves.append({"from": str(file), "to": str(new_path)})

    # Organize screenshots
    for file in path.glob("*.png"):
        new_path = screenshots_dir / file.name
        moves.append({"from": str(file), "to": str(new_path)})

    return {
        "plan": moves,
        "note": "Run execute_moves=true to actually move files"
    }

def main():
    """MCP Server main loop"""
    working_dir = "C:\\Users\\jimjj\\Documents\\my-trading-work"

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "list":
            result = list_backtest_files(working_dir)
            print(json.dumps(result, indent=2))

        elif command == "organize":
            result = organize_files(working_dir)
            print(json.dumps(result, indent=2))

        elif command == "read":
            if len(sys.argv) < 3:
                print(json.dumps({"error": "Provide filename"}))
                return

            filepath = os.path.join(working_dir, sys.argv[2])
            result = read_excel_summary(filepath)
            print(json.dumps(result, indent=2))

        elif command == "analyze-all":
            files = list_backtest_files(working_dir)
            results = []

            for file in files:
                if file['name'].endswith('.xlsx'):
                    data = read_excel_summary(file['path'])
                    results.append(data)

            print(json.dumps(results, indent=2))
    else:
        print(json.dumps({
            "error": "No command provided",
            "usage": "python excel_mcp_server.py [list|organize|read|analyze-all] [filename]"
        }))

if __name__ == "__main__":
    main()
