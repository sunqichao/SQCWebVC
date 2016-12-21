//
//  SQCWebViewController.h
//  YaoFang
//
//  Created by 小猪猪 on 2016/12/21.
//  Copyright © 2016年 SQC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SQCWebViewController : UIViewController<UIWebViewDelegate>

- (instancetype)initWithURL:(NSURL *)url;


- (instancetype)initWithURLString:(NSString *)urlString;

@property (nonatomic,strong) NSURL *url;
@property (nonatomic,strong) NSMutableURLRequest *urlRequest;
@property (nonatomic,readonly) UIWebView *webView;
@property (nonatomic,assign) BOOL showLoadingBar;
@property (nonatomic,assign) BOOL showUrlWhileLoading;
@property (nonatomic,assign) BOOL navigationButtonsHidden;
@property (nonatomic,assign) BOOL showActionButton;
@property (nonatomic,assign) BOOL showDoneButton;
@property (nonatomic,assign) BOOL showPageTitles;
@property (nonatomic,assign) BOOL disableContextualPopupMenu;
@property (nonatomic,assign) BOOL hideWebViewBoundaries;
@property (nonatomic,copy) void (^modalCompletionHandler)(void);
@property (nonatomic,copy) BOOL (^shouldStartLoadRequestHandler)(NSURLRequest *request, UIWebViewNavigationType navigationType);
@property (nonatomic,copy) UIColor *loadingBarTintColor;
@property (nonatomic,copy) NSString *doneButtonTitle;
@property (nonatomic,strong) UIColor *buttonTintColor;
@property (nonatomic,assign) CGFloat buttonBevelOpacity;

- (void)webViewDidStartLoad:(UIWebView *)webView;

- (void)webViewDidFinishLoad:(UIWebView *)webView;

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;


@end
