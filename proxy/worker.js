/**
 * AIClient Cloudflare Worker TLS Proxy
 *
 * Deploy to Cloudflare Workers for free TLS 1.3 termination.
 * iOS 6 connects via HTTP -> Worker -> HTTPS (TLS 1.3) to AI APIs.
 *
 * Supports: OpenAI, Anthropic, Google Gemini, NVIDIA NIM
 *
 * Deployment:
 * 1. Go to https://dash.cloudflare.com -> Workers & Pages
 * 2. Create Worker -> Paste this code
 * 3. Set environment variables in Worker settings
 * 4. Deploy -> Get your *.workers.dev URL
 * 5. Configure in AIClient Settings -> Proxy URL
 */

// ============ CONFIGURATION ============
// Set these as Environment Variables in Cloudflare Dashboard:
// TARGET_HOST: "api.openai.com" (or api.anthropic.com, generativelanguage.googleapis.com, api.nvidia.com)
// ALLOWED_ORIGINS: "*" or "your-app-bundle-id"
// VERBOSE_LOGGING: "true" or "false"

const PROVIDERS = {
  openai: {
    host: 'api.openai.com',
    paths: ['/v1/chat/completions', '/v1/completions', '/v1/embeddings', '/v1/images/generations', '/v1/models'],
    streamPath: '/v1/chat/completions',
  },
  anthropic: {
    host: 'api.anthropic.com',
    paths: ['/v1/messages', '/v1/models'],
    streamPath: '/v1/messages',
  },
  gemini: {
    host: 'generativelanguage.googleapis.com',
    paths: ['/v1beta/models', '/v1/models'],
    streamPath: '/v1beta/models',
  },
  nvidia: {
    host: 'api.nvidia.com',
    paths: ['/v1/chat/completions', '/v1/models'],
    streamPath: '/v1/chat/completions',
  },
};

// ============ UTILITIES ============

function log(...args) {
  if (VERBOSE_LOGGING) console.log('[AIClient]', new Date().toISOString(), ...args);
}

function isStreamingRequest(path, provider) {
  const p = PROVIDERS[provider];
  if (!p) return false;
  return path.includes(p.streamPath);
}

function getProviderFromHost(host) {
  for (const [key, config] of Object.entries(PROVIDERS)) {
    if (host === config.host) return key;
  }
  return 'openai'; // default
}

function buildTargetUrl(request, targetHost) {
  const url = new URL(request.url);
  url.host = targetHost;
  url.protocol = 'https:';
  return url.toString();
}

function filterRequestHeaders(headers) {
  const filtered = new Headers();
  const skip = new Set([
    'host', 'connection', 'keep-alive', 'proxy-authenticate',
    'proxy-authorization', 'te', 'trailers', 'transfer-encoding',
    'upgrade', 'content-length', 'cf-connecting-ip', 'cf-ray',
    'cf-visitor', 'cf-ipcountry', 'x-forwarded-for', 'x-forwarded-proto',
  ]);

  for (const [key, value] of headers.entries()) {
    if (!skip.has(key.toLowerCase())) {
      filtered.set(key, value);
    }
  }
  return filtered;
}

function filterResponseHeaders(headers, isStreaming) {
  const filtered = new Headers();
  const skip = new Set([
    'connection', 'keep-alive', 'transfer-encoding',
    'content-encoding', 'content-length',  // We handle streaming
  ]);

  for (const [key, value] of headers.entries()) {
    if (!skip.has(key.toLowerCase())) {
      filtered.set(key, value);
    }
  }

  // For SSE streaming, ensure no compression
  if (isStreaming) {
    filtered.delete('content-encoding');
    filtered.delete('content-length');
  }

  return filtered;
}

// ============ SSE STREAM HANDLER ============

async function handleStreamingResponse(response, request) {
  const contentType = response.headers.get('content-type') || '';
  const isSSE = contentType.includes('text/event-stream');

  if (!isSSE) {
    // Not SSE, just pipe through
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: filterResponseHeaders(response.headers, false),
    });
  }

  // SSE streaming: transform to ensure proper flushing
  const readable = new ReadableStream({
    async start(controller) {
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n');
          buffer = lines.pop() || '';

          for (const line of lines) {
            if (line.trim()) {
              controller.enqueue(new TextEncoder().encode(line + '\n'));
            }
          }
        }

        // Flush remaining buffer
        if (buffer.trim()) {
          controller.enqueue(new TextEncoder().encode(buffer + '\n'));
        }
      } catch (e) {
        controller.error(e);
      } finally {
        controller.close();
      }
    },
  });

  return new Response(readable, {
    status: response.status,
    statusText: response.statusText,
    headers: filterResponseHeaders(response.headers, true),
  });
}

// ============ MAIN FETCH HANDLER ============

export default {
  async fetch(request, env, ctx) {
    const startTime = Date.now();
    const VERBOSE_LOGGING = env.VERBOSE_LOGGING === 'true';
    const ALLOWED_ORIGINS = (env.ALLOWED_ORIGINS || '*').split(',').map(s => s.trim());

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCORS(request, ALLOWED_ORIGINS);
    }

    // Health check
    const url = new URL(request.url);
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', timestamp: Date.now() }), {
        headers: { 'content-type': 'application/json', ...corsHeaders(ALLOWED_ORIGINS, request) },
      });
    }

    // OpenAI-compatible /v1/models endpoint for NIM discovery
    if (url.pathname === '/v1/models' && request.method === 'GET') {
      return handleModelsEndpoint(ALLOWED_ORIGINS, request);
    }

    // Determine target host
    const targetHost = env.TARGET_HOST || 'api.openai.com';
    const provider = getProviderFromHost(targetHost);

    log(`→ ${request.method} ${url.pathname} -> ${targetHost}`);

    try {
      // Build target request
      const targetUrl = buildTargetUrl(request, targetHost);
      const requestHeaders = filterRequestHeaders(request.headers);
      requestHeaders.set('Host', targetHost);

      // Forward request body
      const body = request.method === 'GET' || request.method === 'HEAD' ? null : await request.arrayBuffer();

      // Fetch from upstream
      const upstreamResponse = await fetch(targetUrl, {
        method: request.method,
        headers: requestHeaders,
        body,
        redirect: 'manual',
        cf: {
          // Cloudflare specific options
          cacheTtl: 0,
          cacheEverything: false,
        },
      });

      log(`← ${upstreamResponse.status} ${url.pathname} (${Date.now() - startTime}ms)`);

      // Handle streaming
      const isStreaming = isStreamingRequest(url.pathname, provider);
      const response = await handleStreamingResponse(upstreamResponse, request);

      // Add CORS headers
      const cors = corsHeaders(ALLOWED_ORIGINS, request);
      for (const [key, value] of cors.entries()) {
        response.headers.set(key, value);
      }

      return response;

    } catch (error) {
      log('Error:', error.message);
      return new Response(JSON.stringify({
        error: 'proxy_error',
        message: error.message,
      }), {
        status: 502,
        headers: { 'content-type': 'application/json', ...corsHeaders(ALLOWED_ORIGINS, request) },
      });
    }
  },
};

// ============ CORS HELPERS ============

function corsHeaders(allowedOrigins, request) {
  const origin = request.headers.get('Origin') || '';
  const allowOrigin = allowedOrigins.includes('*') || allowedOrigins.includes(origin)
    ? origin || '*'
    : allowedOrigins[0];

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, Anthropic-Version, OpenAI-Beta',
    'Access-Control-Max-Age': '86400',
    'Access-Control-Allow-Credentials': 'false',
  };
}

function handleCORS(request, allowedOrigins) {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(allowedOrigins, request),
  });
}

// ============ MODELS ENDPOINT ============

function handleModelsEndpoint(allowedOrigins, request) {
  // OpenAI-compatible models list for NVIDIA NIM and other providers
  const models = {
    object: 'list',
    data: [
      { id: 'gpt-4o', object: 'model', owned_by: 'openai' },
      { id: 'gpt-4o-mini', object: 'model', owned_by: 'openai' },
      { id: 'gpt-4-turbo', object: 'model', owned_by: 'openai' },
      { id: 'claude-3-5-sonnet-20241022', object: 'model', owned_by: 'anthropic' },
      { id: 'claude-3-5-haiku-20241022', object: 'model', owned_by: 'anthropic' },
      { id: 'claude-3-opus-20240229', object: 'model', owned_by: 'anthropic' },
      { id: 'gemini-1.5-pro', object: 'model', owned_by: 'google' },
      { id: 'gemini-1.5-flash', object: 'model', owned_by: 'google' },
      { id: 'meta/llama-3.1-405b-instruct', object: 'model', owned_by: 'nvidia' },
      { id: 'meta/llama-3.1-70b-instruct', object: 'model', owned_by: 'nvidia' },
      { id: 'meta/llama-3.1-8b-instruct', object: 'model', owned_by: 'nvidia' },
      { id: 'nvidia/nemotron-3-ultra', object: 'model', owned_by: 'nvidia' },
      { id: 'mistralai/mixtral-8x22b-instruct', object: 'model', owned_by: 'nvidia' },
      { id: 'google/gemma-2-27b-it', object: 'model', owned_by: 'nvidia' },
    ],
  };

  return new Response(JSON.stringify(models), {
    headers: { 'content-type': 'application/json', ...corsHeaders(allowedOrigins, request) },
  });
}

// ============ Wrangler config (for reference) ============
/*
# wrangler.toml
name = "aiclient-proxy"
main = "worker.js"
compatibility_date = "2024-01-01"
compatibility_flags = ["nodejs_compat"]

[vars]
TARGET_HOST = "api.openai.com"
ALLOWED_ORIGINS = "*"
VERBOSE_LOGGING = "false"

# For multiple providers, deploy separate workers:
# - aiclient-openai (api.openai.com)
# - aiclient-anthropic (api.anthropic.com)
# - aiclient-gemini (generativelanguage.googleapis.com)
# - aiclient-nvidia (api.nvidia.com)
*/