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

package com.runrev.android;

import android.app.PendingIntent;
import android.content.*;
import android.content.pm.*;
import android.os.Build;

public class Utils
{
    public static int[] splitIntegerList(String p_list)
    {
        try
        {
            String[] t_items = p_list.split(",");
            int[] t_list = new int[t_items.length];
            
            for (int i = 0; i < t_items.length; i++)
            {
                t_list[i] = Integer.parseInt(t_items[i].trim());
            }
            
            return t_list;
        }
        catch (Exception e)
        {
            return null;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    
    public static String getLabel(Context context)
    {
        PackageManager pm = context.getPackageManager();
        ApplicationInfo ai = context.getApplicationInfo();
        ai.loadLabel(pm);
        return pm.getApplicationLabel(ai).toString();
    }
    
    // OXT-Beyond: the flags to make a PendingIntent with. Android 12 (API
    // 31) and newer refuse to make one, for an app that targets API 31 or
    // newer (as every standalone has since its target became 33), unless
    // the flags say FLAG_IMMUTABLE or FLAG_MUTABLE: PendingIntent.get*
    // throws. Older versions of Android are given the flags as they are,
    // so nothing changes there. FLAG_MUTABLE and FLAG_IMMUTABLE are
    // constants, which javac writes into the code, so no older Android
    // looks them up.
    
    // A PendingIntent that whoever sends it cannot change: the alarm,
    // notification and registration intents, whose extras are the app's
    // own.
    public static int immutablePendingIntentFlags(int p_flags)
    {
        if (Build.VERSION.SDK_INT >= 31)
            return p_flags | PendingIntent.FLAG_IMMUTABLE;
        return p_flags;
    }
    
    // A PendingIntent that its sender fills in: NFC foreground dispatch,
    // which adds the tag that was found to the intent.
    public static int mutablePendingIntentFlags(int p_flags)
    {
        if (Build.VERSION.SDK_INT >= 31)
            return p_flags | PendingIntent.FLAG_MUTABLE;
        return p_flags;
    }
    
    // OXT-Beyond: whether the app's manifest asks for a permission
    // (<uses-permission>): Android refuses a runtime permission that it does
    // not, without asking the user.
    public static boolean declaresPermission(Context p_context, String p_permission)
    {
        try
        {
            PackageInfo t_info = p_context.getPackageManager().getPackageInfo(p_context.getPackageName(),
                                                                             PackageManager.GET_PERMISSIONS);
            if (t_info.requestedPermissions != null)
                for (String t_permission : t_info.requestedPermissions)
                    if (p_permission.equals(t_permission))
                        return true;
        }
        catch (PackageManager.NameNotFoundException e)
        {
        }
        return false;
    }
}
