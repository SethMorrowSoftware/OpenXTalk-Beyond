/* Copyright (C) 2003-2015 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

#include "prefix.h"

#ifdef _MACOSX

#import <Cocoa/Cocoa.h>
#include "foundation-objc.h"
#include "macicon.h"
#include "osspec.h"

bool MCS_macseticon(MCStringRef p_icon_path, MCStringRef p_file_path, MCStringRef& r_error)
{
    @autoreleasepool {
        // Resolve paths to native format (handles aliases, tilde, etc.)
        MCAutoStringRef t_native_icon_path;
        if (!MCS_pathtonative(p_icon_path, &t_native_icon_path))
        {
            MCStringCreateWithCString("Failed to resolve icon path", r_error);
            return false;
        }
        
        MCAutoStringRef t_native_file_path;
        if (!MCS_pathtonative(p_file_path, &t_native_file_path))
        {
            MCStringCreateWithCString("Failed to resolve file path", r_error);
            return false;
        }
        
        NSString *t_icon_path = MCStringConvertToAutoreleasedNSString(*t_native_icon_path);
        NSString *t_file_path = MCStringConvertToAutoreleasedNSString(*t_native_file_path);
        
        NSLog(@"[MCS_macseticon] icon_path=%@, file_path=%@", t_icon_path, t_file_path);
        
        // Check if files exist
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL t_icon_exists = [fm fileExistsAtPath:t_icon_path];
        BOOL t_file_exists = [fm fileExistsAtPath:t_file_path];
        NSLog(@"[MCS_macseticon] icon exists=%d, file exists=%d", (int)t_icon_exists, (int)t_file_exists);
        
        if (!t_icon_exists)
        {
            MCStringCreateWithCString("Icon file does not exist", r_error);
            return false;
        }
        if (!t_file_exists)
        {
            MCStringCreateWithCString("Target file does not exist", r_error);
            return false;
        }
        
        NSImage *t_icon = [[NSImage alloc] initWithContentsOfFile:t_icon_path];
        if (!t_icon)
        {
            MCStringCreateWithCString("Failed to load icon", r_error);
            return false;
        }
        
        NSLog(@"[MCS_macseticon] icon loaded, size=%@", NSStringFromSize([t_icon size]));
        
        __block BOOL t_ok = NO;
        if ([NSThread isMainThread])
        {
            t_ok = [[NSWorkspace sharedWorkspace] setIcon:t_icon
                                                  forFile:t_file_path
                                                  options:0];
        }
        else
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                t_ok = [[NSWorkspace sharedWorkspace] setIcon:t_icon
                                                      forFile:t_file_path
                                                      options:0];
            });
        }
        
        [t_icon release];
        
        NSLog(@"[MCS_macseticon] setIcon result=%d", (int)t_ok);
        
        if (!t_ok)
        {
            MCStringCreateWithCString("Failed to set icon", r_error);
            return false;
        }
        
        r_error = MCValueRetain(kMCEmptyString);
        return true;
    }
}

#endif
