# AIClient Development Log
## Last Session: 2026-11-18

### Project State: **READY FOR BUILD & TESTING**

---

## What's Done ✅

### Theme System (Complete)
- **3 Themes implemented** in `AIClientCore/Themes/AITheme.m`:
  1. **Skeuomorphic (iOS 6)** - Leather/metal textures, gradients, glossy buttons, rounded corners
  2. **Minimalist (iOS 13+)** - Flat design, SF fonts, system colors, subtle shadows
  3. **Claude Code (Terminal)** - Menlo monospace, green-on-black (#0D0D0D/#00D932), ASCII borders, sharp corners

### Legacy UI (All Updated - No Auto Layout)
| Component | File | Theme Support |
|-----------|------|---------------|
| App Delegate | `AITerminalAppDelegate.m` | Initializes AIThemeManager |
| Root VC | `AITerminalRootViewController.m` | Manual layout, conversations list |
| Chat VC | `AITerminalChatViewController.m` | Manual layout, streaming, keyboard handling |
| Settings VC | `AITerminalSettingsViewController.m` | **Proxy URL field**, Theme selector section |
| Provider Selector | `AITerminalProviderSelectorViewController.m` | Themed cells with [OK] badges |
| Image Gen VC | `AITerminalImageGenViewController.m` | Manual layout, pickers, stepper |
| Attachment Picker | `AITerminalAttachmentPickerViewController.m` | Themed, async PHPicker/UIImagePicker |
| Conversation Cell | `AITerminalConversationCell.m` | Manual layout, index + preview |
| Message Cell | `AITerminalMessageView.m` | Manual layout, height caching, ASCII bubbles |
| Input View | `AITerminalInputView.m` | Manual layout, height notifications, attachments bar |
| Status Bar | `AITerminalStatusBar.m` | 3-column manual layout |
| Loading Indicator | `AITerminalLoadingIndicator.m` | Animated dots, centered |

### Network Stack (Dual Stack)
- `AIHTTPClientFactory` - Auto-selects NSURLSession (iOS 7+) vs NSURLConnection (iOS 6)
- `AIHTTPClientLegacy` - Full NSURLConnection delegate pattern with streaming + multipart
- `AIStreamParser` - SSE parser works with both stacks

### Providers
- OpenAI (GPT-4o, DALL-E 3)
- Anthropic (Claude 3.5 Sonnet/Opus/Haiku)
- Google Gemini (1.5 Pro/Flash, Imagen 3)
- **NVIDIA NIM** (Nemotron, Llama, Mistral via OpenAI-compatible API)

### TLS Proxy (Go)
- `proxy/main.go` - Reverse proxy terminating TLS 1.2+, forwards via TLS 1.0
- `proxy/build.sh` - Cross-compile for Linux VPS
- `proxy/proxy.service` - systemd service

---

## Next Steps (Priority Order)

### 1. Build & Test on Device/Simulator
```bash
# In Theos environment
cd /path/to/AIClient
make package FINALPACKAGE=1
# Install .ipa to iOS 6 device or iOS 6.1 simulator
```

### 2. Deploy TLS Proxy to VPS
```bash
cd proxy
./build.sh
# Copy 'proxy' binary to VPS
# Install proxy.service via systemd
# Configure nginx/cloudflare in front if needed
```

### 3. Test Scenarios
- [ ] Theme switching (Skeuomorphic ↔ Minimalist ↔ Claude Code) via Settings
- [ ] Chat with each provider (OpenAI, Anthropic, Gemini, NVIDIA NIM)
- [ ] Streaming responses render correctly
- [ ] Image generation (DALL-E 3, Imagen 3)
- [ ] File attachments (photos, camera, files, clipboard)
- [ ] iOS 6.1 simulator: NSURLConnection path works
- [ ] Modern iOS: NSURLSession path works
- [ ] Proxy connection from iOS 6 device

### 4. Known Issues to Verify
- Height caching in `AITerminalChatViewController` (static `heightCache` - may need invalidation on theme change)
- `AITerminalImageGenViewController` picker views may need explicit theme styling
- Keyboard animations with manual layout (check `keyboardWillShow/Hide`)
- Memory usage on iOS 6 (256-512MB limit)

---

## Key Files to Review Tomorrow

```
AIClient/
├── Make                    # Build config
├── AIClientCore/Themes/AITheme.m       # All 3 theme implementations
├── AIClientUILegacy/
│   ├── AITerminalChatViewController.m  # Main chat logic
│   ├── AITerminalSettingsViewController.m  # Proxy + Theme settings
│   ├── Views/AITerminalMessageView.m   # Message bubbles + height cache
│   ├── Views/AITerminalInputView.m     # Input + attachments bar
│   └── Cells/AITerminalConversationCell.m
├── AIClientCore/Network/
│   ├── AIHTTPClientFactory.m           # Dual stack selector
│   └── AIHTTPClientLegacy.m            # iOS 6 NSURLConnection
└── proxy/main.go                       # Go TLS proxy
```

---

## Environment Notes
- **Target**: iOS 6.0+ (armv7, armv7s, arm64)
- **SDK**: iPhoneOS6.1.sdk (set `SDKROOT` in Makefile or env)
- **Theos**: Required for build
- **Dependencies**: SQLite3, Security, CoreText, QuartzCore, Photos, MobileCoreServices, UniformTypeIdentifiers

---

## Resume Prompt for Tomorrow
> "Continue AIClient iOS 6 development. Project has complete theme system (3 themes), dual network stack, 4 providers including NVIDIA NIM, and TLS proxy. Need to build/test on device, deploy proxy, and verify all flows work on iOS 6."

---
*Log created: 2026-11-18*