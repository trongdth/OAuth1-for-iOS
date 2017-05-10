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

#pragma mark - view life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _arr = [NSMutableArray array];
    [self loadData];

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

- (void)doAuth:(NSDictionary *)dict {
    [[FHSTwitterEngine sharedEngine] setDelegate:self];
    if([[FHSTwitterEngine sharedEngine] isAuthorized]) {
        NSLog(@"YES");
        [self callUserRequest];

    } else {
        NSError *err = [[FHSTwitterEngine sharedEngine] authWithInfo:dict];
        if (!err) {
            UIViewController *loginController = [[FHSTwitterEngine sharedEngine]loginControllerWithCompletionHandler:^(BOOL success) {
                if(success) {
                    NSLog(@"YES");
                } else {
                    NSLog(@"NO");
                }
            }];
            [self presentViewController:loginController animated:YES completion:^{
                
            }];
        }

    }
}

- (void)callUserRequest {
    id data = [[FHSTwitterEngine sharedEngine] sendGETRequestForURL:[NSURL URLWithString:@"https://api.twitter.com/1.1/account/verify_credentials.json"] andParams:nil];
    NSLog(@"%@", data);
}

#pragma mark - Functions

- (void)loadData {
    _arr = [[NSMutableArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Autonomous" ofType:@"plist"]];
    if (!_arr) {
        [tblView reloadData];
    }
}

#pragma mark - FHSTwitterEngineAccessTokenDelegate methods

- (void)oauth1Reponsed:(NSDictionary *)dict {
    NSLog(@"%@", dict);
}


#pragma mark - UITableViewDelegate method

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self doAuth:[_arr objectAtIndex:indexPath.row]];
}

#pragma mark - UITableViewDatasource method

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _arr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath; {
    static NSString *cellIdentifier = @"cellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *dict = [_arr objectAtIndex:indexPath.row];
    cell.textLabel.text = [dict objectForKey:@"name"];
    
    return cell;
}


@end
