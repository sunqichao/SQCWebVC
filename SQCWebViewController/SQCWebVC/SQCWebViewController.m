//
//  SQCWebViewController.m
//  YaoFang
//
//  Created by 小猪猪 on 2016/12/21.
//  Copyright © 2016年 SQC. All rights reserved.
//

#import "SQCWebViewController.h"
#import "SQCActivitySafari.h"

#import "UIImage+SQCWebViewControllerIcons.h"

#import <QuartzCore/QuartzCore.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import <MessageUI/MFMessageComposeViewController.h>

#define MINIMAL_UI      ([[UIViewController class] instancesRespondToSelector:@selector(edgesForExtendedLayout)])

#define NEW_ROTATIONS   ([[UIViewController class] instancesRespondToSelector:NSSelectorFromString(@"viewWillTransitionToSize:withTransitionCoordinator:")])

#define DEFAULT_BAR_TINT_COLOR [UIColor colorWithRed:0.0f green:110.0f/255.0f blue:1.0f alpha:1.0f]

#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

#define BLANK_BARBUTTONITEM [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]

#define BACKGROUND_COLOR_MINIMAL    [UIColor colorWithRed:0.741f green:0.741 blue:0.76f alpha:1.0f]
#define BACKGROUND_COLOR_CLASSIC    [UIColor scrollViewTexturedBackgroundColor]
#define BACKGROUND_COLOR            ((MINIMAL_UI) ? BACKGROUND_COLOR_MINIMAL : BACKGROUND_COLOR_CLASSIC)

#define NAVIGATION_BUTTON_WIDTH             31
#define NAVIGATION_BUTTON_SIZE              CGSizeMake(31,31)
#define NAVIGATION_BUTTON_SPACING           40
#define NAVIGATION_BUTTON_SPACING_IPAD      20
#define NAVIGATION_BAR_HEIGHT               (MINIMAL_UI ? 64.0f : 44.0f)
#define NAVIGATION_TOGGLE_ANIM_TIME         0.3

#define TOOLBAR_HEIGHT      44.0f

#define LOADING_BAR_HEIGHT          2

NSString *SQCCompleteRPCURL = @"webviewprogress:///complete";

static const float kInitialProgressValue                = 0.35f;
static const float kBeforeInteractiveMaxProgressValue   = 0.5f;
static const float kAfterInteractiveMaxProgressValue    = 0.9f;

#pragma mark -
#pragma mark Loading Bar Private Interface
@interface SQCWebLoadingView : UIView
@end

@implementation SQCWebLoadingView
- (void)tintColorDidChange { self.backgroundColor = self.tintColor; }
@end

#pragma mark -
#pragma mark Hidden Properties/Methods
@interface SQCWebViewController () <UIActionSheetDelegate,
UIPopoverControllerDelegate,
MFMailComposeViewControllerDelegate,
MFMessageComposeViewControllerDelegate>
{
    
    struct {
        CGSize     frameSize;
        CGSize     contentSize;
        CGPoint    contentOffset;
        CGFloat    zoomScale;
        CGFloat    minimumZoomScale;
        CGFloat    maximumZoomScale;
        CGFloat    topEdgeInset;
        CGFloat    bottomEdgeInset;
    } _webViewState;
    
    struct {
        NSInteger   loadingCount;
        NSInteger   maxLoadCount;
        BOOL        interactive;
        CGFloat     loadingProgress;
    } _loadingProgressState;
}

@property (nonatomic,readonly) BOOL beingPresentedModally;
@property (nonatomic,readonly) BOOL onTopOfNavigationControllerStack;

@property (nonatomic,strong, readwrite) UIWebView *webView;
@property (nonatomic,readonly) UINavigationBar *navigationBar;
@property (nonatomic,readonly) UIToolbar *toolbar;
@property (nonatomic,strong)   SQCWebLoadingView *loadingBarView;
@property (nonatomic,strong)   UIImageView *webViewRotationSnapshot;

@property (nonatomic,strong) CAGradientLayer *gradientLayer;


@property (nonatomic,strong) UIButton *backButton;
@property (nonatomic,strong) UIButton *forwardButton;
@property (nonatomic,strong) UIButton *reloadStopButton;
@property (nonatomic,strong) UIButton *actionButton;
@property (nonatomic,strong) UIView   *buttonsContainerView;

@property (nonatomic,assign) CGFloat buttonWidth;
@property (nonatomic,assign) CGFloat buttonSpacing;

@property (nonatomic,strong) UIImage *reloadIcon;
@property (nonatomic,strong) UIImage *stopIcon;


@property (nonatomic,strong) NSMutableDictionary *buttonThemeAttributes;


#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic,strong) UIPopoverController *sharingPopoverController;
#pragma GCC diagnostic pop


@property (nonatomic,assign) BOOL hideToolbarOnClose;


@property (nonatomic,assign) BOOL hideNavBarOnClose;


- (void)setup;

- (NSURL *)cleanURL:(NSURL *)url;


- (void)setUpNavigationButtons;
- (UIView *)containerViewWithNavigationButtons;

- (void)refreshButtonsState;

- (void)backButtonTapped:(id)sender;
- (void)forwardButtonTapped:(id)sender;
- (void)reloadStopButtonTapped:(id)sender;
- (void)actionButtonTapped:(id)sender;
- (void)doneButtonTapped:(id)sender;

- (void)copyURLToClipboard;
- (void)openInBrowser;
- (void)openMailDialog;
- (void)openMessageDialog;

- (void)resetLoadProgress;
- (void)startLoadProgress;
- (void)incrementLoadProgress;
- (void)finishLoadProgress;
- (void)setLoadingProgress:(CGFloat)loadingProgress;
- (void)handleLoadRequestCompletion;
- (CGRect)rectForVisibleRegionOfWebViewAnimatingToOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
- (void)setUpWebViewForRotationToOrientation:(UIInterfaceOrientation)toOrientation withDuration:(NSTimeInterval)duration;
- (void)animateWebViewRotationToOrientation:(UIInterfaceOrientation)toOrientation withDuration:(NSTimeInterval)duration;
- (void)restoreWebViewFromRotationFromOrientation:(UIInterfaceOrientation)fromOrientation;

- (UIView *)webViewContentView;
- (BOOL)webViewPageWidthIsDynamic;
- (UIColor *)webViewPageBackgroundColor;

@end


#pragma mark -
#pragma mark Class Implementation
@implementation SQCWebViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
        [self setup];
    
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
        [self setup];
    
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
{
    if (self = [super init])
        _url = [self cleanURL:url];
    
    return self;
}

- (instancetype)initWithURLString:(NSString *)urlString
{
    return [self initWithURL:[NSURL URLWithString:urlString]];
}

- (NSURL *)cleanURL:(NSURL *)url
{
    if (url.scheme.length == 0) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", [url absoluteString]]];
    }
    
    return url;
}

- (void)setup
{
    _showActionButton = YES;
    _showDoneButton   = YES;
    _buttonSpacing    = (IPAD == NO) ? NAVIGATION_BUTTON_SPACING : NAVIGATION_BUTTON_SPACING_IPAD;
    _buttonWidth      = NAVIGATION_BUTTON_WIDTH;
    _showLoadingBar   = YES;
    _showUrlWhileLoading = YES;
    _showPageTitles   = NO;
    
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    
    self.urlRequest = [[NSMutableURLRequest alloc] init];
}

- (void)loadView
{
    
    self.loadingBarTintColor = [UIColor colorWithRed:13/255.0 green:185/255.0 blue:94/255.0 alpha:1.0];
    
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    view.backgroundColor = (self.hideWebViewBoundaries ? [UIColor whiteColor] : BACKGROUND_COLOR);
#pragma clang diagnostic pop
    view.opaque = YES;
    view.clipsToBounds = YES;
    self.view = view;
    
    if (MINIMAL_UI == NO) {
        self.gradientLayer = [CAGradientLayer layer];
        self.gradientLayer.colors = @[(id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor],(id)[[UIColor colorWithWhite:0.0f alpha:0.35f] CGColor]];
        self.gradientLayer.frame = self.view.bounds;
        [self.view.layer addSublayer:self.gradientLayer];
    }
    
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.delegate = self;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.scalesPageToFit = YES;
    self.webView.contentMode = UIViewContentModeRedraw;
    self.webView.opaque = YES;
    [self.view addSubview:self.webView];
    
    CGFloat y = self.webView.scrollView.contentInset.top;
    self.loadingBarView = [[SQCWebLoadingView alloc] initWithFrame:CGRectMake(0, y, CGRectGetWidth(self.view.frame), LOADING_BAR_HEIGHT)];
    self.loadingBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (self.loadingBarTintColor && [self.loadingBarView respondsToSelector:@selector(setTintColor:)])
        self.loadingBarView.tintColor = self.loadingBarTintColor;
    
    if (MINIMAL_UI && self.loadingBarTintColor == nil) {
        if (self.navigationController && self.navigationController.view.window.tintColor)
            self.loadingBarView.backgroundColor = self.navigationController.view.window.tintColor;
        else if (self.view.window.tintColor)
            self.loadingBarView.backgroundColor = self.view.window.tintColor;
        else
            self.loadingBarView.backgroundColor = DEFAULT_BAR_TINT_COLOR;
    }
    else if (self.loadingBarTintColor)
        self.loadingBarView.backgroundColor = self.loadingBarTintColor;
    else
        self.loadingBarView.backgroundColor = DEFAULT_BAR_TINT_COLOR;
    
    if (MINIMAL_UI == NO) {
        CAGradientLayer *loadingBarGradientLayer = [CAGradientLayer layer];
        loadingBarGradientLayer.colors = @[(id)[[UIColor colorWithWhite:0.0f alpha:0.25f] CGColor],(id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor]];
        loadingBarGradientLayer.frame = self.loadingBarView.bounds;
        [self.loadingBarView.layer addSublayer:loadingBarGradientLayer];
    }
    
    if (self.navigationButtonsHidden == NO)
        [self setUpNavigationButtons];
}

- (void)setUpNavigationButtons
{
    CGRect buttonFrame = CGRectZero;
    buttonFrame.size = NAVIGATION_BUTTON_SIZE;
    
    UIButtonType buttonType = UIButtonTypeCustom;
    if (MINIMAL_UI)
        buttonType = UIButtonTypeSystem;
    
    UIImage *backButtonImage = [UIImage SQCWebViewControllerIcon_backButtonWithAttributes:self.buttonThemeAttributes];
    if (self.backButton == nil) {
        self.backButton = [UIButton buttonWithType:buttonType];
        [self.backButton setFrame:buttonFrame];
        [self.backButton setShowsTouchWhenHighlighted:YES];
    }
    [self.backButton setImage:backButtonImage forState:UIControlStateNormal];
    
    UIImage *forwardButtonImage = [UIImage SQCWebViewControllerIcon_forwardButtonWithAttributes:self.buttonThemeAttributes];
    if (self.forwardButton == nil) {
        self.forwardButton  = [UIButton buttonWithType:buttonType];
        [self.forwardButton setFrame:buttonFrame];
        [self.forwardButton setShowsTouchWhenHighlighted:YES];
    }
    [self.forwardButton setImage:forwardButtonImage forState:UIControlStateNormal];
    
    if (self.reloadStopButton == nil) {
        self.reloadStopButton = [UIButton buttonWithType:buttonType];
        [self.reloadStopButton setFrame:buttonFrame];
        [self.reloadStopButton setShowsTouchWhenHighlighted:YES];
    }
    
    self.reloadIcon = [UIImage SQCWebViewControllerIcon_refreshButtonWithAttributes:self.buttonThemeAttributes];
    self.stopIcon   = [UIImage SQCWebViewControllerIcon_stopButtonWithAttributes:self.buttonThemeAttributes];
    [self.reloadStopButton setImage:self.reloadIcon forState:UIControlStateNormal];
    
    if (self.showActionButton) {
        if (self.actionButton == nil) {
            self.actionButton = [UIButton buttonWithType:buttonType];
            [self.actionButton setFrame:buttonFrame];
            [self.actionButton setShowsTouchWhenHighlighted:YES];
        }
        
        [self.actionButton setImage:[UIImage SQCWebViewControllerIcon_actionButtonWithAttributes:self.buttonThemeAttributes] forState:UIControlStateNormal];
    }
}

- (UIView *)containerViewWithNavigationButtons
{
    CGRect buttonFrame = CGRectZero;
    buttonFrame.size = NAVIGATION_BUTTON_SIZE;
    
    UIView *iconsContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, self.buttonWidth)];
    iconsContainerView.backgroundColor = [UIColor clearColor];
    
    self.backButton.frame = buttonFrame;
    [iconsContainerView addSubview:self.backButton];
    
    self.forwardButton.frame = buttonFrame;
    [iconsContainerView addSubview:self.forwardButton];
    
    self.reloadStopButton.frame = buttonFrame;
    [iconsContainerView addSubview:self.reloadStopButton];
    
    if (self.showActionButton) {
        self.actionButton.frame = buttonFrame;
        [iconsContainerView addSubview:self.actionButton];
    }
    
    NSUInteger count = iconsContainerView.subviews.count;
    if(count){
        CGRect newFrame = iconsContainerView.frame;
        CGFloat newWidth = newFrame.size.width = (self.buttonWidth*count)+(self.buttonSpacing*count-1);
        iconsContainerView.frame = newFrame;
        [iconsContainerView.subviews enumerateObjectsUsingBlock:^(UIView *subview, NSUInteger index, BOOL *stop) {
            subview.center = CGPointMake((newWidth/count)*index + (self.buttonSpacing + self.buttonWidth)/2, subview.center.y);
        }];
    }
    return iconsContainerView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.navigationController) {
        self.hideToolbarOnClose = self.navigationController.toolbarHidden;
        self.hideNavBarOnClose  = self.navigationBar.hidden;
    }
    
    if (MINIMAL_UI == NO) {
        for (UIView *view in self.webView.scrollView.subviews) {
            if ([view isKindOfClass:[UIImageView class]] && CGRectGetWidth(view.frame) == CGRectGetWidth(self.view.frame) && CGRectGetMinY(view.frame) > 0.0f + FLT_EPSILON)
                [view removeFromSuperview];
            else if ([view isKindOfClass:[UIImageView class]] && self.hideWebViewBoundaries)
                [view setHidden:YES];
        }
    }
    
    if (self.hideWebViewBoundaries)
        self.gradientLayer.hidden = YES;
    
    self.buttonsContainerView = [self containerViewWithNavigationButtons];
    if (IPAD) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.buttonsContainerView];
    }
    else {
        NSArray *items = @[BLANK_BARBUTTONITEM, [[UIBarButtonItem alloc] initWithCustomView:self.buttonsContainerView], BLANK_BARBUTTONITEM];
        self.toolbarItems = items;
    }
    
    if (MINIMAL_UI)
        self.buttonsContainerView.tintColor = self.buttonTintColor;
    
    if (self.showDoneButton && self.beingPresentedModally && !self.onTopOfNavigationControllerStack) {
        UIBarButtonItem *doneButton = nil;
        
        if (self.doneButtonTitle) {
            doneButton = [[UIBarButtonItem alloc] initWithTitle:self.doneButtonTitle style:UIBarButtonItemStyleDone
                                                         target:self
                                                         action:@selector(doneButtonTapped:)];
        }
        else {
            doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                       target:self
                                                                       action:@selector(doneButtonTapped:)];
        }
        
        if (IPAD)
            self.navigationItem.leftBarButtonItem = doneButton;
        else
            self.navigationItem.rightBarButtonItem = doneButton;
    }
    
    [self.backButton        addTarget:self action:@selector(backButtonTapped:)          forControlEvents:UIControlEventTouchUpInside];
    [self.forwardButton     addTarget:self action:@selector(forwardButtonTapped:)       forControlEvents:UIControlEventTouchUpInside];
    [self.reloadStopButton  addTarget:self action:@selector(reloadStopButtonTapped:)    forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton      addTarget:self action:@selector(actionButtonTapped:)        forControlEvents:UIControlEventTouchUpInside];
    self.view.backgroundColor = [UIColor colorWithRed:237/255.0 green:237/255.0 blue:237/255.0 alpha:1.0];
    
    UIBarButtonItem *leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"backgreen"] style:UIBarButtonItemStylePlain target:self action:@selector(backMethod)];
    self.navigationItem.leftBarButtonItem = leftBarButtonItem;
    
}

- (void)backMethod
{
    
    [self.navigationController popViewControllerAnimated:YES];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.navigationController) {
        if (IPAD == NO) {
            if (self.beingPresentedModally == NO) {
                [self.navigationController setToolbarHidden:self.navigationButtonsHidden animated:animated];
                [self.navigationController setNavigationBarHidden:NO animated:animated];
            }
            else {
                self.navigationController.toolbarHidden = self.navigationButtonsHidden;
            }
        }
        else {
            [self.navigationController setNavigationBarHidden:NO animated:animated];
            [self.navigationController setToolbarHidden:YES animated:animated];
        }
    }
    
    self.gradientLayer.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.url && self.webView.request == nil)
    {
        [self.urlRequest setURL:self.url];
        [self.webView loadRequest:self.urlRequest];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.beingPresentedModally == NO) {
        [self.navigationController setToolbarHidden:self.hideToolbarOnClose animated:animated];
        [self.navigationController setNavigationBarHidden:self.hideNavBarOnClose animated:animated];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
}

- (BOOL)shouldAutorotate
{
    if (self.webViewRotationSnapshot)
        return NO;
    
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (self.webViewRotationSnapshot)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self setUpWebViewForRotationToOrientation:toInterfaceOrientation withDuration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.gradientLayer.frame = self.view.bounds;
    
    self.loadingBarView.frame = ({
        CGRect frame = self.loadingBarView.frame;
        frame.origin.y = self.webView.scrollView.contentInset.top;
        frame.origin.x = -CGRectGetWidth(self.loadingBarView.frame) + (CGRectGetWidth(self.view.bounds) * _loadingProgressState.loadingProgress);
        frame;
    });
    
    [self animateWebViewRotationToOrientation:toInterfaceOrientation withDuration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self restoreWebViewFromRotationFromOrientation:fromInterfaceOrientation];
}

#pragma mark -
#pragma mark State Tracking
- (BOOL)beingPresentedModally
{
    if (self.navigationController && self.navigationController.presentingViewController)
        return ([self.navigationController.viewControllers indexOfObject:self] == 0);
    else
        return ([self presentingViewController] != nil);
    
    return NO;
}

- (BOOL)onTopOfNavigationControllerStack
{
    if (self.navigationController == nil)
        return NO;
    
    if ([self.navigationController.viewControllers count] && [self.navigationController.viewControllers indexOfObject:self] > 0)
        return YES;
    
    return NO;
}

#pragma mark -
#pragma mark Manual Property Accessors
- (void)setUrl:(NSURL *)url
{
    if (self.url == url)
        return;
    
    _url = [self cleanURL:url];
    
    if (self.webView.loading)
        [self.webView stopLoading];
    
    [self.urlRequest setURL:self.url];
    [self.webView loadRequest:self.urlRequest];
}

- (void)setLoadingBarTintColor:(UIColor *)loadingBarTintColor
{
    if (loadingBarTintColor == self.loadingBarTintColor)
        return;
    
    _loadingBarTintColor = loadingBarTintColor;
    
    self.loadingBarView.backgroundColor = self.loadingBarTintColor;
    
    if ([self.loadingBarView respondsToSelector:@selector(setTintColor:)])
        self.loadingBarView.tintColor = self.loadingBarTintColor;
}

- (UINavigationBar *)navigationBar
{
    if (self.navigationController)
        return self.navigationController.navigationBar;
    
    return nil;
}

- (UIToolbar *)toolbar
{
    if (IPAD)
        return nil;
    
    if (self.navigationController)
        return self.navigationController.toolbar;
    
    return nil;
}

- (void)setNavigationButtonsHidden:(BOOL)navigationButtonsHidden
{
    if (navigationButtonsHidden == _navigationButtonsHidden)
        return;
    
    _navigationButtonsHidden = navigationButtonsHidden;
    
    if (_navigationButtonsHidden == NO)
    {
        [self setUpNavigationButtons];
        UIView *iconsContainerView = [self containerViewWithNavigationButtons];
        if (IPAD) {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:iconsContainerView];
        }
        else {
            NSArray *items = @[BLANK_BARBUTTONITEM, [[UIBarButtonItem alloc] initWithCustomView:iconsContainerView], BLANK_BARBUTTONITEM];
            self.toolbarItems = items;
        }
    }
    else
    {
        if (IPAD) {
            self.navigationItem.rightBarButtonItem  = nil;
        }
        else {
            self.navigationController.toolbarItems = nil;
            self.navigationController.toolbarHidden = YES;
        }
        
        self.backButton = nil;
        self.forwardButton = nil;
        self.reloadIcon = nil;
        self.stopIcon = nil;
        self.reloadStopButton = nil;
        self.actionButton = nil;
    }
}

- (void)setButtonTintColor:(UIColor *)buttonTintColor
{
    if (buttonTintColor == _buttonTintColor)
        return;
    
    _buttonTintColor = buttonTintColor;
    
    if (MINIMAL_UI) {
        self.buttonsContainerView.tintColor = _buttonTintColor;
    }
    else {
        if (self.buttonThemeAttributes == nil)
            self.buttonThemeAttributes = [NSMutableDictionary dictionary];
        
        self.buttonThemeAttributes[SQCWebViewControllerButtonTintColor] = _buttonTintColor;
        [self setUpNavigationButtons];
    }
}

- (void)setButtonBevelOpacity:(CGFloat)buttonBevelOpacity
{
    if (buttonBevelOpacity == _buttonBevelOpacity)
        return;
    
    _buttonBevelOpacity = buttonBevelOpacity;
    
    if (self.buttonThemeAttributes == nil)
        self.buttonThemeAttributes = [NSMutableDictionary dictionary];
    
    self.buttonThemeAttributes[SQCWebViewControllerButtonBevelOpacity] = @(_buttonBevelOpacity);
    [self setUpNavigationButtons];
}

#pragma mark -
#pragma mark WebView Delegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    BOOL shouldStart = YES;
    
    if (self.shouldStartLoadRequestHandler)
        shouldStart = self.shouldStartLoadRequestHandler(request, navigationType);
    
    
    if ([request.URL.absoluteString isEqualToString:SQCCompleteRPCURL] || !shouldStart) {
        [self finishLoadProgress];
        return NO;
    }
    
    BOOL isFragmentJump = NO;
    if (request.URL.fragment)
    {
        NSString *nonFragmentURL = [request.URL.absoluteString stringByReplacingOccurrencesOfString:[@"#" stringByAppendingString:request.URL.fragment] withString:@""];
        isFragmentJump = [nonFragmentURL isEqualToString:webView.request.URL.absoluteString];
    }
    
    BOOL isTopLevelNavigation = [request.mainDocumentURL isEqual:request.URL];
    BOOL isHTTP = [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"];
    if (shouldStart && !isFragmentJump && isHTTP && isTopLevelNavigation && navigationType != UIWebViewNavigationTypeBackForward)
    {
        _url = [request URL];
        [self resetLoadProgress];
    }
    
    return shouldStart;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    _loadingProgressState.loadingCount++;
    
    _loadingProgressState.maxLoadCount = MAX(_loadingProgressState.maxLoadCount, _loadingProgressState.loadingCount);
    
    [self startLoadProgress];
    
    [self refreshButtonsState];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self handleLoadRequestCompletion];
    [self refreshButtonsState];
    
    if (self.showPageTitles)
        self.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.loadingBarView.alpha = 0.0f;
    [self handleLoadRequestCompletion];
    [self refreshButtonsState];
}

#pragma mark -
#pragma mark Button Callbacks
- (void)backButtonTapped:(id)sender
{
    [self.webView goBack];
    [self refreshButtonsState];
}

- (void)forwardButtonTapped:(id)sender
{
    [self.webView goForward];
    [self refreshButtonsState];
}

- (void)reloadStopButtonTapped:(id)sender
{
    [self.webView stopLoading];
    
    if (self.webView.isLoading) {
        self.loadingBarView.alpha = 0.0f;
    }
    else {
        if (self.webView.request.URL.absoluteString.length == 0 && self.url)
        {
            [self.webView loadRequest:self.urlRequest];
        }
        else {
            [self.webView reload];
        }
    }
    
    [self refreshButtonsState];
}

- (void)doneButtonTapped:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:self.modalCompletionHandler];
}

#pragma mark -
#pragma mark Action Item Event Handlers
- (void)actionButtonTapped:(id)sender
{
    if (NSClassFromString(@"UIPresentationController")) {
        NSArray *browserActivities = @[[SQCActivitySafari new]];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[self.url] applicationActivities:browserActivities];
        activityViewController.modalPresentationStyle = UIModalPresentationPopover;
        activityViewController.popoverPresentationController.sourceRect = self.actionButton.frame;
        activityViewController.popoverPresentationController.sourceView = self.actionButton.superview;
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
    else if (NSClassFromString(@"UIActivityViewController"))
    {
        NSArray *browserActivities = @[[SQCActivitySafari new]];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[self.url] applicationActivities:browserActivities];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
            [self presentViewController:activityViewController animated:YES completion:nil];
        }
        else
        {
            if (self.sharingPopoverController)
            {
                [self.sharingPopoverController dismissPopoverAnimated:NO];
                self.sharingPopoverController = nil;
            }
            
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            
            self.sharingPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
            self.sharingPopoverController.delegate = self;
            [self.sharingPopoverController presentPopoverFromRect:self.actionButton.frame inView:self.actionButton.superview permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            
#pragma GCC diagnostic pop
        }
    }
    else
    {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                 delegate:self
                                                        cancelButtonTitle:nil
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:@"复制链接", nil];
        
        NSInteger numberOfButtons = 1;
        
        
        NSString *browserMessage = @"用 Safari 打开";
        
        [actionSheet addButtonWithTitle:browserMessage];
        numberOfButtons++;
        
        if ([MFMailComposeViewController canSendMail]) {
            [actionSheet addButtonWithTitle:@"邮件"];
            numberOfButtons++;
        }
        
        if ([MFMessageComposeViewController canSendText]) {
            [actionSheet addButtonWithTitle:@"短信"];
            numberOfButtons++;
        }
        
        
        if (IPAD == NO) {
            [actionSheet addButtonWithTitle:@"取消"];
            [actionSheet setCancelButtonIndex:numberOfButtons];
            [actionSheet showInView:self.view];
        }
        else {
            [actionSheet showFromRect:[(UIView *)sender frame] inView:[(UIView *)sender superview] animated:YES];
        }
        
#pragma clang diagnostic pop
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
            [self copyURLToClipboard];
            break;
        case 1:
            [self openInBrowser];
            break;
        case 2:
        {
            if ([MFMailComposeViewController canSendMail])
                [self openMailDialog];
            else if ([MFMessageComposeViewController canSendText])
                [self openMessageDialog];
            
        }
            break;
        case 3:
        {
            if ([MFMessageComposeViewController canSendText])
                [self openMessageDialog];
            
        }
            break;
        case 4:
            
        default:
            break;
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.sharingPopoverController = nil;
}

- (void)copyURLToClipboard
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.url.absoluteString;
}

- (void)openInBrowser
{
    NSURL *inputURL = self.webView.request.URL;
    
    
    [[UIApplication sharedApplication] openURL:inputURL];
}

- (void)openMailDialog
{
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    mailViewController.mailComposeDelegate = self;
    [mailViewController setMessageBody:[self.url absoluteString] isHTML:NO];
    [self presentViewController:mailViewController animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openMessageDialog
{
    MFMessageComposeViewController *messageViewController = [[MFMessageComposeViewController alloc] init];
    messageViewController.messageComposeDelegate = self;
    [messageViewController setBody:[self.url absoluteString]];
    [self presentViewController:messageViewController animated:YES completion:nil];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark -
#pragma mark Page Load Progress Tracking Handlers
- (void)resetLoadProgress
{
    memset(&_loadingProgressState, 0, sizeof(_loadingProgressState));
    [self setLoadingProgress:0.0f];
}

- (void)startLoadProgress
{
    if (self.webView.isLoading == NO)
        return;
    
    if (_loadingProgressState.loadingProgress < kInitialProgressValue)
    {
        CGRect frame = self.loadingBarView.frame;
        frame.size.width = CGRectGetWidth(self.view.bounds);
        frame.origin.x = -frame.size.width;
        frame.origin.y = self.webView.scrollView.contentInset.top;
        self.loadingBarView.frame = frame;
        self.loadingBarView.alpha = 1.0f;
        
        if (self.showLoadingBar)
            [self.view insertSubview:self.loadingBarView aboveSubview:self.navigationBar];
        
        [self setLoadingProgress:kInitialProgressValue];
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
        if (self.showPageTitles && self.showUrlWhileLoading) {
            NSString *url = [self.url absoluteString];
            url = [url stringByReplacingOccurrencesOfString:@"http://" withString:@""];
            url = [url stringByReplacingOccurrencesOfString:@"https://" withString:@""];
            self.title = url;
        }
        
        if (self.reloadStopButton)
            [self.reloadStopButton setImage:self.stopIcon forState:UIControlStateNormal];
    }
}

- (void)incrementLoadProgress
{
    float progress          = _loadingProgressState.loadingProgress;
    float maxProgress       = _loadingProgressState.interactive ? kAfterInteractiveMaxProgressValue : kBeforeInteractiveMaxProgressValue;
    float remainingPercent  = (float)_loadingProgressState.loadingCount / (float)_loadingProgressState.maxLoadCount;
    float increment         = (maxProgress - progress) * remainingPercent;
    progress                = fmin((progress+increment), maxProgress);
    
    [self setLoadingProgress:progress];
}

- (void)finishLoadProgress
{
    [self refreshButtonsState];
    [self setLoadingProgress:1.0f];
    
    if (self.showPageTitles)
        self.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    
    if (self.reloadStopButton)
        [self.reloadStopButton setImage:self.reloadIcon forState:UIControlStateNormal];
}

- (void)setLoadingProgress:(CGFloat)loadingProgress
{
    if (loadingProgress > _loadingProgressState.loadingProgress)
    {
        _loadingProgressState.loadingProgress = loadingProgress;
        
        if (self.showLoadingBar)
        {
            CGRect frame = self.loadingBarView.frame;
            frame.origin.x = -CGRectGetWidth(self.loadingBarView.frame) + (CGRectGetWidth(self.view.bounds) * _loadingProgressState.loadingProgress);
            
            [UIView animateWithDuration:1.0f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.loadingBarView.frame = frame;
            } completion:^(BOOL finished) {
                
                if (loadingProgress >= 1.0f - FLT_EPSILON)
                {
                    [UIView animateWithDuration:0.5f animations:^{
                        self.loadingBarView.alpha = 0.0f;
                    }];
                }
            }];
        }
    }
    else if (loadingProgress == 0)
    {
        _loadingProgressState.loadingProgress = loadingProgress;
        if (self.showLoadingBar)
        {
            CGRect frame = self.loadingBarView.frame;
            frame.origin.x = -CGRectGetWidth(self.loadingBarView.frame);
            self.loadingBarView.frame = frame;
        }
    }
}

- (void)handleLoadRequestCompletion
{
    _loadingProgressState.loadingCount--;
    
    [self incrementLoadProgress];
    
    NSString *readyState = [self.webView stringByEvaluatingJavaScriptFromString:@"document.readyState"];
    
    BOOL interactive = [readyState isEqualToString:@"interactive"];
    if (interactive)
    {
        _loadingProgressState.interactive = YES;
        
        NSString *waitForCompleteJS = [NSString stringWithFormat:   @"window.addEventListener('load',function() { "
                                       @"var iframe = document.createElement('iframe');"
                                       @"iframe.style.display = 'none';"
                                       @"iframe.src = '%@';"
                                       @"document.body.appendChild(iframe);"
                                       @"}, false);", SQCCompleteRPCURL];
        
        [self.webView stringByEvaluatingJavaScriptFromString:waitForCompleteJS];
        
        if (self.showPageTitles)
            self.title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
        
        if (self.hideWebViewBoundaries)
            self.view.backgroundColor = [self webViewPageBackgroundColor];
        
        if (self.disableContextualPopupMenu)
            [self.webView stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
    }
    
    BOOL isNotRedirect = self.url && [self.url isEqual:self.webView.request.URL];
    BOOL complete = [readyState isEqualToString:@"complete"];
    if (complete && isNotRedirect)
        [self finishLoadProgress];
}

#pragma mark -
#pragma mark Button State Handling
- (void)refreshButtonsState
{
    if (self.webView.canGoBack)
        [self.backButton setEnabled:YES];
    else
        [self.backButton setEnabled:NO];
    
    if (self.webView.canGoForward)
        [self.forwardButton setEnabled:YES];
    else
        [self.forwardButton setEnabled:NO];
    
    if (self.webView.isLoading) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self.reloadStopButton setImage:self.stopIcon forState:UIControlStateNormal];
    }
    else {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [self.reloadStopButton setImage:self.reloadIcon forState:UIControlStateNormal];
    }
}

#pragma mark -
#pragma mark UIWebView Attrbutes
- (UIView *)webViewContentView
{
    for (UIView *view in self.webView.scrollView.subviews)
    {
        if ([NSStringFromClass([view class]) rangeOfString:@"WebBrowser"].location != NSNotFound)
            return view;
    }
    
    return nil;
}

- (BOOL)webViewPageWidthIsDynamic
{
    NSString *metaDataQuery =   @"(function() {"
    @"var metaTags = document.getElementsByTagName('meta');"
    @"for (i=0; i<metaTags.length; i++) {"
    @"if (metaTags[i].name=='viewport') {"
    @"return metaTags[i].getAttribute('content');"
    @"}"
    @"}"
    @"})()";
    
    NSString *pageViewPortContent = [self.webView stringByEvaluatingJavaScriptFromString:metaDataQuery];
    if ([pageViewPortContent length] == 0)
        return NO;
    
    pageViewPortContent = [[pageViewPortContent stringByReplacingOccurrencesOfString:@" " withString:@""] lowercaseString];
    
    if ([pageViewPortContent rangeOfString:@"maximum-scale=1"].location != NSNotFound)
        return YES;
    
    if ([pageViewPortContent rangeOfString:@"user-scalable=no"].location != NSNotFound)
        return YES;
    
    if ([pageViewPortContent rangeOfString:@"width=device-width"].location != NSNotFound)
        return YES;
    
    if ([pageViewPortContent rangeOfString:@"initial-scale=1"].location != NSNotFound)
        return YES;
    
    return NO;
}

- (UIColor *)webViewPageBackgroundColor
{
    NSString *rgbString = [self.webView stringByEvaluatingJavaScriptFromString:@"window.getComputedStyle(document.body,null).getPropertyValue('background-color');"];
    
    if ([rgbString length] == 0 || [rgbString rangeOfString:@"rgb"].location == NSNotFound)
        return [UIColor whiteColor];
    
    rgbString = [rgbString stringByReplacingOccurrencesOfString:@"rgba" withString:@""];
    
    rgbString = [rgbString stringByReplacingOccurrencesOfString:@"rgb" withString:@""];
    
    rgbString = [rgbString stringByReplacingOccurrencesOfString:@"(" withString:@""];
    rgbString = [rgbString stringByReplacingOccurrencesOfString:@")" withString:@""];
    
    rgbString = [rgbString stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSArray *componenets = [rgbString componentsSeparatedByString:@","];
    
    CGFloat red, green, blue, alpha = 1.0f;
    
    if ([componenets count] < 3 || ([componenets count] >= 4 && [[componenets objectAtIndex:3] integerValue] == 0))
        return [UIColor whiteColor];
    
    red     = (CGFloat)[[componenets objectAtIndex:0] integerValue] / 255.0f;
    green   = (CGFloat)[[componenets objectAtIndex:1] integerValue] / 255.0f;
    blue    = (CGFloat)[[componenets objectAtIndex:2] integerValue] / 255.0f;
    
    if ([componenets count] >= 4)
        alpha = (CGFloat)[[componenets objectAtIndex:3] integerValue] / 255.0f;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

#pragma mark -
#pragma mark UIWebView Interface Rotation Handler
- (CGRect)rectForVisibleRegionOfWebViewAnimatingToOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    CGRect  rect            = CGRectZero;
    CGPoint contentOffset   = self.webView.scrollView.contentOffset;
    CGSize  webViewSize     = self.webView.bounds.size;
    CGSize  contentSize     = self.webView.scrollView.contentSize;
    CGFloat topInset        = self.webView.scrollView.contentInset.top;
    
    if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
    {
        rect.origin = contentOffset;
        rect.size   = webViewSize;
        
        if (contentOffset.y < 0.0f + FLT_EPSILON) {
            rect.origin.y = 0.0f;
            rect.size.height -= MAX(contentOffset.y + topInset, 0);
        }
        else if (contentOffset.y + CGRectGetHeight(rect) > contentSize.height) {
            rect.size.height = contentSize.height - contentOffset.y;
        }
    }
    else
    {
        CGFloat heightInPortraitMode = webViewSize.width;
        if (MINIMAL_UI == NO) {
            if (self.navigationBar)
                heightInPortraitMode -= 44.0f;
            
            if (self.toolbar)
                heightInPortraitMode -= 44.0f;
            
            if ([UIApplication sharedApplication].statusBarHidden == NO)
                heightInPortraitMode -= [[UIApplication sharedApplication] statusBarFrame].size.width;
        }
        
        CGSize  contentSize   = self.webView.scrollView.contentSize;
        
        if ([self webViewPageWidthIsDynamic])
        {
            rect.origin = contentOffset;
            if (contentOffset.y + heightInPortraitMode > contentSize.height )
                rect.origin.y = contentSize.height - heightInPortraitMode;
            
            rect.size.width = webViewSize.width;
            rect.size.height = heightInPortraitMode;
        }
        else
        {
            
            rect.origin = contentOffset;
            
            CGFloat portraitWidth = webViewSize.height;
            if (MINIMAL_UI == NO) {
                if (self.navigationBar)
                    portraitWidth += CGRectGetHeight(self.navigationBar.frame);
                
                if (self.toolbar)
                    portraitWidth += CGRectGetHeight(self.toolbar.frame);
                
                if ([UIApplication sharedApplication].statusBarHidden == NO)
                    heightInPortraitMode -= [[UIApplication sharedApplication] statusBarFrame].size.width;
            }
            
            CGFloat scaledHeight = heightInPortraitMode * (webViewSize.width / portraitWidth);
            
            rect.origin.y = (contentOffset.y+(webViewSize.height*0.5f)) - (scaledHeight*0.5f);
            
            if (rect.origin.y < 0)
                rect.origin.y = 0;
            else if (rect.origin.y + scaledHeight > contentSize.height)
                rect.origin.y = contentSize.height - scaledHeight;
            
            rect.size.width = webViewSize.width;
            rect.size.height = scaledHeight;
        }
    }
    
    return rect;
}

- (void)setUpWebViewForRotationToOrientation:(UIInterfaceOrientation)toOrientation withDuration:(NSTimeInterval)duration
{
    
    if (IPAD && self.modalPresentationStyle == UIModalPresentationFormSheet)
        return;
    
    if (self.webViewRotationSnapshot)
    {
        [self.webViewRotationSnapshot removeFromSuperview];
        self.webViewRotationSnapshot = nil;
    }
    
    _webViewState.frameSize         = self.webView.frame.size;
    _webViewState.contentSize       = self.webView.scrollView.contentSize;
    _webViewState.zoomScale         = self.webView.scrollView.zoomScale;
    _webViewState.contentOffset     = self.webView.scrollView.contentOffset;
    _webViewState.minimumZoomScale  = self.webView.scrollView.minimumZoomScale;
    _webViewState.maximumZoomScale  = self.webView.scrollView.maximumZoomScale;
    _webViewState.topEdgeInset      = self.webView.scrollView.contentInset.top;
    _webViewState.bottomEdgeInset   = self.webView.scrollView.contentInset.bottom;
    
    UIView  *webContentView         = [self webViewContentView];
    UIColor *pageBackgroundColor    = [self webViewPageBackgroundColor];
    UIColor *webViewBackgroundColor = [self view].backgroundColor;
    CGRect  renderBounds            = [self rectForVisibleRegionOfWebViewAnimatingToOrientation:toOrientation];
    
    CGFloat scale = 1.0f;
    if (UIInterfaceOrientationIsLandscape(toOrientation))
        scale = 0.0f;
    
    UIGraphicsBeginImageContextWithOptions(renderBounds.size, YES, scale);
    {
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextSetFillColorWithColor(context, webViewBackgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0,0,CGRectGetWidth(renderBounds),CGRectGetHeight(renderBounds)));
        
        CGContextTranslateCTM(context, -renderBounds.origin.x, -renderBounds.origin.y);
        
        [webContentView.layer renderInContext:context];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        
        self.webViewRotationSnapshot = [[UIImageView alloc] initWithImage:image];
    }
    UIGraphicsEndImageContext();
    
    CGRect frame = (CGRect){CGPointZero, renderBounds.size};
    
    if (UIInterfaceOrientationIsLandscape(toOrientation))
    {
        if ([self webViewPageWidthIsDynamic])
        {
            self.webViewRotationSnapshot.backgroundColor = pageBackgroundColor;
            self.webViewRotationSnapshot.contentMode = UIViewContentModeTop;
        }
        else {
            self.webViewRotationSnapshot.contentMode = UIViewContentModeScaleAspectFill;
        }
        
        if (_webViewState.contentOffset.y < 0.0f) {
            frame.origin.y = _webViewState.topEdgeInset - (_webViewState.topEdgeInset + _webViewState.contentOffset.y);
            frame.origin.y = MAX(0, frame.origin.y);
        }
    }
    else
    {
        if ([self webViewPageWidthIsDynamic])
        {
            self.webViewRotationSnapshot.backgroundColor = pageBackgroundColor;
            
            CGFloat heightInPortraitMode = CGRectGetWidth(self.webView.frame);
            if (self.webView.scrollView.contentOffset.y + heightInPortraitMode > self.webView.scrollView.contentSize.height )
                self.webViewRotationSnapshot.contentMode = UIViewContentModeBottomLeft;
            else
                self.webViewRotationSnapshot.contentMode = UIViewContentModeTopLeft;
        }
        else
        {
            self.webViewRotationSnapshot.contentMode = UIViewContentModeScaleAspectFill;
            
            frame.size  = self.webViewRotationSnapshot.image.size;
            
            if ((_webViewState.contentOffset.y + _webViewState.topEdgeInset) > FLT_EPSILON) {
                
                CGFloat webViewMidPoint  = _webViewState.contentOffset.y + (_webViewState.frameSize.height * 0.5f);
                CGFloat topContentOffset = webViewMidPoint - (renderBounds.size.height * 0.5f);
                CGFloat bottomContentOffset = webViewMidPoint + (renderBounds.size.height * 0.5f);
                
                if (topContentOffset < -_webViewState.topEdgeInset) {
                    frame.origin.y = -_webViewState.contentOffset.y;
                }
                else if (bottomContentOffset > _webViewState.contentSize.height) {
                    CGFloat bottomOfScrollContentView = _webViewState.contentSize.height - (_webViewState.contentOffset.y + _webViewState.frameSize.height);
                    frame.origin.y = (_webViewState.frameSize.height + bottomOfScrollContentView) - CGRectGetHeight(frame);
                }
                else {
                    frame.origin.y = ((CGRectGetHeight(self.webView.frame)*0.5) - CGRectGetHeight(frame)*0.5);
                }
            }
            else {
                frame.origin.y = _webViewState.topEdgeInset;
            }
        }
    }
    
    self.webViewRotationSnapshot.frame = frame;
    [self.view insertSubview:self.webViewRotationSnapshot aboveSubview:self.webView];
    
    
    if (NEW_ROTATIONS == NO) {
        self.webView.scrollView.layer.speed = 9999.0f;
        
        CGFloat zoomScale = (self.webView.scrollView.minimumZoomScale+self.webView.scrollView.maximumZoomScale) * 0.5f;
        [self.webView.scrollView setZoomScale:zoomScale animated:YES];
    }
    
    self.webView.hidden = YES;
}


- (void)animateWebViewRotationToOrientation:(UIInterfaceOrientation)toOrientation withDuration:(NSTimeInterval)duration
{
    if (IPAD && self.modalPresentationStyle == UIModalPresentationFormSheet)
        return;
    
    
    [self.webView.layer removeAllAnimations];
    [self.webView.scrollView.layer removeAllAnimations];
    
    CGRect frame = self.webView.bounds;
    
    if ([self webViewPageWidthIsDynamic] == NO)
    {
        CGFloat scale = CGRectGetHeight(self.webViewRotationSnapshot.frame)/CGRectGetWidth(self.webViewRotationSnapshot.frame);
        frame.size.height = CGRectGetWidth(frame) * scale;
        
        if ((_webViewState.contentOffset.y + _webViewState.topEdgeInset) > FLT_EPSILON) {
            
            CGFloat scale = (CGRectGetHeight(self.webView.frame) / CGRectGetWidth(self.webView.frame));
            CGFloat destinationBoundsHeight = self.webView.bounds.size.height;
            CGFloat destinationHeight = destinationBoundsHeight * scale;
            CGFloat webViewOffsetOrigin = (_webViewState.contentOffset.y + (_webViewState.frameSize.height * 0.5f));
            CGFloat topContentOffset = webViewOffsetOrigin - (destinationHeight * 0.5f);
            CGFloat bottomContentOffset = webViewOffsetOrigin + (destinationHeight * 0.5f);
            
            if (topContentOffset < -_webViewState.topEdgeInset) {
                frame.origin.y = self.webView.scrollView.contentInset.top;
            }
            else if (bottomContentOffset > _webViewState.contentSize.height) {
                frame.origin.y = (CGRectGetMaxY(self.webView.frame) - (CGRectGetHeight(frame) + self.webView.scrollView.contentInset.bottom));
            }
            else {
                frame.origin.y = ((destinationBoundsHeight*0.5f) - (CGRectGetHeight(frame)*0.5f));
                
                if (_webViewState.contentOffset.y < 0.0f) {
                    CGFloat delta = _webViewState.topEdgeInset - (_webViewState.topEdgeInset + _webViewState.contentOffset.y);
                    frame.origin.y += (delta * (_webViewState.frameSize.height/_webViewState.frameSize.width));
                }
            }
        }
        else {
            frame.origin.y = self.webView.scrollView.contentInset.top;
        }
    }
    else {
        if (_webViewState.contentOffset.y < 0.0f) {
            CGFloat delta = _webViewState.topEdgeInset - (_webViewState.topEdgeInset + _webViewState.contentOffset.y);
            
            if (UIInterfaceOrientationIsLandscape(toOrientation))
                frame.origin.y += delta - (_webViewState.topEdgeInset - self.webView.scrollView.contentInset.top);
            else
                frame.origin.y -= (_webViewState.topEdgeInset - self.webView.scrollView.contentInset.top);
        }
        
        if (UIInterfaceOrientationIsPortrait(toOrientation))
            frame.origin.x = floor(CGRectGetWidth(self.view.bounds) * 0.5f) - (CGRectGetWidth(self.webViewRotationSnapshot.frame) * 0.5f);
    }
    
    self.webViewRotationSnapshot.frame = frame;
}

- (void)restoreWebViewFromRotationFromOrientation:(UIInterfaceOrientation)fromOrientation
{
    if (IPAD && self.modalPresentationStyle == UIModalPresentationFormSheet)
        return;
    
    CGFloat translatedScale = ((_webViewState.zoomScale/_webViewState.minimumZoomScale) * self.webView.scrollView.minimumZoomScale);
    
    if (translatedScale > self.webView.scrollView.maximumZoomScale)
        self.webView.scrollView.maximumZoomScale = translatedScale;
    
    CABasicAnimation *anim = [[self.webView.scrollView.layer animationForKey:@"bounds"] mutableCopy];
    if (NEW_ROTATIONS == NO) {
        [self.webView.scrollView.layer removeAllAnimations];
        self.webView.scrollView.layer.speed = 9999.0f;
        [self.webView.scrollView setZoomScale:translatedScale animated:YES];
        
        if (anim == nil) {
            [self animationDidStop:anim finished:YES];
            return;
        }
        
        [self.webView.scrollView.layer removeAnimationForKey:@"bounds"];
        [anim setDelegate:self];
        [self.webView.scrollView.layer addAnimation:anim forKey:@"bounds"];
    }
    else {
        [self.webView.scrollView setZoomScale:translatedScale animated:NO];
        [self animationDidStop:anim finished:YES];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    self.webView.hidden = NO;
    
    CGSize contentSize = self.webView.scrollView.contentSize;
    CGPoint translatedContentOffset = _webViewState.contentOffset;
    
    if ([self webViewPageWidthIsDynamic])
    {
        CGFloat delta = (_webViewState.topEdgeInset - self.webView.scrollView.contentInset.top);
        translatedContentOffset.y += delta;
    }
    else
    {
        CGFloat magnitude = contentSize.width / _webViewState.contentSize.width;
        
        translatedContentOffset.x *= magnitude;
        translatedContentOffset.y *= magnitude;
        
        if ((_webViewState.contentOffset.y + _webViewState.topEdgeInset) > FLT_EPSILON)
        {
            
            if(UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) {
                translatedContentOffset.y += (CGRectGetHeight(self.webViewRotationSnapshot.frame)*0.5f) - (CGRectGetHeight(self.webView.frame)*0.5f);
            }
            else {
                
                CGFloat scale = (_webViewState.frameSize.width / _webViewState.frameSize.height);
                CGFloat destinationBoundsHeight = self.webView.bounds.size.height;
                CGFloat destinationHeight = destinationBoundsHeight * scale;
                CGFloat webViewOffsetOrigin = (_webViewState.contentOffset.y + _webViewState.frameSize.height * 0.5f);
                CGFloat bottomContentOffset = webViewOffsetOrigin + (destinationHeight * 0.5f); // the bottom offset
                
                if (bottomContentOffset > _webViewState.contentSize.height)
                    translatedContentOffset.y = self.webView.scrollView.contentSize.height - (CGRectGetHeight(self.webView.frame)) + self.webView.scrollView.contentInset.top;
                else
                    translatedContentOffset.y -= (CGRectGetHeight(self.webView.frame)*0.5f) - (((_webViewState.frameSize.height*magnitude)*0.5f));
            }
        }
        else {
            translatedContentOffset.y = -self.webView.scrollView.contentInset.top;
        }
    }
    
    translatedContentOffset.x = MAX(translatedContentOffset.x, -self.webView.scrollView.contentInset.left);
    translatedContentOffset.x = MIN(translatedContentOffset.x, contentSize.width - CGRectGetWidth(self.webView.frame));
    
    translatedContentOffset.y = MAX(translatedContentOffset.y, -self.webView.scrollView.contentInset.top);
    translatedContentOffset.y = MIN(translatedContentOffset.y, contentSize.height - (CGRectGetHeight(self.webView.frame) - self.webView.scrollView.contentInset.bottom));
    
    [self.webView.scrollView setContentOffset:translatedContentOffset animated:NO];
    
    self.webView.scrollView.layer.speed = 1.0f;
    
    [self.webViewRotationSnapshot removeFromSuperview];
    self.webViewRotationSnapshot = nil;
    
    [UIViewController attemptRotationToDeviceOrientation];
}

@end
