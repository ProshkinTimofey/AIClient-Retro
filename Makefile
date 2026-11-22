# AIClient — AI Client for iOS (Theos)
# iOS 6+ legacy support with terminal/Claude Code style UI
# Supports: OpenAI, Anthropic, Google Gemini, NVIDIA NIM
# Features: Chat, Image Generation (DALL-E 3, Imagen 3), File Attachments
# Themes: Skeuomorphic (iOS 6), Minimalist (iOS 13+), Claude Code (Terminal)

export ARCHS = armv7 armv7s arm64
export TARGET = iphone:clang:16.5:6.0
export DEBUG = 0
export FINALPACKAGE = 1

# SDK path for iOS 6 (if using legacy SDK)
# export SDKROOT = $(THEOS)/sdks/iPhoneOS6.1.sdk

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AIClient

# Core files (providers, API, storage work on iOS 6+)
AIClient_FILES = \
    AIClientLauncher/main.m \
    AIClientLauncher/AIAppDelegate.m \
    \
    AIClientCore/AIAPIManager.m \
    AIClientCore/AIConversationManager.m \
    AIClientCore/AIMessage.m \
    AIClientCore/AIAttachment.m \
    AIClientCore/Providers/AIOpenAIProvider.m \
    AIClientCore/Providers/AIAnthropicProvider.m \
    AIClientCore/Providers/AIGeminiProvider.m \
    AIClientCore/Providers/AINVIDIAProvider.m \
    AIClientCore/Providers/AIProviderProtocol.m \
    AIClientCore/Network/AIHTTPClient.m \
    AIClientCore/Network/AIHTTPClientLegacy.m \
    AIClientCore/Network/AIHTTPClientFactory.m \
    AIClientCore/Network/AIStreamParser.m \
    AIClientCore/Storage/AIKeychainManager.m \
    AIClientCore/Storage/AISQLiteManager.m \
    AIClientCore/Utils/AIJSONParser.m \
    AIClientCore/Utils/AIFileManager.m \
    AIClientCore/Themes/AITheme.m \
    \
    AIClientPlatform/AIPlatform.m \
    AIClientPlatform/AIPasteboardMonitor.m \
    AIClientPlatform/AINotificationManager.m \
    \
    # iOS 6 Terminal UI (Legacy - no Auto Layout)
    AIClientUILegacy/AITerminalAppDelegate.m \
    AIClientUILegacy/AITerminalRootViewController.m \
    AIClientUILegacy/AITerminalChatViewController.m \
    AIClientUILegacy/AITerminalSettingsViewController.m \
    AIClientUILegacy/AITerminalProviderSelectorViewController.m \
    AIClientUILegacy/AITerminalImageGenViewController.m \
    AIClientUILegacy/AITerminalAttachmentPickerViewController.m \
    AIClientUILegacy/Views/AITerminalInputView.m \
    AIClientUILegacy/Views/AITerminalStatusBar.m \
    AIClientUILegacy/Views/AITerminalMessageView.m \
    AIClientUILegacy/Cells/AITerminalConversationCell.m \
    AIClientUILegacy/Views/AITerminalLoadingIndicator.m

AIClient_FRAMEWORKS = UIKit Foundation CoreGraphics Photos MobileCoreServices UniformTypeIdentifiers Security SQLite3 CoreText QuartzCore
AIClient_PRIVATE_FRAMEWORKS = GraphicsServices
AIClient_LIBRARIES = sqlite3
AIClient_CFLAGS = -fobjc-arc -Wall -Wextra -std=c++17 -D__IPHONE_6_0=60000
AIClient_LDFLAGS = -lc++
AIClient_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# Custom build steps
before-package::
	@echo "Building AIClient for iOS 6..."
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/AIClient.app/Resources
	@cp -r Resources/* $(THEOS_STAGING_DIR)/Applications/AIClient.app/Resources/ 2>/dev/null || true

after-install::
	install.exec "killall -9 AIClient 2>/dev/null || true"

# Convenience targets
.PHONY: package-deb package-ipa clean-all

package-deb:
	$(MAKE) package FINALPACKAGE=1 DEBUG=0

package-ipa: package-deb
	@DEB_FILE=$$(ls packages/*.deb 2>/dev/null | head -1); \
	if [ -z "$$DEB_FILE" ]; then echo "No .deb found"; exit 1; fi; \
	mkdir -p build/ipa/Payload; \
	dpkg-deb -x "$$DEB_FILE" build/ipa; \
	APP_PATH=$$(find build/ipa -name "*.app" -type d | head -1); \
	cp -r "$$APP_PATH" build/ipa/Payload/; \
	cd build/ipa && zip -r "../../AIClient.ipa" Payload && cd ../..; \
	echo "Created AIClient.ipa"

clean-all:
	$(MAKE) clean
	rm -rf packages/ .theos/ obj/ layout/ build/