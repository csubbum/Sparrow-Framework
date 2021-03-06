//
//  SPTween.m
//  Sparrow
//
//  Created by Daniel Sperl on 09.05.09.
//  Copyright 2011-2015 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPTransitions.h"
#import "SPTween.h"
#import "SPTweenedProperty.h"

#import <objc/runtime.h>

#define TRANS_SUFFIX @":"

typedef float (*FnPtrTransition) (id, SEL, float);

@implementation SPTween
{
    id _target;
    SEL _transition;
    IMP _transitionFunc;
    SPTransitionBlock _transitionBlock;
    SP_GENERIC(NSMutableArray, SPTweenedProperty*) *_properties;
    
    double _totalTime;
    double _currentTime;
    double _delay;
    double _progress;
    
    NSInteger _repeatCount;
    double _repeatDelay;
    BOOL _reverse;
    BOOL _roundToInt;
    NSInteger _currentCycle;
    
    SPCallbackBlock _onStart;
    SPCallbackBlock _onUpdate;
    SPCallbackBlock _onRepeat;
    SPCallbackBlock _onComplete;
    SPTween *_nextTween;
}

#pragma mark Initialization

- (instancetype)initWithTarget:(id)target time:(double)time transition:(NSString *)transition
{
    if ((self = [super init]))
    {
        _target = [target retain];
        _totalTime = MAX(0.0001, time); // zero is not allowed
        _currentTime = 0;
        _delay = 0;
        _properties = [[NSMutableArray alloc] init];
        _repeatCount = 1;
        _currentCycle = -1;
        _reverse = NO;
        self.transition = transition;
    }
    return self;
}

- (instancetype)initWithTarget:(id)target time:(double)time
{
    return [self initWithTarget:target time:time transition:SPTransitionLinear];
}

- (instancetype)init
{
    SP_USE_DESIGNATED_INITIALIZER(initWithTarget:time:transition:);
    return nil;
}

- (void)dealloc
{
    [_target release];
    [_properties release];
    [_transitionBlock release];
    [_onStart release];
    [_onUpdate release];
    [_onRepeat release];
    [_onComplete release];
    [_nextTween release];
    [super dealloc];
}

+ (instancetype)tweenWithTarget:(id)target time:(double)time transition:(NSString *)transition
{
    return [[[self alloc] initWithTarget:target time:time transition:transition] autorelease];
}

+ (instancetype)tweenWithTarget:(id)target time:(double)time
{
    return [[[self alloc] initWithTarget:target time:time] autorelease];
}

#pragma mark Methods

- (void)animateProperty:(NSString *)property targetValue:(double)value
{    
    if (!_target) return; // tweening nil just does nothing.
    
    SPTweenedProperty *tweenedProp = [[SPTweenedProperty alloc] initWithTarget:_target name:property endValue:value];
    [_properties addObject:tweenedProp];
    [tweenedProp release];
}

- (void)animateProperties:(SP_GENERIC(NSDictionary, NSString*, NSNumber*) *)properties
{
    for (NSString *property in properties)
        [self animateProperty:property targetValue:[properties[property] doubleValue]];
}

- (void)moveToX:(float)x y:(float)y
{
    [self animateProperty:@"x" targetValue:x];
    [self animateProperty:@"y" targetValue:y];
}

- (void)scaleTo:(float)scale
{
    [self animateProperty:@"scaleX" targetValue:scale];
    [self animateProperty:@"scaleY" targetValue:scale];
}

- (void)fadeTo:(float)alpha
{
    [self animateProperty:@"alpha" targetValue:alpha];
}

- (float)endValueOfProperty:(NSString *)property
{
    NSInteger index = [_properties indexOfObjectPassingTest:^BOOL (SPTweenedProperty *obj, NSUInteger idx, BOOL *stop)
    {
        if ([obj.name isEqualToString:property])
            return YES;
        
        return NO;
    }];
    
    if (index == NSNotFound)
        [NSException raise:SPExceptionInvalidOperation
                    format:@"The property '%@' is not animated", property];
    
    return [_properties[index] endValue];
}

#pragma mark SPAnimatable

- (void)advanceTime:(double)time
{
    if (time == 0.0 || (_repeatCount == 1 && _currentTime == _totalTime))
        return; // nothing to do
    else if ((_repeatCount == 0 || _repeatCount > 1) && _currentTime == _totalTime)
        _currentTime = 0.0;

    double previousTime = _currentTime;
    double restTime = _totalTime - _currentTime;
    double carryOverTime = time > restTime ? time - restTime : 0.0;
    _currentTime = MIN(_totalTime, _currentTime + time);
    BOOL isStarting = _currentCycle < 0 && previousTime <= 0 && _currentTime > 0;

    if (_currentTime <= 0) return; // the delay is not over yet

    if (isStarting)
    {
        _currentCycle++;
        if (_onStart) _onStart();
    }

    float ratio = _currentTime / _totalTime;
    BOOL reversed = _reverse && (_currentCycle % 2 == 1);
    FnPtrTransition transFunc = (FnPtrTransition) _transitionFunc;
    Class transClass = [SPTransitions class];
    
    if (_transitionBlock)
    {
        _progress = reversed ? _transitionBlock(1.0 - ratio) :
                               _transitionBlock(ratio);
    }
    else
    {
        _progress = reversed ? transFunc(transClass, _transition, 1.0 - ratio) :
                               transFunc(transClass, _transition, ratio);
    }
    
    for (SPTweenedProperty *prop in _properties)
    {
        if (isStarting) prop.startValue = prop.currentValue;
        prop.rountToInt = _roundToInt;
        
        [prop update:_progress];
    }

    if (_onUpdate) _onUpdate();

    if (previousTime < _totalTime && _currentTime >= _totalTime)
    {
        if (_repeatCount == 0 || _repeatCount > 1)
        {
            _currentTime = -_repeatDelay;
            _currentCycle++;
            if (_repeatCount > 1) _repeatCount--;
            if (_onRepeat) _onRepeat();
        }
        else
        {
            [self dispatchEventWithType:SPEventTypeRemoveFromJuggler];
            if (_onComplete) _onComplete();
        }
    }

    if (carryOverTime)
        [self advanceTime:carryOverTime];
}

#pragma mark Properties

- (NSString *)transition
{
    NSString *selectorName = NSStringFromSelector(_transition);
    return [selectorName substringToIndex:selectorName.length - [TRANS_SUFFIX length]];
}

- (void)setTransition:(NSString *)transition
{
    NSString *transMethod = [transition stringByAppendingString:TRANS_SUFFIX];
    _transition = NSSelectorFromString(transMethod);
    if (![SPTransitions respondsToSelector:_transition])
        [NSException raise:SPExceptionInvalidOperation
                    format:@"transition not found: '%@'", transition];
    _transitionFunc = [SPTransitions methodForSelector:_transition];
}

- (BOOL)isComplete
{
    return _currentTime >= _totalTime && _repeatCount == 1;
}

- (void)setDelay:(double)delay
{
    _currentTime = _currentTime + _delay - delay;
    _delay = delay;
}

@end
