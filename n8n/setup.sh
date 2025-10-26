#!/bin/bash

# n8n MCP Setup Script
# This script helps you quickly set up n8n with MCP integration

set -e

echo "=========================================="
echo "n8n MCP Setup Script"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "✓ Created .env file"
    echo ""
    echo "WARNING: Please edit .env file and update the following:"
    echo "  - N8N_BASIC_AUTH_PASSWORD"
    echo "  - MCP_BEARER_TOKEN"
    echo "  - Trading API credentials (if using live trading)"
    echo ""
    read -p "Press Enter to continue after updating .env file..."
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p data workflows templates mcp-config
echo "✓ Directories created"
echo ""

# Pull Docker images
echo "Pulling Docker images..."
docker-compose pull
echo "✓ Images pulled"
echo ""

# Start services
echo "Starting n8n and PostgreSQL..."
docker-compose up -d
echo "✓ Services started"
echo ""

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check if n8n is running
if docker-compose ps | grep -q "n8n-trading.*Up"; then
    echo "✓ n8n is running"
else
    echo "ERROR: n8n failed to start. Check logs with: docker-compose logs n8n"
    exit 1
fi

# Check if PostgreSQL is running
if docker-compose ps | grep -q "n8n-postgres.*Up"; then
    echo "✓ PostgreSQL is running"
else
    echo "ERROR: PostgreSQL failed to start. Check logs with: docker-compose logs postgres"
    exit 1
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "n8n is now running at: http://localhost:5678"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: (check your .env file)"
echo ""
echo "Next steps:"
echo "1. Open http://localhost:5678 in your browser"
echo "2. Log in with the credentials above"
echo "3. Import workflows from the workflows/ directory"
echo "4. Configure your trading API credentials"
echo "5. Test the MCP integration"
echo ""
echo "Useful commands:"
echo "  View logs:        docker-compose logs -f n8n"
echo "  Stop services:    docker-compose down"
echo "  Restart services: docker-compose restart"
echo "  Update n8n:       docker-compose pull && docker-compose up -d"
echo ""
