    asyncio.run(main())) 
import mcp.types as types
from mcp.server import Server
from mcp.server.stdio import stdio_server

app = Server("n8n")

@app.list_tools()
async def list_tools():
    return [types.Tool(name="trigger_workflow", description="Trigger workflow")]

async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())


