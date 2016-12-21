//
//  UIImage+SQCWebViewControllerIcons.h
//  YaoFang
//
//  Created by 小猪猪 on 2016/12/21.
//  Copyright © 2016年 SQC. All rights reserved.
//

#import <UIKit/UIKit.h>
extern const NSString *SQCWebViewControllerButtonTintColor;
extern const NSString *SQCWebViewControllerButtonBevelOpacity;

@interface UIImage (SQCWebViewControllerIcons)


+ (instancetype)SQCWebViewControllerIcon_backButtonWithAttributes:(NSDictionary *)attributes;
+ (instancetype)SQCWebViewControllerIcon_forwardButtonWithAttributes:(NSDictionary *)attributes;
+ (instancetype)SQCWebViewControllerIcon_refreshButtonWithAttributes:(NSDictionary *)attributes;
+ (instancetype)SQCWebViewControllerIcon_stopButtonWithAttributes:(NSDictionary *)attributes;
+ (instancetype)SQCWebViewControllerIcon_actionButtonWithAttributes:(NSDictionary *)attributes;



@end
