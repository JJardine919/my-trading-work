# My Trading Work

A trading workspace with n8n MCP (Model Context Protocol) integration for AI-assisted workflow automation.

## Features

- MQL5 Expert Advisors and trading bots
- Neural network integration for trading strategies
- n8n MCP server for AI-assisted workflow automation
- Trading analysis and documentation

## Quick Start

### 1. Set Up n8n MCP

Follow the [MCP Setup Guide](docs/MCP_SETUP.md) to configure n8n integration with Claude Code.

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your n8n credentials
# Then test the configuration
npm run mcp:test
```

### 2. Directory Structure

```
.
├── .mcp/                  # MCP configuration
├── analysis/              # Trading analysis
├── data/                  # Trading data
├── docs/                  # Documentation
│   └── MCP_SETUP.md      # n8n MCP setup guide
├── scripts/               # Utility scripts
├── strategies/            # Trading strategies
├── *.mq5                  # MQL5 Expert Advisors
├── *.mqh                  # MQL5 include files
├── .env.example          # Environment template
└── package.json          # Node.js configuration
```

## MCP Integration

This workspace includes n8n MCP server integration, allowing Claude Code to:
- Execute n8n workflows
- Monitor trading automation
- Manage workflow configurations
- Integrate AI with trading strategies

See [docs/MCP_SETUP.md](docs/MCP_SETUP.md) for complete setup instructions.

## Trading Bots

The repository includes various MQL5 Expert Advisors:
- Adaptive Bitcoin Master Bot
- Neural Networks Propagation EA
- Nexa AI Trading Bots
- StrikeBot AI
- And more...

## Documentation

- [MCP Setup Guide](docs/MCP_SETUP.md) - Configure n8n MCP integration
- [Trading Analysis](analysis/) - Analysis and research
- [Strategies](strategies/) - Trading strategy documentation

## Requirements

- **MetaTrader 5** (for MQL5 bots)
- **Node.js** 16+ (for MCP)
- **n8n** instance (for workflow automation)

## License

ISC
