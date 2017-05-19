//
//  FHSTwitterEngine.m
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
// Edited by trongdth

#import "FHSTwitterEngine.h"

#import <QuartzCore/QuartzCore.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CommonCrypto/CommonHMAC.h>
#import <objc/runtime.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <ifaddrs.h>

static char const Encode[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static NSString * const newPinJS = @"var d = document.getElementById('oauth-pin'); if (d == null) d = document.getElementById('oauth_pin'); if (d) { var d2 = d.getElementsByTagName('code'); if (d2.length > 0) d2[0].innerHTML; }";
static NSString * const oldPinJS = @"var d = document.getElementById('oauth-pin'); if (d == null) d = document.getElementById('oauth_pin'); if (d) d = d.innerHTML; d;";

NSString * const FHSErrorDomain = @"FHSErrorDomain";
static NSString * const authBlockKey = @"FHSTwitterEngineOAuthCompletion";

static NSString * oauth1_token = @"";
static NSString * oauth1_request_token = @"";
static NSString * oauth1_authorize = @"";
static NSString * oauth1_consumer_key = @"";
static NSString * oauth1_secret_key = @"";
static NSString * oauth1_xauth_username = @"";
static NSString * oauth1_xauth_password = @"";

NSString * fhs_url_remove_params(NSURL *url) {
    if (url.absoluteString.length == 0) {
        return nil;
    }
    
    NSArray *parts = [url.absoluteString componentsSeparatedByString:@"?"];
    return (parts.count == 0)?nil:parts[0];
}

id removeNull(id rootObject) {
    if ([rootObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *sanitizedDictionary = [NSMutableDictionary dictionaryWithDictionary:rootObject];
        [rootObject enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            id sanitized = removeNull(obj);
            if (!sanitized) {
                [sanitizedDictionary setObject:@"" forKey:key];
            } else {
                [sanitizedDictionary setObject:sanitized forKey:key];
            }
        }];
        return [NSMutableDictionary dictionaryWithDictionary:sanitizedDictionary];
    }
    
    if ([rootObject isKindOfClass:[NSArray class]]) {
        NSMutableArray *sanitizedArray = [NSMutableArray arrayWithArray:rootObject];
        [rootObject enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id sanitized = removeNull(obj);
            if (!sanitized) {
                [sanitizedArray replaceObjectAtIndex:[sanitizedArray indexOfObject:obj] withObject:@""];
            } else {
                [sanitizedArray replaceObjectAtIndex:[sanitizedArray indexOfObject:obj] withObject:sanitized];
            }
        }];
        return [NSMutableArray arrayWithArray:sanitizedArray];
    }

    if ([rootObject isKindOfClass:[NSNull class]]) {
        return (id)nil;
    } else {
        return rootObject;
    }
}

@interface FHSConsumer : NSObject

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *secret;

+ (FHSConsumer *)consumerWithKey:(NSString *)key secret:(NSString *)secret;

@end

@implementation FHSConsumer

+ (FHSConsumer *)consumerWithKey:(NSString *)key secret:(NSString *)secret {
    return [[[self class]alloc]initWithKey:key secret:secret];
}

- (instancetype)initWithKey:(NSString *)key secret:(NSString *)secret {
    self = [super init];
    if (self) {
        self.key = key;
        self.secret = secret;
    }
    return self;
}

@end

@implementation FHSToken

+ (FHSToken *)tokenWithHTTPResponseBody:(NSString *)body {
    return [[[self class]alloc]initWithHTTPResponseBody:body];
}

- (id)initWithHTTPResponseBody:(NSString *)body {
    self = [super init];
	if (self) {
        
        if (body.length > 0) {
            NSArray *pairs = [body componentsSeparatedByString:@"&"];
            
            for (NSString *pair in pairs) {
                
                NSArray *elements = [pair componentsSeparatedByString:@"="];
                
                if (elements.count > 1) {
                    NSString *field = elements[0];
                    NSString *value = elements[1];
                    
                    if ([field isEqualToString:@"oauth_token"]) {
                        self.key = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    } else if ([field isEqualToString:@"oauth_token_secret"]) {
                        self.secret = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    }
                }
            }
        }
	}
    
    return self;
}

@end

@interface FHSTwitterEngineController : UIViewController <UIWebViewDelegate> 

@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UIWebView *theWebView;
@property (nonatomic, strong) UILabel *loadingText;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) FHSToken *requestToken;

@end

@interface FHSTwitterEngine ()

// Login stuff
- (NSString *)getRequestTokenString;

// General Get request sender
- (id)sendRequest:(NSURLRequest *)request;

// These are here to obfuscate them from prying eyes
@property (strong, nonatomic) FHSConsumer *consumer;
@property (assign, nonatomic) BOOL shouldClearConsumer;

@end

@implementation NSError (FHSTwitterEngine)

+ (NSError *)badRequestError {
    return [NSError errorWithDomain:FHSErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:@"The request has missing or malformed parameters."}];
}

+ (NSError *)noDataError {
    return [NSError errorWithDomain:FHSErrorDomain code:204 userInfo:@{NSLocalizedDescriptionKey:@"The request did not return any content."}];
}

+ (NSError *)invalidAuth {
    return [NSError errorWithDomain:FHSErrorDomain code:400 userInfo:@{NSLocalizedDescriptionKey:@"You input invalid auth."}];
}

+ (NSError *)imageTooLargeError {
    return [NSError errorWithDomain:FHSErrorDomain code:422 userInfo:@{NSLocalizedDescriptionKey:@"The image you are trying to upload is too large."}];
}

@end

@implementation NSString (FHSTwitterEngine)

- (NSString *)fhs_URLEncode {
    CFStringRef url = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8);
	return (__bridge NSString *)url;
}

- (NSString *)fhs_truncatedToLength:(int)length {
    return [self substringToIndex:MIN(length, self.length)];
}

- (NSString *)fhs_trimForTwitter {
    return [self fhs_truncatedToLength:140];
}

- (NSString *)fhs_stringWithRange:(NSRange)range {
    return [[self substringFromIndex:range.location]substringToIndex:range.length];
}

+ (NSString *)fhs_UUID {
    if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 6.0f) {
        return [[NSUUID UUID]UUIDString];
    } else {
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        CFStringRef string = CFUUIDCreateString(kCFAllocatorDefault, theUUID);
        CFRelease(theUUID);
        NSString *uuid = [NSString stringWithString:(__bridge NSString *)string];
        CFRelease(string);
        return uuid;
    }
}

- (BOOL)fhs_isNumeric {
	const char *raw = (const char *)[self UTF8String];
    
	for (int i = 0; i < strlen(raw); i++) {
		if (raw[i] < '0' || raw[i] > '9') {
            return NO;
        }
	}
	return YES;
}

@end

@implementation NSData (FHSTwitterEngine)

- (NSString *)appropriateFileExtension {
    uint8_t c;
    [self getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
        case 0x4D:
            return @"tiff";
    }
    return nil;
}

- (NSString *)base64Encode {
    int outLength = ((((self.length*4)/3)/4)*4)+(((self.length*4)/3)%4?4:0);
    const char *inputBuffer = self.bytes;
    char *outputBuffer = malloc(outLength+1);
    outputBuffer[outLength] = 0;
    
    int cycle = 0;
    int inpos = 0;
    int outpos = 0;
    char temp;
    
    outputBuffer[outLength-1] = '=';
    outputBuffer[outLength-2] = '=';
    
    while (inpos < self.length) {
        switch (cycle) {
            case 0:
                outputBuffer[outpos++] = Encode[(inputBuffer[inpos]&0xFC)>>2];
                cycle = 1;
                break;
            case 1:
                temp = (inputBuffer[inpos++]&0x03)<<4;
                outputBuffer[outpos] = Encode[temp];
                cycle = 2;
                break;
            case 2:
                outputBuffer[outpos++] = Encode[temp|(inputBuffer[inpos]&0xF0)>>4];
                temp = (inputBuffer[inpos++]&0x0F)<<2;
                outputBuffer[outpos] = Encode[temp];
                cycle = 3;
                break;
            case 3:
                outputBuffer[outpos++] = Encode[temp|(inputBuffer[inpos]&0xC0)>>6];
                cycle = 4;
                break;
            case 4:
                outputBuffer[outpos++] = Encode[inputBuffer[inpos++]&0x3f];
                cycle = 0;
                break;
            default:
                cycle = 0;
                break;
        }
    }
    NSString *pictemp = [NSString stringWithUTF8String:outputBuffer];
    free(outputBuffer);
    return pictemp;
}

@end

@implementation FHSTwitterEngine

// Actual calls to the Twitter API

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelTouched:) name:@"FHSTwitterEngineControllerDidCancel" object:nil];
    }
    return self;
}

+ (FHSTwitterEngine *)sharedEngine {
    static FHSTwitterEngine *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class]alloc]init];
    });
    return sharedInstance;
}

//
// sendRequest:
//

- (id)sendRequest:(NSURLRequest *)request {
    
    if (_shouldClearConsumer) {
        self.shouldClearConsumer = NO;
        self.consumer = nil;
    }
    
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error) {
        return error;
    }
    
    if (response == nil) {
        return error;
    }
    
    if (response.statusCode >= 304) {
        return error;
    }
    
    if (data.length == 0) {
        return error;
    }
    
    return data;
}

- (void)signRequest:(NSMutableURLRequest *)request {
    [self signRequest:request withToken:_accessToken.key tokenSecret:_accessToken.secret verifier:nil];
}

- (void)signRequest:(NSMutableURLRequest *)request withToken:(NSString *)tokenString tokenSecret:(NSString *)tokenSecretString verifier:(NSString *)verifierString {
    
    NSString *consumerKey = [_consumer.key fhs_URLEncode];
    NSString *nonce = [NSString fhs_UUID];
    NSString *timestamp = [NSString stringWithFormat:@"%ld",time(nil)];
    NSString *urlWithoutParams = [fhs_url_remove_params(request.URL) fhs_URLEncode];
    
    // OAuth Spec, Section 9.1.1 "Normalize Request Parameters"
    // build a sorted array of both request parameters and OAuth header parameters
    NSMutableDictionary *mutableParams = [NSMutableDictionary dictionary];
    
    mutableParams[@"oauth_consumer_key"] = consumerKey;
    mutableParams[@"oauth_signature_method"] = @"HMAC-SHA1";
    mutableParams[@"oauth_timestamp"] = timestamp;
    mutableParams[@"oauth_nonce"] = nonce;
    mutableParams[@"oauth_version"] = @"1.0";
    
    if (tokenString.length > 0) {
        mutableParams[@"oauth_token"] = [tokenString fhs_URLEncode];
        if (verifierString.length > 0) {
            mutableParams[@"oauth_verifier"] = [verifierString fhs_URLEncode];
        }
    } else {
        mutableParams[@"oauth_callback"] = @"oob";
    }
    
    NSMutableArray *paramPairs = [NSMutableArray arrayWithCapacity:mutableParams.count];
    
    for (NSString *key in mutableParams.allKeys) {
        [paramPairs addObject:[NSString stringWithFormat:@"%@=%@",[key fhs_URLEncode],[mutableParams[key] fhs_URLEncode]]];
    }
    
    if ([request.HTTPMethod isEqualToString:@"GET"]) {
        
        NSArray *halves = [request.URL.absoluteString componentsSeparatedByString:@"?"];
        
        if (halves.count > 1) {
            NSArray *parameters = [halves[1] componentsSeparatedByString:@"&"];
            
            if (parameters.count > 0) {
                [paramPairs addObjectsFromArray:parameters];
            }
        }
    }
    
    [paramPairs sortUsingSelector:@selector(compare:)];
    
    NSString *normalizedRequestParameters = [[paramPairs componentsJoinedByString:@"&"]fhs_URLEncode];
    
    // OAuth Spec, Section 9.1.2 "Concatenate Request Elements"
    // Sign request elements using HMAC-SHA1
    NSString *signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@",request.HTTPMethod,urlWithoutParams,normalizedRequestParameters];
    
    NSString *tokenSecretSantized = (tokenSecretString.length > 0)?[tokenSecretString fhs_URLEncode]:@""; // this way a nil token won't make a bad signature
    
    NSString *secret = [NSString stringWithFormat:@"%@&%@",[_consumer.secret fhs_URLEncode],tokenSecretSantized];
    
    NSData *secretData = [secret dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [signatureBaseString dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[20];
	CCHmac(kCCHmacAlgSHA1, secretData.bytes, secretData.length, clearTextData.bytes, clearTextData.length, result);
    NSData *theData = [[[NSData dataWithBytes:result length:20]base64Encode]dataUsingEncoding:NSUTF8StringEncoding];

    NSString *signature = [[[NSString alloc]initWithData:theData encoding:NSUTF8StringEncoding]fhs_URLEncode];
    
	NSString *oauthToken = (tokenString.length > 0)?[NSString stringWithFormat:@"oauth_token=\"%@\", ",[tokenString fhs_URLEncode]]:@"oauth_callback=\"oob\", ";
    NSString *oauthVerifier = (verifierString.length > 0)?[NSString stringWithFormat:@"oauth_verifier=\"%@\", ",verifierString]:@"";

    NSString *oauthHeader = [NSString stringWithFormat:@"OAuth oauth_consumer_key=\"%@\", %@%@oauth_signature_method=\"HMAC-SHA1\", oauth_signature=\"%@\", oauth_timestamp=\"%@\", oauth_nonce=\"%@\", oauth_version=\"1.0\"",consumerKey,oauthToken,oauthVerifier,signature,timestamp,nonce];
    
    [request setValue:oauthHeader forHTTPHeaderField:@"Authorization"];
}

- (int)parameterLengthForURL:(NSString *)url params:(NSMutableDictionary *)params {
    int length = url.length;

    for (NSString *key in params) {
        length += [key fhs_URLEncode].length;
        length += [params[key] fhs_URLEncode].length;
        length += 1; // for the equal sign
    }
    
    return length;
}

- (NSError *)checkAuth {
    if (![self isAuthorized]) {
        [self loadAccessToken];
        if (![self isAuthorized]) {
            return [NSError errorWithDomain:FHSErrorDomain code:401 userInfo:@{NSLocalizedDescriptionKey:@"You are not authorized via OAuth."}];
        }
    }
    return nil;
}

- (NSError *)checkError:(id)json {
    if ([json isKindOfClass:[NSDictionary class]]) {
        NSArray *errors = json[@"errors"];
        
        if (errors.count > 0) {
            return [NSError errorWithDomain:FHSErrorDomain code:418 userInfo:@{NSLocalizedDescriptionKey: @"Multiple Errors", @"errors": errors}];
        }
    }
    return nil;
}

- (NSData *)POSTBodyWithParams:(NSDictionary *)params boundary:(NSString *)boundary {
    NSMutableData *body = [NSMutableData dataWithLength:0];
    
    for (NSString *key in params.allKeys) {
        id obj = params[key];
        
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSData *data = nil;
        
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n",key] dataUsingEncoding:NSUTF8StringEncoding]];
        
        if ([obj isKindOfClass:[NSData class]]) {
            [body appendData:[@"Content-Type: application/octet-stream\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            data = (NSData *)obj;
        } else if ([obj isKindOfClass:[NSString class]]) {
            data = [[NSString stringWithFormat:@"%@",(NSString *)obj]dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:data];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    return body;
}

- (NSError *)sendPOSTRequestForURL:(NSURL *)url andParams:(NSDictionary *)params {
    
    NSError *authError = [self checkAuth];
    
    if (authError) {
        return authError;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0f];
    [request setHTTPMethod:@"POST"];
    [request setHTTPShouldHandleCookies:NO];
    
    NSString *boundary = [NSString fhs_UUID];
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    [self signRequest:request];
    
    NSData *body = [self POSTBodyWithParams:params boundary:boundary];
    [request setValue:@(body.length).stringValue forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = body;
    
    id retobj = [self sendRequest:request];
    
    if (!retobj) {
        return [NSError noDataError];
    } else if ([retobj isKindOfClass:[NSError class]]) {
        return retobj;
    }
    
    id parsed = removeNull([NSJSONSerialization JSONObjectWithData:(NSData *)retobj options:NSJSONReadingMutableContainers error:nil]);
    
    NSError *error = [self checkError:parsed];
    
    if (error) {
        return error;
    }
    
    return nil; // eventually return the parsed response
}

- (id)sendGETRequestForURL:(NSURL *)url andParams:(NSDictionary *)params {
    
    NSError *authError = [self checkAuth];
    
    if (authError) {
        return authError;
    }
    
    if (params.count > 0) {
        NSMutableArray *paramPairs = [NSMutableArray arrayWithCapacity:params.count];
        
        for (NSString *key in params) {
            NSString *paramPair = [NSString stringWithFormat:@"%@=%@",[key fhs_URLEncode],[params[key] fhs_URLEncode]];
            [paramPairs addObject:paramPair];
        }
        
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@",fhs_url_remove_params(url), [paramPairs componentsJoinedByString:@"&"]]];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0f];
    [request setHTTPMethod:@"GET"];
    [request setHTTPShouldHandleCookies:NO];
    [self signRequest:request];

    id retobj = [self sendRequest:request];
    
    if (!retobj) {
        return [NSError noDataError];
    } else if ([retobj isKindOfClass:[NSError class]]) {
        return retobj;
    }
    
    id parsed = removeNull([NSJSONSerialization JSONObjectWithData:(NSData *)retobj options:NSJSONReadingMutableContainers error:nil]);
    
    NSError *error = [self checkError:parsed];
    
    if (error) {
        return error;
    }
    
    return parsed;
}

//
// OAuth
//

- (NSString *)getRequestTokenString {
    
    NSURL *url = [NSURL URLWithString:oauth1_request_token];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0f];
    [request setHTTPMethod:@"POST"];
    [request setHTTPShouldHandleCookies:NO];
    [self signRequest:request withToken:nil tokenSecret:nil verifier:nil];

    id retobj = [self sendRequest:request];
    
    if ([retobj isKindOfClass:[NSData class]]) {
        return [[NSString alloc]initWithData:(NSData *)retobj encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (BOOL)finishAuthWithRequestToken:(FHSToken *)reqToken {

    NSURL *url = [NSURL URLWithString:oauth1_token];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0f];
    [request setHTTPMethod:@"POST"];
    [request setHTTPShouldHandleCookies:NO];
    [self signRequest:request withToken:reqToken.key tokenSecret:reqToken.secret verifier:reqToken.verifier];
    
    if (_shouldClearConsumer) {
        self.shouldClearConsumer = NO;
        self.consumer = nil;
    }
    
    id retobj = [self sendRequest:request];
    
    if ([retobj isKindOfClass:[NSError class]]) {
        return NO;
    }
    
    NSString *response = [[NSString alloc]initWithData:(NSData *)retobj encoding:NSUTF8StringEncoding];
    
    if (response.length == 0) {
        return NO;
    }
    
    [self storeAccessToken:response];
    
    return YES;
}

//
// XAuth
//

- (NSError *)getXAuthAccessTokenForUsername:(NSString *)username password:(NSString *)password {
    
    if (password.length == 0) {
        return [NSError badRequestError];
    } else if (username.length == 0) {
        return [NSError badRequestError];
    }
    
    NSURL *url = [NSURL URLWithString:oauth1_token];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0f];
    [request setHTTPMethod:@"POST"];
    [request setHTTPShouldHandleCookies:NO];
    [self signRequest:request withToken:nil tokenSecret:nil verifier:nil];
    
    // generate the POST body...
    
    NSString *bodyString = [NSString stringWithFormat:@"x_auth_mode=client_auth&x_auth_username=%@&x_auth_password=%@",username,password];
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    if (_shouldClearConsumer) {
        self.shouldClearConsumer = NO;
        self.consumer = nil;
    }
    
    id ret = [self sendRequest:request];
    
    if ([ret isKindOfClass:[NSError class]]) {
        return ret;
    } else if ([ret isKindOfClass:[NSData class]]) {
        NSString *httpBody = [[NSString alloc]initWithData:(NSData *)ret encoding:NSUTF8StringEncoding];
        
        if (httpBody.length > 0) {
            [self storeAccessToken:httpBody];
        } else {
            [self storeAccessToken:nil];
            return [NSError errorWithDomain:FHSErrorDomain code:422 userInfo:@{NSLocalizedDescriptionKey:@"The request was well-formed but was unable to be followed due to semantic errors.", @"request":request}];
        }
    }
    
    return nil;
}

//
// Access Token Management
//

- (void)loadAccessToken {
    
    NSString *savedHttpBody = nil;
    
    if (_delegate && [_delegate respondsToSelector:@selector(loadAccessToken)]) {
        savedHttpBody = [_delegate loadAccessToken];
    } else {
        savedHttpBody = [[NSUserDefaults standardUserDefaults]objectForKey:@"SavedAccessHTTPBody"];
    }
    
    self.accessToken = [FHSToken tokenWithHTTPResponseBody:savedHttpBody];
}

- (void)storeAccessToken:(NSString *)accessTokenZ {
    self.accessToken = [FHSToken tokenWithHTTPResponseBody:accessTokenZ];
    if (_delegate && [_delegate respondsToSelector:@selector(storeAccessToken:)]) {
        [_delegate storeAccessToken:accessTokenZ];
        
    } else if (_delegate && [_delegate respondsToSelector:@selector(oauth1Reponsed:)]) {
        [_delegate oauth1Reponsed:[self extractValueFromHTTPBody:accessTokenZ]];
        
    } else {
        [[NSUserDefaults standardUserDefaults]setObject:accessTokenZ forKey:@"SavedAccessHTTPBody"];
    }
        
}

- (NSDictionary *)extractValueFromHTTPBody:(NSString *)body {
    if (body.length == 0) {
        return nil;
    }
    
	NSArray *tuples = [body componentsSeparatedByString:@"&"];
	if (tuples.count < 1) {
        return nil;
    }
	
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	for (NSString *tuple in tuples) {
		NSArray *keyValueArray = [tuple componentsSeparatedByString:@"="];
		
		if (keyValueArray.count >= 2) {
			NSString *key = [keyValueArray objectAtIndex:0];
			NSString *value = [keyValueArray objectAtIndex:1];
            [dict setObject:value forKey:key];
		}
	}
	
	return dict;
}

- (BOOL)isAuthorized {
    if (!self.consumer) {
        return NO;
    }
    
	if (self.accessToken.key && self.accessToken.secret) {
        if (self.accessToken.key.length > 0 && self.accessToken.secret.length > 0) {
            return YES;
        }
    }
    
	return NO;
}

- (void)clearAccessToken {
    [self storeAccessToken:@""];
	self.accessToken = nil;
}

- (void)clearConsumer {
    self.consumer = nil;
}

- (void)permanentlySetConsumerKey:(NSString *)consumerKey andSecret:(NSString *)consumerSecret {
    self.shouldClearConsumer = NO;
    self.consumer = [FHSConsumer consumerWithKey:consumerKey secret:consumerSecret];
}

- (void)temporarilySetConsumerKey:(NSString *)consumerKey andSecret:(NSString *)consumerSecret {
    self.shouldClearConsumer = YES;
    self.consumer = [FHSConsumer consumerWithKey:consumerKey secret:consumerSecret];
}

- (NSError *)authWithInfo:(NSDictionary *)dict {
    if ([self validateOAuth1:dict]) {
        [self permanentlySetConsumerKey:oauth1_consumer_key andSecret:oauth1_secret_key];
        
    } else if([self validateXAuth:dict]) {
        return [self getXAuthAccessTokenForUsername:[dict objectForKey:kOAuth1_xAUTH_USERNAME] password:[dict objectForKey:kOAuth1_xAUTH_PASSWORD]];
        
    } else {
        return [NSError invalidAuth];
    }
    
    return nil;
}

- (BOOL)validateOAuth1:(NSDictionary *)dict {
    if (dict) {
        if ([dict objectForKey:kOAuth1_TOKEN] &&
            [dict objectForKey:kOAuth1_REQUEST_TOKEN] &&
            [dict objectForKey:kOAuth1_AUTHORIZE] &&
            [dict objectForKey:kOAuth1_CONSUMER_KEY] &&
            [dict objectForKey:kOAuth1_SECRET_KEY]) {
            
            oauth1_token = [dict objectForKey:kOAuth1_TOKEN];
            oauth1_request_token = [dict objectForKey:kOAuth1_REQUEST_TOKEN];
            oauth1_authorize = [dict objectForKey:kOAuth1_AUTHORIZE];
            oauth1_consumer_key = [dict objectForKey:kOAuth1_CONSUMER_KEY];
            oauth1_secret_key = [dict objectForKey:kOAuth1_SECRET_KEY];
            
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)validateXAuth:(NSDictionary *)dict {
    if (dict) {
        if ([dict objectForKey:kOAuth1_TOKEN] &&
            [dict objectForKey:kOAuth1_xAUTH_PASSWORD] &&
            [dict objectForKey:kOAuth1_xAUTH_USERNAME]) {
            
            oauth1_token = [dict objectForKey:kOAuth1_TOKEN];
            oauth1_xauth_username = [dict objectForKey:kOAuth1_xAUTH_USERNAME];
            oauth1_xauth_password = [dict objectForKey:kOAuth1_xAUTH_PASSWORD];
            
            return YES;
        }
    }
    return NO;
}

- (UIViewController *)loginController {
    return [[FHSTwitterEngineController alloc]init]; // It's legit because this project is ARC only.
}

- (UIViewController *)loginControllerWithCompletionHandler:(void(^)(BOOL success))block {
    FHSTwitterEngineController *vc = [[FHSTwitterEngineController alloc]init];
    objc_setAssociatedObject(vc, (__bridge const void *)(authBlockKey), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return vc;
}

+ (BOOL)isConnectedToInternet {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    
    if (reachability) {
        SCNetworkReachabilityFlags flags;
        BOOL worked = SCNetworkReachabilityGetFlags(reachability, &flags);
        CFRelease(reachability);
        
        if (worked) {
            
            if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
                return NO;
            }
            
            if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
                return YES;
            }
            
            if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
                if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
                    return YES;
                }
            }
            
            if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
                return YES;
            }
        }
        
    }
    return NO;
}

- (void)cancelTouched:(NSNotification *)notification {
    if ( [_delegate respondsToSelector:@selector(twitterEngineControllerDidCancel)] ) {
        [_delegate twitterEngineControllerDidCancel];
    }
}

- (void)dealloc {
    [self setDelegate:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end

@implementation FHSTwitterEngineController

- (void)loadView {
    [super loadView];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(pasteboardChanged:) name:UIPasteboardChangedNotification object:nil];
    
    self.view = [[UIView alloc]initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.navBar = [[UINavigationBar alloc]initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f)?64:44)];
    _navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    UINavigationItem *navItem = [[UINavigationItem alloc]initWithTitle:@"Login"];
	navItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close)];
	[_navBar pushNavigationItem:navItem animated:NO];
    
    self.theWebView = [[UIWebView alloc]initWithFrame:CGRectMake(0, _navBar.bounds.size.height, self.view.bounds.size.width, self.view.bounds.size.height-_navBar.bounds.size.height)];
    _theWebView.hidden = YES;
    _theWebView.delegate = self;
    _theWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _theWebView.dataDetectorTypes = UIDataDetectorTypeNone;
    _theWebView.scrollView.clipsToBounds = NO;
    _theWebView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:_theWebView];
    [self.view addSubview:_navBar];
    
    self.loadingText = [[UILabel alloc]initWithFrame:CGRectMake((self.view.bounds.size.width/2)-40, (self.view.bounds.size.height/2)-10-7.5, 100, 15)];
	_loadingText.text = @"Please Wait...";
	_loadingText.backgroundColor = [UIColor clearColor];
	_loadingText.textColor = [UIColor blackColor];
	_loadingText.textAlignment = NSTextAlignmentLeft;
	_loadingText.font = [UIFont boldSystemFontOfSize:15];
	[self.view addSubview:_loadingText];
	
	self.spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_spinner.center = CGPointMake((self.view.bounds.size.width/2)-60, (self.view.bounds.size.height/2)-10);
	[self.view addSubview:_spinner];
	[_spinner startAnimating];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSString *reqString = [[FHSTwitterEngine sharedEngine]getRequestTokenString];

            if (reqString.length == 0) {
                double delayInSeconds = 0.5;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(),^(void) {
                    @autoreleasepool {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    }
                });
            } else {
                self.requestToken = [FHSToken tokenWithHTTPResponseBody:reqString];
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@?oauth_token=%@",oauth1_authorize, _requestToken.key]]];
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        [_theWebView loadRequest:request];
                    }
                });
            }
        }
    });
}

- (void)gotPin:(NSString *)pin {
    _requestToken.verifier = pin;
    BOOL ret = [[FHSTwitterEngine sharedEngine]finishAuthWithRequestToken:_requestToken];
    
    void(^block)(BOOL success) = objc_getAssociatedObject(self, (__bridge const void *)(authBlockKey));
    
    if (block) {
        block(ret);
    }
    
    objc_setAssociatedObject(self, (__bridge const void *)(authBlockKey), nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pasteboardChanged:(NSNotification *)note {
	
	if (![note.userInfo objectForKey:UIPasteboardChangedTypesAddedKey]) {
        return;
    }
    
    NSString *string = [[UIPasteboard generalPasteboard]string];
	
	if (string.length != 7 || !string.fhs_isNumeric) {
        return;
    }
	
	[self gotPin:string];
}

- (NSString *)locatePin {
	NSString *pin = [[_theWebView stringByEvaluatingJavaScriptFromString:newPinJS]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if (pin.length == 7) {
		return pin;
	} else {
		pin = [[_theWebView stringByEvaluatingJavaScriptFromString:oldPinJS]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if (pin.length == 7) {
			return pin;
		}
	}
	return nil;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _theWebView.userInteractionEnabled = YES;
    NSString *authPin = [self locatePin];
    
    if (authPin.length > 0) {
        [self gotPin:authPin];
        return;
    }
    
    NSString *formCount = [webView stringByEvaluatingJavaScriptFromString:@"document.forms.length"];
    
    if ([formCount isEqualToString:@"0"]) {
        _navBar.topItem.title = @"Select and Copy the PIN";
    }
	
	[UIView beginAnimations:nil context:nil];
    _spinner.hidden = YES;
    _loadingText.hidden = YES;
	[UIView commitAnimations];
	
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    _theWebView.hidden = NO;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    _theWebView.userInteractionEnabled = NO;
    [_theWebView setHidden:YES];
    _spinner.hidden = NO;
    _loadingText.hidden = NO;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if (strstr([request.URL.absoluteString UTF8String], "denied=")) {
		[self dismissViewControllerAnimated:YES completion:nil];
        return NO;
    }
    
    NSData *data = request.HTTPBody;
	char *raw = data?(char *)[data bytes]:"";
	
	if (raw && (strstr(raw, "cancel=") || strstr(raw, "deny="))) {
        [self close];
		return NO;
	}
    
	return YES;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:^(void){
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FHSTwitterEngineControllerDidCancel" object:nil userInfo:nil];
    }];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [_theWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@""]]];
    [super dismissViewControllerAnimated:flag completion:completion];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end
