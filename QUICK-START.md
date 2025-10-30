# n8n MCP Quick Start

## Start n8n

```bash
./start-n8n.sh
```

Then open: **http://localhost:5678**

## Create Your First MCP Workflow

### 1. In n8n Dashboard:
- Click **"+ Create"** → New Workflow
- Add **"MCP Server Trigger"** node
- Configure authentication (Bearer token)
- Add your tool logic (e.g., HTTP Request node)
- **Activate the workflow** (toggle switch)

### 2. Get Your MCP Endpoint:
- Copy the webhook URL from the MCP Server Trigger node
- Example: `http://localhost:5678/webhook/mcp-server-abc123`

### 3. Configure Claude Code:
- Add to your Claude MCP config
- Use the webhook URL and bearer token

## Common Commands

```bash
# Start n8n
./start-n8n.sh

# Or with npx directly
npx n8n

# Start with tunnel (public URL)
npx n8n start --tunnel

# Stop n8n
Press Ctrl+C
```

## Testing Your MCP Server

Once n8n is running and workflow is active:

1. In Claude Code, ask: "What MCP tools are available?"
2. Claude should see your n8n exposed tools
3. Test calling one: "Call the [tool name] from n8n"

## Troubleshooting

**Port already in use?**
```bash
# Find and kill process on port 5678
lsof -ti:5678 | xargs kill -9
```

**Workflow not activating?**
- Check all nodes are properly configured
- Ensure no errors in the workflow
- Check the execution log in n8n

**MCP connection failing?**
- Verify n8n is running
- Check the webhook URL is correct
- Confirm bearer token matches
- Ensure workflow is "Active"

## Need Help?

See full documentation: `N8N-MCP-SETUP.md`
