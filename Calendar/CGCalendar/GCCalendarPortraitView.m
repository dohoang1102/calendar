/*
 Copyright (c) 2009 Caleb Davenport
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "GCCalendar.h"

#define kAnimationDuration 0.3f

@interface GCCalendarPortraitView ()
@property (nonatomic, retain) NSDate *date;
@property (nonatomic, retain) GCCalendarDayView *dayView;

- (void)reloadDayAnimated:(BOOL)animated context:(void *)context;
@end

@implementation GCCalendarPortraitView

@synthesize date, dayView;

#pragma mark create and destroy view
- (id)init {
	if(self = [super init]) {
		self.title = [[NSBundle mainBundle] localizedStringForKey:@"CALENDAR" value:@"" table:@"GCCalendar"];
		self.tabBarItem.image = [UIImage imageNamed:@"Calendar.png"];
		
		viewDirty = YES;
		viewVisible = NO;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(calendarTileTouch:)
													 name:CGCalendarTileTouchNotification
												   object:nil];
	}
	
	return self;
}
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.date = nil;
	self.dayView = nil;
	
	[dayPicker release];
	dayPicker = nil;
	
	[super dealloc];
}

#pragma mark core data actions
- (void)coreDataDidSave:(NSNotification *)notif {
	viewDirty = YES;
}

#pragma mark calendar actions
- (void)calendarTileTouch:(NSNotification *)notif {
	GCCalendarEvent *event = [[notif object] event];
	
	/*
	 do something with the event
	 
	 id info = [event userInfo];
	 */
}

#pragma mark MGDatePickerControl actions
- (void)datePickerDidChangeDate:(GCDatePickerControl *)picker {
	NSTimeInterval interval = [date timeIntervalSinceDate:picker.date];
	
	self.date = picker.date;
	
	[[NSUserDefaults standardUserDefaults] setObject:date forKey:@"GCCalendarDate"];
	
	[self reloadDayAnimated:YES context:[NSNumber numberWithInt:interval]];
}

#pragma mark button actions
- (void)today:(UIBarButtonItem *)button {
	dayPicker.date = [NSDate date];
	
	self.date = dayPicker.date;
	
	[[NSUserDefaults standardUserDefaults] setObject:date forKey:@"GCCalendarDate"];
	
	[self reloadDayAnimated:NO context:NULL];
}

#pragma mark view notifications
- (void)loadView {
	[super loadView];
	
	self.view.backgroundColor = [UIColor whiteColor];
	
	self.date = [[NSUserDefaults standardUserDefaults] objectForKey:@"GCCalendarDate"];
	if (date == nil) {
		self.date = [NSDate date];
	}
	
	// setup day picker
	dayPicker = [[GCDatePickerControl alloc] init];
	dayPicker.frame = CGRectMake(0, 0, self.view.frame.size.width, 0);
	dayPicker.autoresizingMask = UIViewAutoresizingNone;
	dayPicker.date = date;
	[dayPicker addTarget:self action:@selector(datePickerDidChangeDate:) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:dayPicker];
	
	// setup initial day view
	dayView = [[GCCalendarDayView alloc] init];
	dayView.frame = CGRectMake(0,
							   dayPicker.frame.size.height,
							   self.view.frame.size.width,
							   self.view.frame.size.height - dayPicker.frame.size.height);
	dayView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
	[self.view addSubview:dayView];
	
	// setup today button
	UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:[[NSBundle mainBundle] localizedStringForKey:@"TODAY" value:@"" table:@"GCCalendar"]
															   style:UIBarButtonItemStylePlain
															  target:self 
															  action:@selector(today:)];
	self.navigationItem.leftBarButtonItem = button;
	[button release];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	if (viewDirty) {
		[self reloadDayAnimated:NO context:NULL];
		viewDirty = NO;
	}
	
	viewVisible = YES;
}
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	
	viewVisible = NO;
}

#pragma mark view animation functions
- (void)reloadDayAnimated:(BOOL)animated context:(void *)context {
	if (animated) {
		NSTimeInterval interval = [(NSNumber *)context doubleValue];
		
		// block user interaction
		dayPicker.userInteractionEnabled = NO;
		
		// setup next day view
		GCCalendarDayView *nextDayView = [[GCCalendarDayView alloc] init];
		CGRect initialFrame = dayView.frame;
		if (interval < 0) {
			initialFrame.origin.x = initialFrame.size.width;
		}
		else if (interval > 0) {
			initialFrame.origin.x = 0 - initialFrame.size.width;
		}
		else {
			[nextDayView release];
			return;
		}
		nextDayView.frame = initialFrame;
		nextDayView.date = date;
		[nextDayView reloadData];
		nextDayView.contentOffset = dayView.contentOffset;

		[self.view addSubview:nextDayView];
		
		[UIView beginAnimations:nil context:nextDayView];
		[UIView setAnimationDuration:kAnimationDuration];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
		CGRect finalFrame = dayView.frame;
		if(interval < 0) {
			finalFrame.origin.x = 0 - finalFrame.size.width;
		} else if(interval > 0) {
			finalFrame.origin.x = finalFrame.size.width;
		}
		nextDayView.frame = dayView.frame;
		dayView.frame = finalFrame;
		[UIView commitAnimations];
	}
	else {
		CGPoint contentOffset = dayView.contentOffset;
		dayView.date = date;
		[dayView reloadData];
		dayView.contentOffset = contentOffset;
	}
}
- (void)animationDidStop:(NSString *)animationID 
				finished:(NSNumber *)finished 
				 context:(void *)context {
	
	GCCalendarDayView *nextDayView = (GCCalendarDayView *)context;
	
	// cut variables
	[dayView removeFromSuperview];
	
	// reassign variables
	self.dayView = nextDayView;
	
	// release pointers
	[nextDayView release];
	
	// reset pickers
	dayPicker.userInteractionEnabled = YES;
}

@end