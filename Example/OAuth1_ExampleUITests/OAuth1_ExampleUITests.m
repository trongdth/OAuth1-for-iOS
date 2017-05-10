//
//  OAuth1_ExampleUITests.m
//  OAuth1_ExampleUITests
//
//  Created by Trong_iOS on 5/10/17.
//  Copyright © 2017 trongdth. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface OAuth1_ExampleUITests : XCTestCase

@end

@implementation OAuth1_ExampleUITests

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    [[[XCUIApplication alloc] init] launch];
    
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testTwitterValidWithEmailAndPasswordFields {
    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.

    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app.tables.staticTexts[@"Twitter"] tap];
    
    XCUIElementQuery *webViewsQuery = app.webViews;
    [webViewsQuery.staticTexts[@"Username or email"] tap];
    
    XCUIElement *element = [[webViewsQuery.otherElements[@"main"] childrenMatchingType:XCUIElementTypeOther] elementBoundByIndex:2];
    XCTAssert([[[element childrenMatchingType:XCUIElementTypeOther] elementBoundByIndex:0] childrenMatchingType:XCUIElementTypeTextField].element.exists);
    
    [webViewsQuery.staticTexts[@"Password"] tap];
    XCTAssert([[[element childrenMatchingType:XCUIElementTypeOther] elementBoundByIndex:1] childrenMatchingType:XCUIElementTypeSecureTextField].element.exists);
    
    XCUIElement *btnCancel = app.navigationBars[@"Login"].buttons[@"Cancel"];
    XCTAssertNotNil(btnCancel);
}

@end
