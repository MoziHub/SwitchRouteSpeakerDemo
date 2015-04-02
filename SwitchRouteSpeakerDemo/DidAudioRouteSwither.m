//
//  DidAudioRouteSwither.m
//  SwitchRouteSpeakerDemo
//
//  Created by Tony on 1/6/15.
//  Copyright (c) 2015 Didi.Inc. All rights reserved.
//

#import "DidAudioRouteSwither.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>


#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)


@interface DidAudioRouteSwither ()

// DB
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSTimer *levelTimer;
@property (nonatomic, assign) float curDbLevel;

// 加速度
@property (nonatomic, strong) CMMotionManager *motionManager;

// 红外
@property (nonatomic, assign) BOOL isUseSensorDectect;

@end


@implementation DidAudioRouteSwither

@synthesize recorder;
@synthesize levelTimer;

+ (instancetype)sharedInstance {
	static DidAudioRouteSwither *instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	    instance = [[DidAudioRouteSwither alloc] init];
	});
	return instance;
}

// 插上耳机后，无任何影响，都会走耳机线路，SO 不需要任何处理


#pragma mark - 近距离感应

- (void)setIsUseSensorDectect:(BOOL)isUseSensorDectect {
	if (_isUseSensorDectect != isUseSensorDectect) {
		_isUseSensorDectect = isUseSensorDectect;
		[self setSensorDectectIsEnabled:isUseSensorDectect];

		// 2秒后自动关闭红外探测
		if (_isUseSensorDectect == YES) {
			const float delayTime = 2.0;
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			    // 如果2秒内成功判断为使用耳机，则仍然开启，延迟到远离设备时关闭
			    // 否则立即关闭红外探测
			    if ([self isUseTelEarPhone] == NO) {
			        [self setIsUseSensorDectect:NO];
				}
			});
		}
	}
}

- (void)setSensorDectectIsEnabled:(BOOL)isEnabled {
	if (isEnabled) {
		[[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
		if ([UIDevice currentDevice].proximityMonitoringEnabled == YES) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:) name:UIDeviceProximityStateDidChangeNotification object:nil];
			NSLog(@"打开红外距离探测");
		}
		else {
			NSLog(@"当前设备没有近距离传感器");
		}
	}
	else {
		// 关闭监听
		[[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
		if ([UIDevice currentDevice].proximityMonitoringEnabled == YES) {
			[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
			NSLog(@"关闭红外距离探测");
		}
		[[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
	}
}

- (void)sensorStateChange:(NSNotificationCenter *)notification {
	// 听筒输出，屏幕变暗
	if ([[UIDevice currentDevice] proximityState] == YES) { //接近了！
		NSLog(@"手机靠近用户了！");
		[self setAudioSessionUseTelEarPhone];
		[self closeDBLevelDectect];
	}
	else { //未接近
		NSLog(@"手机远离用户了！");
		[self setAudioSessionUseLoadSpeaker];
		[self startDBLevelDectect];

		// 当远离设备后，关闭红外传感器
		[self setIsUseSensorDectect:NO];
	}
}

#pragma mark - Main Control

- (void)setIsActive:(BOOL)isActive {
	_isActive = isActive;
	if (self.isActive) {
		[self prepareForPlay];
	}
	else {
		[self playFinished];
	}
}

- (void)prepareForPlay {
	// 默认情况下扬声器播放
	[self setAudioSessionUseLoadSpeaker];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];

	// 开启分贝探测
	[self startDBLevelDectect];

	// 开启加速度探测
	[self startAccelerometer];
}

- (void)playFinished {
	[self setSensorDectectIsEnabled:NO];
	[self setAudioSessionUseLoadSpeaker];
	[self closeDBLevelDectect];
	[self stopAccelerometer];
	[self setDbLevelUpdateBlock:nil];
	[[AVAudioSession sharedInstance] setActive:NO error:nil];
}

#pragma mark - Utils

// PlayAndRecord 使用听筒
- (void)setAudioSessionUseTelEarPhone {
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0")) {
		// iOS 6.0 以上可用
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
	}
	else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
		// iOS 6.0以下设备兼容
		UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
		                        sizeof(UInt32),
		                        &sessionCategory);

		UInt32 overrideCategory = 0;
		AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
		                        sizeof(overrideCategory),
		                        &overrideCategory);
#pragma GCC diagnostic pop
	}
}

// PlayAndRecord 使用扬声器
- (void)setAudioSessionUseLoadSpeaker {
	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0")) {
		// iOS 6.0 以上可用
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
	}
	else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
		// iOS 6.0以下设备兼容
		UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
		                        sizeof(UInt32),
		                        &sessionCategory);

		UInt32 overrideCategory = 1;
		AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
		                        sizeof(overrideCategory),
		                        &overrideCategory);
#pragma GCC diagnostic pop
	}
}

- (BOOL)isUseTelEarPhone {
	BOOL ret = [[AVAudioSession sharedInstance] categoryOptions] != AVAudioSessionCategoryOptionDefaultToSpeaker;
	return ret;
}

#pragma mark - 分贝数探测

- (void)closeDBLevelDectect {
	[self.recorder stop];
	self.recorder = nil;
	[self.levelTimer invalidate];
	self.levelTimer = nil;
}

- (void)startDBLevelDectect {
	[self closeDBLevelDectect];

	// 多少秒探测一次
	const float dectectFrequency = 0.3;

	// 不需要保存录音文件
	NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];

	NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
	                          [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
	                          [NSNumber numberWithInt:kAudioFormatAppleLossless], AVFormatIDKey,
	                          [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
	                          [NSNumber numberWithInt:AVAudioQualityMax], AVEncoderAudioQualityKey,
	                          nil, nil];

	NSError *error;
	recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
	if (recorder) {
		[recorder prepareToRecord];
		[recorder setMeteringEnabled:YES];
		[recorder record];
		levelTimer = [NSTimer scheduledTimerWithTimeInterval:dectectFrequency target:self selector:@selector(levelTimerCallback:) userInfo:nil repeats:YES];
	}
	else {
		NSLog(@"Error in initializeRecorder: %@", [error description]);
	}
}

- (void)levelTimerCallback:(NSTimer *)timer {
	[recorder updateMeters];

	// http://stackoverflow.com/questions/9247255/am-i-doing-the-right-thing-to-convert-decibel-from-120-0-to-0-120

	float level;                  // The linear 0.0 .. 1.0 value we need.
	float minDecibels = -80.0f;   // Or use -60dB, which I measured in a silent room.
	float decibels    = [recorder averagePowerForChannel:0];

	if (decibels < minDecibels) {
		level = 0.0f;
	}
	else if (decibels >= 0.0f) {
		level = 1.0f;
	}
	else {
		float root            = 2.0f;
		float minAmp          = powf(10.0f, 0.05f * minDecibels);
		float inverseAmpRange = 1.0f / (1.0f - minAmp);
		float amp             = powf(10.0f, 0.05f * decibels);
		float adjAmp          = (amp - minAmp) * inverseAmpRange;

		level = powf(adjAmp, 1.0f / root);
	}

	self.curDbLevel = level * 120;
	NSLog(@"dbLevel: %.2f", self.curDbLevel);

	// TODO: 多少db算是嘈杂？
	if (self.dbLevelUpdateBlock) {
		self.dbLevelUpdateBlock(self.curDbLevel);
	}
}

#pragma mark - 重力加速度

- (void)stopAccelerometer {
	[self.motionManager stopAccelerometerUpdates];
	self.motionManager = nil;
}

- (void)startAccelerometer {
	self.motionManager = [[CMMotionManager alloc] init];

	// 加速度器的检测
	if ([self.motionManager isAccelerometerAvailable]) {
		NSLog(@"开启加速度检测");

		[self.motionManager setAccelerometerUpdateInterval:0.1f];

		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		[self.motionManager startAccelerometerUpdatesToQueue:queue
		                                         withHandler:
		 ^(CMAccelerometerData *accelerometerData, NSError *error) {
		    CMAcceleration acceleration = accelerometerData.acceleration;

		    const float threshold = 0.2f;   //经验值

		    if (acceleration.x > threshold || acceleration.y > threshold || acceleration.z > threshold) {
		        // 在有加速度后，打开 x 秒探测红外
		        NSLog(@"X = %.04f, Y = %.04f, Z = %.04f", acceleration.x, acceleration.y, acceleration.z);
		        [self setIsUseSensorDectect:YES];
			}
		}];
	}
	else {
		NSLog(@"不支持加速度检测");
	}
}

@end
