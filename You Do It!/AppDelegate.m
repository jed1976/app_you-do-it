//
//  AppDelegate.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSBundle *bundle = [NSBundle mainBundle];
    
    DBAccountManager *accountManager = [[DBAccountManager alloc] initWithAppKey:[bundle objectForInfoDictionaryKey:@"APP_KEY"] secret:[bundle objectForInfoDictionaryKey:@"APP_SECRET"]];
    [DBAccountManager setSharedManager:accountManager];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation
{
    DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
    
    if (account)
    {
        ListViewController *viewController = (ListViewController *)self.window.rootViewController;
        [viewController loadData];
        
        return YES;
    }
    
    return NO;
}

@end
