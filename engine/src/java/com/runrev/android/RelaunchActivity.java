/* Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

package com.runrev.android;

import android.os.*;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.util.Log;

// OXT-Beyond: starts the app's activity again in a new process, for an
// activity that Android makes again in the process whose engine has already
// run (LiveCodeActivity.onCreate).
//
// The engine runs once in a process. Started a second time in the same one
// it opens stdin, stdout and stderr again (MCAndroidSystem::Initialize,
// fdopen), which the first run's streams still hold, and Android 11 and
// newer stop an app that targets API 30 or newer for that (fdsan: "fd 0 is
// owned by FILE*"). Android makes the activity again in the same process
// for a configuration change the manifest does not list (the builder's
// configChanges lists the usual ones; an app's theme overlays, for example
// those Android 12 and newer make of the wallpaper's colours, cannot be
// listed), and when it is opened again after its engine quit, if the
// process is still there.
//
// This activity runs in a process of its own (the builder declares it with
// android:process=":relaunch"). The app's activity starts it, with the
// Intent it was started with and its process's id, and finishes; this one
// then ends that process, starts the Intent, which Android starts in a new
// process, and ends its own. The stack opens again, as it does when its
// app starts, where the app would otherwise have been stopped.
//
// It is the pattern of Jake Wharton's ProcessPhoenix: the app's process
// cannot start its activity again itself and then end, as the new activity
// could be started in the process that is ending.
public class RelaunchActivity extends Activity
{
    public static final String TAG = "revandroid.RelaunchActivity";

    // The extras of the Intent that starts this activity: the Intent to
    // start in a new process, and the process to end first
    public static final String EXTRA_INTENT = "com.runrev.android.relaunch.INTENT";
    public static final String EXTRA_PID = "com.runrev.android.relaunch.PID";

    // Whether the app's manifest declares this activity: an app built with
    // a builder that did not leave it out (a manifest of the app's own, for
    // one, may not have it)
    public static boolean isDeclared(Context p_context)
    {
        try
        {
            p_context.getPackageManager().getActivityInfo(new ComponentName(p_context, RelaunchActivity.class), 0);
            return true;
        }
        catch (PackageManager.NameNotFoundException e)
        {
            return false;
        }
    }

    // Called by the app's activity in the process whose engine has run: starts
    // this activity to start it again in a new process, and finishes it. False,
    // having done nothing, when the manifest does not declare this activity
    public static boolean relaunch(Activity p_activity)
    {
        if (!isDeclared(p_activity))
            return false;

        Intent t_intent;
        t_intent = new Intent(p_activity, RelaunchActivity.class);
        t_intent.putExtra(EXTRA_INTENT, new Intent(p_activity.getIntent()));
        t_intent.putExtra(EXTRA_PID, android.os.Process.myPid());

        Log.i(TAG, "the engine has run in this process; starting the app again in a new one");
        p_activity.startActivity(t_intent);
        p_activity.overridePendingTransition(0, 0);
        p_activity.finish();
        return true;
    }

    @Override
    protected void onCreate(Bundle p_saved_state)
    {
        super.onCreate(p_saved_state);

        Intent t_intent;
        t_intent = getIntent();

        // The app's process first, so that the activity starts in a new one
        int t_pid;
        t_pid = t_intent.getIntExtra(EXTRA_PID, 0);
        if (t_pid != 0 && t_pid != android.os.Process.myPid())
            android.os.Process.killProcess(t_pid);

        Intent t_app_intent;
        t_app_intent = (Intent)t_intent.getParcelableExtra(EXTRA_INTENT);
        if (t_app_intent != null)
        {
            // Started by this activity, not by what started it before (the
            // launcher, a notification, a URL), with its action, data and
            // extras
            Intent t_start;
            t_start = new Intent(t_app_intent);
            t_start.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(t_start);
        }

        finish();
        overridePendingTransition(0, 0);

        // and this process, which has nothing more to do
        Runtime.getRuntime().exit(0);
    }
}
