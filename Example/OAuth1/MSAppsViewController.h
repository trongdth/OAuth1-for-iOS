//
//  MSAppsViewController.h
//  OAuth1
//
//  Created by Trong_iOS on 5/8/17.
//  Copyright © 2017 trongdth. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MSAppsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    __weak IBOutlet UITableView *tblView;
}

@property (nonatomic, strong) NSMutableArray *arr;

@end
