# AIClient TLS Proxy

TLS termination proxy for iOS 6 AIClient. Accepts HTTP/1.1 (or old TLS) from iOS 6 devices and forwards to modern AI APIs (OpenAI, Anthropic, Gemini, NVIDIA NIM) with TLS 1.2+.

## Why?

- **iOS 6** only supports **TLS 1.0/1.1**
- **Modern AI APIs** require **TLS 1.2+** (OpenAI, Anthropic, Google, NVIDIA)
- This proxy bridges the gap: iOS 6 → HTTP → Proxy → HTTPS (TLS 1.3) → API

---

## Option 1: Cloudflare Worker (Recommended — Free, No Server Needed)

**Best for:** Most users. Runs on Cloudflare's edge network for free (100k requests/day).

### Deploy in 2 minutes:

1. Go to [Cloudflare Workers](https://dash.cloudflare.com/?to=/:account/workers-and-pages)
2. **Create Worker** → Paste `worker.js` content
3. **Settings → Variables** → Add:
   - `TARGET_HOST` = `api.openai.com` (or `api.anthropic.com`, `generativelanguage.googleapis.com`, `api.nvidia.com`)
   - `ALLOWED_ORIGINS` = `*`
   - `VERBOSE_LOGGING` = `false`
4. **Deploy** → Get `https://your-worker.your-subdomain.workers.dev`
5. **In AIClient Settings → Proxy URL:** Paste the Worker URL

### Multi-Provider Setup:

Deploy 4 workers (one per provider) and switch in Settings → Provider:

| Worker Name | TARGET_HOST | Use For |
|-------------|-------------|---------|
| `aiclient-openai` | `api.openai.com` | GPT-4o, DALL-E 3 |
| `aiclient-anthropic` | `api.anthropic.com` | Claude 3.5 |
| `aiclient-gemini` | `generativelanguage.googleapis.com` | Gemini 1.5, Imagen 3 |
| `aiclient-nvidia` | `api.nvidia.com` | Nemotron, Llama, Mistral |

### With Wrangler CLI:

```bash
cd proxy
npm install -g wrangler
wrangler login
# Edit wrangler.toml with your TARGET_HOST
wrangler deploy
```

---

## Option 2: Local Python Proxy (macOS/Linux/Windows)

**Best for:** Local development, testing, or when you want to run on your own machine.

### Requirements:
- Python 3.10+
- `pip install -r requirements.txt` (aiohttp)

### Run:

```bash
cd proxy
pip install -r requirements.txt

# Run proxy (terminal must stay open)
python main.py -listen 0.0.0.0:8080 -target api.openai.com -v
```

### In AIClient Settings → Proxy URL:
```
http://YOUR_COMPUTER_LAN_IP:8080
```

### Arguments:
| Flag | Default | Description |
|------|---------|-------------|
| `-listen` | `0.0.0.0:8080` | Bind address |
| `-target` | `api.openai.com` | Target API hostname |
| `-v` | false | Verbose logging |

---

## Option 3: Self-Hosted Go Proxy (Linux VPS)

**Best for:** Production self-hosting, high traffic, full control.

### Build:

```bash
cd proxy
./build.sh  # Cross-compiles to linux/amd64, darwin/amd64, windows/amd64
```

### Deploy to VPS:

```bash
# Copy binary
scp aiclient-proxy-linux-amd64 user@your-vps:/opt/aiclient-proxy/

# On VPS
sudo mkdir -p /opt/aiclient-proxy
sudo cp aiclient-proxy-linux-amd64 /opt/aiclient-proxy/aiclient-proxy
sudo chmod +x /opt/aiclient-proxy/aiclient-proxy

# Install systemd service
sudo cp proxy.service /etc/systemd/system/aiclient-proxy.service
sudo systemctl daemon-reload
sudo systemctl enable aiclient-proxy
sudo systemctl start aiclient-proxy
sudo systemctl status aiclient-proxy
```

### Configure Firewall:

```bash
sudo ufw allow 8080/tcp
```

### In AIClient Settings → Proxy URL:
```
http://your-vps-ip:8080
```

### Supported Targets:

| Target | Flag | Example |
|--------|------|---------|
| OpenAI | `-target api.openai.com` | `./aiclient-proxy -target api.openai.com` |
| Anthropic | `-target api.anthropic.com` | `./aiclient-proxy -target api.anthropic.com` |
| Google Gemini | `-target generativelanguage.googleapis.com` | `./aiclient-proxy -target generativelanguage.googleapis.com` |
| NVIDIA NIM | `-target api.nvidia.com` | `./aiclient-proxy -target api.nvidia.com` |

### Multiple Targets (Advanced):

Run multiple proxies on different ports:

```bash
# OpenAI on :8080
./aiclient-proxy -listen :8080 -target api.openai.com &

# Anthropic on :8081
./aiclient-proxy -listen :8081 -target api.anthropic.com &

# NVIDIA NIM on :8082
./aiclient-proxy -listen :8082 -target api.nvidia.com &
```

Then configure each provider in the app with its proxy URL.

---

## Option 4: HTTPS for iOS 6 (Optional)

If you want iOS 6 to use HTTPS (with old TLS) to the proxy:

### Generate self-signed cert:
```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=your-vps-ip"
```

### Run with TLS:

**Go proxy:**
```bash
./aiclient-proxy -listen :8443 -target api.openai.com -cert cert.pem -key key.pem
```

**Python proxy:**
```bash
python main.py -listen 0.0.0.0:8443 -target api.openai.com -cert cert.pem -key key.pem -v
```

Then in iOS app: `https://your-vps-ip:8443` (you'll need to trust the cert on device via Safari).

---

## Architecture

```
iOS 6 Device                          Proxy                              AI API
┌─────────────┐    HTTP/1.1           ┌─────────────┐    HTTPS/TLS 1.3  ┌─────────────┐
│  AIClient   │ ──────────────────►  │  (Python/   │ ──────────────►  │  OpenAI/    │
│  (NSURLConnection)                │   Go/Worker)│                  │  Anthropic/ │
│  TLS 1.0/1.1                      │  TLS term.  │                  │  Gemini/    │
└─────────────┘                     └─────────────┘                  │  NVIDIA NIM │
                                                                     └─────────────┘
```

---

## Performance Notes

- **Connection pooling**: Reuses upstream connections
- **Streaming**: Properly handles SSE (Server-Sent Events) for chat streaming
- **Timeouts**: 5 min read/write for long streaming responses
- **Memory**: Low footprint (~10-20MB)

---

## Troubleshooting

### Connection refused
- Check firewall: `ufw status`
- Check service: `systemctl status aiclient-proxy`
- Check port: `netstat -tlnp | grep 8080`

### Streaming not working
- Ensure `Content-Type: text/event-stream` is passed through
- Check proxy logs with `-v` flag

### iOS 6 SSL errors
- Use HTTP (not HTTPS) to proxy: `http://vps:8080`
- Or install CA cert on device via Safari

### Cloudflare Worker errors
- Check Workers logs in Cloudflare Dashboard
- Verify `TARGET_HOST` is correct
- Check CORS: `ALLOWED_ORIGINS` should include your origin or `*`

---

## File Overview

| File | Purpose |
|------|---------|
| `main.py` | Python async proxy (aiohttp) — local dev |
| `requirements.txt` | Python dependencies |
| `worker.js` | Cloudflare Worker — free cloud proxy |
| `wrangler.toml` | Worker configuration |
| `main.go` | Go proxy — VPS production |
| `build.sh` | Cross-compile Go proxy |
| `proxy.service` | systemd service for Go proxy |

---

## License

MIT