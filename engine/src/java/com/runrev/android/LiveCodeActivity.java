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
        // (registerBackCallback), and the stack drawn edge to edge where the
        // app asks for it (drawEdgeToEdge), else kept out of the system bars
        // where Android draws an app edge to edge (keepOutOfSystemBars)
        if (Build.VERSION.SDK_INT >= 33)
            registerBackCallback();
        if (Build.VERSION.SDK_INT >= 30 && asksForEdgeToEdge())
            drawEdgeToEdge();
        else if (Build.VERSION.SDK_INT >= 35 && getApplicationInfo().targetSdkVersion >= 35)
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

    // OXT-Beyond: an app whose stack asks to be drawn edge to edge (the
    // stack's "android,edge to edge" standalone setting, which the Android
    // builder writes into the manifest as this meta-data of the application)
    public static final String EDGE_TO_EDGE = "com.runrev.android.EDGE_TO_EDGE";
    
    // The stack drawn edge to edge (drawEdgeToEdge), else null
    protected static EdgeToEdge s_edge_to_edge;
    
    protected boolean asksForEdgeToEdge()
    {
        try
        {
            Bundle t_meta_data = getPackageManager().getApplicationInfo(getPackageName(), PackageManager.GET_META_DATA).metaData;
            return t_meta_data != null && t_meta_data.getBoolean(EDGE_TO_EDGE, false);
        }
        catch (PackageManager.NameNotFoundException e)
        {
            return false;
        }
    }
    
    // OXT-Beyond: the stack drawn edge to edge, on Android 11 and newer, as
    // the app asks (asksForEdgeToEdge): its window goes under the status and
    // navigation bars, which are see-through, and into the display's
    // cutout, on every Android from 11, as Android 15 and newer draw an app
    // that targets API 35 or newer (the window's colours and contrast are
    // no longer theirs to set there). The keyboard still resizes it, as
    // before, while the window is to resize for it
    // (SOFT_INPUT_ADJUST_RESIZE): the view that holds the stack is padded
    // by the keyboard, and by nothing else. A script finds the part of the
    // screen that the bars, the cutout and the keyboard leave it in the
    // effective working screenRect (Engine.getEffectiveWorkarea), and the
    // bars' icons are dark in the light appearance and light in the dark
    // (showBarsForAppearance), as the stack's systemAppearance says
    protected void drawEdgeToEdge()
    {
        Window t_window = getWindow();
        t_window.setDecorFitsSystemWindows(false);
        t_window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS | WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);
        t_window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        t_window.setStatusBarColor(Color.TRANSPARENT);
        t_window.setNavigationBarColor(Color.TRANSPARENT);
        t_window.setStatusBarContrastEnforced(false);
        WindowManager.LayoutParams t_attributes = t_window.getAttributes();
        t_attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        t_window.setAttributes(t_attributes);
        s_edge_to_edge = new EdgeToEdge(this);
        s_main_layout.setOnApplyWindowInsetsListener(s_edge_to_edge);
        showBarsForAppearance(getResources().getConfiguration());
    }
    
    // The bars' icons dark over a light appearance, light over a dark one
    protected void showBarsForAppearance(Configuration p_config)
    {
        int t_light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
        boolean t_dark = (p_config.uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        WindowInsetsController t_controller = getWindow().getInsetsController();
        if (t_controller != null)
            t_controller.setSystemBarsAppearance(t_dark ? 0 : t_light, t_light);
    }
    
    protected static class EdgeToEdge implements View.OnApplyWindowInsetsListener
    {
        protected Activity m_activity;
        // the bars', the cutout's and the keyboard's insets, as the window
        // last had them (onApplyWindowInsets), null before
        protected Insets m_covered;
        
        public EdgeToEdge(Activity p_activity)
        {
            m_activity = p_activity;
        }
        
        @Override
        public WindowInsets onApplyWindowInsets(View p_view, WindowInsets p_insets)
        {
            Insets t_keyboard = p_insets.getInsets(WindowInsets.Type.ime());
            m_covered = Insets.max(p_insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout()),
                                   t_keyboard);
            int t_bottom = 0;
            if ((m_activity.getWindow().getAttributes().softInputMode & WindowManager.LayoutParams.SOFT_INPUT_MASK_ADJUST) ==
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
                t_bottom = t_keyboard.bottom;
            p_view.setPadding(0, 0, 0, t_bottom);
            return WindowInsets.CONSUMED;
        }
        
        // The part of p_view, in the screen's pixels, that no bar, cutout
        // or keyboard covers, into r_area; false while the window has had
        // no insets
        public boolean uncoveredArea(View p_view, Rect r_area)
        {
            if (m_covered == null || s_main_layout == null)
                return false;
            int[] t_origin = new int[2];
            s_main_layout.getLocationOnScreen(t_origin);
            Rect t_uncovered = new Rect(t_origin[0] + m_covered.left, t_origin[1] + m_covered.top,
                                        t_origin[0] + s_main_layout.getWidth() - m_covered.right,
                                        t_origin[1] + s_main_layout.getHeight() - m_covered.bottom);
            p_view.getLocationOnScreen(t_origin);
            Rect t_view = new Rect(t_origin[0], t_origin[1], t_origin[0] + p_view.getWidth(), t_origin[1] + p_view.getHeight());
            if (!t_uncovered.intersect(t_view))
                t_uncovered.set(t_view.left, t_view.top, t_view.left, t_view.top);
            r_area.set(t_uncovered);
            return true;
        }
    }
    
    // OXT-Beyond: the engine's view asks for the part of it that no bar,
    // cutout or keyboard covers (Engine.getEffectiveWorkarea): false when
    // the stack is not drawn edge to edge
    public static boolean edgeToEdgeUncoveredArea(View p_view, Rect r_area)
    {
        return s_edge_to_edge != null && s_edge_to_edge.uncoveredArea(p_view, r_area);
    }
    
    // OXT-Beyond: the engine's view asks for the size of the screen that a
    // stack drawn edge to edge fills (Engine.getViewport): the whole of its
    // window, the bars and the cutout included, from (0, 0), where the
    // default display's metrics leave the navigation bar and the cutout
    // out; false when the stack is not drawn edge to edge
    public static boolean edgeToEdgeWindowSize(Rect r_size)
    {
        if (s_edge_to_edge == null)
            return false;
        Rect t_bounds = s_edge_to_edge.m_activity.getWindowManager().getCurrentWindowMetrics().getBounds();
        r_size.set(0, 0, t_bounds.width(), t_bounds.height());
        return true;
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
        // OXT-Beyond: the bars' icons follow the appearance (night mode)
        if (s_edge_to_edge != null)
            showBarsForAppearance(p_new_config);
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
