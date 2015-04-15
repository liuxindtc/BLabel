//
// BLabel.h
//
// Version:1.0.0.1
//

#import <UIKit/UIKit.h>

#define BLabelTextAlignmentLeft     (1 << 0)
#define BLabelTextAlignmentCenter   (1 << 1)
#define BLabelTextAlignmentRight    (1 << 2)
#define BLabelTextAlignmentJustify  (1 << 3)
#define BLabelTextAlignmentTop      (1 << 4)
#define BLabelTextAlignmentMiddle   (1 << 5)
#define BLabelTextAlignmentBottom   (1 << 6)

#define BLableFitToNone             (1 << 0)
#define BLableFitToFontSize         (1 << 1)
#define BLableFitToRect             (1 << 2)

@class BLabel;
@protocol BLabelDelegate<NSObject>
@optional
- (void)labelFrameChanged:(BLabel*)label;
- (void)labelFontSizeChanged:(BLabel*)label;
@end


@interface BLabel : UIView

@property (nonatomic, weak)   id<BLabelDelegate>    delegate;

@property (nonatomic, strong) NSString*             text;
@property (nonatomic, assign) NSUInteger            numberOfLines;
@property (nonatomic, strong) UIColor*              highlightColor;
@property (nonatomic, assign) CGFloat               lineHeight;
@property (nonatomic, readonly) NSInteger           currentLineNumber;

@property (nonatomic, assign) CGFloat               shadowOffset;
@property (nonatomic, strong) UIColor*              shadowColor;
@property (nonatomic, assign) CGFloat               shadowBlur;
@property (nonatomic, assign) NSUInteger            textAlignment;
@property (nonatomic, assign) NSUInteger            fitTo;

- (void)setFont:(UIFont*)font;
- (void)setFont:(UIFont*)font range:(NSRange)range;
- (void)setColor:(UIColor*)color;
- (void)setColor:(UIColor*)color range:(NSRange)range;

- (void)clearRangeAttribute;
@end
