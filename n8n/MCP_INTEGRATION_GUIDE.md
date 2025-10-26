# MCP Integration Quick Reference

This guide provides quick examples for integrating your existing n8n workflows with Model Context Protocol (MCP).

## What is MCP?

Model Context Protocol (MCP) is a standardized way for AI models to interact with external tools and services. In the context of n8n:

- **MCP Server** = Your n8n workflows become tools that AI agents can use
- **MCP Client** = Your n8n workflows can use external AI tools and services

## Use Cases

### 1. Expose n8n Workflows to AI (MCP Server)

Your AI agent (like Claude) can trigger your n8n workflows to:
- Analyze market data
- Execute trades
- Monitor portfolio
- Generate reports
- Send alerts

### 2. Use AI Tools in n8n (MCP Client)

Your n8n workflows can call external AI services to:
- Get trading recommendations
- Analyze sentiment
- Process natural language
- Generate insights

## Quick Setup for Existing Workflows

### Option A: Add MCP Server Trigger (Expose Workflow to AI)

1. Open your existing workflow in n8n
2. Add a new "MCP Server Trigger" node at the beginning:
   ```json
   {
     "type": "n8n-nodes-base.mcpServerTrigger",
     "parameters": {
       "path": "/my-workflow-name",
       "authentication": "bearer",
       "bearerToken": "={{ $env.MCP_BEARER_TOKEN }}"
     }
   }
   ```
3. Connect it to your existing workflow
4. The workflow can now be called via MCP!

### Option B: Add MCP Client Tool (Use AI in Workflow)

1. Open your existing workflow in n8n
2. Add an "MCP Client Tool" node where you want AI assistance:
   ```json
   {
     "type": "n8n-nodes-langchain.toolMcp",
     "parameters": {
       "server": "trading-analytics",
       "tool": "analyze_market_data",
       "parameters": {
         "symbol": "={{ $json.symbol }}",
         "timeframe": "1h"
       }
     }
   }
   ```
3. Process the AI response in your workflow

## Practical Examples

### Example 1: Trigger Your Workflow from Claude

```bash
# In your Claude Code MCP configuration
{
  "tools": [
    {
      "name": "analyze_trading_opportunity",
      "url": "http://localhost:5678/webhook/my-workflow",
      "method": "POST",
      "headers": {
        "Authorization": "Bearer YOUR_MCP_TOKEN"
      }
    }
  ]
}
```

Now you can tell Claude: "Analyze BTCUSD trading opportunity" and it will trigger your n8n workflow!

### Example 2: Get AI Analysis in Your Workflow

In your n8n workflow, add a Code node:

```javascript
// Prepare data for AI analysis
const marketData = {
  symbol: $json.symbol,
  price: $json.current_price,
  volume: $json.volume,
  indicators: {
    rsi: $json.rsi,
    macd: $json.macd
  }
};

// This will be passed to MCP Client Tool node
return [{ json: marketData }];
```

Then connect to MCP Client Tool node to get AI recommendation.

### Example 3: Webhook with MCP Authentication

Replace your webhook node with MCP Server Trigger:

**Before:**
```json
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "path": "my-webhook"
  }
}
```

**After:**
```json
{
  "type": "n8n-nodes-base.mcpServerTrigger",
  "parameters": {
    "path": "my-webhook",
    "authentication": "bearer",
    "bearerToken": "={{ $env.MCP_BEARER_TOKEN }}"
  }
}
```

Now your webhook is MCP-enabled!

## MCP Tools Available

Based on `mcp-config/server-config.json`, these tools are available:

### 1. analyze_market_data
```javascript
// Call from AI or external service
POST /mcp/analyze_market_data
{
  "symbol": "BTCUSD",
  "timeframe": "1h",
  "indicators": ["sma", "rsi", "macd"]
}
```

### 2. execute_trade
```javascript
POST /mcp/execute_trade
{
  "symbol": "BTCUSD",
  "side": "buy",
  "quantity": 0.01,
  "type": "market"
}
```

### 3. get_portfolio_status
```javascript
POST /mcp/get_portfolio_status
{
  "include_history": true
}
```

### 4. set_risk_parameters
```javascript
POST /mcp/set_risk_parameters
{
  "max_position_size": 20,
  "stop_loss_percentage": 5,
  "take_profit_percentage": 15
}
```

## Common Integration Patterns

### Pattern 1: AI-Triggered Workflow

```
AI Agent → MCP Request → n8n MCP Server Trigger → Your Workflow → Response
```

Use case: Claude analyzes your chat and triggers a trading workflow

### Pattern 2: AI-Enhanced Workflow

```
Schedule/Trigger → Your Workflow → MCP Client Tool → AI Analysis → Continue Workflow
```

Use case: Your automated trading bot asks AI for confirmation before executing

### Pattern 3: Bidirectional AI Integration

```
AI Agent ←→ n8n (both MCP Server + Client) ←→ External AI Services
```

Use case: Complex multi-agent trading system

## Testing Your MCP Integration

### Test MCP Server (Your Workflows)

```bash
# Test with curl
curl -X POST http://localhost:5678/webhook/your-workflow \
  -H "Authorization: Bearer YOUR_MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"symbol": "BTCUSD", "action": "analyze"}'
```

### Test MCP Client (External AI)

1. Set up external MCP server in `mcp-config/client-config.json`
2. Add MCP Client Tool node in workflow
3. Execute workflow and check results

## Environment Variables for MCP

Add to your `.env` file:

```bash
# MCP Server (exposing n8n)
MCP_BEARER_TOKEN=your_secure_token_here
N8N_MCP_ENABLED=true
N8N_MCP_SERVER_PORT=3000

# MCP Clients (external AI services)
EXTERNAL_MCP_TOKEN=external_service_token
MARKET_DATA_API_KEY=market_data_token
```

## Troubleshooting

### MCP Trigger Not Working
- Check bearer token is set in .env
- Verify n8n has MCP support (self-hosted required)
- Check workflow is activated

### MCP Client Connection Failed
- Verify external MCP server URL
- Check authentication credentials
- Test external service availability

### Authentication Errors
- Ensure bearer token matches between client and server
- Check token is loaded from environment variable
- Verify Authorization header format

## Security Notes

1. **Never expose MCP endpoints publicly** without proper authentication
2. **Use strong bearer tokens** (generate with: `openssl rand -hex 32`)
3. **Rotate tokens regularly** for production systems
4. **Use HTTPS** in production (setup reverse proxy)
5. **Validate all inputs** in MCP-triggered workflows
6. **Rate limit** MCP endpoints to prevent abuse

## Next Steps

1. Identify which of your existing workflows would benefit from MCP
2. Add MCP Server Trigger to workflows you want to expose
3. Add MCP Client Tool to workflows that need AI assistance
4. Test the integration thoroughly
5. Update your AI agent configuration to use the new tools
6. Monitor workflow executions and adjust as needed

## Resources

- [n8n MCP Documentation](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.toolmcp/)
- [Model Context Protocol Docs](https://modelcontextprotocol.io/)
- [n8n Community Forum](https://community.n8n.io/)

## Need Help?

Check the main README.md for detailed setup instructions and examples.
