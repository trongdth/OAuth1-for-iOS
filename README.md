# OAuth1-for-iOS

It's a library on iOS which is suitable for OAuth1.

[![Build Status](https://travis-ci.org/trongdth/OAuth1-for-iOS.svg?branch=master)](https://travis-ci.org/trongdth/OAuth1-for-iOS)
[![Version](https://img.shields.io/cocoapods/v/OAuth1.svg?style=flat)](http://cocoapods.org/pods/OAuth1)
[![License](https://img.shields.io/cocoapods/l/OAuth1.svg?style=flat)](http://cocoapods.org/pods/OAuth1)
[![Platform](https://img.shields.io/cocoapods/p/OAuth1.svg?style=flat)](http://cocoapods.org/pods/OAuth1)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

## OVERVIEW

The idea based on FHSTwitterEngine (https://github.com/natesymer/FHSTwitterEngine) but has reduced more code and make it lightweight and suitable for all others OAuth1.

## Usage

 1. To run the example project, clone the repo, and run `pod install` from the Example directory first.

 2. Declare FHSTwitterEngine:

```objective-c
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
```

 3. Implement FHSTwitterEngineAccessTokenDelegate method to obtain accesstoken:

```objective-c
- (void)oauth1Reponsed:(NSDictionary *)dict {
    NSLog(@"%@", dict);
}
```

 4. Call custom request:

```objective-c
- (void)callUserRequest {
    id data = [[FHSTwitterEngine sharedEngine] sendGETRequestForURL:[NSURL URLWithString:@"https://api.twitter.com/1.1/account/verify_credentials.json"] andParams:nil];
    NSLog(@"%@", data);
}
```

## Installation

1. Pod:
+ OAuth1 is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "OAuth1"
```

2. Carthage:
+ For Carthage installation:

```ruby
github "trongdth/OAuth1-for-iOS" "master"
```


## Author

Trong Dinh, trongdth@gmail.com

## License

OAuth1 is available under the APACHE license. See the LICENSE file for more info.
