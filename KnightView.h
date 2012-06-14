//
//  KnightView.h
//  KnightsTour
//
//  Created by Ujjwal Thaakar on 23/05/11.
//  Copyright 2011 Addiciton. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


@interface KnightView : NSView <NSWindowDelegate> {
	CATextLayer *knight; // The Knight
	CATextLayer *score;
	CALayer *backgroundLayer; // The background which holds all the tiles of the chess board
	NSTrackingArea *initialTrackingArea; // Initial tracking area to be used to update the cursor before the knight is placed
	NSInteger wrongMoves, rightMoves; // Number of wrong moves i.e. undos made by the user
	CGPoint moves[64]; // The positions of the tiles it has already traversed
	NSUInteger movesCount;
	CALayer *currentLayer; // The current tile on which the knight resides
	NSMutableArray *trackingAreas; // All the tracking areas - one for each tile
	BOOL knightInitialized, knightIsBlack; // Wether the knight has been placed and wether the user has chosen a black knight
	CGFloat gridSize; // The size of each tile i.e. its width and height
	NSMutableArray *availableTiles; // All the tiles where you can move right now
	NSArray *tilesWhereKnightCanMove; // All the tiles where the knight can make its next move
	CGFloat deltaX, deltaY;
	BOOL yGreaterThanX, isInMotion, undoing, dragging, gameOver;
}

- (void)setUpTiles; // Set up all the tiles - only called once !
- (void)setUpTrackingAreas; // Set up all the tracking areas - called during intialization and when view is resized
- (void)setUpTilesWhereKnightCanMove; // Set up the tiles where the knight can make its moves
- (void)moveKnightToTile:(CALayer *)newPos; // Move knight to speicfied tile
- (void)animateMovementByX:(CGFloat)newX Y:(CGFloat)newY; // Move the knight by the specified offset
- (void)paintTiles:(NSArray *)array;
- (CALayer *)tileForPoint:(CGPoint)point; // Return the tile which contains the given point
- (IBAction)fullScreenManagement:(id)sender;
- (IBAction)showScore:(id)sender;
- (IBAction)newGame:(id)sender;


@end
