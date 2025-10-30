# n8n MCP Server Setup Guide

## Quick Start

### 1. Start n8n

```bash
./start-n8n.sh
```

Or directly with npx:
```bash
npx n8n
```

n8n will start on: **http://localhost:5678**

### 2. First Time Setup

1. Open http://localhost:5678 in your browser
2. Create your n8n account (local instance)
3. You'll be taken to the n8n dashboard

## MCP Integration (Built-in to n8n v1.88+)

n8n has **native MCP support** with two built-in nodes:

### 1. MCP Server Trigger Node
Makes n8n workflows available as MCP tools that AI agents can call

### 2. MCP Client Tool Node
Connects to external MCP servers from within n8n workflows

## Setting Up n8n as an MCP Server

### Step 1: Create a New Workflow

1. Click "**+ Create**" in n8n dashboard
2. Add the "**MCP Server Trigger**" node
   - Find it under: **Triggers > MCP Server Trigger**

### Step 2: Configure MCP Server Trigger

1. **Authentication**: Configure Bearer token
   - Click on the MCP Server Trigger node
   - Set up authentication (recommended for security)
   - Save your bearer token (you'll need it for clients)

2. **Add AI Tool**: Define what your MCP server can do
   - Click "+ Add Tool"
   - Configure the tool (e.g., "Get Trading Data", "Execute Trade", etc.)
   - Connect it to other n8n nodes (HTTP Request, Database, etc.)

3. **Activate Workflow**
   - Toggle the workflow to "Active"
   - The MCP Server Trigger will display your endpoint URL
   - Example: `http://localhost:5678/webhook/mcp-server-xxxxx`

### Step 3: Connect Claude Code to Your n8n MCP Server

Add to your Claude Code MCP configuration:

```json
{
  "mcpServers": {
    "n8n-trading": {
      "url": "http://localhost:5678/webhook/mcp-server-xxxxx",
      "transport": {
        "type": "sse"
      },
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN_HERE"
      }
    }
  }
}
```

## Example MCP Workflows

### Example 1: Trading Data API

```
MCP Server Trigger → HTTP Request → Format Data → Return Response
```

This exposes a tool like "get_trading_data" that Claude can call.

### Example 2: Execute Trade Order

```
MCP Server Trigger → Validate Input → HTTP Request (to broker API) → Log Result → Return Response
```

This exposes a tool like "execute_trade" for placing orders.

### Example 3: Market Analysis

```
MCP Server Trigger → Get Market Data → AI Agent Node → Return Analysis
```

This exposes a tool like "analyze_market" for AI-powered analysis.

## Using n8n as an MCP Client

You can also connect n8n TO other MCP servers:

1. Add the "**MCP Client Tool**" node to your workflow
2. Configure the SSE Endpoint (MCP server URL)
3. Add authentication if required
4. Connect it to AI Agent nodes or other workflows

## Common Use Cases for Trading

1. **Market Data Provider**: Expose your trading data via MCP
2. **Order Execution**: Let AI agents place trades through n8n
3. **Portfolio Management**: Query and manage positions
4. **Alert System**: Send notifications based on market conditions
5. **Strategy Backtesting**: Run backtests via MCP calls

## Troubleshooting

### n8n Won't Start
- Make sure no other service is using port 5678
- Try: `npx n8n start --tunnel` for public access

### MCP Endpoint Not Working
- Ensure workflow is "Active"
- Check authentication token matches
- Verify the endpoint URL is correct

### Connection Issues
- n8n must be running for MCP endpoints to work
- Check firewall settings if accessing remotely
- Use `http://localhost:5678` for local connections

## Environment Variables (Optional)

Create a `.env` file for custom configuration:

```bash
# n8n Configuration
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_HOST=localhost

# For production (optional)
N8N_ENCRYPTION_KEY=your-encryption-key
```

## Data Persistence

n8n stores data in: `~/.n8n/`

To backup your workflows:
```bash
cp -r ~/.n8n/ ./n8n-backup/
```

## Next Steps

1. Start n8n: `./start-n8n.sh`
2. Create your first MCP workflow
3. Connect Claude Code to your n8n MCP server
4. Test by asking Claude to call your exposed tools

## Resources

- [n8n MCP Documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcptrigger/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [n8n Community Examples](https://community.n8n.io/)

## Support

- n8n Community: https://community.n8n.io/
- MCP Documentation: https://docs.anthropic.com/en/docs/model-context-protocol
