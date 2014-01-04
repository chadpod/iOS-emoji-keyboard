//
//  EmojiKeyBoardView.m
//  EmojiKeyBoard
//
//  Created by Ayush on 09/05/13.
//  Copyright (c) 2013 Ayush. All rights reserved.
//

#import "EmojiKeyBoardView.h"
#import "EmojiPageView.h"
#import "DDPageControl.h"

#define BUTTON_WIDTH 45
#define BUTTON_HEIGHT 37

#define DEFAULT_SELECTED_SEGMENT 0
#define PAGE_CONTROL_INDICATOR_DIAMETER 6.0
#define RECENT_EMOJIS_MAINTAINED_COUNT 50

#define BACKGROUND_COLOR 0xFAF7F7

static CGFloat const kScrollViewTopMargin = 8.0;

static NSString *const segmentRecentName = @"Recent";
NSString *const RecentUsedEmojiCharactersKey = @"RecentUsedEmojiCharactersKey";

@implementation UIColor (TDTAdditions)

+ (UIColor *)colorWithIntegerValue:(NSUInteger)value alpha:(CGFloat)alpha {
  NSUInteger mask = 255;
  NSUInteger blueValue = value & mask;
  value >>= 8;
  NSUInteger greenValue = value & mask;
  value >>= 8;
  NSUInteger redValue = value & mask;
  return [UIColor colorWithRed:(CGFloat)(redValue / 255.0) green:(CGFloat)(greenValue / 255.0) blue:(CGFloat)(blueValue / 255.0) alpha:alpha];
}

@end


@interface EmojiKeyBoardView () <UIScrollViewDelegate, EmojiPageViewDelegate>

@property (nonatomic, retain) UISegmentedControl *segmentsBar;
@property (nonatomic, retain) DDPageControl *pageControl;
@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) NSDictionary *emojis;
@property (nonatomic, retain) NSMutableArray *pageViews;
@property (nonatomic, retain) NSString *category;
@property (nonatomic, assign) NSUInteger selectedIndex;
@property (nonatomic, retain) UIView* barDivider;
@property (nonatomic, retain) UIImageView* infoImageView;
@property (nonatomic, retain) UILabel* infoLabel;

@end

@implementation EmojiKeyBoardView
@synthesize delegate = delegate_;
@synthesize segmentsBar = segmentsBar_;
@synthesize pageControl = pageControl_;
@synthesize scrollView = scrollView_;
@synthesize emojis = emojis_;
@synthesize pageViews = pageViews_;
@synthesize category = category_;
@synthesize selectedIndex = selectedIndex_;
@synthesize barDivider = barDivider_;
@synthesize infoImageView = infoImageView_;
@synthesize infoLabel = infoLabel_;


- (NSDictionary *)emojis {
  if (!emojis_) {
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"EmojisList"
                                                          ofType:@"plist"];
    emojis_ = [[NSDictionary dictionaryWithContentsOfFile:plistPath] copy];
  }
  return emojis_;
}

// recent emojis are backed in NSUserDefaults to save them across app restarts.
- (NSMutableArray *)recentEmojis {
  NSArray *emojis = [[NSUserDefaults standardUserDefaults] arrayForKey:RecentUsedEmojiCharactersKey];
  NSMutableArray *recentEmojis = [[emojis mutableCopy] autorelease];
  if (recentEmojis == nil) {
    recentEmojis = [NSMutableArray array];
  }
  return recentEmojis;
}

- (void)setRecentEmojis:(NSMutableArray *)recentEmojis {
  // remove emojis if they cross the cache maintained limit
  if ([recentEmojis count] > RECENT_EMOJIS_MAINTAINED_COUNT) {
    NSIndexSet *indexesToBeRemoved = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(RECENT_EMOJIS_MAINTAINED_COUNT, [recentEmojis count] - RECENT_EMOJIS_MAINTAINED_COUNT)];
    [recentEmojis removeObjectsAtIndexes:indexesToBeRemoved];
  }
  [[NSUserDefaults standardUserDefaults] setObject:recentEmojis forKey:RecentUsedEmojiCharactersKey];
}

+ (void)clearRecentEmojis {
  [[NSUserDefaults standardUserDefaults] setObject:[NSMutableArray array] forKey:RecentUsedEmojiCharactersKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    // initialize category
    self.category = segmentRecentName;

    self.backgroundColor = [UIColor colorWithIntegerValue:BACKGROUND_COLOR alpha:1.0];

    self.segmentsBar = [[[UISegmentedControl alloc] initWithItems:@[
                         [[UIImage imageNamed:@"emoji_tab_recent_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                         [[UIImage imageNamed:@"emoji_tab_face_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                         [[UIImage imageNamed:@"emoji_tab_bell_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                         [[UIImage imageNamed:@"emoji_tab_flower_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                         [[UIImage imageNamed:@"emoji_tab_car_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                         [[UIImage imageNamed:@"emoji_tab_symbols_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                         [[UIImage imageNamed:@"emoji_delete_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                         ]] autorelease];
    CGFloat segmentBarHeight = 48.0;
    self.segmentsBar.frame = CGRectMake(0, CGRectGetHeight(self.bounds) - segmentBarHeight, CGRectGetWidth(self.bounds), segmentBarHeight);
    self.segmentsBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.segmentsBar.contentMode = UIViewContentModeScaleAspectFill;

    // set custom background image
    [self.segmentsBar setBackgroundImage:[UIImage imageNamed:@"emoji_tab_bg.png"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [self.segmentsBar setBackgroundImage:[UIImage imageNamed:@"emoji_tab_bg.png"] forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    [self.segmentsBar setBackgroundImage:[UIImage imageNamed:@"emoji_tab_bg.png"] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    
    // set custom divider
    UIImage* dividerImage = [UIImage imageNamed:@"emoji_divider.png"];
    [self.segmentsBar setDividerImage:dividerImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    // manually set the width for each tab so the tabs utilize the entire width of the segment control,
    // since iOS is too stupid to figure this out on its own.
    CGFloat dividerWidth = dividerImage.size.width;
    CGFloat remainingWidth = CGRectGetWidth(self.segmentsBar.frame);
    remainingWidth -= ((self.segmentsBar.numberOfSegments - 1) * dividerWidth);
    for (int i=0; i < self.segmentsBar.numberOfSegments; ++i) {
      CGFloat remainingTabs = self.segmentsBar.numberOfSegments - i;
      CGFloat tabWidth = floorf(remainingWidth / remainingTabs);
      [self.segmentsBar setWidth:tabWidth forSegmentAtIndex:i];
      remainingWidth -= tabWidth;
    }
    
    [self.segmentsBar addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
    [self setSelectedCategoryImageInSegmentControl:self.segmentsBar AtIndex:DEFAULT_SELECTED_SEGMENT];
    self.segmentsBar.selectedSegmentIndex = DEFAULT_SELECTED_SEGMENT;
    self.selectedIndex = self.segmentsBar.selectedSegmentIndex; // initialize property
    [self addSubview:self.segmentsBar];

    self.pageControl = [[DDPageControl alloc] initWithType:DDPageControlTypeOnFullOffFull];
    self.pageControl.onColor = [UIColor darkGrayColor];
    self.pageControl.offColor = [UIColor lightGrayColor];
    self.pageControl.indicatorDiameter = PAGE_CONTROL_INDICATOR_DIAMETER;
    self.pageControl.hidesForSinglePage = YES;
    self.pageControl.currentPage = 0;
    self.pageControl.backgroundColor = [UIColor clearColor];
    CGSize pageControlSize = [self.pageControl sizeForNumberOfPages:3];
    NSUInteger numberOfPages = [self numberOfPagesForCategory:self.category
                                                  inFrameSize:CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - CGRectGetHeight(self.segmentsBar.bounds) - pageControlSize.height)];
    self.pageControl.numberOfPages = numberOfPages;
    pageControlSize = [self.pageControl sizeForNumberOfPages:numberOfPages];
    self.pageControl.frame = CGRectIntegral(CGRectMake((CGRectGetWidth(self.bounds) - pageControlSize.width) / 2,
                                                       CGRectGetMinY(self.segmentsBar.frame) - pageControlSize.height,
                                                       pageControlSize.width,
                                                       pageControlSize.height));
    [self.pageControl addTarget:self action:@selector(pageControlTouched:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.pageControl];

    self.scrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake(0,
                                                                      kScrollViewTopMargin,
                                                                      CGRectGetWidth(self.bounds),
                                                                      CGRectGetHeight(self.bounds) - CGRectGetHeight(self.segmentsBar.bounds) - pageControlSize.height)] autorelease];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;

    [self addSubview:self.scrollView];
    
    self.barDivider = [[UIView alloc] init];
    self.barDivider.backgroundColor = [UIColor colorWithIntegerValue:0xE4E3E4 alpha:1.0];
    self.barDivider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    CGRect divFrame = CGRectMake(0, 0, CGRectGetWidth(self.frame), 0.5);
    divFrame.origin.y = CGRectGetMinY(self.segmentsBar.frame) - divFrame.size.height;
    self.barDivider.frame = divFrame;
    [self addSubview:self.barDivider];
    
    self.infoImageView = [[UIImageView alloc] init];
    self.infoImageView.backgroundColor = [UIColor clearColor];
    self.infoImageView.contentMode = UIViewContentModeCenter;
    self.infoImageView.image = [UIImage imageNamed:@"emoji_recent_msg.png"];
    [self.infoImageView sizeToFit];
    [self addSubview:self.infoImageView];
    self.infoImageView.hidden = YES;
    
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.backgroundColor = [UIColor clearColor];
    self.infoLabel.numberOfLines = 1;
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.infoLabel.text = @"Recently Used";
    
    // Try to use proxima if available, otherwise fall back to system.
    UIFont* font = [UIFont fontWithName:@"ProximaNova-Regular" size:12];
    if (font == nil) {
      font = [UIFont systemFontOfSize:11];
    }
    self.infoLabel.font = font;
    self.infoLabel.textColor = [UIColor colorWithIntegerValue:0xADA5A5 alpha:1.0];
    [self addSubview:self.infoLabel];
    self.infoLabel.hidden = YES;
    [self.infoLabel sizeToFit];
  }
  return self;
}


- (void)dealloc {
  self.pageControl = nil;
  self.scrollView = nil;
  self.segmentsBar = nil;
  self.category = nil;
  self.emojis = nil;
  self.barDivider = nil;
  self.infoImageView = nil;
  self.infoLabel = nil;
  [self purgePageViews];
  [super dealloc];
}

- (void)layoutSubviews {

  CGSize pageControlSize = [self.pageControl sizeForNumberOfPages:3];
  
  NSUInteger numberOfPages = [self numberOfPagesForCategory:self.category
                                                inFrameSize:CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - CGRectGetHeight(self.segmentsBar.bounds) - pageControlSize.height)];

  NSInteger currentPage = (self.pageControl.currentPage > numberOfPages) ? numberOfPages : self.pageControl.currentPage;

  // if (currentPage > numberOfPages) it is set implicitly to max pageNumber available
  self.pageControl.numberOfPages = numberOfPages;
  pageControlSize = [self.pageControl sizeForNumberOfPages:numberOfPages];
  self.pageControl.frame = CGRectIntegral(CGRectMake((CGRectGetWidth(self.bounds) - pageControlSize.width) / 2,
                                                     CGRectGetMinY(self.segmentsBar.frame) - pageControlSize.height,
                                                     pageControlSize.width,
                                                     pageControlSize.height));

  self.scrollView.frame = CGRectMake(0,
                                     kScrollViewTopMargin,
                                     CGRectGetWidth(self.bounds),
                                     CGRectGetHeight(self.bounds) - CGRectGetHeight(self.segmentsBar.bounds) - pageControlSize.height);
  [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
  self.scrollView.contentOffset = CGPointMake(CGRectGetWidth(self.scrollView.bounds) * currentPage, 0);
  self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.scrollView.bounds) * numberOfPages, CGRectGetHeight(self.scrollView.bounds));
  
  // Do not purge pageViews because we can still reuse old pages when we switch to a new category.
  // Since we removed the pages from the scrollView, we will know that they are available to be reused.
  if (self.pageViews == nil) {
    self.pageViews = [NSMutableArray array];
  }

  [self setPage:currentPage];

  CGRect divFrame = self.barDivider.frame;;
  divFrame.size.width = CGRectGetWidth(self.frame);
  divFrame.origin.y = CGRectGetMinY(self.segmentsBar.frame) - divFrame.size.height;
  self.barDivider.frame = divFrame;
  
  CGPoint center = CGPointMake(floorf(CGRectGetWidth(self.bounds)/2.0),
                               floorf(CGRectGetMinY(self.segmentsBar.frame)/2.0));
  self.infoImageView.center = center;
  
  // Show message if Recent category is selected but empty.
  if ([self.category isEqualToString:segmentRecentName]) {
    
    if ([[self recentEmojis] count] > 0) {
      self.infoImageView.hidden = YES;
      self.infoLabel.hidden = NO;
      self.infoLabel.center = self.pageControl.center;
      
    } else {
      self.infoImageView.hidden = NO;
      self.infoLabel.hidden = YES;
    }
    
    
  } else {
    self.infoImageView.hidden = YES;
    self.infoLabel.hidden = YES;
  }
}

#pragma mark event handlers

- (void)setSelectedCategoryImageInSegmentControl:(UISegmentedControl *)segmentsBar AtIndex:(NSInteger)index {
  
  NSArray *imagesForSelectedSegments = @[[[UIImage imageNamed:@"emoji_tab_recent_icon-selected.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                         [[UIImage imageNamed:@"emoji_tab_face_icon-selected.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                         [[UIImage imageNamed:@"emoji_tab_bell_icon-selected.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                         [[UIImage imageNamed:@"emoji_tab_flower_icon-selected.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                         [[UIImage imageNamed:@"emoji_tab_car_icon-selected.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                         [[UIImage imageNamed:@"emoji_tab_symbols_icon-selected.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                         [[UIImage imageNamed:@"emoji_delete_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
  NSArray *imagesForNonSelectedSegments = @[[[UIImage imageNamed:@"emoji_tab_recent_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                            [[UIImage imageNamed:@"emoji_tab_face_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                            [[UIImage imageNamed:@"emoji_tab_bell_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                            [[UIImage imageNamed:@"emoji_tab_flower_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                            [[UIImage imageNamed:@"emoji_tab_car_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                            [[UIImage imageNamed:@"emoji_tab_symbols_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                            [[UIImage imageNamed:@"emoji_delete_icon.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
  
  for (int i=0; i < self.segmentsBar.numberOfSegments; ++i) {
    [segmentsBar setImage:imagesForNonSelectedSegments[i] forSegmentAtIndex:i];
  }
  [segmentsBar setImage:imagesForSelectedSegments[index] forSegmentAtIndex:index];
}

- (void)segmentAction:(UISegmentedControl*)sender {
  
  NSUInteger idx = [sender selectedSegmentIndex];
  NSUInteger lastSegment = [sender numberOfSegments] - 1;
  
  // delete button (momentary)
  if (idx == lastSegment) {
    sender.selectedSegmentIndex = self.selectedIndex;
    [self.delegate emojiKeyBoardViewDidPressBackSpace:self];
  }
  // emoji tab (toggle)
  else {
    self.selectedIndex = idx;
    [self categoryChangedViaSegmentsBar:sender];
  }
}

- (void)categoryChangedViaSegmentsBar:(UISegmentedControl *)sender {
  // recalculate number of pages for new category and recreate emoji pages
  NSArray *categoryList = @[segmentRecentName, @"People", @"Objects", @"Nature", @"Places", @"Symbols"];

  self.category = categoryList[sender.selectedSegmentIndex];
  [self setSelectedCategoryImageInSegmentControl:sender AtIndex:sender.selectedSegmentIndex];
  self.pageControl.currentPage = 0;
  // This triggers layoutSubviews
  // Choose a number that can never be equal to numberOfPages of pagecontrol else
  // layoutSubviews would not be called
  self.pageControl.numberOfPages = 100;
}

- (void)pageControlTouched:(DDPageControl *)sender {
  CGRect bounds = self.scrollView.bounds;
  bounds.origin.x = CGRectGetWidth(bounds) * sender.currentPage;
  bounds.origin.y = 0;
  // scrollViewDidScroll is called here. Page set at that time.
  [self.scrollView scrollRectToVisible:bounds animated:YES];
}

// Track the contentOffset of the scroll view, and when it passes the mid
// point of the current view’s width, the views are reconfigured.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  CGFloat pageWidth = CGRectGetWidth(scrollView.frame);
  NSInteger newPageNumber = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
  if (self.pageControl.currentPage == newPageNumber) {
    return;
  }
  self.pageControl.currentPage = newPageNumber;
  [self setPage:self.pageControl.currentPage];
}

#pragma mark change a page on scrollView

// Check if setting pageView for an index is required
- (BOOL)requireToSetPageViewForIndex:(NSUInteger)index {
  if (index >= self.pageControl.numberOfPages) {
    return NO;
  }
  for (EmojiPageView *page in self.pageViews) {
    // Ignore pageView if it's not a subView of the scrollView (i.e. a pageView needs to be set for this index).
    if ([page isDescendantOfView:self.scrollView]) {
      if ((page.frame.origin.x / CGRectGetWidth(self.scrollView.bounds)) == index) {
        return NO;
      }
    }
  }
  return YES;
}

// Create a pageView and add it to the scroll view.
- (EmojiPageView *)synthesizeEmojiPageView {
  NSUInteger rows = [self numberOfRowsForFrameSize:self.scrollView.bounds.size];
  NSUInteger columns = [self numberOfColumnsForFrameSize:self.scrollView.bounds.size];
  EmojiPageView *pageView = [[[EmojiPageView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.scrollView.bounds), CGRectGetHeight(self.scrollView.bounds))
                                                       buttonSize:CGSizeMake(BUTTON_WIDTH, BUTTON_HEIGHT)
                                                             rows:rows
                                                          columns:columns] autorelease];
  pageView.delegate = self;
  [self.pageViews addObject:pageView];
  [self.scrollView addSubview:pageView];
  return pageView;
}

// return a pageView that can be used in the current scrollView.
// look for an available pageView in current pageView-s on scrollView.
// If all are in use i.e. are of current page or neighbours
// of current page, we create a new one

- (EmojiPageView *)usableEmojiPageView {
  EmojiPageView *pageView = nil;
  for (EmojiPageView *page in self.pageViews) {
    
    // If the page is in the scrollView and it's not a neighbor of the current page, then use it.
    // If it's not in the scrollView, then use it.
    if ([page isDescendantOfView:self.scrollView]) {
      NSUInteger pageNumber = page.frame.origin.x / CGRectGetWidth(self.scrollView.bounds);
      if (abs(pageNumber - self.pageControl.currentPage) > 1) {
        pageView = page;
        break;
      }
    } else {
      pageView = page;
      break;
    }
  }
  if (!pageView) {
    pageView = [self synthesizeEmojiPageView];
  }
  return pageView;
}

// Set emoji page view for given index.
- (void)setEmojiPageViewInScrollView:(UIScrollView *)scrollView atIndex:(NSUInteger)index {
  
  if (![self requireToSetPageViewForIndex:index]) {
    return;
  }

  EmojiPageView *pageView = [self usableEmojiPageView];
  
  // Make sure pageView has been added to the scrollView (in case it's being reused in a new category).
  if (![pageView isDescendantOfView:self.scrollView]) {
    [self.scrollView addSubview:pageView];
  }

  NSUInteger rows = [self numberOfRowsForFrameSize:scrollView.bounds.size];
  NSUInteger columns = [self numberOfColumnsForFrameSize:scrollView.bounds.size];
  NSUInteger startingIndex = index * (rows * columns);
  NSUInteger endingIndex = (index + 1) * (rows * columns);
  
  NSMutableArray *buttonTexts = [self emojiTextsForCategory:self.category
                                                  fromIndex:startingIndex
                                                    toIndex:endingIndex];
  
  [pageView setButtonTexts:buttonTexts];
  pageView.frame = CGRectMake(index * CGRectGetWidth(scrollView.bounds), 0, CGRectGetWidth(scrollView.bounds), CGRectGetHeight(scrollView.bounds));
}

// Set the current page.
// sets neightbouring pages too, as they are viewable by part scrolling.
- (void)setPage:(NSInteger)page {
  [self setEmojiPageViewInScrollView:self.scrollView atIndex:page - 1];
  [self setEmojiPageViewInScrollView:self.scrollView atIndex:page];
  [self setEmojiPageViewInScrollView:self.scrollView atIndex:page + 1];
}

- (void)purgePageViews {
  for (EmojiPageView *page in self.pageViews) {
    page.delegate = nil;
  }
  self.pageViews = nil;
}

#pragma mark data methods

- (NSUInteger)numberOfColumnsForFrameSize:(CGSize)frameSize {
  return (NSUInteger)floor(frameSize.width / BUTTON_WIDTH);
}

- (NSUInteger)numberOfRowsForFrameSize:(CGSize)frameSize {
  return (NSUInteger)floor(frameSize.height / BUTTON_HEIGHT);
}

- (NSArray *)emojiListForCategory:(NSString *)category {
  if ([category isEqualToString:segmentRecentName]) {
    return [self recentEmojis];
  }
  return [self.emojis objectForKey:category];
}

// for a given frame size of scroll view, return the number of pages
// required to show all the emojis for a category
- (NSUInteger)numberOfPagesForCategory:(NSString *)category inFrameSize:(CGSize)frameSize {

  if ([category isEqualToString:segmentRecentName]) {
    return 1;
  }

  NSUInteger emojiCount = [[self emojiListForCategory:category] count];
  NSUInteger numberOfRows = [self numberOfRowsForFrameSize:frameSize];
  NSUInteger numberOfColumns = [self numberOfColumnsForFrameSize:frameSize];
  NSUInteger numberOfEmojisOnAPage = numberOfRows * numberOfColumns;

  NSUInteger numberOfPages = (NSUInteger)ceil((float)emojiCount / numberOfEmojisOnAPage);
  return numberOfPages;
}

// return the emojis for a category, given a staring and an ending index
- (NSMutableArray *)emojiTextsForCategory:(NSString *)category fromIndex:(NSUInteger)start toIndex:(NSUInteger)end {
  NSArray *emojis = [self emojiListForCategory:category];
  end = ([emojis count] > end)? end : [emojis count];
  NSIndexSet *index = [[[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(start, end-start)] autorelease];
  return [[emojis objectsAtIndexes:index] mutableCopy];
}

#pragma mark EmojiPageViewDelegate

- (void)setInRecentsEmoji:(NSString *)emoji {
  NSAssert(emoji != nil, @"Emoji can't be nil");

  NSMutableArray *recentEmojis = [self recentEmojis];
  for (int i = 0; i < [recentEmojis count]; ++i) {
    if ([recentEmojis[i] isEqualToString:emoji]) {
      [recentEmojis removeObjectAtIndex:i];
    }
  }
  [recentEmojis insertObject:emoji atIndex:0];
  [self setRecentEmojis:recentEmojis];
}

// add the emoji to recents
- (void)emojiPageView:(EmojiPageView *)emojiPageView didUseEmoji:(NSString *)emoji {
  [self setInRecentsEmoji:emoji];
  [self.delegate emojiKeyBoardView:self didUseEmoji:emoji];
}


@end
