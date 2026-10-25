/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

// A probe, not a test: where AppKit orders a window that cannot become key
// (the engine's backdrop, engine/src/mac-core.mm) when it is clicked, and
// which of a few ways of keeping it behind the app's other windows works.
// tools/ci/mac_backdrop_probe.py starts it once per way and clicks.
//
//   mac-backdrop-probe <way> <folder>
//
// The ways (the engine today is "firstmouse"):
//   firstmouse  sync in acceptsFirstMouse: only
//   upstream    the same, with LiveCode's own sync (ordered out first)
//   mousedown   sync in acceptsFirstMouse: and when mouseDown: starts
//   sendevent   sync in acceptsFirstMouse: and after [super sendEvent:]
//   prevent     shouldDelayWindowOrderingForEvent: YES while the app is
//               active, and preventWindowOrdering and sync in mouseDown:
//   keyable     the backdrop can become key, sync in acceptsFirstMouse:
//
// It writes <folder>/probe.txt and reads <folder>/command.txt every 100 ms:
// "log <label>", "sync" or "quit".

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

static NSWindow *s_backdrop = nil;
static NSString *s_way = nil;
static NSString *s_folder = nil;
static FILE *s_log = NULL;

static void ProbeLog(NSString *p_format, ...) NS_FORMAT_FUNCTION(1, 2);
static void ProbeLog(NSString *p_format, ...)
{
	va_list t_args;
	va_start(t_args, p_format);
	NSString *t_text = [[NSString alloc] initWithFormat: p_format arguments: t_args];
	va_end(t_args);
	fprintf(s_log, "%.3f %s\n", [[NSDate date] timeIntervalSince1970], [t_text UTF8String]);
	fflush(s_log);
}

static NSString *ProbeOrder(void)
{
	NSMutableArray *t_names = [NSMutableArray array];
	for (NSNumber *t_number in [NSWindow windowNumbersWithOptions: 0])
	{
		NSWindow *t_window = [NSApp windowWithWindowNumber: [t_number integerValue]];
		if (t_window == nil)
			[t_names addObject: [NSString stringWithFormat: @"foreign#%ld", (long)[t_number integerValue]]];
		else if ([[t_window title] length] == 0)
			[t_names addObject: [NSString stringWithFormat: @"#%ld(%ld)", (long)[t_number integerValue], (long)[t_window level]]];
		else
			[t_names addObject: [NSString stringWithFormat: @"%@(%ld)", [t_window title], (long)[t_window level]]];
	}
	return [t_names componentsJoinedByString: @" > "];
}

// The engine's MCMacPlatformSyncBackdrop, as it is
static void ProbeSyncEngine(void)
{
	[CATransaction begin];
	[CATransaction setDisableActions: YES];
	NSInteger t_window_above_id = -1;
	for (NSNumber *t_window_id in [NSWindow windowNumbersWithOptions: 0])
	{
		NSWindow *t_window = [NSApp windowWithWindowNumber: [t_window_id longValue]];
		if (t_window == nil || t_window == s_backdrop)
			continue;
		if (t_window_above_id != -1)
			[t_window orderWindow: NSWindowBelow relativeTo: t_window_above_id];
		t_window_above_id = [t_window_id longValue];
	}
	if (t_window_above_id != -1)
		[s_backdrop orderWindow: NSWindowBelow relativeTo: t_window_above_id];
	else
		[s_backdrop orderBack: nil];
	[CATransaction commit];
}

// LiveCode's: the backdrop ordered out first
static void ProbeSyncUpstream(void)
{
	NSDisableScreenUpdates();
	[s_backdrop orderOut: nil];
	NSInteger t_window_above_id = -1;
	for (NSNumber *t_window_id in [NSWindow windowNumbersWithOptions: 0])
	{
		NSWindow *t_window = [NSApp windowWithWindowNumber: [t_window_id longValue]];
		if (t_window == nil || t_window == s_backdrop)
			continue;
		if (t_window_above_id != -1)
			[t_window orderWindow: NSWindowBelow relativeTo: t_window_above_id];
		t_window_above_id = [t_window_id longValue];
	}
	if (t_window_above_id != -1)
		[s_backdrop orderWindow: NSWindowBelow relativeTo: t_window_above_id];
	else
		[s_backdrop orderFront: nil];
	NSEnableScreenUpdates();
}

static void ProbeSync(NSString *p_where)
{
	if ([s_way isEqualToString: @"upstream"])
		ProbeSyncUpstream();
	else
		ProbeSyncEngine();
	ProbeLog(@"%@ synced: %@", p_where, ProbeOrder());
}

@interface ProbeWindow : NSWindow
@property (nonatomic) BOOL canKey;
@end

@implementation ProbeWindow
- (BOOL)canBecomeKeyWindow
{
	return self.canKey;
}

// As the engine's windows: a frame is not kept off the menu bar
- (NSRect)constrainFrameRect: (NSRect)p_frame toScreen: (NSScreen *)p_screen
{
	return p_frame;
}

- (void)sendEvent: (NSEvent *)p_event
{
	NSEventType t_type = [p_event type];
	BOOL t_press = self == s_backdrop &&
		(t_type == NSEventTypeLeftMouseDown || t_type == NSEventTypeLeftMouseUp);
	if (t_press)
		ProbeLog(@"sendEvent %@ before (active %d): %@", t_type == NSEventTypeLeftMouseDown ? @"down" : @"up",
				 [NSApp isActive], ProbeOrder());
	[super sendEvent: p_event];
	if (t_press)
	{
		ProbeLog(@"sendEvent %@ after (active %d): %@", t_type == NSEventTypeLeftMouseDown ? @"down" : @"up",
				 [NSApp isActive], ProbeOrder());
		if ([s_way isEqualToString: @"sendevent"] && t_type == NSEventTypeLeftMouseDown)
			ProbeSync(@"sendEvent");
	}
}
@end

@interface ProbePanel : NSPanel
@end

@implementation ProbePanel
- (BOOL)canBecomeKeyWindow
{
	return YES;
}
@end

@interface ProbeView : NSView
@property (nonatomic, strong) NSColor *colour;
@end

@implementation ProbeView
- (void)drawRect: (NSRect)p_dirty
{
	[self.colour setFill];
	NSRectFill(p_dirty);
}

- (BOOL)acceptsFirstMouse: (NSEvent *)p_event
{
	if ([self window] == s_backdrop)
	{
		ProbeLog(@"acceptsFirstMouse (active %d): %@", [NSApp isActive], ProbeOrder());
		ProbeSync(@"acceptsFirstMouse");
	}
	return YES;
}

- (BOOL)shouldDelayWindowOrderingForEvent: (NSEvent *)p_event
{
	BOOL t_delay = [s_way isEqualToString: @"prevent"] && [self window] == s_backdrop && [NSApp isActive];
	if ([self window] == s_backdrop)
		ProbeLog(@"shouldDelayWindowOrderingForEvent -> %d: %@", t_delay, ProbeOrder());
	return t_delay;
}

- (void)mouseDown: (NSEvent *)p_event
{
	if ([self window] != s_backdrop)
		return;
	ProbeLog(@"mouseDown (active %d): %@", [NSApp isActive], ProbeOrder());
	if ([s_way isEqualToString: @"prevent"] && [NSApp isActive])
		[NSApp preventWindowOrdering];
	if ([s_way isEqualToString: @"mousedown"] || [s_way isEqualToString: @"prevent"])
		ProbeSync(@"mouseDown");
}

- (void)mouseUp: (NSEvent *)p_event
{
	if ([self window] == s_backdrop)
		ProbeLog(@"mouseUp (active %d): %@", [NSApp isActive], ProbeOrder());
}
@end

@interface ProbeCommands : NSObject
@end

@implementation ProbeCommands
- (void)poll: (NSTimer *)p_timer
{
	NSString *t_path = [s_folder stringByAppendingPathComponent: @"command.txt"];
	NSString *t_command = [NSString stringWithContentsOfFile: t_path encoding: NSUTF8StringEncoding error: nil];
	if (t_command == nil)
		return;
	[[NSFileManager defaultManager] removeItemAtPath: t_path error: nil];
	t_command = [t_command stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([t_command hasPrefix: @"log "])
		ProbeLog(@"%@ (active %d, key %@): %@", [t_command substringFromIndex: 4], [NSApp isActive],
				 [[NSApp keyWindow] title], ProbeOrder());
	else if ([t_command isEqualToString: @"sync"])
		ProbeSync(@"command");
	else if ([t_command isEqualToString: @"quit"])
		[NSApp terminate: nil];
}
@end

static ProbeWindow *ProbeMakeWindow(NSString *p_title, NSRect p_content, NSUInteger p_style, NSColor *p_colour)
{
	ProbeWindow *t_window = [[ProbeWindow alloc] initWithContentRect: p_content styleMask: p_style
															 backing: NSBackingStoreBuffered defer: NO];
	t_window.canKey = YES;
	[t_window setTitle: p_title];
	[t_window setReleasedWhenClosed: NO];
	ProbeView *t_view = [[ProbeView alloc] initWithFrame: NSMakeRect(0, 0, p_content.size.width, p_content.size.height)];
	t_view.colour = p_colour;
	[t_window setContentView: t_view];
	return t_window;
}

int main(int argc, const char *argv[])
{
	@autoreleasepool
	{
		s_way = argc > 1 ? [NSString stringWithUTF8String: argv[1]] : @"firstmouse";
		s_folder = argc > 2 ? [NSString stringWithUTF8String: argv[2]] : NSTemporaryDirectory();
		s_log = fopen([[s_folder stringByAppendingPathComponent: @"probe.txt"] fileSystemRepresentation], "a");
		if (s_log == NULL)
			s_log = stdout;

		[NSApplication sharedApplication];
		[NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];

		// A menu bar of an application menu and a Text menu
		NSMenu *t_bar = [[NSMenu alloc] init];
		NSMenuItem *t_app_item = [[NSMenuItem alloc] init];
		NSMenu *t_app_menu = [[NSMenu alloc] init];
		[t_app_menu addItemWithTitle: @"Quit" action: @selector(terminate:) keyEquivalent: @"q"];
		[t_app_item setSubmenu: t_app_menu];
		[t_bar addItem: t_app_item];
		NSMenuItem *t_text_item = [[NSMenuItem alloc] initWithTitle: @"Text" action: nil keyEquivalent: @""];
		NSMenu *t_text_menu = [[NSMenu alloc] initWithTitle: @"Text"];
		[t_text_menu addItemWithTitle: @"Bold" action: nil keyEquivalent: @""];
		[t_text_menu addItemWithTitle: @"Italic" action: nil keyEquivalent: @""];
		[t_text_item setSubmenu: t_text_menu];
		[t_bar addItem: t_text_item];
		[NSApp setMainMenu: t_bar];

		// The engine's dummy window, at the bottom of the app's windows
		NSWindow *t_dummy = [[NSWindow alloc] initWithContentRect: NSZeroRect styleMask: NSWindowStyleMaskBorderless
														  backing: NSBackingStoreBuffered defer: YES];
		[t_dummy orderFront: nil];

		NSRect t_screen = [[NSScreen mainScreen] frame];
		NSRect t_visible = [[NSScreen mainScreen] visibleFrame];
		NSUInteger t_titled = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;

		ProbeWindow *t_menubar = ProbeMakeWindow(@"Menubar", NSMakeRect(0, 0, 600, 50), t_titled, [NSColor whiteColor]);
		[t_menubar setFrameTopLeftPoint: NSMakePoint(NSMinX(t_visible) + 160, NSMaxY(t_visible))];
		ProbeWindow *t_document = ProbeMakeWindow(@"Document", NSMakeRect(0, 0, 320, 220), t_titled, [NSColor yellowColor]);
		[t_document setFrameTopLeftPoint: NSMakePoint(NSMinX(t_visible) + 300, NSMaxY(t_visible) - 120)];

		ProbePanel *t_palette = [[ProbePanel alloc] initWithContentRect: NSMakeRect(0, 0, 120, 360)
															  styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskUtilityWindow
																backing: NSBackingStoreBuffered defer: NO];
		[t_palette setTitle: @"Palette"];
		[t_palette setFloatingPanel: YES];
		[t_palette setHidesOnDeactivate: NO];
		ProbeView *t_palette_view = [[ProbeView alloc] initWithFrame: NSMakeRect(0, 0, 120, 360)];
		t_palette_view.colour = [NSColor cyanColor];
		[t_palette setContentView: t_palette_view];
		[t_palette setFrameTopLeftPoint: NSMakePoint(NSMinX(t_visible) + 10, NSMaxY(t_visible) - 60)];

		ProbeWindow *t_backdrop = ProbeMakeWindow(@"Backdrop", t_screen, NSWindowStyleMaskBorderless, [NSColor darkGrayColor]);
		[t_backdrop setFrame: t_screen display: NO];
		t_backdrop.canKey = [s_way isEqualToString: @"keyable"];
		s_backdrop = t_backdrop;

		[t_menubar orderFront: nil];
		[t_document makeKeyAndOrderFront: nil];
		[t_palette orderFront: nil];
		// As the engine shows the backdrop (MCMacPlatformWindow::DoShow), then a
		// stack after it
		[t_backdrop makeKeyAndOrderFront: nil];
		ProbeSync(@"backdrop shown");
		[t_document makeKeyAndOrderFront: nil];
		ProbeSync(@"document shown");

		[NSApp activateIgnoringOtherApps: YES];

		ProbeCommands *t_commands = [[ProbeCommands alloc] init];
		[NSTimer scheduledTimerWithTimeInterval: 0.1 target: t_commands selector: @selector(poll:) userInfo: nil repeats: YES];

		// A point of the backdrop that no window covers, in the screen's
		// top-left coordinates (CGEvent's), off the Dock
		int t_x = (int)(NSMaxX(t_visible) - 60);
		int t_y = (int)(NSMaxY(t_screen) - NSMinY(t_visible) - 60);
		ProbeLog(@"READY %d,%d screen %d,%d,%d,%d way %@ macOS %@", t_x, t_y, (int)t_screen.origin.x, (int)t_screen.origin.y,
				 (int)t_screen.size.width, (int)t_screen.size.height, s_way,
				 [[NSProcessInfo processInfo] operatingSystemVersionString]);

		[NSApp run];
	}
	return 0;
}
