//
//  DidAudioRouteSwither.h
//  SwitchRouteSpeakerDemo
//
//  Created by Tony on 1/6/15.
//  Copyright (c) 2015 Didi.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DidAudioRouteSwither : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, assign) BOOL isActive;

@property (nonatomic, copy) void (^dbLevelUpdateBlock)(float dbValue);

@end
