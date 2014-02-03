//
//  EmojiPageView.m
//  EmojiKeyBoard
//
//  Created by Ayush on 09/05/13.
//  Copyright (c) 2013 Ayush. All rights reserved.
//

#import "EmojiPageView.h"

#define BUTTON_FONT_SIZE 32

@interface EmojiPageView ()

@property (nonatomic, assign) CGSize buttonSize;
@property (nonatomic, retain) NSMutableArray *buttons;
@property (nonatomic, assign) NSUInteger columns;
@property (nonatomic, assign) NSUInteger rows;

@end

@implementation EmojiPageView
@synthesize buttonSize = buttonSize_;
@synthesize buttons = buttons_;
@synthesize columns = columns_;
@synthesize rows = rows_;
@synthesize delegate = delegate_;

- (void)setButtonTexts:(NSMutableArray *)buttonTexts {
    
    NSAssert(buttonTexts != nil, @"Array containing texts to be set on buttons is nil");
    
    // If page has enough buttons to accomodate number of emojis for the page, then just reassign
    // new emojis to the buttons. Otherwise create new buttons for page.
    if ([self.buttons count] >= [buttonTexts count]) {
        
        // just reset text on each button
        for (NSUInteger i = 0; i < [self.buttons count]; ++i) {
            
            // If we have text for button, then set it and enable button. Otherwise clear button title and disable.
            if (i < [buttonTexts count]) {
                [self.buttons[i] setTitle:buttonTexts[i] forState:UIControlStateNormal];
                [self.buttons[i] setEnabled:YES];
            } else {
                [self.buttons[i] setTitle:nil forState:UIControlStateNormal];
                [self.buttons[i] setEnabled:NO];
            }
        }
        
    } else {
        
        [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.buttons = nil;
        self.buttons = [NSMutableArray arrayWithCapacity:self.rows * self.columns];
        for (NSUInteger i = 0; i < [buttonTexts count]; ++i) {
            UIButton *button = [self createButtonAtIndex:i];
            [button setTitle:buttonTexts[i] forState:UIControlStateNormal];
            [self addToViewButton:button];
        }
    }
}

- (void)addToViewButton:(UIButton *)button {
    
    NSAssert(button != nil, @"Button to be added is nil");
    
    [self.buttons addObject:button];
    [self addSubview:button];
}

// Padding is the expected space between two buttons.
// Thus, space of top button = padding / 2
// extra padding according to particular button's pos = pos * padding
// Margin includes, size of buttons in between = pos * buttonSize
// Thus, margin = padding / 2
//                + pos * padding
//                + pos * buttonSize

- (CGFloat)XMarginForButtonInColumn:(NSInteger)column {
    CGFloat padding = ((CGRectGetWidth(self.bounds) - self.columns * self.buttonSize.width) / self.columns);
    return (padding / 2 + column * (padding + self.buttonSize.width));
}

- (CGFloat)YMarginForButtonInRow:(NSInteger)rowNumber {
    CGFloat padding = ((CGRectGetHeight(self.bounds) - self.rows * self.buttonSize.height) / self.rows);
    return (padding / 2 + rowNumber * (padding + self.buttonSize.height));
}

- (UIButton *)createButtonAtIndex:(NSUInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.font = [UIFont fontWithName:@"Apple color emoji" size:BUTTON_FONT_SIZE];
    NSInteger row = (NSInteger)(index / self.columns);
    NSInteger column = (NSInteger)(index % self.columns);
    button.frame = CGRectIntegral(CGRectMake([self XMarginForButtonInColumn:column],
                                             [self YMarginForButtonInRow:row],
                                             self.buttonSize.width,
                                             self.buttonSize.height));
    [button addTarget:self action:@selector(emojiButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (id)initWithFrame:(CGRect)frame buttonSize:(CGSize)buttonSize rows:(NSUInteger)rows columns:(NSUInteger)columns {
    self = [super initWithFrame:frame];
    if (self) {
        self.buttonSize = buttonSize;
        self.columns = columns;
        self.rows = rows;
        self.buttons = [[NSMutableArray alloc] initWithCapacity:rows * columns];
    }
    return self;
}

- (void)emojiButtonPressed:(UIButton *)button {
    [self.delegate emojiPageView:self didUseEmoji:button.titleLabel.text];
}

- (void)dealloc {
    self.buttons = nil;
}

@end
