#!/bin/bash

# n8n Startup Script with MCP Support
# This script runs n8n directly using npx (no installation required)

echo "Starting n8n with MCP support..."
echo "==============================================="
echo ""
echo "n8n will start on: http://localhost:5678"
echo ""
echo "MCP Server Trigger node is available in:"
echo "  Triggers > MCP Server Trigger"
echo ""
echo "Press Ctrl+C to stop n8n"
echo "==============================================="
echo ""

# Run n8n with npx
# This will download and run n8n without installing it permanently
npx n8n
