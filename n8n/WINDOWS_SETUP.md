# n8n MCP Setup for Windows

Quick setup guide for Windows users.

## Prerequisites

1. **Install Docker Desktop for Windows**
   - Download: https://www.docker.com/products/docker-desktop
   - Make sure WSL 2 is enabled
   - Restart your computer after installation

2. **Install Git for Windows** (if not already installed)
   - Download: https://git-scm.com/download/win

## Setup Steps

### Method 1: Using the Batch Script (Recommended)

1. **Clone the repository** (if you haven't already):
   ```cmd
   cd C:\Users\jimjj\Documents
   git clone https://github.com/JJardine919/my-trading-work.git
   cd my-trading-work\n8n
   ```

2. **Run the setup script**:
   ```cmd
   setup.bat
   ```

3. **Edit the .env file** when prompted:
   - Change `N8N_BASIC_AUTH_PASSWORD` to a secure password
   - Generate a secure token for `MCP_BEARER_TOKEN`
   - Add your trading API credentials if needed

4. **Access n8n**:
   - Open browser: http://localhost:5678
   - Login with username `admin` and your password

### Method 2: Manual Setup

1. **Navigate to n8n directory**:
   ```cmd
   cd my-trading-work\n8n
   ```

2. **Create .env file**:
   ```cmd
   copy .env.example .env
   notepad .env
   ```

3. **Start Docker containers**:
   ```cmd
   docker-compose up -d
   ```

4. **Check status**:
   ```cmd
   docker-compose ps
   ```

## Common Windows Commands

### Instead of Linux Commands:

| Linux Command | Windows Command |
|--------------|-----------------|
| `./setup.sh` | `setup.bat` |
| `cp file1 file2` | `copy file1 file2` |
| `nano file` | `notepad file` |
| `ls` | `dir` |
| `pwd` | `cd` |
| `cat file` | `type file` |

### Using PowerShell (Recommended):

PowerShell is more powerful than CMD. Open PowerShell and use:

```powershell
# Navigate to directory
cd C:\Users\jimjj\Documents\my-trading-work\n8n

# Copy files
Copy-Item .env.example .env

# Edit file
notepad .env

# Start Docker
docker-compose up -d

# View logs
docker-compose logs -f n8n
```

## Testing Webhooks from Windows

### Using PowerShell (Recommended):

```powershell
$body = @{
    name = "Test User"
    email = "test@example.com"
    phone = "555-1234"
    message = "This is a test lead"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://sustai.app.n8n.cloud/webhook/lead-capture" `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $body
```

### Using curl in CMD:

```cmd
curl -X POST https://sustai.app.n8n.cloud/webhook/lead-capture -H "Content-Type: application/json" -d "{\"name\": \"Test User\", \"email\": \"test@example.com\", \"phone\": \"555-1234\", \"message\": \"This is a test lead\"}"
```

### Using curl in PowerShell:

```powershell
curl -X POST "https://sustai.app.n8n.cloud/webhook/lead-capture" `
    -H "Content-Type: application/json" `
    -d '{"name": "Test User", "email": "test@example.com", "phone": "555-1234", "message": "This is a test lead"}'
```

## Useful Docker Commands for Windows

```cmd
REM View all containers
docker-compose ps

REM View logs
docker-compose logs -f n8n

REM Stop services
docker-compose down

REM Restart services
docker-compose restart

REM Update n8n
docker-compose pull
docker-compose up -d

REM Remove everything and start fresh
docker-compose down -v
docker-compose up -d
```

## Troubleshooting

### Docker Desktop Not Running
- Start Docker Desktop from Windows Start Menu
- Wait for it to fully start (whale icon in system tray)
- Try the commands again

### Port 5678 Already in Use
Edit `docker-compose.yml` and change:
```yaml
ports:
  - "5679:5678"  # Changed from 5678:5678
```

Then access n8n at http://localhost:5679

### WSL 2 Issues
If Docker says WSL 2 is not installed:
1. Open PowerShell as Administrator
2. Run: `wsl --install`
3. Restart computer
4. Start Docker Desktop again

### Permission Errors
- Run Command Prompt or PowerShell as Administrator
- Right-click → "Run as administrator"

### Cannot Find Docker Command
- Docker Desktop must be running
- Restart your terminal after installing Docker
- Check Docker Desktop settings

## File Paths in Windows

When working with the repository:

```
C:\Users\jimjj\Documents\my-trading-work\
├── n8n\
│   ├── setup.bat                  ← Run this
│   ├── .env.example               ← Copy to .env
│   ├── docker-compose.yml         ← Docker config
│   ├── workflows\                 ← Import these
│   └── mcp-config\                ← MCP settings
```

## Next Steps

1. ✅ Run `setup.bat`
2. ✅ Edit `.env` file
3. ✅ Open http://localhost:5678
4. ✅ Import workflows from `workflows\` folder
5. ✅ Configure your trading API
6. ✅ Test MCP integration

## Need Help?

- Check Docker Desktop is running
- View logs: `docker-compose logs -f n8n`
- Read main README.md for detailed documentation
- Check MCP_INTEGRATION_GUIDE.md for integration examples

## Using Git Bash (Alternative)

If you have Git Bash installed, you can use Linux commands:

```bash
cd /c/Users/jimjj/Documents/my-trading-work/n8n
./setup.sh  # Linux script will work in Git Bash
```

Git Bash provides a Unix-like environment on Windows.
