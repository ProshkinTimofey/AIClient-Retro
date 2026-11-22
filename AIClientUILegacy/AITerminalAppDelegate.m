//
//  AITerminalAppDelegate.m
//  AIClient
//
//  Theme-aware app delegate
//

#import "AITerminalAppDelegate.h"
#import "AITerminalRootViewController.h"
#import "AIAPIManager.h"
#import "AIConversationManager.h"
#import "AIKeychainManager.h"
#import "AITheme.h"

@implementation AITerminalAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize core managers
    [AIAPIManager sharedManager];
    [AIConversationManager sharedManager];
    [AIKeychainManager sharedManager];
    [AIThemeManager sharedManager]; // Initialize theme system

    // Create window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Root view controller - terminal style
    AITerminalRootViewController *rootVC = [[AITerminalRootViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];

    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[AIConversationManager sharedManager] saveAllConversations];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[AIConversationManager sharedManager] saveAllConversations];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[AIConversationManager sharedManager] saveAllConversations];
}

@end