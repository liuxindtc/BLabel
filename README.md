
# BLabel
We can change the color, alignment, shadow and line height.

    NSRange r = {25, 3};
    BLabel* l = [[BLabel alloc] initWithFrame:CGRectMake(10, 100, 100, 30)];
    [l setBackgroundColor:[UIColor whiteColor]];
    [l setText:@"123123123123123asfadaa b c d e f g h i j k n m l o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z"];
    [l setFont:[UIFont systemFontOfSize:50] range:r];
    [l setColor:[UIColor blackColor] range:NSMakeRange(0, 0)];
    [l setColor:[UIColor redColor] range:r];
	[l setLineHeight:16];
	[l setHighlightColor:[UIColor blueColor]];
	[l setNumberOfLines:4];
    [l setShadowColor:[UIColor colorWithRed:0.5 green:0.50 blue:1.0 alpha:0.5f]];
    [l setShadowBlur:1.0f];
    [l setShadowOffset:0.0f];
    [l setTextAlignment:BLabelTextAlignmentBottom|BLabelTextAlignmentLeft];

 FitType will change the font or frame to show all text if the frame of words is more than the frame of view.
 
    [l setFitTo:BLableFitToNone];
    [l setFitTo:BLableFitToRect];
    [l setFitTo:BLableFitToFontSize];
    
