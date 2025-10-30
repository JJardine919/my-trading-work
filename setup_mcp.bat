@echo off
echo ========================================
echo Setting up MCP Server for File Management
echo ========================================
echo.

echo Installing Python packages...
pip install openpyxl pandas

echo.
echo Testing MCP server...
python excel_mcp_server.py list

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Available commands:
echo   python excel_mcp_server.py list          - List all backtest files
echo   python excel_mcp_server.py organize      - Show file organization plan
echo   python excel_mcp_server.py analyze-all   - Analyze all Excel files
echo   python excel_mcp_server.py read filename - Read specific file
echo.
pause
