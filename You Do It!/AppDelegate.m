//
//  AppDelegate.m
//  You Do It!
//
//  Created by Joe Dakroub on 9/6/13.
//  Copyright (c) 2013 Teacup Studio, LLC. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate()

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSBundle *bundle = [NSBundle mainBundle];
    
    DBAccountManager *accountManager = [[DBAccountManager alloc] initWithAppKey:[bundle objectForInfoDictionaryKey:@"APP_KEY"]
                                                                         secret:[bundle objectForInfoDictionaryKey:@"APP_SECRET"]];
    [DBAccountManager setSharedManager:accountManager];
    
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    [[DBAccountManager sharedManager] handleOpenURL:url];
    
    return YES;
}

@end
