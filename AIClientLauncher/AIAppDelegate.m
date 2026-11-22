//
//  AIAppDelegate.m
//  AIClient
//

#import "AIAppDelegate.h"
#import "AIRootViewController.h"
#import "AIAPIManager.h"
#import "AIConversationManager.h"
#import "AIKeychainManager.h"

@interface AIAppDelegate ()

@end

@implementation AIAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize core managers
    [AIAPIManager sharedManager];
    [AIConversationManager sharedManager];
    [AIKeychainManager sharedManager];

    // Setup appearance
    [self setupAppearance];

    // Create window
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor systemBackgroundColor];

    // Root view controller
    AIRootViewController *rootVC = [[AIRootViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];
    navController.navigationBar.prefersLargeTitles = YES;

    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)setupAppearance {
    // Navigation bar appearance
    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    navAppearance.configureWithOpaqueBackground();
    navAppearance.backgroundColor = [UIColor systemBackgroundColor];
    navAppearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor label]};
    navAppearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor label]};

    [[UINavigationBar appearance] setStandardAppearance:navAppearance];
    [[UINavigationBar appearance] setScrollEdgeAppearance:navAppearance];
    [[UINavigationBar appearance] setCompactAppearance:navAppearance];
    [[UINavigationBar appearance] setCompactScrollEdgeAppearance:navAppearance];

    // Tab bar appearance (if used)
    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    tabAppearance.configureWithOpaqueBackground();
    tabAppearance.backgroundColor = [UIColor systemBackgroundColor];
    [[UITabBar appearance] setStandardAppearance:tabAppearance];
    [[UITabBar appearance] setScrollEdgeAppearance:tabAppearance];

    // Toolbar appearance
    UIToolbarAppearance *toolbarAppearance = [[UIToolbarAppearance alloc] init];
    toolbarAppearance.configureWithOpaqueBackground();
    toolbarAppearance.backgroundColor = [UIColor systemBackgroundColor];
    [[UIToolbar appearance] setStandardAppearance:toolbarAppearance];
    [[UIToolbar appearance] setScrollEdgeAppearance:toolbarAppearance];

    // Tint color
    [[UIView appearance] setTintColor:[UIColor systemBlueColor]];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Save conversations
    [[AIConversationManager sharedManager] saveAllConversations];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[AIConversationManager sharedManager] saveAllConversations];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Refresh if needed
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[AIConversationManager sharedManager] saveAllConversations];
}

@end