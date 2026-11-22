# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "mcp==2.1.1",
#     "httpx==0.28.1",
#     "jsonschema==4.26.0",
# ]
# ///

import os
import asyncio
import argparse
from mcp.server.lowlevel import Server
from mcp.server.context import ServerRequestContext
import mcp.types as mt
import httpx
import jsonschema
from mcp.server.session import ServerSession

GDAI_MCP_SERVER_PORT = int(os.getenv("GDAI_MCP_SERVER_PORT", "3571"))
GDAI_SERVER_VERSION = "0.3.3"
GDAI_HTTP_SERVER_BASE_URL = f"http://localhost:{GDAI_MCP_SERVER_PORT}"
tool_definitions: dict[str, mt.Tool] = {}


async def http_get(url: str, body = None):
    async with httpx.AsyncClient() as client:
        response = await client.request(method="GET", url=url, json=body)
        response.raise_for_status()
        return response.json()


async def http_post(url: str, body, timeout=5):
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=body, timeout=timeout)
        response.raise_for_status()
        return response.json()


async def handle_initialized(ctx: ServerRequestContext, params: mt.NotificationParams):
    client_params = ctx.session.client_params
    if client_params is None:
        return
    await http_post(GDAI_HTTP_SERVER_BASE_URL + "/client_initialized", {
        "protocol_version": ctx.protocol_version,
        "client_name": client_params.client_info.name,
        "client_version": client_params.client_info.version,
    })


async def list_tools(ctx: ServerRequestContext, params: mt.PaginatedRequestParams | None) -> mt.ListToolsResult:
    json = await http_get(GDAI_HTTP_SERVER_BASE_URL + "/tools")
    if not "mcp_tools" in json:
        raise Exception("Error listing tools. Could not find 'mcp_tools' in response.")
    tools = [mt.Tool(**tool) for tool in json["mcp_tools"]]
    tool_definitions.clear()
    tool_definitions.update((tool.name, tool) for tool in tools)
    return mt.ListToolsResult(tools=tools)


async def send_tool_progress_notification(
    session: ServerSession, progress_token: str | int, request_id: str | int
):
    i = 0
    while True:
        await session.send_progress_notification(
            progress_token=progress_token,
            progress=float(i+1),
            message="processing...",
            related_request_id=request_id
        )
        i += 1
        await asyncio.sleep(2)


async def call_tool(ctx: ServerRequestContext, params: mt.CallToolRequestParams) -> mt.CallToolResult:
    name = params.name
    progress_token = ctx.meta.get("progress_token") if ctx.meta else None
    notif_task = None
    if progress_token is not None:
        notif_task = asyncio.create_task(send_tool_progress_notification(
            session=ctx.session,
            progress_token=progress_token,
            request_id=ctx.request_id,
        ))

    timeout = 5
    if name == "get_running_scene_screenshot":
        timeout = 30
    if name == "simulate_input":
        timeout = 65

    try:
        if name not in tool_definitions:
            await list_tools(ctx, None)
        tool = tool_definitions.get(name)
        if tool is not None:
            try:
                jsonschema.validate(params.arguments or {}, tool.input_schema)
            except jsonschema.ValidationError as e:
                raise ValueError(f"Input validation error: {e.message}")
        try:
            json = await http_post(GDAI_HTTP_SERVER_BASE_URL + "/call-tool", {
                "tool_name": name,
                "tool_args": params.arguments or {}
            }, timeout=timeout)
        except httpx.TimeoutException:
            raise Exception(f"Timeout calling tool {name}. Took longer than {timeout} seconds.")

        if json["is_error"]:
            raise Exception(f"Error calling tool {name}: {json['tool_call_result']}")

        if json.get("type") == "image":
            return mt.CallToolResult(content=[mt.ImageContent(
                type="image", mime_type=json.get("mime_type", "image/jpg"), data=json["tool_call_result"]
            )])
        return mt.CallToolResult(content=[mt.TextContent(type="text", text=json["tool_call_result"])])
    except Exception as e:
        return mt.CallToolResult(is_error=True, content=[mt.TextContent(type="text", text=str(e))])
    finally:
        if notif_task is not None:
            notif_task.cancel()
            await asyncio.gather(notif_task, return_exceptions=True)

async def list_prompts(ctx: ServerRequestContext, params: mt.PaginatedRequestParams | None) -> mt.ListPromptsResult:
    json = await http_get(GDAI_HTTP_SERVER_BASE_URL + "/prompts")
    if not "mcp_prompts" in json:
        raise Exception("Error listing prompts. Could not find 'mcp_prompts' in response.")
    return mt.ListPromptsResult(prompts=[mt.Prompt(**prompt) for prompt in json["mcp_prompts"]])


async def get_prompt(ctx: ServerRequestContext, params: mt.GetPromptRequestParams) -> mt.GetPromptResult:
    name = params.name
    if name != "gdai-mcp-default-prompt":
        raise ValueError(f"Unknown prompt: {name}")

    json = await http_get(GDAI_HTTP_SERVER_BASE_URL + f"/prompt", {
        "prompt_name": name,
        "prompt_args": params.arguments
    })

    if "is_error" in json and json["is_error"]:
        raise ValueError(json["result"])

    messages = json["messages"]

    return mt.GetPromptResult(
        messages=[
            mt.PromptMessage(
                role=message["role"],
                content=mt.TextContent(type="text", text=message["content"]["text"])
            ) for message in messages
        ]
    )


server = Server(
    "gdai-mcp-godot",
    version=GDAI_SERVER_VERSION,
    instructions="This server is used to interact with the Godot game engine.",
    on_list_tools=list_tools,
    on_call_tool=call_tool,
    on_list_prompts=list_prompts,
    on_get_prompt=get_prompt,
)
server.add_notification_handler("notifications/initialized", mt.NotificationParams, handle_initialized)


async def run():
    from mcp.server.stdio import stdio_server

    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream, write_stream, server.create_initialization_options()
        )


def create_http_app(host: str, port: int, allowed_hosts: list[str]):
    from mcp.server.streamable_http_manager import StreamableHTTPSessionManager
    from mcp.server.transport_security import TransportSecurityMiddleware, TransportSecuritySettings
    from starlette.applications import Starlette
    from starlette.routing import Route

    hosts = {"localhost", "127.0.0.1", "[::1]", host, *allowed_hosts}
    hosts = {f"[{name}]" if ":" in name and not name.startswith("[") else name for name in hosts}
    authorities = {f"{name}:{port}" for name in hosts}
    if port == 80:
        authorities.update(hosts)
    security_settings = TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=sorted(authorities),
        allowed_origins=sorted(f"http://{authority}" for authority in authorities),
    )
    manager = StreamableHTTPSessionManager(app=server, security_settings=security_settings)
    security = TransportSecurityMiddleware(security_settings)

    class MCPHTTPApp:
        async def __call__(self, scope, receive, send):
            from starlette.requests import Request

            # Reject untrusted requests before the SDK allocates a session.
            error = await security.validate_request(
                Request(scope, receive), is_post=scope["method"] == "POST"
            )
            if error is not None:
                await error(scope, receive, send)
                return
            await manager.handle_request(scope, receive, send)

    return Starlette(
        routes=[Route("/mcp", endpoint=MCPHTTPApp())],
        lifespan=lambda app: manager.run(),
    )


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Connect MCP clients to the Godot editor.")
    parser.add_argument("--transport", choices=("stdio", "http"), default="stdio")
    parser.add_argument("--host", help="HTTP bind address (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, help="MCP HTTP port (default: 9090)")
    parser.add_argument(
        "--allowed-host", action="append", default=[], metavar="HOSTNAME",
        help="Additional HTTP hostname or IP clients use, without a port; repeat as needed",
    )
    args = parser.parse_args(argv)
    if args.transport == "stdio" and (args.host is not None or args.port is not None or args.allowed_host):
        parser.error("--host, --port, and --allowed-host require --transport http")
    if args.port is not None and not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    args.host = args.host if args.host is not None else "127.0.0.1"
    args.port = args.port if args.port is not None else 9090
    return args


def main():
    args = parse_args()
    if args.transport == "http":
        import uvicorn

        uvicorn.run(
            create_http_app(args.host, args.port, args.allowed_host),
            host=args.host, port=args.port,
        )
    else:
        asyncio.run(run())


if __name__ == "__main__":
    main()
