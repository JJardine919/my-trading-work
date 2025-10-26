@echo off
REM n8n MCP Setup Script for Windows
REM This script helps you quickly set up n8n with MCP integration on Windows

echo ==========================================
echo n8n MCP Setup Script (Windows)
echo ==========================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed. Please install Docker Desktop for Windows first.
    echo Download from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM Check if Docker Compose is installed
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Compose is not installed. Please install Docker Desktop for Windows.
    pause
    exit /b 1
)

REM Check if .env file exists
if not exist .env (
    echo Creating .env file from template...
    copy .env.example .env
    echo Done: Created .env file
    echo.
    echo WARNING: Please edit .env file and update the following:
    echo   - N8N_BASIC_AUTH_PASSWORD
    echo   - MCP_BEARER_TOKEN
    echo   - Trading API credentials (if using live trading^)
    echo.
    echo Opening .env file in Notepad...
    notepad .env
    echo.
    pause
)

REM Create necessary directories
echo Creating directories...
if not exist data mkdir data
if not exist workflows mkdir workflows
if not exist templates mkdir templates
if not exist mcp-config mkdir mcp-config
echo Done: Directories created
echo.

REM Pull Docker images
echo Pulling Docker images...
docker-compose pull
echo Done: Images pulled
echo.

REM Start services
echo Starting n8n and PostgreSQL...
docker-compose up -d
echo Done: Services started
echo.

REM Wait for services to be ready
echo Waiting for services to be ready...
timeout /t 10 /nobreak >nul

REM Check if n8n is running
docker-compose ps | find "n8n-trading" | find "Up" >nul
if errorlevel 1 (
    echo ERROR: n8n failed to start. Check logs with: docker-compose logs n8n
    pause
    exit /b 1
) else (
    echo Done: n8n is running
)

REM Check if PostgreSQL is running
docker-compose ps | find "n8n-postgres" | find "Up" >nul
if errorlevel 1 (
    echo ERROR: PostgreSQL failed to start. Check logs with: docker-compose logs postgres
    pause
    exit /b 1
) else (
    echo Done: PostgreSQL is running
)

echo.
echo ==========================================
echo Setup Complete!
echo ==========================================
echo.
echo n8n is now running at: http://localhost:5678
echo.
echo Default credentials:
echo   Username: admin
echo   Password: (check your .env file^)
echo.
echo Next steps:
echo 1. Open http://localhost:5678 in your browser
echo 2. Log in with the credentials above
echo 3. Import workflows from the workflows\ directory
echo 4. Configure your trading API credentials
echo 5. Test the MCP integration
echo.
echo Useful commands:
echo   View logs:        docker-compose logs -f n8n
echo   Stop services:    docker-compose down
echo   Restart services: docker-compose restart
echo   Update n8n:       docker-compose pull ^&^& docker-compose up -d
echo.
pause
