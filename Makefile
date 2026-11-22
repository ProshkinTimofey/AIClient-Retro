export ARCHS = arm64
export TARGET = iphone:clang:latest:14.0
export DEBUG = 0
export FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AIClient

AIClient_FILES = \
	AIClientLauncher/main.m \
	AIClientLauncher/AIAppDelegate.m \
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
	AIClientPlatform/AIPlatform.m \
	AIClientPlatform/AIPasteboardMonitor.m \
	AIClientPlatform/AINotificationManager.m \
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

AIClient_FRAMEWORKS = UIKit Foundation CoreGraphics Photos MobileCoreServices Security CoreText QuartzCore
AIClient_PRIVATE_FRAMEWORKS = GraphicsServices
AIClient_LIBRARIES = sqlite3
AIClient_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter
AIClient_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

before-package::
	@echo "Building AIClient for iOS..."
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/AIClient.app/Resources
	@cp -r Resources/* $(THEOS_STAGING_DIR)/Applications/AIClient.app/Resources/ 2>/dev/null || true

after-install::
	install.exec "killall -9 AIClient 2>/dev/null || true"

.PHONY: package-ipa clean-all

package-ipa:
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
