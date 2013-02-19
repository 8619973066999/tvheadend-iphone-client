//
//  TVHStatusSubscription.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/18/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHStatusSubscription.h"

@implementation TVHStatusSubscription

@synthesize channel = _channel;
@synthesize errors = _errors;
@synthesize hostname = _hostname;
@synthesize id = _id;
@synthesize service = _service;
@synthesize start = _start;
@synthesize state = _state;
@synthesize title = _title;

-(void)setStart:(id)startDate {
    if([startDate isKindOfClass:[NSString class]]) {
        _start = [NSDate dateWithTimeIntervalSince1970:[startDate intValue]];
    }
}

@end