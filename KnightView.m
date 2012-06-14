//
//  KnightView.m
//  KnightsTour
//
//  Created by Ujjwal Thaakar on 23/05/11.
//  Copyright 2011 Addiction. All rights reserved.
//

#import "KnightView.h"
#import <Quartz/Quartz.h>
#import <math.h>

static NSString const * const LayerKey = @"layerKey"; // Used for storing the layer in events userData
static NSString const * const BlackKnight = @"\u265E"; // Unicode string for a black knight
static NSString const * const WhiteKnight = @"\u2658"; // Unicode string for a white knight

@implementation KnightView

#pragma mark Initalization

- (id)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
		wrongMoves = movesCount = rightMoves = 0;
	}
	return self;
}

- (void)awakeFromNib {
	[[self window] center]; // Centre the window
							// Inititalize the root layer
	QCCompositionLayer *rootLayer = [QCCompositionLayer compositionLayerWithFile:
									 [[NSBundle mainBundle] pathForResource:@"Scanner" 
																	 ofType:@"qtz"]];
	rootLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
	[self setLayer:rootLayer];
	[self setWantsLayer:YES];
	[self setUpTiles]; // Set up the tiles - once time process
	[rootLayer layoutIfNeeded];
	trackingAreas = [NSMutableArray new];
	[self setUpTrackingAreas]; // Set up the tracking rectangles
	score = [CATextLayer layer];
	score.layoutManager = [CAConstraintLayoutManager layoutManager];
	[score addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX
													relativeTo:@"superlayer"
													 attribute:kCAConstraintMidX]];
	[score addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidY
													relativeTo:@"superlayer"
													 attribute:kCAConstraintMidY]];
	score.alignmentMode = kCAAlignmentCenter;
	score.zPosition = 1000;
	score.opacity = 0.0;
	score.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
	score.string = [NSString stringWithFormat:@"Score: 0"];
	[[self layer] addSublayer:score];
}

- (void)setUpTrackingAreas {
	for (CALayer *layerInFocus in backgroundLayer.sublayers) {
		if (layerInFocus == knight) {
			continue; // If the layer is the knight then don't process it
		}
		NSDictionary *d = [NSDictionary dictionaryWithObject:layerInFocus forKey:LayerKey];
		CGRect r = [backgroundLayer convertRect:layerInFocus.frame toLayer:[self layer]];
		NSTrackingArea *trackA = [[NSTrackingArea alloc] initWithRect:NSRectFromCGRect(r)
															  options:(NSTrackingMouseEnteredAndExited | NSTrackingEnabledDuringMouseDrag | NSTrackingActiveWhenFirstResponder | NSTrackingCursorUpdate)
																owner:self
															 userInfo:d];
		[self addTrackingArea:trackA];
		[trackingAreas addObject:trackA]; // Add the trackign area to the trackingAreas array so that we can reference it again
	}
	if (!knightInitialized) {
			// If knight has not yet been placed then setup intialTrackArea
		initialTrackingArea = [[NSTrackingArea alloc] initWithRect:NSRectFromCGRect(backgroundLayer.frame)
														   options:(NSTrackingCursorUpdate | NSTrackingActiveWhenFirstResponder)
															 owner:self
														  userInfo:nil];
		[self addTrackingArea:initialTrackingArea];
	}
}

- (void)setUpTiles {
	backgroundLayer = [[CALayer alloc] init]; // Initialize the background which holds the tiles
	backgroundLayer.frame = [[self layer] frame];
	backgroundLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
	[backgroundLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidX
															  relativeTo:@"superlayer"
															   attribute:kCAConstraintMidX]];
	[backgroundLayer addConstraint:[CAConstraint constraintWithAttribute:kCAConstraintMidY
															  relativeTo:@"superlayer"
															   attribute:kCAConstraintMidY]];
	[[self layer] addSublayer:backgroundLayer];
	for (int i = 0; i < 8; i++) {
		for (int j = 0; j < 8; j++) {
			CALayer *newTile = [CALayer layer];
			if ((i+j)%2==0) {
				newTile.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
			}
			newTile.borderColor = CGColorGetConstantColor(kCGColorBlack);
			newTile.borderWidth = 1.0;
			newTile.opacity = 0.9;
			[backgroundLayer addSublayer:newTile];
		}
	}
	[self windowDidResize:nil];
}

#pragma mark Resizing

- (void)windowDidResize:(NSNotification *)notification {
	CGRect r = [self layer].frame;
	r.size.width = r.size.height = MIN(r.size.width, r.size.height);
	backgroundLayer.bounds = r;
	CGFloat g = gridSize;
	gridSize = backgroundLayer.frame.size.height/8.0;
	CGFloat size = score.fontSize;
	size *= (gridSize/g);
	score.fontSize = size;
	size = knight.fontSize;
	size *= (gridSize/g);
	knight.fontSize = size;
	for (int i = 0; i < 8; i++) {
		for (int j = 0; j< 8; j++) {
			CALayer *c = [[backgroundLayer sublayers] objectAtIndex:i*8+j%8];
			CGRect r = CGRectMake(j*gridSize, i*gridSize, gridSize, gridSize);
			c.frame = r;
		}
	}
	knight.frame = currentLayer.frame;
}

- (void)updateTrackingAreas {
	for (NSTrackingArea *t in trackingAreas) {
		[self removeTrackingArea:t];
	}
	[trackingAreas removeAllObjects];
	if (!knightInitialized) {
		[self removeTrackingArea:initialTrackingArea];
		initialTrackingArea = nil;
	}
	[self setUpTrackingAreas];
}

#pragma mark Event Handling

- (BOOL)acceptsFirstResponder {
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent {
	if (isInMotion || gameOver) {
		NSBeep();
		return;
	}
	if (!knightInitialized) {
		knight = [[CATextLayer alloc] init];
		knight.font = @"Tahoma";
		
		CGFloat s = 46.0; // 46.0 is a good font size for a grid of 60x60
		s *= (gridSize/60.0);
		knight.fontSize = s;
		
		knight.alignmentMode = kCAAlignmentCenter;
		CGPoint loc = [backgroundLayer convertPoint:NSPointToCGPoint([theEvent locationInWindow]) fromLayer:[self layer]];
		NSUInteger i = loc.x/gridSize, j = loc.y/gridSize;
		NSUInteger index = j*8 + i;
		currentLayer = [backgroundLayer.sublayers objectAtIndex:index];
		CGColorRef black = CGColorGetConstantColor(kCGColorBlack);
		if (CGColorEqualToColor(currentLayer.backgroundColor, black)) {
			knight.string = WhiteKnight;
		} else {
			knight.string = BlackKnight;
		}
		knight.frame = currentLayer.frame;
		[backgroundLayer addSublayer:knight];
		knightInitialized = YES;
		availableTiles = [NSMutableArray arrayWithArray:backgroundLayer.sublayers];
		[self setUpTilesWhereKnightCanMove];
	} else {
		CGPoint p = [backgroundLayer convertPoint:NSPointToCGPoint([theEvent locationInWindow]) fromLayer:[self layer]];
		CALayer *tempLayer = [self tileForPoint:p];
		if ([tilesWhereKnightCanMove containsObject:tempLayer]) {
			currentLayer.backgroundColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
			[availableTiles removeObjectIdenticalTo:currentLayer];
			moves[movesCount++] = currentLayer.position;
			currentLayer = tempLayer;
			rightMoves++;
			score.string = [NSString stringWithFormat:@"Score: %d", (-2*wrongMoves + rightMoves)];
			[self moveKnightToTile:currentLayer];
		} else {
				//NSBeep();
		}
	}
}

- (void)mouseDragged:(NSEvent *)theEvent {
	if (gameOver) {
		return;
	}
	dragging = YES;
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.0] forKey:kCATransactionAnimationDuration];
	knight.position = [backgroundLayer convertPoint:NSPointToCGPoint([theEvent locationInWindow]) fromLayer:[self layer]];
	[CATransaction commit];
}

- (void)mouseUp:(NSEvent *)theEvent {
	if (gameOver) {
		return;
	}
	if (dragging) {
		dragging = NO;
		CGPoint loc = [backgroundLayer convertPoint:NSPointToCGPoint([theEvent locationInWindow]) fromLayer:[self layer]];
		CALayer *tile = [self tileForPoint:loc];
		if ([tilesWhereKnightCanMove containsObject:tile]) {
			currentLayer.backgroundColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
			[availableTiles removeObjectIdenticalTo:currentLayer];
			moves[movesCount++] = currentLayer.position;
			currentLayer = tile;
			rightMoves++;
			score.string = [NSString stringWithFormat:@"Score: %d", (-2*wrongMoves + rightMoves)];
			[self moveKnightToTile:currentLayer];
		} else {
			knight.position = currentLayer.position;
		}
	}
}

- (void)mouseEntered:(NSEvent *)theEvent {
	CALayer *layerInFocus = [(NSDictionary *)[theEvent userData] objectForKey:LayerKey];
	layerInFocus.borderColor = CGColorCreateGenericRGB(0.0, 0.0, 1.0, .5);
	layerInFocus.borderWidth = 3.0;
	CIFilter *filter = [CIFilter filterWithName:@"CIBloom"];
	[filter setName:@"filterKey"];
	[filter setDefaults];
	[filter setValue:[NSNumber numberWithFloat:5.0] forKey:@"inputRadius"];
	[layerInFocus setFilters:[NSArray arrayWithObject:filter]];
	CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"filters.filterKey.inputIntensity"];
	pulseAnimation.fromValue = [NSNumber numberWithFloat:0.0];
	pulseAnimation.toValue = [NSNumber numberWithFloat:2.0];
	pulseAnimation.duration = 1.0;
	pulseAnimation.repeatCount = HUGE_VALF;
	pulseAnimation.autoreverses = YES;
	[layerInFocus addAnimation:pulseAnimation forKey:@"pulse"];
}

- (void)mouseExited:(NSEvent *)theEvent {
	CALayer *layerInFocus = [(NSDictionary *)[theEvent userData] objectForKey:LayerKey];
	[layerInFocus removeAnimationForKey:@"pulse"];
	[layerInFocus setFilters:nil];
	layerInFocus.borderColor = nil;
	layerInFocus.borderWidth = 1.0;
}

- (void)cursorUpdate:(NSEvent *)event {
	if (!knightInitialized) {
		if (NSPointInRect([event locationInWindow], NSRectFromCGRect(backgroundLayer.frame))) {
			[[NSCursor pointingHandCursor] set];
			return;
		}
	} else if ([(NSDictionary *)[event userData] objectForKey:LayerKey] == currentLayer) {
		[[NSCursor openHandCursor] set];
		return;
	} else if ([tilesWhereKnightCanMove containsObject:[(NSDictionary *)[event userData] objectForKey:LayerKey]] && !dragging) {
		[[NSCursor pointingHandCursor] set];
		return;
	} else if (dragging) {
		[[NSCursor closedHandCursor] set];
		return;
	}
	[[NSCursor arrowCursor] set];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
	if (gameOver) {
		return NO;
	}
	if (([theEvent modifierFlags] & NSCommandKeyMask)) {
		if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"f"]) {
			[self fullScreenManagement:self];
			return YES;
		} else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"z"]) {
			if (movesCount == 0) {
				NSBeep();
				return YES;
			}
			if ([score.string isEqualToString:@"No more moves possible !\nUndo (Cmd+Z) / Restart (Cmd+N)"]) {
				score.opacity = 0.0;
			}
			CALayer *layer = [self tileForPoint:moves[--movesCount]];
			wrongMoves++;
			[availableTiles addObject:layer];
			undoing = YES;
			score.string = [NSString stringWithFormat:@"Score: %d", (-2*wrongMoves + rightMoves)];
			[self moveKnightToTile:layer];
			return YES;
		} else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"s"]) {
			[self showScore:self];
			return YES;
		} else if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"n"]) {
			[self newGame:self];
		}
	}
	return NO;
}

- (void)cancelOperation:(id)sender {
	score.opacity = 0.0;
}

- (IBAction)showScore:(id)sender {
	score.opacity = 0.6;
}

- (IBAction)fullScreenManagement:(id)sender {
	if ([self isInFullScreenMode]) {
		[self exitFullScreenModeWithOptions:nil];
	} else {
		[self enterFullScreenMode:[[self window] screen]
					  withOptions:nil];
	}
	[self windowDidResize:nil];
}

- (IBAction)newGame:(id)sender {
	gameOver = NO;
	wrongMoves = movesCount = rightMoves = 0;
	score.string = [NSString stringWithFormat:@"Score: 0"];
	[knight removeFromSuperlayer];
	knight = nil;
	knightInitialized = NO;
	availableTiles = nil;
	availableTiles = [NSMutableArray arrayWithArray:backgroundLayer.sublayers];
	[self paintTiles:backgroundLayer.sublayers];
}

- (void)magnifyWithEvent:(NSEvent *)event {
	if ([event magnification] > 0) {
		[self enterFullScreenMode:[self.window screen]
					  withOptions:nil];
	} else {
		[self exitFullScreenModeWithOptions:nil];
	}
	[self windowDidResize:nil];
}

#pragma mark Utilities

- (CALayer *)tileForPoint:(CGPoint)point {
	for (CALayer *layerInFocus in backgroundLayer.sublayers) {
		if (CGRectContainsPoint(layerInFocus.frame, point)) {
			return layerInFocus;
		}
	}
	return nil;
}

- (void)paintTiles:(NSArray *)array {
	for (CALayer *layerInFocus in array) {
		int i, j;
		i = layerInFocus.position.x/gridSize;
		j = layerInFocus.position.y/gridSize;
		if ((i+j)%2 == 0) {
			layerInFocus.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
		} else {
			layerInFocus.backgroundColor = nil;
		}
	}
}

- (void)setUpTilesWhereKnightCanMove {
		// Restore colors
	[self paintTiles:tilesWhereKnightCanMove];
	
	int k1[] = {1, -1, 2, 2, 1, -1, -2, -2}, k2[] = {2, 2, 1, -1, -2, -2, 1, -1};
	NSMutableArray *tempA = [[NSMutableArray alloc] init];
	for (int i = 0; i < 8; i++) {
		CGPoint p = currentLayer.position;
		p.x += gridSize*k1[i];
		p.y += gridSize*k2[i];
		CALayer *tempL = [self tileForPoint:p];
		if ([availableTiles count] != 0) {
			if (![availableTiles containsObject:tempL]) {
				continue;
			}
		}
		
		tempL.backgroundColor = CGColorCreateGenericRGB(0.0, 1.0, 0.0, 1.0);
		[tempA addObject:tempL];
	}
	if ([tempA count] == 0) {
		score.string = @"No more moves possible !\nUndo (Cmd+Z) / Restart (Cmd+N)";
		[self showScore:self];
		return;
	}
	tilesWhereKnightCanMove = nil;
	tilesWhereKnightCanMove = [NSArray arrayWithArray:tempA];
	tempA = nil;
}

- (void)moveKnightToTile:(CALayer *)newPos {
	CGPoint newPosition = newPos.position;
	deltaX = newPosition.x - knight.position.x;
	deltaY = newPosition.y - knight.position.y;
	yGreaterThanX = (fabsf(deltaY) > fabsf(deltaX));
	isInMotion = YES;
	if (yGreaterThanX) {
		if (undoing) {
			[self animateMovementByX:deltaX Y:0.0];
		} else {
			[self animateMovementByX:0.0 Y:deltaY];
		}

	} else {
		if (undoing) {
			[self animateMovementByX:0.0 Y:deltaY];
		} else {
			[self animateMovementByX:deltaX Y:0.0];
		}
	}
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
	static BOOL first = NO;
	first = !first;
	if (flag && first) {
		if (yGreaterThanX) {
			if (undoing) {
				[self animateMovementByX:0.0 Y:deltaY];
			} else {
				[self animateMovementByX:deltaX Y:0.0];
			}
			
		} else {
			if (undoing) {
				[self animateMovementByX:deltaX Y:0.0];
			} else {
				[self animateMovementByX:0.0 Y:deltaY];
			}
		}
	} else {
		isInMotion = NO;
		if (undoing) {
			undoing = NO;
			currentLayer = [self tileForPoint:knight.position];
			[self paintTiles:[NSArray arrayWithObject:currentLayer]];
		}
		[self setUpTilesWhereKnightCanMove];
		if (movesCount == 64) {
			score.string = @"You Win !";
			gameOver = YES;
		}
	}
}

- (void)animateMovementByX:(CGFloat)newX Y:(CGFloat)newY {
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	CABasicAnimation *ba = [CABasicAnimation animationWithKeyPath:@"position"];
	ba.duration = .5;
	ba.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	ba.fromValue = [NSValue valueWithPoint:NSPointFromCGPoint(knight.position)];
	CGPoint p = knight.position;
	p.x += newX;
	p.y += newY;
	knight.position = p;
	ba.toValue = [NSValue valueWithPoint:NSPointFromCGPoint(knight.position)];
	[ba setDelegate:self];
	[knight addAnimation:ba forKey:@"knightMove"];
	[CATransaction commit];
}

@end
