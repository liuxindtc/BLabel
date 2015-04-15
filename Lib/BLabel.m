//
//  BLabel.m
//

#import "BLabel.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

#define SELF_CHECK(a) if (!_text) return a
#define BLAddAttribute(b, c, d) \
BLabelAttribute* attr = [[BLabelAttribute alloc] initWithKey:b value:c range:d]; \
NSString* key = [attr attributeKey];\
[_attributes setObject:attr forKey:key]; \
[_attributeKeys addObject:key]

#define IS_ALIGNMENT(a, b) (((a) & (b)) > 0)
#define IS_FIT(a, b) (((a) & (b)) > 0)

CGRect CTLineGetTypographicBoundsAsRect(CTLineRef line, CGPoint lineOrigin) {
    CGFloat ascent = 0;
    CGFloat descent = 0;
    CGFloat leading = 0;
    CGFloat width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat height = ascent + descent + leading;

    return CGRectMake(lineOrigin.x,
                      lineOrigin.y - ascent,
                      width,
                      height);
}

UIFont* UIFontCreate(CTFontRef ctFont)
{
    CFStringRef fontName = CTFontCopyFullName(ctFont);
    CGFloat fontSize     = CTFontGetSize(ctFont);
    UIFont* ret          = [UIFont fontWithName:(__bridge NSString*)fontName size:fontSize];
    CFRelease(fontName);
    return ret;
}

CTFontRef CTFontCreate(UIFont *font)
{
    CTFontRef ctFont = CTFontCreateWithName((CFStringRef)font.fontName,
                                            font.pointSize,
                                            NULL);
    return ctFont;
}

@interface BLabelAttribute : NSObject
@property (nonatomic, strong) id key;
@property (nonatomic, strong) id value;
@property (nonatomic, assign) NSRange range;
- (id)initWithKey:(id)key value:(id)value range:(NSRange)range;
- (NSDictionary*)dic;
- (NSString*)attributeKey;
@end

@implementation BLabelAttribute
- (id)initWithKey:(id)key value:(id)value range:(NSRange)range
{
    self = [super init];
    if (self)
    {
        _key   = key;
        _value = value;
        _range = range;
    }
    return self;
}
- (NSDictionary*)dic
{
    return _key && _value ?  @{_key:_value} : [[NSDictionary alloc] init];
}
- (NSString*)attributeKey
{
    return _range.length > 0 ?
    [NSString stringWithFormat:@"_%@_%@_%@", @(_range.location), @(_range.length), _key] :
    [NSString stringWithFormat:@"___%@", _key];
}
@end

@interface BLabelLine:NSObject
@property (nonatomic, assign) CGRect        bounds;
@property (nonatomic, assign) CTLineRef     line;
@property (nonatomic, strong) UIColor*      highLight;
@property (nonatomic, assign) CFRange       range;
@property (nonatomic, assign) CGFloat       lineHeight;
@end

@implementation BLabelLine

- (void)dealloc
{
    if (_line)
    {
        CFRelease(_line);
        _line = NULL;
    }
}

- (void)setLine:(CTLineRef)line
{
    if (_line)
    {
        CFRelease(_line);
        _line = NULL;
    }
    
    _line = CFRetain(line);
}
@end

@interface BLabel()
{
    CGFloat                     _textHeight;
    NSMutableDictionary*        _attributes;
    NSMutableArray*             _attributeKeys;

    NSMutableArray*             _lines;
    NSAttributedString*         _aString;
    CTTypesetterRef             _typeSetter;

    BOOL                        _reDisplay;

    NSUInteger                  _fontChangeSize;
}
@end

@implementation BLabel

- (void)dealloc
{
    if (_typeSetter)
    {
        CFRelease(_typeSetter);
        _typeSetter = NULL;
    }
}

- (void)clearRangeAttribute
{
    SELF_CHECK();
    [_attributes removeAllObjects];
}

- (void)setFont:(UIFont*)font
{
    [self setFont:font range:(NSRange){0, 0}];
}

- (void)setFont:(UIFont*)font range:(NSRange)range
{
    BLAddAttribute((__bridge id)kCTFontAttributeName, font, range);
    // CFRelease(f);
    _fontChangeSize = 0;
    [self formatFrame];
    [self setNeedsDisplay];
}

- (void)setColor:(UIColor*)color
{
    [self setColor:color range:(NSRange){0, 0}];
}
- (void)setColor:(UIColor*)color range:(NSRange)range
{
    BLAddAttribute((__bridge id)kCTForegroundColorAttributeName, color, range);
    [self formatFrame];
    [self setNeedsDisplay];
}

- (void)setText:(NSString *)text
{
    _text = [text copy];
    _fontChangeSize = 0;
    [self formatFrame];
    [self setNeedsDisplay];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setBackgroundColor:[UIColor clearColor]];

        _reDisplay      = NO;

        _textHeight     = 0.0f;
        _attributes     = [[NSMutableDictionary alloc] init];
        _attributeKeys  = [[NSMutableArray alloc] init];
        _lines          = [[NSMutableArray alloc] init];

        _numberOfLines  = 0;
        _highlightColor = nil;
        _lineHeight     = 0.0f;
        _shadowOffset   = 0.0f;
        _shadowColor    = nil;
        _shadowBlur     = 5.0f;
        _textAlignment  = BLabelTextAlignmentLeft|BLabelTextAlignmentMiddle;
        _fitTo          = BLableFitToRect;
        _fontChangeSize = 0;

        [self setFont:[UIFont systemFontOfSize:18.0f] range:NSMakeRange(0, 0)];
    }
    return self;
}

- (void)drawLines:(CGContextRef)context
{
    [_lines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BLabelLine* l = (BLabelLine*)obj;
        if (_highlightColor)
        {
            CGFloat descent;
            CTLineGetTypographicBounds(l.line, NULL, &descent, NULL);
            CGRect r = l.bounds;
            r.size.height += 1;
            r.origin.y -= descent + 1;
            CGContextSetFillColorWithColor(context, _highlightColor.CGColor);
            CGContextFillRect(context, r);
        }

        CGContextSetTextPosition(context, l.bounds.origin.x, l.bounds.origin.y);
        CTLineDraw(l.line, context);
    }];
}

- (void)drawShadow:(CGContextRef)context
{
    if (_shadowColor)
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGColorRef colorRef = CGColorCreate(colorSpace, CGColorGetComponents([_shadowColor CGColor]));
        CGContextSetShadowWithColor(context, CGSizeMake(_shadowOffset, _shadowOffset), _shadowBlur, colorRef);
        CGColorSpaceRelease(colorSpace);
        CGColorRelease(colorRef);
    }
}

- (void)formatFrame
{
    if (!_text || [_text length] < 1)
    {
        return;
    }

    __block BOOL isMin = NO;
    NSMutableAttributedString* aString = [[NSMutableAttributedString alloc] initWithString:_text];
    [_attributeKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BLabelAttribute* a = [_attributes objectForKey:obj];
        if (a)
        {
            if ([a.key compare:(id)kCTFontAttributeName] == NSOrderedSame)
            {
                UIFont* uf = (UIFont*)a.value;
                isMin = (_fontChangeSize + 1 > uf.pointSize);
                CTFontRef cf = CTFontCreateWithName((CFStringRef)uf.fontName,
                                                    uf.pointSize - _fontChangeSize,
                                                    NULL);
                BLabelAttribute* attribute = [[BLabelAttribute alloc] initWithKey:a.key value:(__bridge_transfer id)cf range:a.range];
                a = attribute;
            }

            if (a.range.length > 0)
            {
                [aString addAttribute:a.key value:a.value range:a.range];
            }
            else
            {
                NSRange r = {0, [_text length]};
                [aString addAttribute:a.key value:a.value range:r];
            }
        }
    }];

    _aString = aString;

    if (_typeSetter)
    {
        CFRelease(_typeSetter);
    }
    _typeSetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)aString);

    _textHeight = 0;

    NSInteger lineNumber = 0;
    NSInteger index = 0;
    [_lines removeAllObjects];
    do
    {
        CFIndex     lineLength = CTTypesetterSuggestLineBreak(_typeSetter, index, self.bounds.size.width);
        CFRange     lineRange  = CFRangeMake(index, lineLength);
        CTLineRef   line       = CTTypesetterCreateLine(_typeSetter, lineRange);
        CGRect      lineRect   = CTLineGetTypographicBoundsAsRect(line, CGPointMake(0, 0));

        BLabelLine* lableLine = [[BLabelLine alloc] init];
        [lableLine setLine:line];
        [lableLine setRange:lineRange];
        CFRelease(line);
        if (_highlightColor)
        {
            NSString* substring = [_text substringWithRange:NSMakeRange(lineRange.location, lineRange.length)];
            substring = [substring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([substring length] > 0)
            {
                [lableLine setHighLight:_highlightColor];
            }
        }
        [_lines addObject:lableLine];

        lableLine.lineHeight = _lineHeight > 0.0f ? _lineHeight : 0.0f;
        lableLine.lineHeight = lableLine.lineHeight > lineRect.size.height ? lableLine.lineHeight : lineRect.size.height;

        _textHeight += lableLine.lineHeight;
        index       += lineLength;

    } while (++lineNumber != _numberOfLines && index < [_text length]);
    _currentLineNumber = lineNumber;
    
    if (_typeSetter)
    {
        CFRelease(_typeSetter);
        _typeSetter = NULL;
    }

    if (self.frame.size.height < _textHeight && !IS_FIT(_fitTo, BLableFitToNone))
    {
        if (IS_FIT(_fitTo, BLableFitToFontSize))
        {
            [self setFrame:CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _textHeight)];
            if (_delegate && [_delegate respondsToSelector:@selector(labelFrameChanged:)])
            {
                [_delegate labelFrameChanged:self];
            }
        }
        else if (IS_FIT(_fitTo, BLableFitToRect) && !isMin)
        {
            if (_fontChangeSize == 0)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(labelFontSizeChanged:)])
                {
                    [_delegate labelFontSizeChanged:self];
                }
            }

            _fontChangeSize++;

            [self formatFrame];
        }
    }
}

- (void)createDraw
{
    SELF_CHECK();

    CGFloat offsetY = 0.0f;
    if (_textHeight < self.frame.size.height && !IS_ALIGNMENT(_textAlignment, BLabelTextAlignmentTop))
    {
        offsetY = IS_ALIGNMENT(_textAlignment, BLabelTextAlignmentMiddle) ?
        (self.frame.size.height - _textHeight) / 2 : self.frame.size.height - _textHeight;
    }

    __block CGFloat   y = self.bounds.origin.y + self.bounds.size.height - offsetY;

    [_lines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BLabelLine* l = (BLabelLine*)obj;

        CGFloat x = 0.0f;
        if (IS_ALIGNMENT(_textAlignment, BLabelTextAlignmentJustify))
        {
            CTLineRef justifiedLine = CTLineCreateJustifiedLine(l.line, 1.0, self.bounds.size.width);
            l.line = justifiedLine;
            CFRelease(justifiedLine);
        }
        else if (IS_ALIGNMENT(_textAlignment, BLabelTextAlignmentLeft))
        {
            x = CTLineGetPenOffsetForFlush(l.line, 0, self.bounds.size.width);
        }
        else if (IS_ALIGNMENT(_textAlignment, BLabelTextAlignmentCenter))
        {
            x = CTLineGetPenOffsetForFlush(l.line, 0.5, self.bounds.size.width);
        }
        else if (IS_ALIGNMENT(_textAlignment, BLabelTextAlignmentRight))
        {
            x = CTLineGetPenOffsetForFlush(l.line, 2, self.bounds.size.width);
        }

        CGRect lineRect = CTLineGetTypographicBoundsAsRect(l.line, CGPointMake(x, y));

        [l setBounds:lineRect];

        y -= l.lineHeight;
    }];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSaveGState(context);

    [self createDraw];
    [self drawShadow:context];
    [self drawLines:context];
    
    CGContextRestoreGState(context);
    [super drawRect:self.bounds];
}


@end
