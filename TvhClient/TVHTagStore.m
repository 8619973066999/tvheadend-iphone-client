//
//  TVHTagStore.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/9/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHTagStore.h"
#import "TVHJsonClient.h"

@interface TVHTagStore()
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, weak) id <TVHTagStoreDelegate> delegate;
@end


@implementation TVHTagStore

+ (id)sharedInstance {
    static TVHTagStore *__sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[TVHTagStore alloc] init];
    });
    
    return __sharedInstance;
}

- (void)fetchedData:(NSData *)responseData {
    NSError* error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:error];
    if( error ) {
        if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
            [self.delegate didErrorLoadingTagStore:error];
        }
        return ;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *tags = [[NSMutableArray alloc] init];
    
    
    NSEnumerator *e = [entries objectEnumerator];
    id entry;
    //for (NSEnumerator *channel in entries) {
    while (entry = [e nextObject]) {
        NSInteger enabled = [[entry objectForKey:@"enabled"] intValue];
        if( enabled ) {
            TVHTag *tag = [[TVHTag alloc] init];
            [tag updateValuesFromDictionary:entry];
            [tags addObject:tag];
        }
    }
     
    NSMutableArray *orderedTags = [[tags sortedArrayUsingSelector:@selector(compareByName:)] mutableCopy];
    
    // All channels
    TVHTag *t = [[TVHTag alloc] initWithAllChannels];
    [orderedTags insertObject:t atIndex:0];
    
    self.tags = [orderedTags copy];
#ifdef TESTING
    NSLog(@"[Loaded Tags]: %d", [self.tags count]);
#endif
}

- (void)fetchTagList {
    if( [self.tags count] == 0 ) {
        TVHJsonClient *httpClient = [TVHJsonClient sharedInstance];
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"get", @"op", @"channeltags", @"table", nil];
        
        [httpClient postPath:@"/tablemgr" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self fetchedData:responseObject];
            [self.delegate didLoadTags];
            
            //NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            //NSLog(@"Request Successful, response '%@'", responseStr);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([self.delegate respondsToSelector:@selector(didErrorLoadingTagStore:)]) {
                [self.delegate didErrorLoadingTagStore:error];
            }
#ifdef TESTING
            NSLog(@"[TagList HTTPClient Error]: %@", error.description);
#endif
        }];
    }
}

- (void) resetTagStore {
    self.tags = nil;
}

- (TVHTagStore *) objectAtIndex:(int) row {
    if ( row < [self.tags count] ) {
        return [self.tags objectAtIndex:row];
    }
    return nil;
}

- (int) count {
    return [self.tags count];
}

- (void)setDelegate:(id <TVHTagStoreDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

@end
