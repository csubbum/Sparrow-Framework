//
//  SPView.m
//  Sparrow
//
//  Created by Robert Carone on 8/11/15.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPRectangle.h"
#import "SPView.h"
#import "SPViewController_Internal.h"

@implementation SPView
{
    SPViewController __weak *_viewController;
}

@dynamic layer;

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

#pragma mark View

- (void)displayLayer:(CALayer *)layer
{
    [_viewController nextFrame];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [_viewController viewDidResize:self.bounds];
    [_viewController nextFrame];
}

@end
