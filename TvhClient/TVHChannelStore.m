//
//  ModelChannelList.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/3/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHChannelStore.h"
#import "TVHEpg.h"
#import "TVHJsonClient.h"

@interface TVHChannelStore ()
@property (nonatomic, strong) NSArray *channels;
@property (nonatomic, weak) id <TVHChannelStoreDelegate> delegate;
@property (nonatomic, weak) TVHEpgStore *epgStore;
@end

@implementation TVHChannelStore 

+ (id)sharedInstance {
    static TVHChannelStore *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHChannelStore alloc] init];
    });
    
    return __sharedInstance;
}

- (TVHEpgStore*) epgStore {
    if(!_epgStore){
        _epgStore = [TVHEpgStore sharedInstance];
    }
    return _epgStore;
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingChannelStore:)]) {
            [self.delegate didErrorLoadingChannelStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *channels = [[NSMutableArray alloc] init];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHChannel *channel = [[TVHChannel alloc] init];
        [obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if([key isEqualToString:@"chid"]) {
                [channel setChid:[obj intValue]];
            } else {
                [channel setValue:obj forKey:key];
            }
        }];
        
        [channels addObject:channel];

    }];
    
    self.channels =  [[channels copy] sortedArrayUsingSelector:@selector(compareByName:)];
    //self.channels = [channels copy];
    NSLog(@"[Loaded Channels]: %d", [self.channels count]);
}

- (void)resetChannelStore {
    self.channels = nil;
}

- (void)fetchChannelList {
    if( [self.channels count] == 0 ) {
        TVHJsonClient *httpClient = [TVHJsonClient sharedInstance];
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"list", @"op", nil];
       
        [httpClient postPath:@"/channels" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self fetchedData:responseObject];
            [self.delegate didLoadChannels];
            
            [self.epgStore setDelegate:self];
            [self.epgStore downloadEpgList];
            
           // NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
           // NSLog(@"Request Successful, response '%@'", responseStr);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([self.delegate respondsToSelector:@selector(didErrorLoadingChannelStore:)]) {
                [self.delegate didErrorLoadingChannelStore:error];
            }
            NSLog(@"[ChannelList HTTPClient Error]: %@", error.localizedDescription);
        }];
    } 
}

- (TVHChannel*) getChannelById:(NSInteger)channelId {
    NSEnumerator *e = [self.channels objectEnumerator];
    TVHChannel *channel;
    while (channel = [e nextObject]) {
        if ( [channel chid] == channelId ) {
            return channel;
        }
    }
    return nil;
}

#pragma mark EPG delegatee stuff

- (void) didLoadEpg:(TVHEpgStore*)epgStore {
    // for each epg
    NSArray *list = [epgStore getEpgList];
    NSEnumerator *e = [list objectEnumerator];
    TVHEpg *epg;
    while (epg = [e nextObject]) {
        TVHChannel *channel = [self getChannelById:epg.channelId];
        [channel addEpg:epg];
    }
    [self.delegate didLoadChannels];
}

-(void) didErrorLoadingEpgStore:(NSError*)error {
    if ([self.delegate respondsToSelector:@selector(didErrorLoadingChannelStore:)]) {
        [self.delegate didErrorLoadingChannelStore:error];
    }
}

#pragma mark Controller delegate stuff

- (NSArray*) getFilteredChannelList {
    NSMutableArray *filteredChannels = [[NSMutableArray alloc] init];
    
    NSEnumerator *e = [self.channels objectEnumerator];
    TVHChannel *channel;
    while (channel = [e nextObject]) {
        if( [channel hasTag:self.filterTag] ) {
            [filteredChannels addObject:channel];
        }
    }
    return [filteredChannels copy];
}

- (TVHChannel*) objectAtIndex:(int) row {
    if(self.filterTag == 0) {
        return [self.channels objectAtIndex:row];
    } else {
        NSArray *filteredTag = [self getFilteredChannelList];
        if (row < [filteredTag count]){
            return [filteredTag objectAtIndex:row];
        }
    }
    return nil;
}

- (TVHChannel*) channelWithName:(NSString*) name {
    NSEnumerator *e = [self.channels objectEnumerator];
    TVHChannel *channel;
    while (channel = [e nextObject]) {
        if( [channel.name isEqualToString:name] ) {
            return channel;
        }
    }
    return nil;
}

- (int) count {
    if(self.filterTag == 0) {
        return [self.channels count];
    } else {
        NSArray *filteredTag = [self getFilteredChannelList];
        return [filteredTag count];
    }
}

- (void)setDelegate:(id <TVHChannelStoreDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

@end