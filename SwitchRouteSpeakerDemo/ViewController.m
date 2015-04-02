//
//  ViewController.m
//  SwitchRouteSpeakerDemo
//
//  Created by Tony on 1/5/15.
//  Copyright (c) 2015 Didi.Inc. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "DidAudioRouteSwither.h"

@interface ViewController ()

@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) UILabel *dbLevelLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

	UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	playBtn.frame = CGRectMake(100, 100, 100, 44);
	[playBtn setBackgroundColor:[UIColor redColor]];
	[playBtn setTitle:@"play" forState:UIControlStateNormal];
	[playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[playBtn addTarget:self action:@selector(playBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:playBtn];

	self.tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 100)];
	_tipLabel.center = self.view.center;
	_tipLabel.text = @"外界太吵啦，使用听筒更清楚哦~";
	_tipLabel.font = [UIFont systemFontOfSize:15.0];
	_tipLabel.alpha = 0.0;
	[self.view addSubview:_tipLabel];

	self.dbLevelLabel = [[UILabel alloc] initWithFrame:CGRectOffset(_tipLabel.frame, 0, 100)];
	_dbLevelLabel.textAlignment = NSTextAlignmentCenter;
	_dbLevelLabel.font = [UIFont systemFontOfSize:16.0];
	[self.view addSubview:_dbLevelLabel];

	NSURL *url = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp3"]];
	self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
	[self.player prepareToPlay];
}

- (void)playBtnClicked:(UIButton *)sender {
	if ([self.player isPlaying]) {
		[self.player stop];
        
        [[DidAudioRouteSwither sharedInstance] setIsActive:NO];
        
		[sender setBackgroundColor:[UIColor redColor]];
	}
	else {
        [[DidAudioRouteSwither sharedInstance] setIsActive:YES];
        __weak typeof(self) weakSelf = self;
        [[DidAudioRouteSwither sharedInstance] setDbLevelUpdateBlock:^(float value) {
            weakSelf.dbLevelLabel.text = [NSString stringWithFormat:@"dbLevel: %.2f", value];
        }];
        
		[self.player play];
		[sender setBackgroundColor:[UIColor greenColor]];
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}




@end
