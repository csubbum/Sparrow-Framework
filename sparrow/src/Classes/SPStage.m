//
//  SPStage.m
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2009 Incognitek. All rights reserved.
//

#import "SPStage.h"
#import "SPMakros.h"
#import "SPEnterFrameEvent.h"
#import "SPTouchProcessor.h"
#import "SPJuggler.h"

@implementation SPStage

@synthesize width = mWidth;
@synthesize height = mHeight;
@synthesize juggler = mJuggler;
@synthesize nativeView = mNativeView;

- (id)initWithWidth:(float)width height:(float)height
{    
    if (self = [super init])
    {
        mWidth = width;
        mHeight = height;
        mTouchProcessor = [[SPTouchProcessor alloc] initWithRoot:self];
        mJuggler = [[SPJuggler alloc] init];
    }
    return self;
}

- (id)init
{
    return [self initWithWidth:320 height:480];
}

- (void)advanceTime:(double)seconds
{    
    SP_CREATE_POOL(pool);
            
    // advance juggler
    [mJuggler advanceTime:seconds];
    
    // dispatch EnterFrameEvent
    SPEnterFrameEvent *enterFrameEvent = [[SPEnterFrameEvent alloc] 
        initWithType:SP_EVENT_TYPE_ENTER_FRAME passedTime:seconds];    
    [self dispatchEvent:enterFrameEvent];
    [enterFrameEvent release];

    SP_RELEASE_POOL(pool);
}

- (void)processTouches:(NSSet*)touches
{
    [mTouchProcessor processTouches:touches];
}

- (SPDisplayObject*)hitTestPoint:(SPPoint*)localPoint forTouch:(BOOL)isTouch;
{
    if (isTouch && (!self.isVisible || !self.isTouchable)) 
        return nil;
    
    SPDisplayObject *target = [super hitTestPoint:localPoint forTouch:isTouch];
    
    // different to other containers, the stage should acknowledge touches even in empty parts.
    if (!target)
    {
        SPRectangle *bounds = [SPRectangle rectangleWithX:self.x y:self.y 
                                                    width:self.width height:self.height];
        if ([bounds containsPoint:localPoint])      
            target = self;
    }
    return target;
}

#pragma mark -

- (float)width
{
    return mWidth;
}

- (void)setWidth:(float)width
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set width of stage"];
}

- (float)height
{
    return mHeight;
}

- (void)setHeight:(float)height
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set height of stage"];
}

- (void)setX:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set x-coordinate of stage"];
}

- (void)setY:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set y-coordinate of stage"];
}

- (void)setScaleX:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot scale stage"];
}

- (void)setScaleY:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot scale stage"];
}

- (void)setRotationZ:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot rotate stage"];
}

- (void)setFrameRate:(double)value
{
    [mNativeView setFrameRate:value];
}

- (double)frameRate
{
    return [mNativeView frameRate];
}

#pragma mark -

- (void)dealloc 
{    
    [mTouchProcessor release];
    [mJuggler release];
    [super dealloc];
}

@end
