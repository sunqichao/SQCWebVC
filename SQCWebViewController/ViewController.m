//
//  ViewController.m
//  SQCWebViewController
//
//  Created by 小猪猪 on 2016/12/21.
//  Copyright © 2016年 sqc. All rights reserved.
//

#import "ViewController.h"
#import "SQCWebViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)openWebVC:(id)sender {
    SQCWebViewController *webVC = [[SQCWebViewController alloc] initWithURLString:@"https://github.com/"];
    webVC.showPageTitles = YES;
    [self.navigationController pushViewController:webVC animated:YES];
    
}




@end
