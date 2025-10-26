# n8n MCP Setup Guide

This guide explains how to set up and use the n8n Model Context Protocol (MCP) server with Claude Code.

## What is MCP?

Model Context Protocol (MCP) is a standardized protocol that allows AI assistants like Claude to securely connect to external data sources and tools. The n8n MCP server enables Claude to interact with your n8n workflows.

## Prerequisites

1. **n8n instance** running (locally or remote)
   - Default: `http://localhost:5678`
   - Get n8n at: https://n8n.io

2. **Node.js** and **npm** installed
   - Version 16.x or higher recommended

3. **n8n API Key**
   - Generate from: n8n Settings → API → Create API Key

## Installation Steps

### 1. Configure Environment Variables

Copy the example environment file and add your n8n credentials:

```bash
cp .env.example .env
```

Edit `.env` and update:
```bash
N8N_API_URL=http://localhost:5678  # Your n8n instance URL
N8N_API_KEY=your_actual_api_key    # Your n8n API key
```

### 2. Configure Claude Code

Add the MCP server to your Claude Code configuration:

**For Claude Desktop:**
Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or equivalent:

```json
{
  "mcpServers": {
    "n8n": {
      "command": "npx",
      "args": ["-y", "@n8n/mcp-server"],
      "env": {
        "N8N_API_URL": "http://localhost:5678",
        "N8N_API_KEY": "your_n8n_api_key"
      }
    }
  }
}
```

**For Claude Code CLI:**
The MCP configuration is already set up in `.mcp/config.json`. Just ensure your `.env` file is configured correctly.

### 3. Test the Configuration

```bash
npm run mcp:test
```

This will verify that your MCP configuration file is valid.

## Using n8n MCP with Claude

Once configured, Claude can:

1. **List workflows**: See all your n8n workflows
2. **Execute workflows**: Trigger workflows with parameters
3. **Check workflow status**: Monitor execution status
4. **Get workflow details**: View workflow configuration

### Example Commands

You can ask Claude:
- "List all my n8n workflows"
- "Execute the 'trading-signal' workflow"
- "Show me the status of workflow execution XYZ"
- "What workflows are available in n8n?"

## Configuration Files

- **`.mcp/config.json`**: MCP server configuration
- **`.env`**: Environment variables (not tracked in git)
- **`.env.example`**: Template for environment variables
- **`package.json`**: Project metadata and scripts

## Troubleshooting

### MCP Server Not Connecting

1. Verify n8n is running: `curl http://localhost:5678/healthcheck`
2. Check API key is valid in n8n settings
3. Ensure `.env` file exists with correct values
4. Restart Claude Code/Desktop after configuration changes

### Authentication Errors

- Regenerate your n8n API key
- Update the `N8N_API_KEY` in your `.env` file
- Verify the API key has proper permissions

### n8n Instance Not Found

- Check `N8N_API_URL` matches your n8n instance
- For cloud instances, use the full URL: `https://your-instance.app.n8n.cloud`
- Ensure firewall/network allows connection

## Security Notes

- **Never commit** `.env` file to git (already in `.gitignore`)
- **Keep API keys secure** and rotate them regularly
- **Use environment variables** for sensitive data
- For production, consider using a secrets manager

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [n8n MCP Server](https://github.com/n8n-io/mcp-server)

## Integration with Trading Workflows

This MCP setup allows you to:
- Trigger trading strategies from Claude
- Monitor trading signals through n8n workflows
- Automate trading analysis and reporting
- Connect Claude to your trading infrastructure

## Next Steps

1. Create n8n workflows for your trading strategies
2. Use Claude to interact with and manage these workflows
3. Automate trading analysis and decision-making processes
4. Build custom integrations between Claude and your trading systems
