# n8n Workflows with MCP Integration

This directory contains n8n workflow automation setup integrated with Model Context Protocol (MCP) for trading operations.

## Overview

The setup includes:
- **n8n Server**: Self-hosted workflow automation platform
- **MCP Integration**: Model Context Protocol for AI-powered trading tools
- **Trading Workflows**: Pre-built workflows for market analysis, automated trading, and risk management
- **PostgreSQL Database**: For workflow execution history and trade logging

## Directory Structure

```
n8n/
├── docker-compose.yml          # Docker setup for n8n and PostgreSQL
├── .env.example               # Environment variables template
├── mcp-config/                # MCP server and client configurations
│   ├── server-config.json     # MCP server tool definitions
│   └── client-config.json     # MCP client connection settings
├── workflows/                 # Pre-built n8n workflows
│   ├── market-analysis-mcp.json
│   ├── automated-trading-mcp.json
│   └── risk-management-mcp.json
├── templates/                 # Workflow templates (empty, ready for custom workflows)
└── data/                     # n8n data directory (created on first run)
```

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed
- Trading API credentials (optional, for live trading)
- At least 2GB RAM available

### 2. Initial Setup

```bash
# Navigate to n8n directory
cd n8n

# Copy environment template
cp .env.example .env

# Edit .env file with your credentials
nano .env

# Start n8n and PostgreSQL
docker-compose up -d

# Check logs
docker-compose logs -f n8n
```

### 3. Access n8n

Open your browser and navigate to: `http://localhost:5678`

Default credentials:
- Username: `admin` (change in .env)
- Password: `changeme` (change in .env)

## MCP Configuration

### MCP Server (Exposing n8n Workflows to AI)

The MCP Server configuration (`mcp-config/server-config.json`) defines tools that AI agents can use:

#### Available Tools:

1. **analyze_market_data**
   - Analyze market data with technical indicators
   - Parameters: symbol, timeframe, indicators[]

2. **execute_trade**
   - Execute trading orders
   - Parameters: symbol, side, quantity, type, price (optional)

3. **get_portfolio_status**
   - Get current portfolio status and positions
   - Parameters: include_history (optional)

4. **set_risk_parameters**
   - Configure risk management settings
   - Parameters: max_position_size, stop_loss_percentage, take_profit_percentage

### MCP Client (Consuming External MCP Services)

The MCP Client configuration (`mcp-config/client-config.json`) defines external MCP services that n8n can connect to.

## Workflows

### 1. Market Analysis with MCP

**File**: `workflows/market-analysis-mcp.json`

**Purpose**: Exposes market analysis as an MCP tool

**Features**:
- MCP Server Trigger endpoint
- Fetches real-time market data
- Applies technical indicators (SMA, RSI, MACD)
- Returns analysis with buy/sell/hold recommendations

**Usage**:
```bash
# Call via MCP client
curl -X POST http://localhost:5678/webhook/market-analysis \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "symbol": "BTCUSD",
      "timeframe": "1h",
      "indicators": ["sma", "rsi", "macd"]
    }
  }'
```

### 2. Automated Trading with MCP

**File**: `workflows/automated-trading-mcp.json`

**Purpose**: Automated trading bot with MCP integration

**Features**:
- Runs every 5 minutes (configurable)
- Checks portfolio status via MCP
- Analyzes market conditions via MCP
- Executes trades based on signals
- Logs all trades to PostgreSQL

**Safety Features**:
- Risk level checks
- Minimum balance requirements
- Confidence threshold (70%)
- Position sizing limits

### 3. Risk Management with MCP

**File**: `workflows/risk-management-mcp.json`

**Purpose**: Portfolio risk monitoring and management

**Features**:
- Webhook-triggered risk assessment
- Calculates portfolio metrics
- Detects over-concentration
- Monitors unrealized losses
- Adjusts risk parameters automatically
- Sends alerts for high-risk situations

**Risk Metrics**:
- Total exposure percentage
- Largest position percentage
- Diversification score
- Overall risk level (low/medium/high)

## Importing Workflows

### Via UI:
1. Open n8n at `http://localhost:5678`
2. Click "Add workflow"
3. Click "⋮" menu → "Import from File"
4. Select a workflow JSON file
5. Click "Save"

### Via API:
```bash
curl -X POST http://localhost:5678/rest/workflows \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d @workflows/market-analysis-mcp.json
```

## MCP Integration in Your Workflows

### Using MCP Server Trigger Node

```javascript
// In n8n workflow
{
  "node": "MCP Server Trigger",
  "type": "n8n-nodes-base.mcpServerTrigger",
  "parameters": {
    "path": "/your-tool-name",
    "authentication": "bearer",
    "bearerToken": "={{ $env.MCP_BEARER_TOKEN }}"
  }
}
```

### Using MCP Client Tool Node

```javascript
// In n8n workflow
{
  "node": "MCP Client Tool",
  "type": "n8n-nodes-langchain.toolMcp",
  "parameters": {
    "server": "trading-analytics",
    "tool": "analyze_market_data",
    "parameters": {
      "symbol": "{{ $json.symbol }}",
      "timeframe": "5m"
    }
  }
}
```

## Configuration

### Environment Variables

Edit `.env` file:

```bash
# n8n Authentication
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password

# MCP Configuration
MCP_BEARER_TOKEN=your_secure_mcp_token

# Trading API (customize for your exchange)
TRADING_API_KEY=your_api_key
TRADING_API_SECRET=your_api_secret
TRADING_API_URL=https://api.yourexchange.com
```

### MCP Server Configuration

Edit `mcp-config/server-config.json` to:
- Add new tools
- Modify tool parameters
- Configure authentication
- Set timeout and retry settings

### Database Setup

PostgreSQL is automatically configured. To create tables for trade logging:

```bash
# Access PostgreSQL
docker-compose exec postgres psql -U n8n

# Create trade log table
CREATE TABLE trade_log (
  id SERIAL PRIMARY KEY,
  symbol VARCHAR(20),
  side VARCHAR(10),
  quantity DECIMAL(18, 8),
  type VARCHAR(10),
  price DECIMAL(18, 8),
  status VARCHAR(20),
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Security Best Practices

1. **Change Default Passwords**: Update all passwords in `.env`
2. **Use Strong Bearer Tokens**: Generate secure tokens for MCP authentication
3. **Enable HTTPS**: Use reverse proxy (nginx/traefik) for production
4. **Restrict Access**: Use firewall rules to limit access to n8n port
5. **Backup Data**: Regularly backup PostgreSQL and n8n data directory
6. **API Key Management**: Never commit `.env` file with real credentials
7. **Webhook Security**: Use webhook secrets for external triggers

## Monitoring and Logging

### View n8n Logs
```bash
docker-compose logs -f n8n
```

### View PostgreSQL Logs
```bash
docker-compose logs -f postgres
```

### Execution History
- View in n8n UI: Executions tab
- Query database: `SELECT * FROM execution_entity ORDER BY created_at DESC LIMIT 10;`

## Troubleshooting

### n8n Won't Start
```bash
# Check logs
docker-compose logs n8n

# Common issues:
# - Port 5678 already in use: Change N8N_PORT in .env
# - Database connection failed: Wait for postgres to be healthy
```

### MCP Tools Not Working
```bash
# Verify MCP configuration
cat mcp-config/server-config.json | jq

# Check bearer token
echo $MCP_BEARER_TOKEN

# Test MCP endpoint
curl -X POST http://localhost:3000/mcp \
  -H "Authorization: Bearer $MCP_BEARER_TOKEN"
```

### Workflows Not Executing
- Check workflow is activated (toggle in UI)
- Verify trigger configuration
- Check execution logs in n8n UI
- Ensure credentials are properly set

## Customization

### Adding Your Existing Workflows

If you have existing n8n workflows:

1. **Export from existing n8n**:
   - Open workflow in n8n
   - Click "⋮" → "Download"
   - Save to `workflows/` directory

2. **Import to this instance**:
   - Follow import instructions above

3. **Add MCP Integration**:
   - Add "MCP Server Trigger" node to expose as tool
   - Add "MCP Client Tool" node to use external MCP services

### Creating Custom MCP Tools

1. Edit `mcp-config/server-config.json`
2. Add new tool definition:

```json
{
  "name": "your_custom_tool",
  "description": "Tool description",
  "parameters": {
    "type": "object",
    "properties": {
      "param1": {
        "type": "string",
        "description": "Parameter description"
      }
    },
    "required": ["param1"]
  }
}
```

3. Create corresponding n8n workflow with MCP Server Trigger

## Integration with Trading Systems

### MetaTrader 5 (MQL5) Integration

Your existing MQL5 Expert Advisors can interact with n8n workflows:

```mql5
// In your EA
string url = "http://localhost:5678/webhook/market-analysis";
string headers = "Authorization: Bearer " + MCP_BEARER_TOKEN + "\r\n";
string data = "{\"params\":{\"symbol\":\"BTCUSD\",\"timeframe\":\"1h\"}}";

char post[];
char result[];
string result_headers;

ArrayResize(post, StringToCharArray(data, post, 0, WHOLE_ARRAY) - 1);
int res = WebRequest("POST", url, headers, 5000, post, result, result_headers);
```

### AI Agent Integration

Connect Claude or other AI agents to your n8n workflows via MCP:

```python
# Python example using MCP SDK
from mcp import Client

client = Client("http://localhost:3000/mcp", token="YOUR_TOKEN")

# Call trading tool
result = client.call_tool(
    "analyze_market_data",
    symbol="BTCUSD",
    timeframe="1h",
    indicators=["sma", "rsi"]
)
```

## Advanced Topics

### Scaling n8n
- Use external PostgreSQL for production
- Enable queue mode for better performance
- Use multiple n8n workers

### High Availability
- Run multiple n8n instances behind load balancer
- Use Redis for shared state
- Setup database replication

### CI/CD for Workflows
- Version control workflows in git
- Automated deployment via API
- Testing workflows programmatically

## Resources

- [n8n Documentation](https://docs.n8n.io/)
- [MCP Documentation](https://modelcontextprotocol.io/)
- [n8n Community](https://community.n8n.io/)
- [MCP GitHub](https://github.com/anthropics/model-context-protocol)

## Support

For issues or questions:
1. Check n8n logs: `docker-compose logs -f n8n`
2. Review workflow execution history in n8n UI
3. Test MCP endpoints manually
4. Check database connections

## License

This configuration is provided as-is for your trading operations.
