#!/usr/bin/env python3
"""
AIClient TLS Proxy (Python 3)
Reverse proxy that terminates TLS 1.2+ and forwards via TLS 1.0 for iOS 6.
Supports SSE streaming for all providers.
"""

import argparse
import asyncio
import json
import logging
import signal
import ssl
import sys
from typing import Optional
from urllib.parse import urljoin

import aiohttp
from aiohttp import web, ClientSession, ClientTimeout
from aiohttp.web_request import Request
from aiohttp.web_response import StreamResponse


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger(__name__)


class Config:
    def __init__(self):
        self.listen_addr: str = "0.0.0.0:8080"
        self.target_host: str = "api.openai.com"
        self.target_scheme: str = "https"
        self.cert_file: Optional[str] = None
        self.key_file: Optional[str] = None
        self.verbose: bool = False


class StreamingProxy:
    def __init__(self, config: Config):
        self.config = config
        self.target_base = f"{config.target_scheme}://{config.target_host}"
        self.session: Optional[ClientSession] = None

    async def start(self):
        timeout = ClientTimeout(total=0, sock_connect=30, sock_read=300)
        ssl_context = ssl.create_default_context()
        ssl_context.minimum_version = ssl.TLSVersion.TLSv1_2
        connector = aiohttp.TCPConnector(
            limit=100,
            keepalive_timeout=90,
            force_close=False,
            ssl=ssl_context,
        )
        self.session = ClientSession(
            timeout=timeout,
            connector=connector,
            headers={"User-Agent": "AIClient/1.0 Proxy"}
        )
        log.info(f"Starting AIClient TLS Proxy")
        log.info(f"  Listen: {self.config.listen_addr} (HTTP{'S' if self.config.cert_file else ''})")
        log.info(f"  Target: {self.target_base}")
        log.info(f"  iOS 6 TLS: 1.0/1.1 -> Proxy -> TLS 1.2+ to {self.config.target_host}")

    async def stop(self):
        if self.session:
            await self.session.close()

    def _should_forward_header(self, name: str) -> bool:
        hop_by_hop = {
            'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
            'te', 'trailers', 'transfer-encoding', 'upgrade',
            'content-length', 'content-encoding',  # We handle these
        }
        return name.lower() not in hop_by_hop

    async def handle_request(self, request: Request) -> StreamResponse:
        # Build target URL
        target_url = urljoin(self.target_base, request.path_qs)

        # Prepare headers
        headers = {}
        for name, value in request.headers.items():
            if self._should_forward_header(name):
                headers[name] = value
        headers['Host'] = self.config.target_host

        # Get request body
        body = await request.read()

        if self.config.verbose:
            log.info(f"→ {request.method} {request.path_qs}")

        try:
            async with self.session.request(
                request.method,
                target_url,
                headers=headers,
                data=body,
                allow_redirects=False,
                timeout=ClientTimeout(total=0, sock_read=300)
            ) as resp:
                if self.config.verbose:
                    log.info(f"← {resp.status} {request.path_qs}")

                # Check if streaming response (SSE)
                content_type = resp.headers.get('Content-Type', '')
                is_sse = 'text/event-stream' in content_type

                # Prepare response
                response = StreamResponse(
                    status=resp.status,
                    headers={
                        k: v for k, v in resp.headers.items()
                        if k.lower() not in ('content-encoding', 'content-length', 'transfer-encoding')
                    }
                )
                await response.prepare(request)

                if is_sse:
                    # Stream SSE line by line, flush after each line
                    async for line in resp.content.iter_any():
                        if line:
                            await response.write(line)
                            await response.drain()
                else:
                    # Regular response
                    async for chunk in resp.content.iter_chunked(8192):
                        await response.write(chunk)

                await response.write_eof()
                return response

        except asyncio.TimeoutError:
            log.error(f"Upstream timeout: {target_url}")
            return web.Response(status=504, text="Gateway Timeout")
        except aiohttp.ClientError as e:
            log.error(f"Upstream error: {e}")
            return web.Response(status=502, text="Bad Gateway")
        except Exception as e:
            log.exception(f"Unexpected error: {e}")
            return web.Response(status=500, text="Internal Server Error")


async def handle_models(request: Request) -> web.Response:
    """OpenAI-compatible models endpoint for NIM discovery"""
    models = {
        "object": "list",
        "data": [
            {"id": "meta/llama-3.1-405b-instruct", "object": "model", "owned_by": "nvidia"},
            {"id": "meta/llama-3.1-70b-instruct", "object": "model", "owned_by": "nvidia"},
            {"id": "meta/llama-3.1-8b-instruct", "object": "model", "owned_by": "nvidia"},
            {"id": "nvidia/nemotron-3-ultra", "object": "model", "owned_by": "nvidia"},
            {"id": "mistralai/mixtral-8x22b-instruct", "object": "model", "owned_by": "nvidia"},
            {"id": "google/gemma-2-27b-it", "object": "model", "owned_by": "nvidia"},
            {"id": "microsoft/phi-3-medium-128k-instruct", "object": "model", "owned_by": "nvidia"},
        ]
    }
    return web.json_response(models)


def parse_args() -> Config:
    parser = argparse.ArgumentParser(description="AIClient TLS Proxy for iOS 6")
    parser.add_argument("-listen", default="0.0.0.0:8080", help="HTTP listen address")
    parser.add_argument("-target", default="api.openai.com", help="Target API hostname")
    parser.add_argument("-scheme", default="https", help="Target scheme (https)")
    parser.add_argument("-cert", default="", help="TLS cert file (optional)")
    parser.add_argument("-key", default="", help="TLS key file (optional)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose logging")

    args = parser.parse_args()

    config = Config()
    config.listen_addr = args.listen
    config.target_host = args.target
    config.target_scheme = args.scheme
    config.cert_file = args.cert if args.cert else None
    config.key_file = args.key if args.key else None
    config.verbose = args.verbose

    if config.verbose:
        log.setLevel(logging.DEBUG)

    return config


async def main():
    config = parse_args()
    proxy = StreamingProxy(config)

    await proxy.start()

    app = web.Application()
    app.router.add_get("/v1/models", handle_models)
    app.router.add_route("*", "/{tail:.*}", proxy.handle_request)

    host, port_str = config.listen_addr.split(":")
    port = int(port_str)

    runner = web.AppRunner(app)
    await runner.setup()

    ssl_context = None
    if config.cert_file and config.key_file:
        import ssl
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(config.cert_file, config.key_file)
        log.info("Serving HTTPS (for iOS 6 with old TLS)...")
    else:
        log.info("Serving HTTP (iOS 6 connects here)...")

    site = web.TCPSite(runner, host, port, ssl_context=ssl_context)
    await site.start()

    # Graceful shutdown
    stop_event = asyncio.Event()

    def signal_handler():
        log.info("Shutting down...")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, signal_handler)
        except NotImplementedError:
            pass  # Windows

    await stop_event.wait()

    await runner.cleanup()
    await proxy.stop()
    log.info("Server stopped gracefully")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass