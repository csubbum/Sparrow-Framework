//
//  SPVertexData.m
//  Sparrow
//
//  Created by Daniel Sperl on 18.02.13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPVertexData.h"
#import "SPMatrix.h"
#import "SPRectangle.h"
#import "SPPoint.h"
#import "SPMacros.h"
#import "SPFunctions.h"

#define MIN_ALPHA 0.001f

/// --- C methods ----------------------------------------------------------------------------------

void premultiplyAlpha(SPVertex *vertex)
{
    GLKVector4 color = vertex->color;
    vertex->color.r = color.r * color.a;
    vertex->color.g = color.g * color.a;
    vertex->color.b = color.b * color.a;
}

void unmultiplyAlpha(SPVertex *vertex)
{
    GLKVector4 color = vertex->color;
    if (color.a != 0.0f)
    {
        vertex->color.r = color.r / color.a;
        vertex->color.g = color.g / color.a;
        vertex->color.b = color.b / color.a;
    }
}

/// --- Class implementation -----------------------------------------------------------------------

@implementation SPVertexData
{
    SPVertex *mVertices;
    int mNumVertices;
    BOOL mPremultipliedAlpha;
}

@synthesize vertices = mVertices;
@synthesize numVertices = mNumVertices;
@synthesize premultipliedAlpha = mPremultipliedAlpha;

- (id)initWithSize:(int)numVertices premultipliedAlpha:(BOOL)pma
{
    if ((self = [super init]))
    {
        mPremultipliedAlpha = pma;
        self.numVertices = numVertices;
    }
    
    return self;
}

- (id)initWithSize:(int)numVertices
{
    return [self initWithSize:numVertices premultipliedAlpha:NO];
}

- (id)init
{
    return [self initWithSize:0];
}

- (void)dealloc
{
    free(mVertices);
}

- (void)copyToVertexData:(SPVertexData *)target
{
    [self copyToVertexData:target atIndex:0];
}

- (void)copyToVertexData:(SPVertexData *)target atIndex:(int)targetIndex
{
    if (target.numVertices - targetIndex < mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Target too small"];
    
    memcpy(&target->mVertices[targetIndex], mVertices, sizeof(SPVertex) * mNumVertices);
}

- (SPVertex)vertexAtIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];

    return mVertices[index];
}

- (void)setVertex:(SPVertex)vertex atIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];

    mVertices[index] = vertex;
    
    if (mPremultipliedAlpha)
        premultiplyAlpha(&mVertices[index]);
}

- (SPPoint *)positionAtIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    GLKVector2 position = mVertices[index].position;
    return [[SPPoint alloc] initWithX:position.x y:position.y];
}

- (void)setPosition:(SPPoint *)position atIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    mVertices[index].position = GLKVector2Make(position.x, position.y);
}

- (SPPoint *)texCoordsAtIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    GLKVector2 texCoords = mVertices[index].texCoords;
    return [[SPPoint alloc] initWithX:texCoords.x y:texCoords.y];
}

- (void)setTexCoords:(SPPoint *)texCoords atIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    mVertices[index].texCoords = GLKVector2Make(texCoords.x, texCoords.y);
}

- (void)setColor:(int)color alpha:(float)alpha atIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    alpha = SP_CLAMP(alpha, 0.0f, 1.0f);
    float multiplier = 1.0f / 255.0f;
    
    if (mPremultipliedAlpha)
    {
        alpha = MAX(MIN_ALPHA, alpha); // zero alpha would wipe out all color data
        multiplier *= alpha;
    }
    
    mVertices[index].color.r = SP_COLOR_PART_RED(color)   * multiplier;
    mVertices[index].color.g = SP_COLOR_PART_GREEN(color) * multiplier;
    mVertices[index].color.b = SP_COLOR_PART_BLUE(color)  * multiplier;
    mVertices[index].color.a = alpha;
}

- (uint)colorAtIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];

    GLKVector4 color = mVertices[index].color;
    float alpha = color.a;
    
    if (mPremultipliedAlpha && alpha != 0.0f)
    {
        color.r /= alpha;
        color.g /= alpha;
        color.b /= alpha;
    }
    
    return GLKVector4ToSPColor(color);
}

- (void)setColor:(uint)color atIndex:(int)index
{
    float alpha = mVertices[index].color.a;
    [self setColor:color alpha:alpha atIndex:index];
}

- (void)setAlpha:(float)alpha atIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    if (mPremultipliedAlpha)
    {
        uint color = [self colorAtIndex:index];
        [self setColor:color alpha:alpha atIndex:index];
    }
    else
    {
        mVertices[index].color.a = alpha;
    }
}

- (float)alphaAtIndex:(int)index
{
    if (index < 0 || index >= mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid vertex index"];
    
    return mVertices[index].color.a;
}

- (void)scaleAlphaBy:(float)factor
{
    [self scaleAlphaBy:factor atIndex:0 numVertices:mNumVertices];
}

- (void)scaleAlphaBy:(float)factor atIndex:(int)index numVertices:(int)count
{
    if (factor == 1.0f) return;
    
    if (index < 0 || index + count > mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid index range"];
    
    for (int i=index; i<index+count; ++i)
    {
        SPVertex *vertex = &mVertices[i];
        
        float oldAlpha = vertex->color.a;
        float newAlpha = oldAlpha * factor;
        
        if (mPremultipliedAlpha)
        {
            if (newAlpha < MIN_ALPHA) newAlpha = MIN_ALPHA;
            if (oldAlpha < MIN_ALPHA) oldAlpha = MIN_ALPHA;
        }
        
        vertex->color.a = newAlpha;
        
        if (mPremultipliedAlpha)
        {
            vertex->color.r = vertex->color.r / oldAlpha * newAlpha;
            vertex->color.g = vertex->color.g / oldAlpha * newAlpha;
            vertex->color.b = vertex->color.b / oldAlpha * newAlpha;
        }
    }
}

- (void)appendVertex:(SPVertex)vertex
{
    self.numVertices += 1;
    
    if (mVertices) // just to shut down an Analyzer warning ... this will never be NULL.
    {
        mVertices[mNumVertices-1] = vertex;
        if (mPremultipliedAlpha) premultiplyAlpha(&mVertices[mNumVertices-1]);
    }
}

- (void)transformVerticesWithMatrix:(SPMatrix *)matrix atIndex:(int)index numVertices:(int)count
{
    if (index < 0 || index + count > mNumVertices)
        [NSException raise:SP_EXC_INDEX_OUT_OF_BOUNDS format:@"Invalid index range"];
    
    GLKMatrix3 glkMatrix = [matrix convertToGLKMatrix3];
    
    for (int i=index; i<index+count; ++i)
    {
        GLKVector2 pos = mVertices[i].position;
        mVertices[i].position.x = glkMatrix.m00 * pos.x + glkMatrix.m10 * pos.y + glkMatrix.m20;
        mVertices[i].position.y = glkMatrix.m11 * pos.y + glkMatrix.m01 * pos.x + glkMatrix.m21;
    }
}

- (void)setNumVertices:(int)value
{
    if (value != mNumVertices)
    {
        if (value)
        {
            if (mVertices)
                mVertices = realloc(mVertices, sizeof(SPVertex) * value);
            else
                mVertices = malloc(sizeof(SPVertex) * value);
            
            if (value > mNumVertices)
            {
                memset(&mVertices[mNumVertices], 0, sizeof(SPVertex) * (value - mNumVertices));
                
                for (int i=mNumVertices; i<value; ++i)
                    mVertices[i].color.a = 1.0f; // alpha should be '1' per default
            }
        }
        else
        {
            free(mVertices);
            mVertices = NULL;
        }
        
        mNumVertices = value;
    }
}

- (SPRectangle *)bounds
{
    return [self boundsAfterTransformation:nil];
}

- (SPRectangle *)boundsAfterTransformation:(SPMatrix *)matrix
{
    float minX = FLT_MAX, maxX = -FLT_MAX, minY = FLT_MAX, maxY = -FLT_MAX;
    
    if (matrix)
    {
        for (int i=0; i<4; ++i)
        {
            GLKVector2 position = mVertices[i].position;
            SPPoint *transformedPoint = [matrix transformPointWithX:position.x y:position.y];
            float tfX = transformedPoint.x;
            float tfY = transformedPoint.y;
            minX = MIN(minX, tfX);
            maxX = MAX(maxX, tfX);
            minY = MIN(minY, tfY);
            maxY = MAX(maxY, tfY);
        }
    }
    else
    {
        for (int i=0; i<4; ++i)
        {
            GLKVector2 position = mVertices[i].position;
            minX = MIN(minX, position.x);
            maxX = MAX(maxX, position.x);
            minY = MIN(minY, position.y);
            maxY = MAX(maxY, position.y);
        }
    }
    
    return [SPRectangle rectangleWithX:minX y:minY width:maxX-minX height:maxY-minY];
}

- (void)setPremultipliedAlpha:(BOOL)value
{
    [self setPremultipliedAlpha:value updateVertices:YES];
}

- (void)setPremultipliedAlpha:(BOOL)value updateVertices:(BOOL)update
{
    if (value == mPremultipliedAlpha) return;
    
    if (update)
    {
        if (value)
        {
            for (int i=0; i<mNumVertices; ++i)
                premultiplyAlpha(&mVertices[i]);
        }
        else
        {
            for (int i=0; i<mNumVertices; ++i)
                unmultiplyAlpha(&mVertices[i]);
        }
    }
    
    mPremultipliedAlpha = value;
}

- (SPVertex *)vertices
{
    return mVertices;
}

@end
