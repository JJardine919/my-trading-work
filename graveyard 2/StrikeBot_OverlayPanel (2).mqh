
//+------------------------------------------------------------------+
//|                                                   StrikeBot UI  |
//|                                  Minimal Overlay Display         |
//+------------------------------------------------------------------+
#include <ChartObjects\ChartObjectsTxtControls.mqh>

CChartObjectLabel label_status, label_rsi, label_ma, label_equity, label_drawdown;

void InitOverlayPanel()
{
   CreateLabel(label_status, "SB_Status", 10, 20, "Status: N/A");
   CreateLabel(label_rsi, "SB_RSI", 10, 40, "RSI: --");
   CreateLabel(label_ma, "SB_MA", 10, 60, "MA: --");
   CreateLabel(label_equity, "SB_Equity", 10, 80, "Equity: --");
   CreateLabel(label_drawdown, "SB_Drawdown", 10, 100, "Drawdown: --");
}

void CreateLabel(CChartObjectLabel &label, string name, int x, int y, string text)
{
   label.Create(0, name, 0, x, y);
   label.Text(text);
   label.Font("Arial");
   label.FontSize(10);
   label.Color(clrWhite);
   label.Corner(CORNER_LEFT_UPPER);
   label.BackColor(clrNONE);
}

void UpdateOverlayPanel(double rsi, double ma, string status, double equity, double drawdown)
{
   label_status.Text("Status: " + status);
   label_rsi.Text("RSI: " + DoubleToString(rsi, 2));
   label_ma.Text("MA: " + DoubleToString(ma, 2));
   label_equity.Text("Equity: $" + DoubleToString(equity, 2));
   label_drawdown.Text("Drawdown: " + DoubleToString(drawdown, 2) + "%");
}
