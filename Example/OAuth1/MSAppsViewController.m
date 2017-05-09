//
//  MSAppsViewController.m
//  OAuth1
//
//  Created by Trong_iOS on 5/8/17.
//  Copyright © 2017 trongdth. All rights reserved.
//

#import "MSAppsViewController.h"
#import "FHSTwitterEngine.h"

#define kOAuth1_TOKEN                   @"kOAuth1_TOKEN"
#define kOAuth1_REQUEST_TOKEN           @"kOAuth1_REQUEST_TOKEN"
#define kOAuth1_AUTHORIZE               @"kOAuth1_AUTHORIZE"
#define kOAuth1_CONSUMER_KEY            @"kOAuth1_CONSUMER_KEY"
#define kOAuth1_SECRET_KEY              @"kOAuth1_SECRET_KEY"
#define kOAuth1_xAUTH_USERNAME          @"kOAuth1_xAUTH_USERNAME"
#define kOAuth1_xAUTH_PASSWORD          @"kOAuth1_xAUTH_PASSWORD"


@interface MSAppsViewController () <FHSTwitterEngineAccessTokenDelegate>

@end

@implementation MSAppsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[FHSTwitterEngine sharedEngine] setDelegate:self];
    if([[FHSTwitterEngine sharedEngine] isAuthorized]) {
        NSLog(@"YES");
        [self callUserRequest];
        
    } else {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"https://api.twitter.com/oauth/access_token", kOAuth1_TOKEN,
                                                                        @"https://api.twitter.com/oauth/request_token", kOAuth1_REQUEST_TOKEN,
                                                                        @"https://api.twitter.com/oauth/authorize", kOAuth1_AUTHORIZE,
                                                                        @"yRtOrW7lOURB0lTSaTWlN2fMv", kOAuth1_CONSUMER_KEY,
                                                                        @"xOjRhL9mqzFf7Ie6Zv647K8FjPVeQyt2LcyPGAbkPYYae05VwP", kOAuth1_SECRET_KEY, nil];
        
        NSError *err = [[FHSTwitterEngine sharedEngine] authWithInfo:dict];
        if (!err) {
            UIViewController *loginController = [[FHSTwitterEngine sharedEngine]loginControllerWithCompletionHandler:^(BOOL success) {
                if(success) {
                    NSLog(@"YES");
                    [self callUserRequest];
                } else {
                    NSLog(@"NO");
                }
            }];
            [self presentViewController:loginController animated:YES completion:^{
                
            }];
        }

    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)callUserRequest {
    id data = [[FHSTwitterEngine sharedEngine] sendGETRequestForURL:[NSURL URLWithString:@"https://api.twitter.com/1.1/account/verify_credentials.json"] andParams:nil];
    NSLog(@"%@", data);
}

#pragma mark - FHSTwitterEngineAccessTokenDelegate methods

- (void)oauth1Reponsed:(NSDictionary *)dict {
    NSLog(@"%@", dict);
}


@end
