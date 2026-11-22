# AIClient — AI Client for iOS 6+

**Full-featured AI chat client for legacy iOS (6.0+) with modern provider support.**

<p align="center">
  <img src="https://img.shields.io/badge/iOS-6.0%2B-lightgrey?style=flat-square&logo=apple" alt="iOS 6+">
  <img src="https://img.shields.io/badge/arch-armv7%20%7C%20armv7s%20%7C%20arm64-blue?style=flat-square" alt="Architectures">
  <img src="https://img.shields.io/badge/Theos-required-orange?style=flat-square" alt="Theos">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License">
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **4 AI Providers** | OpenAI (GPT-4o, DALL-E 3), Anthropic (Claude 3.5), Google Gemini (1.5 Pro/Flash, Imagen 3), NVIDIA NIM (Nemotron, Llama, Mistral) |
| **3 Visual Themes** | Skeuomorphic (iOS 6 leather/metal), Minimalist (iOS 13+ flat), Claude Code (Terminal monospace) |
| **Streaming Chat** | Real-time token streaming with SSE parsing for all providers |
| **Image Generation** | DALL-E 3, Imagen 3 with size/quality selection |
| **File Attachments** | Photos, Camera, Files, Clipboard with preview |
| **TLS Proxy Support** | Local Python proxy or free Cloudflare Worker for iOS 6-12 |
| **Local Storage** | SQLite conversations + Keychain API keys |
| **Manual Layout** | Zero Auto Layout — runs on iOS 6.0+ |

---

## 📱 Screenshots

| Skeuomorphic (iOS 6) | Minimalist (iOS 13+) | Claude Code (Terminal) |
|:--------------------:|:--------------------:|:----------------------:|
| ![Skeuomorphic](Resources/Screenshots/skeuomorphic.png) | ![Minimalist](Resources/Screenshots/minimalist.png) | ![Claude Code](Resources/Screenshots/claude-code.png) |

---

## 🚀 Quick Start

### Prerequisites

- **macOS** with Xcode Command Line Tools
- **Theos** installed (`/opt/theos` or `~/theos`)
- **iOS 6.1 SDK** (for legacy device support) — [download](https://github.com/haikieu/xcode-sdks/releases/download/6.1/iPhoneOS6.1.sdk.tar.xz)
- **ldid** for signing (`brew install ldid`)

### Build

```bash
cd AIClient

# Set SDK (one time)
export SDKROOT=/opt/theos/sdks/iPhoneOS6.1.sdk

# Build .deb package
make package FINALPACKAGE=1

# Or build .ipa directly
make package-ipa

# Output: AIClient.ipa and packages/*.deb
```

### Install on Device

| Method | iOS Version | Notes |
|--------|-------------|-------|
| **Sideloadly** | 12.0+ | Windows/macOS/Linux, free Apple ID |
| **TrollStore** | 14.0-16.6.1 | Permanent install, no revokes |
| **Cydia/Sileo** | 6.0-12.4 | Jailbroken, install `.deb` |
| **Xcode** | Any | Developer account required |

---

## 🔐 TLS Proxy — Required for iOS 6-12

iOS 6-12 only support TLS 1.0/1.1. Modern AI APIs require TLS 1.2+.  
**Solution:** Use a TLS termination proxy.

### Option 1: Local Python Proxy (macOS/Linux/Windows)

```bash
cd proxy
pip install -r requirements.txt  # aiohttp

# Run proxy (terminal must stay open)
python main.py -listen 0.0.0.0:8080 -target api.openai.com -v
```

**In AIClient Settings → Proxy URL:** `http://YOUR_COMPUTER_IP:8080`

### Option 2: Free Cloudflare Worker (Recommended — No PC Needed)

1. Go to [Cloudflare Workers](https://dash.cloudflare.com/?to=/:account/workers-and-pages)
2. **Create Worker** → Paste `proxy/worker.js`
3. **Settings → Variables** → Add:
   - `TARGET_HOST` = `api.openai.com` (or `api.anthropic.com`, `generativelanguage.googleapis.com`, `api.nvidia.com`)
   - `ALLOWED_ORIGINS` = `*`
   - `VERBOSE_LOGGING` = `false`
4. **Deploy** → Get `https://aiclient-proxy.YOUR_SUBDOMAIN.workers.dev`
5. **In AIClient Settings → Proxy URL:** Paste the Worker URL

> **Tip:** Deploy 4 workers (one per provider) and switch in Settings → Provider.

### Option 3: Self-Hosted Go Proxy (Linux VPS)

```bash
cd proxy
./build.sh  # Cross-compiles to linux/amd64
scp aiclient-proxy-linux-amd64 user@vps:/opt/aiclient-proxy/
# Install proxy.service via systemd
```

---

## ⚙️ Configuration

### API Keys

1. Open **Settings** tab
2. **Provider** → Select OpenAI / Anthropic / Gemini / NVIDIA NIM
3. **API Key** → Enter your key (stored in iOS Keychain)
4. **Model** → Choose model (or "Fetch Models")
5. **Parameters** → Temperature, Max Tokens, System Prompt

### Themes

**Settings → Theme → Select Theme:**
- **Skeuomorphic (iOS 6)** — Leather background, metal nav bars, glossy buttons
- **Minimalist (iOS 13+)** — System colors, SF fonts, subtle shadows
- **Claude Code (Terminal)** — Menlo font, green-on-black, ASCII borders

### Image Generation

**Chat → [Generate] button:**
- Provider: OpenAI (DALL-E 3) or Google (Imagen 3)
- Size: 1024×1024, 1792×1024, 1024×1792
- Quality: Standard / HD
- Count: 1-4 images

---

## 🏗️ Project Structure

```
AIClient/
├── .github/workflows/build.yml    # CI/CD: builds .deb/.ipa on tag push
├── Makefile                       # Theos build config
├── build.sh                       # Build helper script
├── entitlements.plist             # Code signing entitlements
├── Resources/                     # Info.plist, storyboards
├── proxy/
│   ├── main.py                    # Local Python TLS proxy (aiohttp)
│   ├── requirements.txt           # Python deps
│   ├── worker.js                  # Cloudflare Worker proxy
│   ├── wrangler.toml              # Worker config
│   └── README.md                  # Proxy documentation
├── AIClientCore/                  # Shared business logic
│   ├── AIAPIManager.m             # Orchestrates providers, streaming
│   ├── AIConversationManager.m    # SQLite conversation storage
│   ├── AIMessage.m / AIAttachment.m
│   ├── Providers/                 # OpenAI, Anthropic, Gemini, NVIDIA
│   ├── Network/
│   │   ├── AIHTTPClient.m         # NSURLSession (iOS 7+)
│   │   ├── AIHTTPClientLegacy.m   # NSURLConnection (iOS 6)
│   │   ├── AIHTTPClientFactory.m  # Auto-selects at runtime
│   │   └── AIStreamParser.m       # SSE parser (all providers)
│   ├── Storage/                   # Keychain + SQLite
│   ├── Themes/AITheme.m           # 3 theme implementations
│   └── Utils/                     # JSON, FileManager
├── AIClientPlatform/              # Platform abstractions
│   ├── AIPlatform.m               # iOS version detection
│   ├── AIPasteboardMonitor.m      # Clipboard image detection
│   └── AINotificationManager.m    # Local notifications
├── AIClientUILegacy/              # iOS 6 Terminal UI (NO Auto Layout)
│   ├── AITerminalAppDelegate.m
│   ├── AITerminalRootViewController.m     # Conversations list
│   ├── AITerminalChatViewController.m     # Main chat
│   ├── AITerminalSettingsViewController.m # Proxy, Theme, Providers
│   ├── AITerminalProviderSelectorViewController.m
│   ├── AITerminalImageGenViewController.m
│   ├── AITerminalAttachmentPickerViewController.m
│   ├── Views/                     # InputView, StatusBar, MessageView, LoadingIndicator
│   └── Cells/                     # ConversationCell
└── AIClientLauncher/              # App entry point
    ├── main.m
    └── AIAppDelegate.m
```

---

## 🔧 CI/CD — GitHub Actions

Automatic builds on tag push:

```bash
git tag v1.0.0
git push origin v1.0.0
```

**Workflow (`.github/workflows/build.yml`):**
1. Installs Theos + iOS 6.1 SDK on macOS runner
2. Builds `armv7/armv7s/arm64` .deb package
3. Converts .deb → .ipa
4. Publishes both to GitHub Releases

---

## 🐛 Known Issues / TODO

| Issue | Status |
|-------|--------|
| Height caching in `AITerminalChatViewController` (static `heightCache` — needs invalidation on theme change) | ⚠️ Known |
| `AITerminalImageGenViewController` picker views may need explicit theme styling | ⚠️ Known |
| Keyboard animations with manual layout (check `keyboardWillShow/Hide`) | ⚠️ Known |
| Memory usage on iOS 6 (256-512MB limit) | ⚠️ Test needed |
| `ios6style` category files referenced in old Makefile — removed, using AITheme instead | ✅ Fixed |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- **Theos** — iOS build system
- **Onegram** — iOS 6 style categories (inspired `AITheme` Skeuomorphic)
- **Cloudflare Workers** — Free TLS 1.3 termination
- **OpenAI, Anthropic, Google, NVIDIA** — APIs

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/your-repo/AIClient/issues)
- **Discussions:** [GitHub Discussions](https://github.com/your-repo/AIClient/discussions)

---

**Built with ❤️ for the iOS 6 community. Keep legacy alive.**