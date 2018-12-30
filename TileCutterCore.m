//
//  TileCutterCore.m
//  Tile Cutter
//
//  Created by Stepan Generalov on 28.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Tile_CutterAppDelegate.h"
#import "TileCutterCore.h"
#import "NSImage-Tile.h"

@implementation TileCutterCore

@synthesize keepAllTiles, tileWidth, tileHeight, inputFilename, 
			outputBaseFilename, outputSuffix, operationsDelegate, 
			queue, allTilesInfo, imageInfo, outputFormat;
@synthesize tileRowCount, tileColCount, progressCol, progressRow;
@synthesize rigidTiles;
@synthesize contentScaleFactor;
@synthesize POTTiles;

#pragma mark Public Methods

- (id) init
{
	if ( self == [super init]) 
	{
		self.queue = [[[NSOperationQueue alloc] init] autorelease];
		[self.queue setMaxConcurrentOperationCount:1];
		
		self.outputFormat = NSPNGFileType;
		self.outputSuffix = @"";
		self.keepAllTiles = NO;
		self.rigidTiles = NO;
        self.contentScaleFactor = 1.0f;
	}
	
	return self;
}

- (id) initWithDelegate:(id)aDelegate
{
	if ( self == [super init])
	{
        AppDelegate = aDelegate;
		self.queue = [[[NSOperationQueue alloc] init] autorelease];
		[self.queue setMaxConcurrentOperationCount:1];
		
		self.outputFormat = NSPNGFileType;
		self.outputSuffix = @"";
		self.keepAllTiles = NO;
		self.rigidTiles = NO;
        self.contentScaleFactor = 1.0f;
	}
	
	return self;
}

- (void) dealloc
{
	self.queue = nil;
	self.allTilesInfo = nil;
	self.imageInfo = nil;	
	self.inputFilename = nil;
	self.outputBaseFilename = nil;
	self.outputSuffix = nil;
	
	[super dealloc];
}

- (void) startSavingTiles
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; 
    
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile: self.inputFilename] autorelease];
        
    progressCol = 0;
    progressRow = 0;
    
    tileRowCount = [image rowsWithTileHeight: self.tileHeight];
    tileColCount = [image columnsWithTileWidth: self.tileWidth];
    
    NSSize outputImageSizeForPlist = [image size];
    outputImageSizeForPlist.width /= self.contentScaleFactor;
    outputImageSizeForPlist.height /= self.contentScaleFactor;
    self.imageInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                      [self.inputFilename lastPathComponent], @"Filename",
                      NSStringFromSize(outputImageSizeForPlist), @"Size", nil];
    
    self.allTilesInfo = [NSMutableArray arrayWithCapacity: tileRowCount * tileColCount];
    
    // One ImageRep for all TileOperation
    NSBitmapImageRep *imageRep =
    [[[NSBitmapImageRep alloc] initWithCGImage:[image CGImageForProposedRect:NULL context:NULL hints:nil]] autorelease];
    
    if (self.tileHeight && self.tileWidth) {
        //rect cut
        
        for (int row = 0; row < tileRowCount; row++)
        {
            for (int column = 0; column < tileColCount; column++)
            {
                TileOperation *op = [[TileOperation alloc] init];
                op.row = row * self.tileHeight;
                op.column = column * self.tileWidth;
                op.tileWidth = self.tileWidth;
                op.tileHeight = self.tileHeight;
                op.imageRep = imageRep;
                op.baseFilename = outputBaseFilename;
                op.delegate = self;
                op.outputFormat = self.outputFormat;
                op.outputSuffix = self.outputSuffix;
                op.skipTransparentTiles = (! self.keepAllTiles );
                op.rigidTiles = self.rigidTiles;
                op.POTTiles = self.POTTiles;
                [queue addOperation:op];
                [op release];
            }
        }
        
    } else {
        //auto cut
        
        unsigned char *srcData = [imageRep bitmapData];
        int len = (int)outputImageSizeForPlist.width * (int)outputImageSizeForPlist.height;
        unsigned char *srcRect = (unsigned char*)malloc((size_t)len);
        
        NSBitmapImageRep *priviewimageRep =
        [[[NSBitmapImageRep alloc] initWithCGImage:[image CGImageForProposedRect:NULL context:NULL hints:nil]] autorelease];
        unsigned char *byteData = [priviewimageRep bitmapData];
        memset(srcRect, 0x0, len);
        memcpy(byteData, srcData, len*4);
        
        NSMutableArray* tileImageRectArr = [[[NSMutableArray alloc] init] autorelease];
        
        //fill tile
        for (int y = 0; y< outputImageSizeForPlist.height; y++) {
            for (int x = 0; x< outputImageSizeForPlist.width; x++) {
                int index = x + (int)outputImageSizeForPlist.width*y;
                srcRect[index] = srcData[(index)*4 + 3]?0xff:0x0;
            }
        }
        
        for (int y = 0; y< outputImageSizeForPlist.height; y++) {
            for (int x = 0; x< outputImageSizeForPlist.width; x++) {
                int index = x + (int)outputImageSizeForPlist.width*y;
                byteData[(index)*4 + 0] = 0xff & srcRect[index];
                byteData[(index)*4 + 1] = 0xff & srcRect[index];
                byteData[(index)*4 + 2] = 0xff & srcRect[index];
                byteData[(index)*4 + 3] = 0xff;
            }
        }
        
        //check rect
        BOOL needCheck = YES;
        while (needCheck) {
            needCheck = NO;
            for (int y = 0; y< outputImageSizeForPlist.height - 1; y++) {
                for (int x = 1; x< outputImageSizeForPlist.width - 1; x++) {
                    int index = x + (int)outputImageSizeForPlist.width*y;
                    if (srcRect[index] == 0) {
                        continue;
                    }
                    int index_dl = index + (int)outputImageSizeForPlist.width - 1;
                    if(srcRect[index_dl]){
                        if (srcRect[index - 1] == 0) {
                            srcRect[index - 1] = srcRect[index];
                            needCheck = YES;
                        }
                        if (srcRect[index_dl + 1] == 0) {
                            srcRect[index_dl + 1] = srcRect[index];
                            needCheck = YES;
                        }
                    }
                    int index_dr = index + (int)outputImageSizeForPlist.width + 1;
                    if(srcRect[index_dr]){
                        if (srcRect[index + 1] == 0) {
                            srcRect[index + 1] = srcRect[index];
                            needCheck = YES;
                        }
                        if (srcRect[index_dr - 1] == 0) {
                            srcRect[index_dr - 1] = srcRect[index];
                            needCheck = YES;
                        }
                    }
                }
            }
        }
        
        
        
        for (int y = 0; y< outputImageSizeForPlist.height; y++) {
            for (int x = 0; x< outputImageSizeForPlist.width; x++) {
                int index = x + (int)outputImageSizeForPlist.width*y;
                byteData[(index)*4 + 0] = 0xff & srcRect[index];
                byteData[(index)*4 + 1] = 0xff & srcRect[index];
                byteData[(index)*4 + 2] = 0xff & srcRect[index];
                byteData[(index)*4 + 3] = 0xff;
            }
        }
        
        NSImage *greyscale = [[NSImage alloc] initWithSize:outputImageSizeForPlist];
        [greyscale addRepresentation:priviewimageRep];
        
//        NSData* data = [priviewimageRep representationUsingType:NSPNGFileType properties:nil];
//        NSString *filePath = [@"/Users/ifree/Desktop/" stringByAppendingPathComponent:@"imageName.png"];
//        [data writeToFile:filePath atomically:YES];
        
        Tile_CutterAppDelegate* delegate = (Tile_CutterAppDelegate*)AppDelegate;
        [delegate.preview setImage:greyscale];
        
        //add tile rect
        for (int y = 0; y< outputImageSizeForPlist.height; y++) {
            for (int x = 0; x< outputImageSizeForPlist.width; x++) {
                int index = x + (int)outputImageSizeForPlist.width*y;
                if(srcRect[index]) {
                    BOOL isAdd = FALSE;
                    for (id tileRect in tileImageRectArr) {
                        NSValue* rectV = (NSValue*)tileRect;
                        NSPoint point = NSMakePoint(x, y);
                        if(NSPointInRect ( point, [rectV rectValue])) {
                            isAdd = YES;
                        }
                    }
                    if (isAdd)continue;
                    int rectX=x,rectY=y,rectW=0,rectH=0;
                    while (rectX > 0) {
                        rectX--;
                        if (srcRect[index + rectX - x]) {
                            continue;
                        } else {
                            rectX++;
                            break;
                        }
                    }
                    while (rectY > 0) {
                        rectY--;
                        if (srcRect[x + (int)outputImageSizeForPlist.width*(rectY)]) {
                            continue;
                        } else {
                            rectY++;
                            break;
                        }
                    }
                    while (rectW < outputImageSizeForPlist.width && srcRect[index + rectX - x + rectW]) {
                        rectW++;
                    }
                    while (rectH < outputImageSizeForPlist.height && (rectY + rectH <= outputImageSizeForPlist.height) && srcRect[x + (int)outputImageSizeForPlist.width*(rectY + rectH)]) {
                        rectH++;
                    }
                    NSValue* newTile = [NSValue valueWithRect:NSMakeRect(rectX, rectY, rectW, rectH)];
                    [tileImageRectArr addObject:newTile];
                }
            }
        }
        
        free(srcRect);
        
        for (id tileRect in tileImageRectArr) {
            NSValue* rectV = (NSValue*)tileRect;
            NSRect rect= [rectV rectValue];
            
            TileOperation *op = [[TileOperation alloc] init];
            op.row = rect.origin.y;
            op.column = rect.origin.x;
            op.tileWidth = rect.size.width;
            op.tileHeight = rect.size.height;
            op.imageRep = imageRep;
            op.baseFilename = outputBaseFilename;
            op.delegate = self;
            op.outputFormat = self.outputFormat;
            op.outputSuffix = self.outputSuffix;
            op.skipTransparentTiles = (! self.keepAllTiles );
            op.rigidTiles = self.rigidTiles;
            op.POTTiles = self.POTTiles;
            [queue addOperation:op];
            [op release];
            
        }
    }
    
    [pool drain];
}

- (void)operationDidFinishTile:(TileOperation *)op
{
	progressCol++;
    if (progressCol >= tileColCount)
    {
        progressCol = 0;
        progressRow++;
    }
	
	if ([self.operationsDelegate respondsToSelector: _cmd])
		[self.operationsDelegate performSelectorOnMainThread: _cmd 
												  withObject: op 
											   waitUntilDone: NO];
}

- (void) saveImageInfoDictionary
{
	// Change coordinates & size of all tiles for contentScaleFactor
	if (self.contentScaleFactor != 1.0f)
	{
		// Create new array, that will replace old self.allTilesInfo
		NSMutableArray *newTilesInfoArray = [NSMutableArray arrayWithCapacity: [self.allTilesInfo count]];
		
		for (NSDictionary *tileDict in self.allTilesInfo)
		{
			// Get Tile Rect
			NSRect rect = NSRectFromString([tileDict objectForKey: @"Rect"]);
			
			// Divide it by contentScaleFactor
			rect.origin.x /= self.contentScaleFactor;
			rect.origin.y /= self.contentScaleFactor;
			rect.size.width /= self.contentScaleFactor;
			rect.size.height /= self.contentScaleFactor;
			
			// Create new tile info Dict with changed rect
			NSDictionary *newTileDict = [NSDictionary dictionaryWithObjectsAndKeys:
										  [tileDict objectForKey:@"Name"], @"Name",
										  NSStringFromRect(rect), @"Rect",
										  nil];
			
			// Add new tile info for new array
			[newTilesInfoArray addObject:newTileDict ];
			
		}
		
		// Replace Old Tiles with New
		self.allTilesInfo = newTilesInfoArray;
		
	}
	
	// Create Root Dictionary for a PLIST file
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  self.imageInfo, @"Source",
						  self.allTilesInfo, @"Tiles",
						  [NSNumber numberWithFloat:self.contentScaleFactor], @"ContentScaleFactor", nil];
	
	// Be safe with outputSuffix
	if (!self.outputSuffix)
		self.outputSuffix = @"";
	
	// Save Dict to File
	[dict writeToFile:[NSString stringWithFormat:@"%@%@.plist", self.outputBaseFilename, self.outputSuffix]  atomically:YES];
}

- (void)operationDidFinishSuccessfully:(TileOperation *)op
{
	[(NSMutableArray *)self.allTilesInfo addObjectsFromArray: op.tilesInfo];
	op.tilesInfo = nil;
	
	// All Tiles Finished?
	if (progressRow >= tileRowCount)
	{
		[self saveImageInfoDictionary];
	}
	
	if ([self.operationsDelegate respondsToSelector: _cmd])
		[self.operationsDelegate performSelectorOnMainThread: _cmd 
												  withObject: op 
											   waitUntilDone: NO];
}


- (void)operation:(TileOperation *)op didFailWithMessage:(NSString *)message
{
	if ([self.operationsDelegate respondsToSelector: _cmd])
		[self.operationsDelegate performSelectorOnMainThread: _cmd 
												  withObject: op 
											   waitUntilDone: NO];
}


@end
