//
//  TileCutterCore.h
//  Tile Cutter
//
//  Created by Stepan Generalov on 28.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TileOperation.h"


@interface TileCutterCore : NSObject  <TileOperationDelegate>
{
    id AppDelegate;
}

#pragma mark  Public Properties

// Properties of Tiling Operation
@property(readwrite) BOOL POTTiles;
@property(readwrite) BOOL rigidTiles;
@property(readwrite) BOOL keepAllTiles;
@property(readwrite) NSUInteger tileWidth;
@property(readwrite) NSUInteger tileHeight;
@property(readwrite) float_t contentScaleFactor;
@property(readwrite) TileCutterOutputPrefs outputFormat;
@property(readwrite, copy) NSString *inputFilename;
@property(readwrite, copy) NSString *outputBaseFilename;
@property(readwrite, copy) NSString *outputSuffix;

// Properties of Global Tiling Operation Status
@property(readwrite) int tileRowCount;
@property(readwrite) int tileColCount;
@property(readwrite) int progressCol;
@property(readwrite) int progressRow;

// TileOperationDelegate messages will be forwarded after processing to this delegate
@property(readwrite, assign) NSObject<TileOperationDelegate> *operationsDelegate;

#pragma mark Public Methods

- (id) initWithDelegate:(id)aDelegate;
- (void) startSavingTiles;

#pragma mark Private  Properties

// Queue of Operations - used internally
@property(nonatomic, retain) NSOperationQueue *queue;

// Info, prepared for output.plist - used internally
@property(readwrite, retain) NSArray *allTilesInfo;
@property(readwrite, retain) NSDictionary *imageInfo;

@end
