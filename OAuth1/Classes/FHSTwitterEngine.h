//
//  FHSTwitterEngine.h
//  FHSTwitterEngine
//
//  Created by Nathaniel Symer on 8/22/12.
//  Copyright (C) 2012 Nathaniel Symer.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

//
// FHSTwitterEngine
// The synchronous Twitter engine that doesn’t suck!!
//
// Edited by trongdth

#import <UIKit/UIKit.h>

// Remove NSNulls from NSDictionary and NSArray
// Credit for this function goes to Conrad Kramer
id removeNull(id rootObject);

extern NSString * const FHSErrorDomain;

@interface FHSToken : NSObject

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *secret;
@property (nonatomic, strong) NSString *verifier;

+ (FHSToken *)tokenWithHTTPResponseBody:(NSString *)body;

@end

@protocol FHSTwitterEngineAccessTokenDelegate <NSObject>
@optional
- (NSString *)loadAccessToken;
- (void)storeAccessToken:(NSString *)accessToken;
- (void)oauth1Reponsed:(NSDictionary *)dict;

@optional
- (void)twitterEngineControllerDidCancel;

@end

@interface FHSTwitterEngine : NSObject

//
// Request
//

- (id)sendGETRequestForURL:(NSURL *)url andParams:(NSDictionary *)params;
- (NSError *)sendPOSTRequestForURL:(NSURL *)url andParams:(NSDictionary *)params;

//
// Login and Auth
//

// OAuth login
- (UIViewController *)loginController;
- (UIViewController *)loginControllerWithCompletionHandler:(void(^)(BOOL success))block;

// Access Token Mangement
- (void)clearAccessToken;
- (void)loadAccessToken;
- (BOOL)isAuthorized;

// API Key management
- (void)clearConsumer;
- (NSError *)authWithInfo:(NSDictionary *)dict;

// never call -[FHSTwitterEngine init] directly
+ (FHSTwitterEngine *)sharedEngine; 

+ (BOOL)isConnectedToInternet;

@property (nonatomic, strong) FHSToken *accessToken;

// called to retrieve or save access tokens
@property (nonatomic, weak) id<FHSTwitterEngineAccessTokenDelegate> delegate;

@end

@interface NSData (FHSTwitterEngine)
- (NSString *)appropriateFileExtension;
- (NSString *)base64Encode;
@end

@interface NSString (FHSTwitterEngine)
- (NSString *)fhs_URLEncode;
- (NSString *)fhs_truncatedToLength:(int)length;
- (NSString *)fhs_trimForTwitter;
- (NSString *)fhs_stringWithRange:(NSRange)range;
+ (NSString *)fhs_UUID;
- (BOOL)fhs_isNumeric;
@end

@interface NSError (FHSTwitterEngine)

+ (NSError *)badRequestError;
+ (NSError *)invalidAuth;
+ (NSError *)noDataError;
+ (NSError *)imageTooLargeError;

@end
