//
//  TVHTagListViewController.m
//  TVHeadend iPhone Client
//
//  Created by zipleen on 2/9/13.
//  Copyright 2013 Luis Fernandes
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "TVHTagStoreViewController.h"
#import "TVHChannelStoreViewController.h"
#import "CKRefreshControl.h"
#import "UIImageView+WebCache.h"
#import "TVHChannelStore.h"
#import "TVHSettings.h"
#import "TVHShowNotice.h"
#import "TVHImageCache.h"

#import "TVHStatusSubscriptionsStore.h"
#import "TVHAdaptersStore.h"
#import "TVHLogStore.h"
#import "TVHCometPollStore.h"

@interface TVHTagStoreViewController ()
@property (weak, nonatomic) TVHTagStore *tagStore;
@property (strong, nonatomic) NSArray *tags;
@end

@implementation TVHTagStoreViewController

- (TVHTagStore*)tagStore {
    if ( _tagStore == nil) {
        _tagStore = [TVHTagStore sharedInstance];
    }
    return _tagStore;
}

- (void)resetControllerData {
    self.tags = nil;
    [self.tagStore fetchTagList];
    [[TVHChannelStore sharedInstance] fetchChannelList];
}

- (void)viewDidAppear:(BOOL)animated
{
#ifdef TVH_GOOGLEANALYTICS_KEY
    [[GAI sharedInstance].defaultTracker sendView:NSStringFromClass([self class])];
#endif
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,
                                    self.tableView);
}

- (void)viewDidLoad
{
    [super viewDidLoad];    
    [self.tagStore setDelegate:self];
    
    //pull to refresh
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(pullToRefreshViewShouldRefresh) forControlEvents:UIControlEventValueChanged];
    //self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull to refresh"];
    
    TVHSettings *settings = [TVHSettings sharedInstance];
    if( [settings selectedServer] == NSNotFound ) {
        [self performSegueWithIdentifier:@"ShowSettings" sender:self];
    } else {
        // fetch tags
        [self.tagStore fetchTagList];
        
        // and fetch channel data - we need it for a lot of things, channels should always be loaded!
        [TVHChannelStore sharedInstance];
        
        // and maybe start comet poll - after initing status and log
        [TVHStatusSubscriptionsStore sharedInstance];
        [TVHAdaptersStore sharedInstance];
        [TVHLogStore sharedInstance];
        [TVHCometPollStore sharedInstance];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetControllerData)
                                                 name:@"resetAllObjects"
                                               object:nil];
    self.settingsButton.title = NSLocalizedString(@"Settings", @"");
}

- (void)viewDidUnload {
    self.tagStore = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setSettingsButton:nil];
    [super viewDidUnload];
}

- (void)pullToRefreshViewShouldRefresh
{
    [self.tagStore fetchTagList];
}

- (void)reloadData {
    self.tags = [[self.tagStore tags] copy];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.tags count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TagListTableItems";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier ];
    if(cell==nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    TVHTag *tag = [self.tags objectAtIndex:indexPath.row];
    
    UILabel *tagNameLabel = (UILabel *)[cell viewWithTag:100];
	UILabel *tagNumberLabel = (UILabel *)[cell viewWithTag:101];
	__weak UIImageView *channelImage = (UIImageView *)[cell viewWithTag:102];
    tagNameLabel.text = tag.name;
    tagNumberLabel.text = nil;
    channelImage.contentMode = UIViewContentModeScaleAspectFit;
    [channelImage setImageWithURL:[NSURL URLWithString:tag.icon] placeholderImage:[UIImage imageNamed:@"tag.png"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
        if (!error) {
            channelImage.image = [TVHImageCache resizeImage:image];
        }
    } ];
    
    cell.accessibilityLabel = tag.name;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    UIImageView *separator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"separator.png"] ];
    [cell.contentView addSubview: separator];
    
    return cell;
}

- (float)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.01f;
}

#pragma mark - Table view delegate

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"Show Channel List"]) {
        
        NSIndexPath *path = [self.tableView indexPathForSelectedRow];
        TVHTag *tag = [self.tags objectAtIndex:path.row];
        
        TVHChannelStoreViewController *ChannelStore = segue.destinationViewController;
        [ChannelStore setFilterTagId: tag.id];
        
        [segue.destinationViewController setTitle:tag.name];
    }
}

- (void)didLoadTags {
    [self reloadData];
    [self.refreshControl endRefreshing];
    if ( [self.tags count] == 1 ) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
        [self performSegueWithIdentifier:@"Show Channel List" sender:self];
    }
}

- (void)didErrorLoadingTagStore:(NSError*) error {
    [TVHShowNotice errorNoticeInView:self.view title:NSLocalizedString(@"Network Error", nil) message:error.localizedDescription];
    [self reloadData];
    [self.refreshControl endRefreshing];
}


@end