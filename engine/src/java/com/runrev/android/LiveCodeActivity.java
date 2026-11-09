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

import android.os.*;
import android.app.*;
import android.view.*;
import android.content.*;
import android.content.res.*;
import android.widget.*;
import android.util.*;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;

// This is the main activity exported by the application. This is
// split into two parts, a customizable sub-class that gets dynamically
// generated in the standalone builder and a super-class that is implemented
// in com.runrev.revandroid. The reasoning here is that scripters will want their
// apps to appear in their namespace (and so do we!).
public class LiveCodeActivity extends Activity
{
    public static final String TAG = "revandroid.LiveCodeActivity";
	public static FrameLayout s_main_layout;
	public static Engine s_main_view;
    
    // OXT-Beyond: whether an engine has run in this process, and whether
    // this activity started one (see onCreate). An activity that started the
    // app again in a new process instead has no engine: it is finishing, and
    // Android can still call it before it is destroyed (with the
    // configuration change that follows the one it was made again for, as a
    // density change and its return do), so each call below that goes to the
    // engine (s_main_view, null then) does nothing in it
    protected static boolean s_engine_ran;
    protected boolean m_engine_started;

	//////////

	public LiveCodeActivity()
	{
	}

    public Class getServiceClass()
    {
        return LiveCodeService.class;
    }

	//////////

	@Override
	protected void onCreate(Bundle p_saved_state)
	{
		super.onCreate(p_saved_state);
		
        // OXT-Beyond: the engine runs once in a process (RelaunchActivity
        // says why). Made again in a process whose engine has run, for a
        // configuration change the manifest does not list or when opened
        // again before its process ended, the activity starts again in a new
        // process instead, where the builder has declared RelaunchActivity
        if (s_engine_ran && RelaunchActivity.relaunch(this))
            return;
        s_engine_ran = true;
        m_engine_started = true;
        
        s_main_layout = new FrameLayout(this);

		// Create the view and notify the engine of its attachment (just in case
		// any following methods cause resize and such to be sent!).
		s_main_view = new Engine(this);
		s_main_view.doCreate(this, s_main_layout, s_main_view);
        
        // PM-2015-06-05: [[ Bug 15110 ]] Prevent black flash when setting the acceleratedRendering to true for the very first time
        SurfaceView t_empty_view = new SurfaceView(this);
        s_main_layout . addView(t_empty_view,
								new FrameLayout.LayoutParams(0,0));
		
		// Add the view into the heirarchy
		s_main_layout . addView(s_main_view,
								new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,
															 FrameLayout.LayoutParams.MATCH_PARENT));
		setContentView(s_main_layout,
					   new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
												  ViewGroup.LayoutParams.MATCH_PARENT));
        
        // prevent soft keyboard from resizing our view when shown
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        
        s_main_layout.getRootView().getViewTreeObserver().addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener()
        {
            @Override
            public void onGlobalLayout()
            {
                s_main_view.updateKeyboardVisible();
            }
        });
        
        // OXT-Beyond: the back button and gesture on Android 13 and newer
        // (registerBackCallback), and the stack kept out of the system bars
        // where Android draws an app edge to edge (keepOutOfSystemBars)
        if (Build.VERSION.SDK_INT >= 33)
            registerBackCallback();
        if (Build.VERSION.SDK_INT >= 35 && getApplicationInfo().targetSdkVersion >= 35)
            keepOutOfSystemBars();
	}
    
    // OXT-Beyond: Android 16 and newer give an app that targets API 36 or
    // newer no onBackPressed and no KEYCODE_BACK: the back button and gesture
    // call the window's OnBackInvokedCallback instead, which does what
    // onBackPressed does (the stack's backKey). Below that, Android ignores
    // the callback (unless the manifest says enableOnBackInvokedCallback) and
    // calls onBackPressed as before
    protected void registerBackCallback()
    {
        getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                                                                  new BackCallback(this));
    }
    
    // A back press, as onBackPressed has it
    protected static class BackCallback implements OnBackInvokedCallback
    {
        protected Activity m_activity;
        
        public BackCallback(Activity p_activity)
        {
            m_activity = p_activity;
        }
        
        @Override
        public void onBackInvoked()
        {
            m_activity.onBackPressed();
        }
    }
    
    // OXT-Beyond: Android 15 and newer draw an app that targets API 35 or
    // newer edge to edge: its window goes under the status and navigation
    // bars and into the display's cutout, and the keyboard no longer resizes
    // it (SOFT_INPUT_ADJUST_RESIZE, the engine's keyboard display "over").
    // The view that holds the stack is padded by them instead, as they stand
    // at each change (the status bar shown or hidden, the keyboard, a
    // rotation), so that the stack has the area it had before; by the
    // keyboard only while the window is to resize for it, as before (with
    // "pan", SOFT_INPUT_ADJUST_PAN, Android moves the window instead)
    protected void keepOutOfSystemBars()
    {
        s_main_layout.setOnApplyWindowInsetsListener(new SystemBarsPadding(this));
    }
    
    protected static class SystemBarsPadding implements View.OnApplyWindowInsetsListener
    {
        protected Activity m_activity;
        
        public SystemBarsPadding(Activity p_activity)
        {
            m_activity = p_activity;
        }
        
        @Override
        public WindowInsets onApplyWindowInsets(View p_view, WindowInsets p_insets)
        {
            int t_types = WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout();
            if ((m_activity.getWindow().getAttributes().softInputMode & WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST) ==
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
                t_types |= WindowInsets.Type.ime();
            Insets t_bars = p_insets.getInsets(t_types);
            p_view.setPadding(t_bars.left, t_bars.top, t_bars.right, t_bars.bottom);
            return WindowInsets.CONSUMED;
        }
    }

	@Override
	protected void onDestroy()
	{
		super.onDestroy();
        // OXT-Beyond: an activity that started the app again in a new
        // process (onCreate) has no engine here
        if (!m_engine_started)
            return;
        // OXT-Beyond: the screen update the engine is in the middle of is
        // finished first (Engine.finishDrawing)
        s_main_view.finishDrawing();
		s_main_view.clearWakeUp();
		s_main_view.onDestroy();
		s_main_layout = null;
		s_main_view = null;
        // OXT-Beyond: the engine has finished, and runs once in a process.
        // When the activity has finished too (the stack quit, as an unhandled
        // backKey quits it, or the user closed the app), its process ends, so
        // that the app opened again starts in a new one, as it does once
        // Android has ended the process. Not for a configuration change,
        // where Android makes the activity again at once (onCreate)
        if (isFinishing() && !isChangingConfigurations())
            endProcess();
	}
    
    // OXT-Beyond: ends this process once the activity's destruction has been
    // reported to Android
    protected static void endProcess()
    {
        Log.i(TAG, "the engine has finished; ending the process");
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run()
            {
                android.os.Process.killProcess(android.os.Process.myPid());
            }
        });
    }
	
	//////////

	@Override
	protected void onRestart()
	{
		super.onRestart();
        if (!m_engine_started)
            return;
		s_main_view.doRestart(s_main_view);
	}
	
	@Override
	protected void onStart()
	{
		super.onStart();
	}

	@Override
	protected void onResume()
	{
		super.onResume();
        if (!m_engine_started)
            return;
		s_main_view.onResume();
	}

	@Override
	protected void onPause()
	{
		super.onPause();
        if (!m_engine_started)
            return;
		s_main_view.onPause();
	}

	@Override
	protected void onStop()
	{
		super.onStop();
	}
	
	//////////
    
    @Override
    protected void onNewIntent(Intent intent)
    {
        if (!m_engine_started)
            return;
        s_main_view.onNewIntent(intent);
    }
    
	//////////

	@Override
	public void onLowMemory()
	{
		super.onLowMemory();

		// During unicodification we will also harden the engine.
		// At this point, we will instruct the engine to minimize
		// its memory usage.

        if (!m_engine_started)
            return;
		s_main_view.doLowMemory();
	}

	//////////

	@Override
	protected void onSaveInstanceState(Bundle p_out_state)
	{
	}

	@Override
	public void onConfigurationChanged(Configuration p_new_config)
	{
		super.onConfigurationChanged(p_new_config);
        if (!m_engine_started)
            return;
		s_main_view.onConfigurationChanged(p_new_config);
	}

	//////////

	@Override
	public void onBackPressed()
	{
        if (!m_engine_started)
            return;
		s_main_view.onBackPressed();
	}
	
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event)
    {
        if (!m_engine_started)
            return super.onKeyDown(keyCode, event);
        if (keyCode == KeyEvent.KEYCODE_MENU && event.getRepeatCount() == 0)
        {
            s_main_view.onMenuKey();
            return true;
        }
        else if (keyCode == KeyEvent.KEYCODE_SEARCH && event.getRepeatCount() == 0)
        {
            s_main_view.onSearchKey();
            return true;
        }
        
        return super.onKeyDown(keyCode, event);
    }

    //////////
    
	static
	{
		System.loadLibrary("revandroid");
	}

////////////////////////////////////////////////////////////////////////////////

	// 
	@Override
	protected void onActivityResult (int requestCode, int resultCode, Intent data)
	{
        if (!m_engine_started)
            return;
		s_main_view.onActivityResult(requestCode, resultCode, data);
	}
    
    // Callback sent when the app requests permissions on runtime (Android API 23+)
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults)
    {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (!m_engine_started)
            return;
        s_main_view.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

}
