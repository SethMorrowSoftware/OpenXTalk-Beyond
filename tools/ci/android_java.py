#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""The Android runtime's Java layer, Runtime/Android/Classes: build it from
this repository's sources, compare it with another build of it class by
class and method by method, and check that it agrees with the Android engine
across JNI (the Android plan's phase 1).

  python3 tools/ci/android_java.py build --sdk DIR --out FILE [--api N] [--jdk DIR]
  python3 tools/ci/android_java.py compare --old FILE --new FILE
  python3 tools/ci/android_java.py jni --classes FILE --runtime DIR [--android-jar FILE]

build compiles the Java sources that LiveCode's own build compiled into
Classes (engine_java_source_files and engine_aidl_source_files of
engine/engine-sources.gypi, as engine/kernel.gyp and config/java.gypi did),
with the JDK's javac for Java 8 against the SDK's android.jar of --api, into
a jar whose bytes depend only on the class files (names sorted, one fixed
time). Each AIDL interface is compiled from the Java kept beside its .aidl
file, which is what LiveCode's build had aidl make of it (compare checks
that against the shipped classes), so that javac is the only tool it
needs.

compare reads two such jars (the released runtime's and a new build) and
fails on any difference that EXPECTED does not name for the old jar's
SHA-256: a class or member that is gone or changed, and a method whose code
differs. Code is compared as the instructions mean it, not as the bytes
lie, so that two compilers' ways of writing the same method compare equal
(code_listing says which differences it sees through). Classes and members
that only the new jar has are listed, and fail only when the old jar has no
entry in EXPECTED. An entry of EXPECTED that no longer differs fails too,
so that the list cannot keep a reason that is no longer true.

jni checks the two ways the native engine and the Java layer meet:

  - every Java_* function that an engine of the runtime (each architecture's
    Standalone) exports is a native method of a class in the jar, and
    every native method of the jar has its Java_* function in every
    engine, apart from UNEXPORTED (natives the engine never had);
  - every Java method that the engine's C++ sources look up by name and
    signature (MCAndroid*Call, GetMethodID, GetStaticMethodID; the
    sources in NATIVE_SOURCES) is there with that signature, in the class
    the call names or, for calls on an object, in a class of the jar or one
    of its Android superclasses (--android-jar, the SDK's android.jar);
    the calls whose method name the arm64 engine does not hold are
    counted apart, as calls of the source that the runtime's engine does
    not make;
  - every binding of an LCB extension to a class of the jar
    ("java:com.runrev...", extensions/**/*.lcb) is there, as the binding
    says (an interface, a static method, a method);
  - every class of the jar that the runtime's Manifest.xml or the
    standalone builder names (com.runrev.android.X) is there.

Exit status 0 when every check passed, 1 otherwise. Only the Python 3
standard library is used (3.8 or later), with the JDK's javac for build.
"""

import argparse
import fnmatch
import glob
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
GYPI = os.path.join(REPO, 'engine', 'engine-sources.gypi')
ENGINE_DIR = os.path.join(REPO, 'engine')
JAVA_ROOT = os.path.join(ENGINE_DIR, 'src', 'java')
ABIS = ('armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64')
ENGINE_NAME = 'Standalone'
DEFAULT_API = '36'
# One time for every entry of the jar, so that its bytes depend only on
# the class files (zip's own earliest time)
JAR_TIME = (1980, 1, 1, 0, 0, 0)

# The C++ sources whose calls into the Java layer jni checks (relative to
# the repository, glob patterns)
NATIVE_SOURCES = ('engine/src/*.cpp', 'libbrowser/src/libbrowser_android.cpp',
                  'libfoundation/src/foundation-java-private.cpp')
LCB_SOURCES = 'extensions'
# Files that name classes of the jar for Android to load by name: the
# manifest the builder starts from, and the builder's own Java
BUILDER = os.path.join(REPO, 'ide-support', 'revsaveasandroidstandalone.livecodescript')

# Native methods that the jar declares and no engine of the runtime has
# ever exported, each with why that is harmless; jni fails on any other
# native method without its Java_* function, and on an entry here that is
# exported (or gone) now
UNEXPORTED = {
    'com/runrev/android/Engine.doShowCalendarEvent:(Ljava/lang/String;)V':
        'declared and never called; the C++ declares Java_..._doShowCalendarEvent and never defines it',
    'com/runrev/android/Engine.doShowContact:(I)V':
        'declared and never called; the C++ declares Java_..._doShowContact and never defines it',
    'com/runrev/android/Engine.doUrlDidRequest:(I)V':
        'declared and never called; no C++ has it',
}

# The engine's calls into Java that find no such method, in the released
# runtime's Classes as in a build from this tree (the classes have the
# same members), by (source file, method, signature as the source writes
# it): what each costs. The call finds no method, so it does nothing (the
# engine clears the pending exception) and the feature behind it does not
# work on Android today. Making them work is new behaviour, for later
# phases; jni fails on any other call that finds no method, and on an
# entry here that finds its method now (or is no longer made)
KNOWN_CALLS = {
    ('engine/src/mblandroidcalendar.cpp', 'showCalendarEvent', 'vx'):
        'mobileShowEvent: the Java layer has no showCalendarEvent (the source says "TODO - IMPLEMENT SUPPORT '
        'FOR API LEVEL 14")',
    ('engine/src/mblandroidcalendar.cpp', 'getCalendarEventData', 'vx'):
        'mobileGetEventData: the Java layer has no getCalendarEventData (the same TODO)',
    ('engine/src/mblandroidcalendar.cpp', 'removeCalendarEvent', 'xx'):
        'mobileRemoveEvent: the Java layer has no removeCalendarEvent (the same TODO)',
    ('engine/src/mblandroidcalendar.cpp', 'addCalendarEvent', 'xxxxxbbbbiixiix'):
        'mobileAddEvent: the Java layer has no addCalendarEvent (the same TODO)',
    ('engine/src/mblandroidinput.cpp', 'getTextAlign', 'v'):
        'mobileControlGet of a native field\'s "textAlign": the engine asks for a method returning void, '
        'InputView.getTextAlign returns an int, so the engine answers its default (left)',
    ('engine/src/mblandroidinput.cpp', 'getKeyboardType', 'v'):
        'mobileControlGet of a native field\'s "keyboardType": as getTextAlign, the engine answers its default',
}

# compare: the LiveCodeActivity methods that pass nothing to an engine the
# activity did not start (one that started the app again in a new process,
# RelaunchActivity), each with the reason: a difference from LiveCode
# 9.6.3's Classes and from the first Classes built here alike
RELAUNCH_GUARDS = {
    'code com/runrev/android/LiveCodeActivity.onRestart:()V':
        'in an activity that started the app again in a new process (onCreate), which has no engine, it '
        'passes nothing to one: Android can still call that activity before it is destroyed, as it did '
        'with the configuration change of a density\'s return, which crashed on the null engine; an '
        'activity that started the engine does what it did',
    'code com/runrev/android/LiveCodeActivity.onResume:()V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onPause:()V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onNewIntent:(Landroid/content/Intent;)V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onLowMemory:()V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onConfigurationChanged:(Landroid/content/res/Configuration;)V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onBackPressed:()V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onKeyDown:(ILandroid/view/KeyEvent;)Z':
        'the same, and the key is Android\'s there (super.onKeyDown)',
    'code com/runrev/android/LiveCodeActivity.onActivityResult:(IILandroid/content/Intent;)V':
        'the same as onRestart: nothing to an engine the activity did not start',
    'code com/runrev/android/LiveCodeActivity.onRequestPermissionsResult:(I[Ljava/lang/String;[I)V':
        'the same as onRestart: nothing to an engine the activity did not start',
}

# compare: what the engine view and the activity do so that the engine
# finishes showing what it drew before the activity is destroyed
# (Engine.finishDrawing), each with the reason: a difference from LiveCode
# 9.6.3's Classes and from every one built here before it alike
FINISH_DRAWING = {
    'code com/runrev/android/Engine.scheduleWakeUp:(IZ)V':
        'it notes that the engine has not drawn as it yielded (m_wake_after_drawing), which invalidateBitmap '
        'then notes it has, for finishDrawing; the wake-up is scheduled as before',
    'code com/runrev/android/Engine.invalidateBitmap:(IIII)V':
        'it notes that the engine drew as it yielded (m_wake_after_drawing, for finishDrawing); it invalidates '
        'as before',
}
FINISH_DRAWING_ON_DESTROY = (
    'before the wake-up is cleared and the engine destroyed, the activity lets the engine finish showing what it '
    'drew (Engine.finishDrawing runs the wake-up the engine asked for as it drew, as the handler would have): '
    'Android 16 made the activity again for a density change while the engine was in the middle of that, and '
    'LiveCode 9.6.3\'s engine, destroyed there, went on from the drawing only to wait again, so Android\'s thread '
    'waited for it for good and the screen stayed black. An activity whose engine yielded without drawing is '
    'destroyed as before')

# compare: what a build from this repository's sources does differently
# from a released runtime's Classes, by the released jar's SHA-256, each
# with the reason. A key is "class X", "member X.name:descriptor" (gone or
# changed) or "code X.name:descriptor" (the method's code differs).
EXPECTED = {
    # oxt-runtimes-1.15's Runtime/Android/Classes (LiveCode Community
    # 9.6.3's, built 2021-07-26), carried in every runtimes asset since
    'c10841215d429fdc084025805c1abfcaef2e2f8086da4af9cf5935f36159dbc0': {
        # LiveCode's later edits of the same code, which this tree has
        'code com/runrev/android/Engine.updateKeyboardVisible:()V':
            'LiveCode\'s later fix: when the keyboard shows or hides while the engine waits for an event, '
            'it wakes the engine (doProcess, as every other event here does), so keyboardActivated and '
            'keyboardDeactivated are sent then, not at the next event',
        'code com/runrev/android/FileProvider.validQuery:([Ljava/lang/String;)Z':
            'LiveCode\'s later fix: another app that asks for a file the app shares (mobileComposeMail\'s '
            'attachments) with no projection, which Android\'s contract reads as every column, got an '
            'exception (projection.length of null), and now gets the columns',
        'code com/runrev/android/FileProvider.doQuery:(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;'
        '[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;':
            'the same fix: with no projection, every column the file has',
        # OXT-Beyond's changes for API 31 and newer
        'code com/runrev/android/NotificationModule.resetTimer:(Landroid/content/Context;)V':
            'the alarm\'s PendingIntent says FLAG_IMMUTABLE on Android 12 and newer, which threw without it '
            '(Utils.immutablePendingIntentFlags); older Android is given 0 as before',
        'code com/runrev/android/NotificationModule.createNotificationContentIntent:(Landroid/content/Context;)'
        'Landroid/app/PendingIntent;':
            'the notification\'s PendingIntent: FLAG_IMMUTABLE on Android 12 and newer, as resetTimer',
        'code com/runrev/android/NotificationModule.createNotificationCancelIntent:(Landroid/content/Context;I)'
        'Landroid/app/PendingIntent;':
            'the notification\'s cancel PendingIntent: FLAG_IMMUTABLE on Android 12 and newer, as resetTimer',
        'code com/runrev/android/NotificationModule.registerForRemoteNotifications:(Ljava/lang/String;)Z':
            'the C2DM registration\'s PendingIntent: FLAG_IMMUTABLE on Android 12 and newer, as resetTimer',
        'code com/runrev/android/NFCModule.startDispatch:()V':
            'NFC foreground dispatch\'s PendingIntent says FLAG_MUTABLE on Android 12 and newer (Android adds '
            'the tag to it), which threw without it (Utils.mutablePendingIntentFlags)',
        # OXT-Beyond's changes for API 33 and newer
        'code com/runrev/android/NotificationModule.createLocalNotification:(Ljava/lang/String;Ljava/lang/String;'
        'Ljava/lang/String;JZI)J':
            'on Android 13 and newer, an app whose manifest declares POST_NOTIFICATIONS (the Android card\'s '
            '"Post Notifications") asks the user once a run to let it post notifications when it schedules one '
            'and may not (requestPostNotifications); an app that does not declare it is never asked, as before, '
            'and the notification is scheduled as before either way',
        'code com/runrev/android/Engine.onRequestPermissionsResult:(I[Ljava/lang/String;[I)V':
            'only androidRequestPermission\'s request code answers it, not the notification module\'s; and '
            'a request that Android answers with no results (interrupted, or made while another showed) answers '
            'false, where reading the first result threw',
        'code com/runrev/android/Engine.askPermission:(Ljava/lang/String;)Z':
            'on Android 13 and newer, WRITE_EXTERNAL_STORAGE counts as granted without asking for an app that '
            'declares it (the Android card\'s "Write External Storage") and targets API 30 or newer '
            '(grantedWithoutAsking): Android refuses it there without asking, and it gives such an app nothing, '
            'so what the engine asks for it first (specialFolderPath("external documents") and ("external '
            'cache"), mobileExportImageToAlbum, androidRequestPermission) failed; every other permission, an app '
            'that does not declare it, and Android 12 and older are asked as before',
        'code com/runrev/android/Engine.checkHasPermissionGranted:(Ljava/lang/String;)Z':
            'the same: androidHasPermission answers true for WRITE_EXTERNAL_STORAGE there',
        'code com/runrev/android/Engine.exportImageToAlbum:([BLjava/lang/String;Ljava/lang/String;)'
        'Ljava/lang/String;':
            'on Android 10 and newer the image is added to the shared Pictures folder through MediaStore '
            '(exportImageToMediaStore), as Android asks; writing the file there failed on Android 10, and on '
            'Android 11 and newer for a name that another app\'s picture has (MediaStore names the new one '
            'apart). The same folder, name and answer otherwise, a picture the app added before is written over '
            'as before, and Android 9 and older write the file as before',
        # OXT-Beyond's changes for API 35 and 36
        'code com/runrev/android/LiveCodeActivity.onCreate:(Landroid/os/Bundle;)V':
            'on Android 13 and newer it registers a back callback that does what onBackPressed does '
            '(registerBackCallback): Android 16 and newer call only that for an app that targets API 36, and '
            'ignore it below that, where onBackPressed is called as before; and on Android 15 and newer, for an '
            'app that targets API 35 or newer, which Android draws edge to edge, it pads the view that holds the '
            'stack by the system bars, the cutout and the keyboard (keepOutOfSystemBars), so the stack keeps the '
            'area it had; an app that targets less is laid out as before. Made again in a process whose engine '
            'has run, it starts the app again in a new process (RelaunchActivity) where the manifest declares '
            'that, instead of starting the engine a second time, which Android 11 and newer stop for an app '
            'that targets API 30 or newer (fdsan); without the declaration it starts the engine as before',
        # OXT-Beyond: the engine runs once in a process
        'code com/runrev/android/LiveCodeActivity.onDestroy:()V':
            'once the engine has finished and the activity is finishing (the stack quit, as an unhandled '
            'backKey quits it, or the user closed the app), the process ends (endProcess), so that the app '
            'opened again starts its engine in a new process, as after Android ends the process: opened again '
            'in the same one, its second engine was stopped on Android 11 and newer (fdsan). Not for a '
            'configuration change; and an activity that started the app again in a new process (onCreate) has '
            'no engine to finish. And ' + FINISH_DRAWING_ON_DESTROY,
        **RELAUNCH_GUARDS,
        **FINISH_DRAWING,
        'code com/runrev/android/BusyIndicator.showBusyIndicator:(Ljava/lang/String;)V':
            'the busy indicator\'s dialog gets the same back callback on Android 13 and newer (Android 16 sends '
            'an app that targets API 36 no KEYCODE_BACK), which does what its key listener does',
        'code com/runrev/android/BusyIndicator$1.onKey:(Landroid/content/DialogInterface;ILandroid/view/KeyEvent;)Z':
            'the key listener calls backPressed, which does what it did (every busy indicator dismissed, then '
            'the stack\'s backKey), so that the back callback can do the same',
        # OXT-Beyond's engine built from this tree (the Android plan's phase 2)
        'code com/runrev/android/OpenGLView.start:()V':
            'start() calls startGLES(1), whose code is start()\'s with one branch added: for 1 it makes the '
            'same context, OpenGL ES 1 asked for with no attributes, which this engine draws in; startGLES(3) '
            'makes the OpenGL ES 3 context an engine built from this tree asks for (mblandroiddc.cpp)',
    },
    # oxt-runtimes-0.2.7-rc.6.18b's Runtime/Android/Classes, built here
    # (android_java.py build) from commit b970cad06, the first asset with
    # a Java layer of this repository's: what has changed since
    'e28f35a674222e798ed824ab2a22b0c6370dc37e86573a34565af0dbd6050360': {
        **RELAUNCH_GUARDS,
        **FINISH_DRAWING,
        'code com/runrev/android/LiveCodeActivity.onDestroy:()V': FINISH_DRAWING_ON_DESTROY,
    },
    # oxt-runtimes-0.2.7-rc.6.19's Runtime/Android/Classes, built here
    # from commit 7f5d3e6c5 (its PROVENANCE.md gives this SHA-256)
    '328a531ae3d1f5845fbaa4174760187f2e7435855a5481541f9f8927880e414d': {
        **FINISH_DRAWING,
        'code com/runrev/android/LiveCodeActivity.onDestroy:()V': FINISH_DRAWING_ON_DESTROY,
    },
}


class CheckError(Exception):
    pass


def log(msg=''):
    print(msg, flush=True)


def gha():
    return os.environ.get('GITHUB_ACTIONS') == 'true'


def annotate(kind, msg):
    if gha():
        print('::%s::%s' % (kind, msg.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')), flush=True)


def summary(text):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if path:
        with open(path, 'a', encoding='utf-8') as f:
            f.write(text + '\n')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Class files

ACC_PUBLIC = 0x0001
ACC_PRIVATE = 0x0002
ACC_PROTECTED = 0x0004
ACC_STATIC = 0x0008
ACC_FINAL = 0x0010
ACC_SUPER = 0x0020
ACC_NATIVE = 0x0100
ACC_INTERFACE = 0x0200
ACC_ABSTRACT = 0x0400
ACC_SYNTHETIC = 0x1000

ACCESS_WORDS = ((0x0001, 'public'), (0x0002, 'private'), (0x0004, 'protected'), (0x0008, 'static'),
                (0x0010, 'final'), (0x0100, 'native'), (0x0200, 'interface'), (0x0400, 'abstract'),
                (0x4000, 'enum'), (0x2000, 'annotation'))
# Method flags compared besides those: synchronized (0x0020) and strictfp
# (0x0800); volatile and transient (0x0040, 0x0080) for fields. Bridge and
# varargs (0x0040, 0x0080 of a method) say how javac wrote it, not what it
# is
MEMBER_MASK = {'method': 0x0001 | 0x0002 | 0x0004 | 0x0008 | 0x0010 | 0x0020 | 0x0100 | 0x0400 | 0x0800,
               'field': 0x0001 | 0x0002 | 0x0004 | 0x0008 | 0x0010 | 0x0040 | 0x0080 | 0x4000}
CLASS_MASK = 0x0001 | 0x0010 | 0x0200 | 0x0400 | 0x2000 | 0x4000
ANONYMOUS = re.compile(r'\$\d+$')


def access_words(flags):
    return ' '.join(w for bit, w in ACCESS_WORDS if flags & bit)


class JavaClass(object):
    """What compare and jni need of one class file: its name, flags,
    superclass and interfaces, its fields and methods (name, descriptor,
    flags, and a method's Code attribute), its constant pool and its class
    file version."""

    def __init__(self, name, access, super_name, interfaces, fields, methods, pool, major):
        self.name = name
        self.access = access
        self.super_name = super_name
        self.interfaces = interfaces
        self.fields = fields      # {(name, desc): (access, constant value or None)}
        self.methods = methods    # {(name, desc): (access, code bytes or None, exception table)}
        self.pool = pool
        self.major = major


def parse_class(data):
    """A JavaClass from a class file's bytes."""
    if data[:4] != b'\xca\xfe\xba\xbe':
        raise CheckError('not a class file')

    def u2(pos):
        return struct.unpack('>H', data[pos:pos + 2])[0]

    def u4(pos):
        return struct.unpack('>I', data[pos:pos + 4])[0]

    major = u2(6)
    count = u2(8)
    pool = [None] * count
    pos = 10
    i = 1
    while i < count:
        tag = data[pos]
        if tag == 1:
            n = u2(pos + 1)
            pool[i] = ('utf8', data[pos + 3:pos + 3 + n].decode('utf-8', 'replace'))
            pos += 3 + n
        elif tag == 3:
            pool[i] = ('int', struct.unpack('>i', data[pos + 1:pos + 5])[0])
            pos += 5
        elif tag == 4:
            pool[i] = ('float', data[pos + 1:pos + 5].hex())
            pos += 5
        elif tag == 5:
            pool[i] = ('long', struct.unpack('>q', data[pos + 1:pos + 9])[0])
            pos += 9
            i += 1
        elif tag == 6:
            pool[i] = ('double', data[pos + 1:pos + 9].hex())
            pos += 9
            i += 1
        elif tag in (7, 8, 16, 19, 20):
            pool[i] = ({7: 'class', 8: 'string', 16: 'methodtype', 19: 'module', 20: 'package'}[tag], u2(pos + 1))
            pos += 3
        elif tag in (9, 10, 11, 12, 17, 18):
            pool[i] = ({9: 'field', 10: 'method', 11: 'imethod', 12: 'nameandtype', 17: 'dynamic',
                        18: 'indy'}[tag], u2(pos + 1), u2(pos + 3))
            pos += 5
        elif tag == 15:
            pool[i] = ('handle', data[pos + 1], u2(pos + 2))
            pos += 4
        else:
            raise CheckError('unknown constant pool tag %d' % tag)
        i += 1

    def utf8(idx):
        return pool[idx][1]

    def class_name(idx):
        return utf8(pool[idx][1]) if idx else None

    access = u2(pos)
    name = class_name(u2(pos + 2))
    super_name = class_name(u2(pos + 4))
    pos += 6
    interfaces = []
    for _ in range(u2(pos)):
        interfaces.append(class_name(u2(pos + 2)))
        pos += 2
    pos += 2

    def members(pos, kind):
        out = {}
        n = u2(pos)
        pos += 2
        for _ in range(n):
            acc, ni, di, ac = u2(pos), u2(pos + 2), u2(pos + 4), u2(pos + 6)
            pos += 8
            code = None
            handlers = []
            value = None
            for _ in range(ac):
                an = utf8(u2(pos))
                alen = u4(pos + 2)
                body = data[pos + 6:pos + 6 + alen]
                if kind == 'method' and an == 'Code':
                    code_len = struct.unpack('>I', body[4:8])[0]
                    code = body[8:8 + code_len]
                    p = 8 + code_len
                    for k in range(struct.unpack('>H', body[p:p + 2])[0]):
                        handlers.append(struct.unpack('>HHHH', body[p + 2 + 8 * k:p + 10 + 8 * k]))
                elif kind == 'field' and an == 'ConstantValue':
                    value = struct.unpack('>H', body[:2])[0]
                pos += 6 + alen
            key = (utf8(ni), utf8(di))
            out[key] = (acc, code, handlers) if kind == 'method' else (acc, value)
        return out, pos

    fields, pos = members(pos, 'field')
    methods, pos = members(pos, 'method')
    return JavaClass(name, access, super_name, interfaces, fields, methods, pool, major)


def read_jar(path):
    """{class name: JavaClass} of a jar (or zip) of class files."""
    out = {}
    try:
        with zipfile.ZipFile(path) as z:
            for info in z.infolist():
                if info.filename.endswith('.class'):
                    c = parse_class(z.read(info))
                    out[c.name] = c
    except zipfile.BadZipFile:
        raise CheckError('%s is not a jar' % path)
    return out


def constant(pool, idx):
    """A constant pool entry as text that does not depend on where it is in
    the pool: a class name, a string, a number, owner.name:descriptor."""
    e = pool[idx]
    kind = e[0]
    if kind == 'utf8':
        return e[1]
    if kind in ('int', 'long', 'float', 'double'):
        return '%s %s' % (kind, e[1])
    if kind == 'class':
        return pool[e[1]][1]
    if kind == 'string':
        return 'string ' + repr(pool[e[1]][1])
    if kind == 'methodtype':
        return 'methodtype ' + pool[e[1]][1]
    if kind in ('field', 'method', 'imethod'):
        owner = pool[pool[e[1]][1]][1]
        nt = pool[e[2]]
        return '%s.%s:%s' % (owner, pool[nt[1]][1], pool[nt[2]][1])
    if kind == 'nameandtype':
        return '%s:%s' % (pool[e[1]][1], pool[e[2]][1])
    if kind in ('indy', 'dynamic'):
        nt = pool[e[2]]
        return '%s #%d %s:%s' % (kind, e[1], pool[nt[1]][1], pool[nt[2]][1])
    if kind == 'handle':
        return 'handle %d %s' % (e[1], constant(pool, e[2]))
    return '%s %r' % (kind, e[1:])


# ---------------------------------------------------------------------------
# Code, as the instructions mean it

OPCODES = {
    0x00: 'nop', 0x01: 'aconst_null', 0x2e: 'iaload', 0x2f: 'laload', 0x30: 'faload', 0x31: 'daload',
    0x32: 'aaload', 0x33: 'baload', 0x34: 'caload', 0x35: 'saload', 0x4f: 'iastore', 0x50: 'lastore',
    0x51: 'fastore', 0x52: 'dastore', 0x53: 'aastore', 0x54: 'bastore', 0x55: 'castore', 0x56: 'sastore',
    0x57: 'pop', 0x58: 'pop2', 0x59: 'dup', 0x5a: 'dup_x1', 0x5b: 'dup_x2', 0x5c: 'dup2', 0x5d: 'dup2_x1',
    0x5e: 'dup2_x2', 0x5f: 'swap', 0x60: 'iadd', 0x61: 'ladd', 0x62: 'fadd', 0x63: 'dadd', 0x64: 'isub',
    0x65: 'lsub', 0x66: 'fsub', 0x67: 'dsub', 0x68: 'imul', 0x69: 'lmul', 0x6a: 'fmul', 0x6b: 'dmul',
    0x6c: 'idiv', 0x6d: 'ldiv', 0x6e: 'fdiv', 0x6f: 'ddiv', 0x70: 'irem', 0x71: 'lrem', 0x72: 'frem',
    0x73: 'drem', 0x74: 'ineg', 0x75: 'lneg', 0x76: 'fneg', 0x77: 'dneg', 0x78: 'ishl', 0x79: 'lshl',
    0x7a: 'ishr', 0x7b: 'lshr', 0x7c: 'iushr', 0x7d: 'lushr', 0x7e: 'iand', 0x7f: 'land', 0x80: 'ior',
    0x81: 'lor', 0x82: 'ixor', 0x83: 'lxor', 0x85: 'i2l', 0x86: 'i2f', 0x87: 'i2d', 0x88: 'l2i',
    0x89: 'l2f', 0x8a: 'l2d', 0x8b: 'f2i', 0x8c: 'f2l', 0x8d: 'f2d', 0x8e: 'd2i', 0x8f: 'd2l', 0x90: 'd2f',
    0x91: 'i2b', 0x92: 'i2c', 0x93: 'i2s', 0x94: 'lcmp', 0x95: 'fcmpl', 0x96: 'fcmpg', 0x97: 'dcmpl',
    0x98: 'dcmpg', 0xac: 'ireturn', 0xad: 'lreturn', 0xae: 'freturn', 0xaf: 'dreturn', 0xb0: 'areturn',
    0xb1: 'return', 0xbe: 'arraylength', 0xbf: 'athrow', 0xc2: 'monitorenter', 0xc3: 'monitorexit',
}
BRANCHES = {0x99: 'ifeq', 0x9a: 'ifne', 0x9b: 'iflt', 0x9c: 'ifge', 0x9d: 'ifgt', 0x9e: 'ifle',
            0x9f: 'if_icmpeq', 0xa0: 'if_icmpne', 0xa1: 'if_icmplt', 0xa2: 'if_icmpge', 0xa3: 'if_icmpgt',
            0xa4: 'if_icmple', 0xa5: 'if_acmpeq', 0xa6: 'if_acmpne', 0xa7: 'goto', 0xa8: 'jsr',
            0xc6: 'ifnull', 0xc7: 'ifnonnull'}
POOL_OPS = {0xb2: 'getstatic', 0xb3: 'putstatic', 0xb4: 'getfield', 0xb5: 'putfield', 0xb6: 'invokevirtual',
            0xb7: 'invokespecial', 0xb8: 'invokestatic', 0xbb: 'new', 0xbd: 'anewarray', 0xc0: 'checkcast',
            0xc1: 'instanceof'}
LOADS = 'ilfda'
# java.lang.Object's methods, which javac calls through the receiver's own
# static type (an interface's invokeinterface) or through Object
# (invokevirtual) as its version chose: the same method at run time
OBJECT_METHODS = ('toString:()Ljava/lang/String;', 'hashCode:()I', 'equals:(Ljava/lang/Object;)Z',
                  'getClass:()Ljava/lang/Class;')


def code_listing(cls, code, handlers, descriptor, static):
    """A method's code as a list of instructions that two compilers that
    mean the same thing write the same way, whatever the bytes:

      - constant pool references by what they name, not their index (ldc
        and ldc_w are one instruction, as are goto and goto_w);
      - a branch's target by instruction, not byte offset, and a switch as
        its keys and targets (tableswitch or lookupswitch, as javac chose);
      - small constants by value (iconst_2, bipush 2 and sipush 2 alike);
      - local variables past the parameters numbered in the order the code
        first uses them (javac's versions give them different slots);
      - a call of java.lang.Object's toString, hashCode, equals or getClass
        by name only (javac names the receiver's interface, or Object);
      - checkcast left out (newer javac drops casts it proves redundant);
      - the exception table as instruction ranges and handler."""
    if code is None:
        return []
    pool = cls.pool
    params = parameter_slots(descriptor) + (0 if static else 1)
    slots = {}

    def local(n):
        if n < params:
            return 'p%d' % n
        if n not in slots:
            slots[n] = 'v%d' % len(slots)
        return slots[n]

    insns = []      # (offset, [parts]) with branch targets as offsets for now
    pos = 0
    n = len(code)
    while pos < n:
        op = code[pos]
        start = pos
        if op in OPCODES:
            parts = [OPCODES[op]]
            pos += 1
        elif 0x02 <= op <= 0x08:
            parts = ['const', op - 3]
            pos += 1
        elif op in (0x09, 0x0a):
            parts = ['lconst', op - 0x09]
            pos += 1
        elif 0x0b <= op <= 0x0d:
            parts = ['fconst', op - 0x0b]
            pos += 1
        elif op in (0x0e, 0x0f):
            parts = ['dconst', op - 0x0e]
            pos += 1
        elif op == 0x10:
            parts = ['const', struct.unpack('>b', code[pos + 1:pos + 2])[0]]
            pos += 2
        elif op == 0x11:
            parts = ['const', struct.unpack('>h', code[pos + 1:pos + 3])[0]]
            pos += 3
        elif op == 0x12:
            parts = ['ldc', constant(pool, code[pos + 1])]
            pos += 2
        elif op in (0x13, 0x14):
            parts = ['ldc', constant(pool, struct.unpack('>H', code[pos + 1:pos + 3])[0])]
            pos += 3
        elif 0x15 <= op <= 0x19:
            parts = [LOADS[op - 0x15] + 'load', local(code[pos + 1])]
            pos += 2
        elif 0x1a <= op <= 0x2d:
            parts = [LOADS[(op - 0x1a) // 4] + 'load', local((op - 0x1a) % 4)]
            pos += 1
        elif 0x36 <= op <= 0x3a:
            parts = [LOADS[op - 0x36] + 'store', local(code[pos + 1])]
            pos += 2
        elif 0x3b <= op <= 0x4e:
            parts = [LOADS[(op - 0x3b) // 4] + 'store', local((op - 0x3b) % 4)]
            pos += 1
        elif op == 0x84:
            parts = ['iinc', local(code[pos + 1]), struct.unpack('>b', code[pos + 2:pos + 3])[0]]
            pos += 3
        elif op in BRANCHES:
            parts = [BRANCHES[op], ('to', start + struct.unpack('>h', code[pos + 1:pos + 3])[0])]
            pos += 3
        elif op in (0xc8, 0xc9):
            parts = ['goto' if op == 0xc8 else 'jsr', ('to', start + struct.unpack('>i', code[pos + 1:pos + 5])[0])]
            pos += 5
        elif op == 0xa9:
            parts = ['ret', local(code[pos + 1])]
            pos += 2
        elif op in (0xaa, 0xab):
            pos = start + 1 + ((4 - (start + 1) % 4) % 4)
            default = start + struct.unpack('>i', code[pos:pos + 4])[0]
            cases = []
            if op == 0xaa:
                low, high = struct.unpack('>ii', code[pos + 4:pos + 12])
                pos += 12
                for k in range(high - low + 1):
                    target = start + struct.unpack('>i', code[pos:pos + 4])[0]
                    pos += 4
                    if target != default:
                        cases.append((low + k, ('to', target)))
            else:
                npairs = struct.unpack('>i', code[pos + 4:pos + 8])[0]
                pos += 8
                for _ in range(npairs):
                    key, off = struct.unpack('>ii', code[pos:pos + 8])
                    pos += 8
                    if start + off != default:
                        cases.append((key, ('to', start + off)))
            parts = ['switch', ('to', default), cases]
        elif op in POOL_OPS:
            ref = constant(pool, struct.unpack('>H', code[pos + 1:pos + 3])[0])
            name = POOL_OPS[op]
            if name == 'invokevirtual' and ref.split('.', 1)[-1] in OBJECT_METHODS:
                parts = ['invoke-object', ref.split('.', 1)[-1]]
            elif name == 'checkcast':
                parts = None
            else:
                parts = [name, ref]
            pos += 3
        elif op == 0xb9:
            ref = constant(pool, struct.unpack('>H', code[pos + 1:pos + 3])[0])
            method = ref.split('.', 1)[-1]
            parts = ['invoke-object', method] if method in OBJECT_METHODS else ['invokeinterface', ref]
            pos += 5
        elif op == 0xba:
            parts = ['invokedynamic', constant(pool, struct.unpack('>H', code[pos + 1:pos + 3])[0])]
            pos += 5
        elif op == 0xbc:
            parts = ['newarray', code[pos + 1]]
            pos += 2
        elif op == 0xc4:
            sub = code[pos + 1]
            idx = struct.unpack('>H', code[pos + 2:pos + 4])[0]
            if sub == 0x84:
                parts = ['iinc', local(idx), struct.unpack('>h', code[pos + 4:pos + 6])[0]]
                pos += 6
            elif 0x15 <= sub <= 0x19:
                parts = [LOADS[sub - 0x15] + 'load', local(idx)]
                pos += 4
            elif 0x36 <= sub <= 0x3a:
                parts = [LOADS[sub - 0x36] + 'store', local(idx)]
                pos += 4
            else:
                parts = ['ret', local(idx)]
                pos += 4
        elif op == 0xc5:
            parts = ['multianewarray', constant(pool, struct.unpack('>H', code[pos + 1:pos + 3])[0]), code[pos + 3]]
            pos += 4
        else:
            raise CheckError('%s: unknown instruction 0x%02x at %d' % (cls.name, op, start))
        insns.append((start, parts))

    # Offsets to instruction numbers. A cast that is left out still counts
    # as an instruction for branches that land on it: it maps to the next
    # one that is kept
    kept = [(off, parts) for off, parts in insns if parts is not None]
    index = {}
    k = 0
    for off, parts in insns:
        index[off] = k
        if parts is not None:
            k += 1
    index[n] = k

    def target(x):
        if isinstance(x, tuple) and x and x[0] == 'to':
            return 'L%d' % index[x[1]]
        if isinstance(x, list):
            return [(key, target(t)) for key, t in x]
        return x

    out = [' '.join(str(target(p)) for p in parts) for _, parts in kept]
    for start_pc, end_pc, handler_pc, catch in handlers:
        out.append('catch %s L%d-L%d -> L%d' % (constant(pool, catch) if catch else 'any', index[start_pc],
                                                index[end_pc], index[handler_pc]))
    return out


def parameter_types(descriptor):
    """The parameter types of a method descriptor, each as written in it."""
    m = re.match(r'\((.*)\)', descriptor)
    if not m:
        raise CheckError('not a method descriptor: %s' % descriptor)
    return re.findall(r'\[*(?:L[^;]+;|[ZBCSIJFD])', m.group(1))


def parameter_slots(descriptor):
    return sum(2 if t in ('J', 'D') else 1 for t in parameter_types(descriptor))


# ---------------------------------------------------------------------------
# compare

def class_header(c):
    access = c.access & CLASS_MASK
    if ANONYMOUS.search(c.name):
        # javac 9 and newer leave out the final of an anonymous class
        access &= ~ACC_FINAL
    return '%s class %s extends %s implements %s' % (access_words(access), c.name, c.super_name,
                                                      ', '.join(sorted(c.interfaces)) or '-')


def member_line(kind, flags, name, desc):
    return '%s %s:%s (%s)' % (kind, name, desc, access_words(flags & MEMBER_MASK[kind]) or 'package')


def compare_jars(old, new):
    """The differences between two jars' classes ({name: JavaClass}): a list
    of (key, text) for what is gone or changed (key as EXPECTED has them),
    and a list of lines for what only the new one has."""
    gone = []
    added = []
    for name in sorted(set(old) | set(new)):
        if name not in new:
            gone.append(('class ' + name, 'class %s is gone' % name))
            continue
        if name not in old:
            added.append('class %s' % name)
            continue
        a, b = old[name], new[name]
        if class_header(a) != class_header(b):
            gone.append(('class ' + name, 'class %s was "%s", is "%s"' % (name, class_header(a), class_header(b))))
        for kind, am, bm in (('field', a.fields, b.fields), ('method', a.methods, b.methods)):
            for key in sorted(set(am) | set(bm)):
                fa = am[key][0] if key in am else None
                fb = bm[key][0] if key in bm else None
                if (fa or 0) & ACC_SYNTHETIC and (fb is None or fb & ACC_SYNTHETIC):
                    continue
                if fb is not None and fb & ACC_SYNTHETIC and fa is None:
                    continue
                mkey = 'member %s.%s:%s' % (name, key[0], key[1])
                if fb is None:
                    gone.append((mkey, '%s.%s:%s is gone' % (name, key[0], key[1])))
                elif fa is None:
                    added.append('%s.%s' % (name, member_line(kind, fb, key[0], key[1])))
                elif (fa & MEMBER_MASK[kind]) != (fb & MEMBER_MASK[kind]):
                    gone.append((mkey, '%s.%s:%s was %s, is %s' % (
                        name, key[0], key[1], access_words(fa & MEMBER_MASK[kind]) or 'package',
                        access_words(fb & MEMBER_MASK[kind]) or 'package')))
                elif kind == 'field' and constant_value(a, am[key]) != constant_value(b, bm[key]):
                    gone.append((mkey, '%s.%s:%s was %s, is %s' % (name, key[0], key[1], constant_value(a, am[key]),
                                                                   constant_value(b, bm[key]))))
                elif kind == 'method' and not fa & ACC_SYNTHETIC:
                    static = bool(fa & ACC_STATIC)
                    la = code_listing(a, am[key][1], am[key][2], key[1], static)
                    lb = code_listing(b, bm[key][1], bm[key][2], key[1], static)
                    if la != lb:
                        gone.append(('code %s.%s:%s' % (name, key[0], key[1]),
                                     'the code of %s.%s:%s differs:\n%s' % (name, key[0], key[1],
                                                                            code_diff(la, lb))))
    return gone, added


def constant_value(cls, field):
    return constant(cls.pool, field[1]) if field[1] else None


def code_diff(a, b, context=2, keep=40):
    """The lines that differ between two code listings, as a short unified
    diff."""
    import difflib
    lines = list(difflib.unified_diff(a, b, 'old', 'new', n=context, lineterm=''))[2:]
    if len(lines) > keep:
        lines = lines[:keep] + ['... (%d more lines)' % (len(lines) - keep)]
    return '\n'.join('    ' + x for x in lines)


def compare(args):
    old_sha = sha256(args.old)
    old = read_jar(args.old)
    new = read_jar(args.new)
    log('old: %s (%d classes, SHA-256 %s)' % (args.old, len(old), old_sha))
    log('new: %s (%d classes)' % (args.new, len(new)))
    versions = sorted({c.major for c in old.values()}), sorted({c.major for c in new.values()})
    log('class file versions: old %s, new %s' % versions)
    gone, added = compare_jars(old, new)
    expected = EXPECTED.get(old_sha)
    problems = []
    log()
    if expected is None:
        log('No differences are expected from this old jar (EXPECTED has no entry for its SHA-256), '
            'so every one is a problem.')
        expected = {}
        for line in added:
            problems.append('only the new jar has %s' % line)
    seen = set()
    for key, text in gone:
        if key in expected:
            seen.add(key)
            log('EXPECTED: %s\n    because %s' % (text, expected[key]))
        else:
            problems.append(text)
    for key in sorted(set(expected) - seen):
        problems.append('EXPECTED names "%s" (%s), but it does not differ' % (key, expected[key]))
    log()
    log('Only in the new jar (%d):' % len(added))
    for line in added:
        log('  ' + line)
    log()
    log('%d difference(s) gone or changed, %d of them expected; %d addition(s)'
        % (len(gone), len(seen), len(added)))
    return problems


# ---------------------------------------------------------------------------
# build

def gyp_list(text, key):
    """The quoted items of a list in a .gypi file, without the ones that a
    # comments out."""
    m = re.search(r"'%s'\s*:\s*\[(.*?)\]" % re.escape(key), text, re.S)
    if not m:
        raise CheckError('%s has no list %s' % (GYPI, key))
    return [x for x in re.findall(r"^\s*'([^']+)'", m.group(1), re.M)]


def java_sources(gypi=GYPI):
    """The Java and AIDL sources that LiveCode's build compiled into
    Classes, relative to engine/."""
    with open(gypi, encoding='utf-8') as f:
        text = f.read()
    return gyp_list(text, 'engine_java_source_files'), gyp_list(text, 'engine_aidl_source_files')


def find_tool(folder, name):
    for x in (name, name + '.exe', name + '.bat'):
        p = os.path.join(folder, x)
        if os.path.isfile(p):
            return p
    return None


def run(cmd):
    log('$ ' + ' '.join(cmd))
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
    if p.stdout.strip():
        log(p.stdout.rstrip())
    if p.returncode != 0:
        raise CheckError('%s exited with status %d' % (os.path.basename(cmd[0]), p.returncode))
    return p.stdout


def write_jar(classes_dir, out):
    """A jar of every class file under classes_dir, whose bytes depend only
    on the class files: names sorted, every entry at JAR_TIME."""
    files = []
    for root, _dirs, names in os.walk(classes_dir):
        for x in names:
            if x.endswith('.class'):
                path = os.path.join(root, x)
                files.append((os.path.relpath(path, classes_dir).replace(os.sep, '/'), path))
    files.sort()
    folder = os.path.dirname(os.path.abspath(out))
    os.makedirs(folder, exist_ok=True)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        info = zipfile.ZipInfo('META-INF/MANIFEST.MF', JAR_TIME)
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, 'Manifest-Version: 1.0\r\nCreated-By: tools/ci/android_java.py\r\n\r\n')
        for name, path in files:
            info = zipfile.ZipInfo(name, JAR_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(path, 'rb') as f:
                z.writestr(info, f.read())
    return len(files)


def build(args):
    platform = os.path.join(args.sdk, 'platforms', 'android-' + args.api)
    android_jar = os.path.join(platform, 'android.jar')
    if not os.path.isfile(android_jar):
        raise CheckError('there is no %s (sdkmanager "platforms;android-%s")' % (android_jar, args.api))
    javac = find_tool(os.path.join(args.jdk, 'bin'), 'javac') if args.jdk else shutil.which('javac')
    if not javac:
        raise CheckError('no javac (give --jdk)')
    sources, aidls = java_sources()
    generated = []
    for x in aidls:
        java = os.path.splitext(os.path.join(ENGINE_DIR, x))[0] + '.java'
        if not os.path.isfile(java):
            raise CheckError('%s has no Java beside it (%s): write it as aidl makes it' % (x, java))
        generated.append(java)
    work = tempfile.mkdtemp(prefix='android-java-')
    try:
        classes = os.path.join(work, 'classes')
        os.makedirs(classes)
        # As config/java.gypi: the AIDL interfaces before the sources that
        # use them, the sources' own folder to look in, and nothing
        # compiled that is not listed
        cmd = [javac, '-source', '8', '-target', '8', '-Xlint:-options', '-nowarn', '-encoding', 'utf8',
               '-implicit:none', '-bootclasspath', android_jar, '-classpath', android_jar,
               '-sourcepath', JAVA_ROOT, '-d', classes]
        cmd += generated + [os.path.join(ENGINE_DIR, x) for x in sources]
        run(cmd)
        count = write_jar(classes, args.out)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    log('%s: %d classes from %d sources and %d AIDL interfaces, against android-%s (SHA-256 %s)'
        % (args.out, count, len(sources), len(aidls), args.api, sha256(args.out)))
    return []


# ---------------------------------------------------------------------------
# jni: the engines' exports

def elf_dynamic(data):
    """What an ELF file says to the dynamic linker: the names it exports
    (its .dynsym entries that are defined) and the libraries it needs
    (DT_NEEDED of its .dynamic section)."""
    if data[:4] != b'\x7fELF':
        raise CheckError('not an ELF file')
    is64 = data[4] == 2
    end = '<' if data[5] == 1 else '>'
    if is64:
        shoff, = struct.unpack(end + 'Q', data[40:48])
        shentsize, shnum = struct.unpack(end + 'HH', data[58:62])
    else:
        shoff, = struct.unpack(end + 'I', data[32:36])
        shentsize, shnum = struct.unpack(end + 'HH', data[46:50])
    sections = []
    for i in range(shnum):
        h = data[shoff + i * shentsize:shoff + (i + 1) * shentsize]
        if is64:
            _n, sh_type, _f, _a, off, size, link, _i, _al, entsize = struct.unpack(end + 'IIQQQQIIQQ', h[:64])
        else:
            _n, sh_type, _f, _a, off, size, link, _i, _al, entsize = struct.unpack(end + 'IIIIIIIIII', h[:40])
        sections.append((sh_type, off, size, link, entsize))

    def string(table, at):
        _t, stroff, strsize, _l, _e = sections[table]
        strtab = data[stroff:stroff + strsize]
        return strtab[at:strtab.index(b'\0', at)].decode('ascii', 'replace')

    exports = set()
    needed = []
    for sh_type, off, size, link, entsize in sections:
        if sh_type == 11 and entsize:   # SHT_DYNSYM
            for k in range(1, size // entsize):
                e = data[off + k * entsize:off + (k + 1) * entsize]
                if is64:
                    st_name, _info, _other, shndx = struct.unpack(end + 'IBBH', e[:8])
                else:
                    st_name, = struct.unpack(end + 'I', e[:4])
                    shndx, = struct.unpack(end + 'H', e[14:16])
                if shndx != 0:
                    exports.add(string(link, st_name))
        elif sh_type == 6:              # SHT_DYNAMIC
            size_one = 16 if is64 else 8
            for k in range(size // size_one):
                e = data[off + k * size_one:off + (k + 1) * size_one]
                tag, value = struct.unpack(end + ('qQ' if is64 else 'iI'), e)
                if tag == 0:
                    break
                if tag == 1:            # DT_NEEDED
                    needed.append(string(link, value))
    return exports, needed


def jni_mangle(text):
    """A class or method name as a JNI function name writes it."""
    out = []
    for ch in text:
        if ch == '/':
            out.append('_')
        elif ch == '_':
            out.append('_1')
        elif ch == ';':
            out.append('_2')
        elif ch == '[':
            out.append('_3')
        elif ch.isascii() and ch.isalnum():
            out.append(ch)
        else:
            out.append('_0%04x' % ord(ch))
    return ''.join(out)


def jni_names(cls, name, desc):
    """The two names a native method's function can have: the short one,
    and the one with the parameter types (for overloaded natives)."""
    short = 'Java_%s_%s' % (jni_mangle(cls), jni_mangle(name))
    return short, short + '__' + jni_mangle(''.join(parameter_types(desc)))


def natives(classes):
    """[(class, name, descriptor)] of the native methods of a jar."""
    out = []
    for c in classes.values():
        for (name, desc), (acc, _code, _h) in c.methods.items():
            if acc & ACC_NATIVE:
                out.append((c.name, name, desc))
    return sorted(out)


def check_exports(classes, engines):
    """Problems and lines for the natives of the jar against each engine's
    exports ({abi: set of names})."""
    problems = []
    lines = []
    declared = natives(classes)
    names = {}
    for cls, name, desc in declared:
        for x in jni_names(cls, name, desc):
            names[x] = (cls, name, desc)
    for abi in sorted(engines):
        exports = {x for x in engines[abi] if x.startswith('Java_')}
        orphans = sorted(x for x in exports if x not in names)
        for x in orphans:
            problems.append('%s: the engine exports %s, which no native method of the jar declares' % (abi, x))
        missing = []
        for cls, name, desc in declared:
            if not any(x in exports for x in jni_names(cls, name, desc)):
                missing.append('%s.%s:%s' % (cls, name, desc))
        for key in missing:
            if key not in UNEXPORTED:
                problems.append('%s: the native method %s has no function in the engine' % (abi, key))
        for key in sorted(UNEXPORTED):
            if key not in missing:
                problems.append('%s: UNEXPORTED names %s, which the engine exports or the jar no longer declares'
                                % (abi, key))
        lines.append('%s: %d Java_* exports, %d native methods, %d of them not in the engine (UNEXPORTED)'
                     % (abi, len(exports), len(declared), len(missing)))
    return problems, lines


# ---------------------------------------------------------------------------
# jni: the engine's calls into Java

# MCAndroid*Call's signature letters (mblandroidjava.cpp,
# native_sigchar_to_returntype and return_type_to_java_sig). '@' is a
# value whose Java type is chosen when it is called
SIGCHARS = {'v': 'V', 's': 'Ljava/lang/String;', 't': 'Ljava/lang/String;', 'S': 'Ljava/lang/String;',
            'U': 'Ljava/lang/String;', 'x': 'Ljava/lang/String;', 'd': '[B', 'i': 'I', 'j': 'J', 'b': 'Z',
            'l': 'Ljava/util/List;', 'm': 'Ljava/util/Map;', 'o': 'Ljava/lang/Object;', 'f': 'F', 'r': 'D',
            '@': None}
ANY_TYPE = r'\[*(?:L[^;]+;|[ZBCSIJFD])'


def signature_pattern(sig):
    """A regular expression for the descriptors that MCAndroid*Call's
    signature letters can ask for (the first letter is the return type)."""
    def one(ch, is_return):
        if ch not in SIGCHARS:
            raise CheckError('unknown signature letter %r in %r' % (ch, sig))
        t = SIGCHARS[ch]
        if t is None:
            return 'Ljava/lang/Object;' if is_return else ANY_TYPE
        return re.escape(t)
    return '^\\(' + ''.join(one(ch, False) for ch in sig[1:]) + '\\)' + one(sig[0], True) + '$'


def strip_comments(text):
    """C++ source without its comments; strings and line breaks kept."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == '"' or ch == "'":
            j = i + 1
            while j < n and text[j] != ch:
                j += 2 if text[j] == '\\' else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith('//', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append('\n' * text.count('\n', i, j))
            i = j
        else:
            out.append(ch)
            i += 1
    return ''.join(out)


STR = r'"((?:[^"\\]|\\.)*)"'
CALL_PATTERNS = (
    ('engine', re.compile(r'\bMCAndroidEngine(?:Remote)?Call\s*\(\s*' + STR + r'\s*,\s*' + STR)),
    ('object', re.compile(r'\bMCAndroidObject(?:Remote)?Call\s*\(\s*[^,()]+(?:\([^()]*\))?\s*,\s*' + STR
                          + r'\s*,\s*' + STR)),
    ('static', re.compile(r'\bMCAndroidStatic(?:Remote)?Call\s*\(\s*' + STR + r'\s*,\s*' + STR + r'\s*,\s*' + STR)),
    ('jni', re.compile(r'\b(Get(?:Static)?MethodID)\s*\(\s*([^,]+?)\s*,\s*' + STR + r'\s*,\s*' + STR)),
)
FIND_CLASS = re.compile(r'(\w+)\s*=\s*[^;]*?FindClass\s*\(\s*(?:MCNAME\s*\(\s*)?"([^"]+)"')
GLOBAL_REF = re.compile(r'(\w+)\s*=\s*(?:\(\s*jclass\s*\)\s*)?\w+\s*->\s*NewGlobalRef\s*\(\s*(\w+)\s*\)')
ENGINE_CLASS = 'com/runrev/android/Engine'


def repo_path(path):
    """path as the checkout names it (tools/ci/x.py), or whole when it is
    not in the checkout (on Windows the temporary folder can be on another
    drive, where relpath has no answer)."""
    try:
        rel = os.path.relpath(path, REPO)
    except ValueError:
        return path.replace(os.sep, '/')
    return rel.replace(os.sep, '/')


class Call(object):
    def __init__(self, where, kind, cls, name, pattern, static, text):
        self.where = where
        self.file = where.rsplit(':', 1)[0]
        self.kind = kind
        self.cls = cls          # None: any class (a call on an object)
        self.name = name
        self.pattern = pattern  # a regular expression for the descriptor
        self.static = static
        self.text = text        # the signature as the source writes it


def source_calls(paths):
    """The engine's calls into Java that name their method and signature in
    the source (Call objects), from C++ files."""
    calls = []
    for path in paths:
        with open(path, encoding='utf-8', errors='replace') as f:
            text = strip_comments(f.read())
        rel = repo_path(path)
        found = {}
        for var, cls in FIND_CLASS.findall(text):
            found.setdefault(var, set()).add(cls.replace('.', '/'))
        # s_x_class = (jclass)env->NewGlobalRef(t_x_class): the same class
        for var, other in GLOBAL_REF.findall(text):
            if other in found:
                found.setdefault(var, set()).update(found[other])
        for kind, pattern in CALL_PATTERNS:
            for m in pattern.finditer(text):
                where = '%s:%d' % (rel, text.count('\n', 0, m.start()) + 1)
                if kind == 'engine':
                    name, sig = m.group(1), m.group(2)
                    calls.append(Call(where, kind, ENGINE_CLASS, name, signature_pattern(sig), False, sig))
                elif kind == 'object':
                    name, sig = m.group(1), m.group(2)
                    calls.append(Call(where, kind, None, name, signature_pattern(sig), False, sig))
                elif kind == 'static':
                    cls, name, sig = m.group(1), m.group(2), m.group(3)
                    calls.append(Call(where, kind, cls.replace('.', '/'), name, signature_pattern(sig), True, sig))
                else:
                    func, target, name, desc = m.groups()
                    lit = re.search(r'FindClass\s*\(\s*(?:MCNAME\s*\(\s*)?"([^"]+)"', target)
                    var = re.match(r'^(?:\(\s*\w+\s*\))?\s*(\w+)$', target)
                    cls = None
                    if lit:
                        cls = lit.group(1).replace('.', '/')
                    elif var and len(found.get(var.group(1), ())) == 1:
                        cls = next(iter(found[var.group(1)]))
                    calls.append(Call(where, 'jni', cls, name, '^' + re.escape(desc) + '$',
                                      func == 'GetStaticMethodID', desc))
    return calls


class Classes(object):
    """The jar's classes, and Android's (the SDK's android.jar), read when a
    lookup reaches them."""

    def __init__(self, jar, android_jar=None):
        self.jar = jar
        self.android = zipfile.ZipFile(android_jar) if android_jar else None
        self.cache = {}

    def get(self, name):
        if name in self.jar:
            return self.jar[name]
        if name in self.cache:
            return self.cache[name]
        c = None
        if self.android is not None:
            try:
                c = parse_class(self.android.read(name + '.class'))
            except KeyError:
                c = None
        self.cache[name] = c
        return c

    def find_method(self, cls, name, pattern, static=None):
        """The descriptor of a method named name whose descriptor matches
        pattern, in cls or the classes and interfaces above it, as JNI's
        GetMethodID looks; None when there is none, and 'unknown' when a
        class on the way cannot be read (no android.jar given)."""
        seen = set()
        todo = [cls]
        unknown = False
        while todo:
            c_name = todo.pop(0)
            if c_name is None or c_name in seen:
                continue
            seen.add(c_name)
            c = self.get(c_name)
            if c is None:
                unknown = True
                continue
            for (m_name, desc), (acc, _code, _h) in c.methods.items():
                if m_name == name and re.match(pattern, desc):
                    if static is None or bool(acc & ACC_STATIC) == static:
                        return desc
            todo.append(c.super_name)
            todo.extend(c.interfaces)
        return 'unknown' if unknown else None


def check_calls(calls, classes, engine_strings, known=None):
    """Problems and lines for the engine's calls into Java against the
    jar. A call whose method name the runtime's engine does not hold
    (engine_strings, its bytes) is one this source makes and that engine
    does not; one that finds no method is listed and is not a problem."""
    known = KNOWN_CALLS if known is None else known
    problems = []
    lines = []
    counts = {'checked': 0, 'unknown': 0, 'not in engine': 0}
    seen = set()
    for call in calls:
        in_engine = engine_strings is None or call.name.encode('ascii') in engine_strings
        if call.cls is not None:
            found = classes.find_method(call.cls, call.name, call.pattern, call.static)
            where = call.cls
        else:
            found = None
            for c in sorted(classes.jar):
                found = classes.find_method(c, call.name, call.pattern, call.static)
                if found and found != 'unknown':
                    break
            where = 'any class of the jar or above one'
        if found == 'unknown':
            counts['unknown'] += 1
            lines.append('cannot say (no android.jar): %s %s %s in %s' % (call.where, call.name, call.text, where))
            continue
        counts['checked'] += 1
        key = (call.file, call.name, call.text)
        if found is not None:
            if key in known:
                problems.append('KNOWN_CALLS names %s %s %s, which finds its method now' % key)
                seen.add(key)
            continue
        text = '%s calls %s with the signature %s (%s), and %s has no such method' % (
            call.where, call.name, call.text, call.pattern, where)
        if key in known:
            seen.add(key)
            lines.append('KNOWN: %s\n    (%s)' % (text, known[key]))
        elif not in_engine:
            counts['not in engine'] += 1
            lines.append('not in the runtime\'s engine: %s' % text)
        else:
            problems.append(text)
    for key in sorted(set(known) - seen):
        problems.append('KNOWN_CALLS names %s %s %s, which the source no longer makes' % key)
    lines.append('%d calls into Java checked, %d not (no android.jar); %d find no method and the runtime\'s '
                 'engine does not make them, %d are KNOWN_CALLS'
                 % (counts['checked'], counts['unknown'], counts['not in engine'], len(seen)))
    return problems, lines


LCB_BINDING = re.compile(r'binds\s+to\s+"java:(com\.runrev\.[^">]+)>([^"(]+)\(([^")]*)\)([^"!]*)(?:!(\w+))?"')


def lcb_bindings(root):
    """[(where, class, method, parameters, return, call type)] of the
    bindings of LCB sources to classes of the Java layer."""
    out = []
    for dirpath, dirs, names in os.walk(root):
        dirs.sort()
        for x in sorted(names):
            if not x.endswith('.lcb'):
                continue
            path = os.path.join(dirpath, x)
            with open(path, encoding='utf-8', errors='replace') as f:
                text = f.read()
            rel = repo_path(path)
            for m in LCB_BINDING.finditer(text):
                where = '%s:%d' % (rel, text.count('\n', 0, m.start()) + 1)
                out.append((where, m.group(1).replace('.', '/'), m.group(2), m.group(3), m.group(4),
                            m.group(5) or 'instance'))
    return out


def check_bindings(bindings, classes):
    problems = []
    lines = []
    for where, cls, method, params, ret, call in bindings:
        c = classes.get(cls)
        if c is None:
            problems.append('%s binds to %s, which the jar does not have' % (where, cls))
            continue
        if method == 'interface':
            if not c.access & ACC_INTERFACE:
                problems.append('%s binds to %s as an interface, which it is not' % (where, cls))
            continue
        if call not in ('instance', 'static', 'nonvirtual'):
            problems.append('%s: a binding of the call type %s, which this check does not read' % (where, call))
            continue
        name, desc = ('<init>', '(%s)V' % params) if method == 'new' else (method, '(%s)%s' % (params, ret))
        found = classes.find_method(cls, name, '^' + re.escape(desc) + '$', call == 'static')
        if found == 'unknown':
            lines.append('cannot say (no android.jar): %s %s.%s:%s' % (where, cls, name, desc))
        elif found is None:
            problems.append('%s binds to %s.%s:%s (%s), which the jar does not have' % (where, cls, name, desc, call))
    return problems, lines + ['%d LCB bindings to the Java layer checked' % len(bindings)]


def code_of(path):
    """The text of a file, less the builder's lines that a comment starts
    (the builder keeps old code so); '' when there is no such file."""
    if not os.path.isfile(path):
        return ''
    with open(path, encoding='utf-8', errors='replace') as f:
        text = f.read()
    if path.endswith('.livecodescript'):
        text = '\n'.join(x for x in text.split('\n') if not re.match(r'\s*(--|#|//)', x))
    return text


def named_classes(runtime):
    """[(where, class)] of the classes of the Java layer that Android loads
    by name: those the manifest and the builder name."""
    out = []
    for path in (os.path.join(runtime, 'Manifest.xml'), BUILDER):
        for m in re.finditer(r'com\.runrev\.android(?:\.[A-Za-z_]\w*)+', code_of(path)):
            out.append((os.path.basename(path), m.group(0).replace('.', '/')))
    return sorted(set(out))


def looked_for_classes():
    """The classes whose entries the builder looks for in the runtime's jar
    (androidJavaLayerHas, by the entry's name, com/runrev/android/X.class):
    those it names only where the jar has them, as it declares
    RelaunchActivity only with a layer that has it (LiveCode Community
    9.6.3's has not). That the declaration follows the jar is the device
    check's (verify: the manifest declares RelaunchActivity exactly when
    the package's dex has it); this is only which names may be missing."""
    return {m.group(1) for m in re.finditer(r'(com/runrev/android/[\w/$]+)\.class', code_of(BUILDER))}


def check_named(named, classes, looked_for=()):
    """Problems for the named classes the jar does not have, bar those of
    looked_for that only the builder names: it names them only where the
    jar has them, so a jar without one is said, and is no problem."""
    problems, lines = [], []
    builder = os.path.basename(BUILDER)
    for where, cls in named:
        if classes.get(cls) is not None:
            continue
        if where == builder and cls in looked_for:
            lines.append('%s names %s only where the jar has it, and this jar has not' % (where, cls))
        else:
            problems.append('%s names %s, which the jar does not have' % (where, cls))
    return problems, lines + ['%d classes named by the manifest and the builder checked' % len(named)]


# The OpenGL ES library an engine loads, and the version of the context
# OpenGLView must make for it. One Java layer serves two engines: LiveCode
# 9.6.3's, which the runtime carries, loads libGLESv1_CM and calls start();
# one built from this tree loads a later OpenGL ES library and calls what
# its source says, startGLES(kMCAndroidOpenGLESVersion)
GLES_LIBRARIES = {'libGLESv1_CM.so': 1, 'libGLESv2.so': 2, 'libGLESv3.so': 3}
GLES_CLASS = 'com/runrev/android/OpenGLView'
GLES_SOURCE = 'engine/src/mblandroiddc.cpp'
GLES_WITH_VERSION = 'startGLES'
EGL_CONTEXT_CLIENT_VERSION = 0x3098


def context_version(listing, argument=None):
    """The OpenGL ES version of the context a start method's code makes: the
    value it puts after EGL_CONTEXT_CLIENT_VERSION in the attributes it
    gives eglCreateContext (`argument` where that is its int parameter), or
    1 when it gives none (EGL's default); 0 when this check cannot read
    it."""
    for i, insn in enumerate(listing):
        # dup, const 0, const EGL_CONTEXT_CLIENT_VERSION, iastore, dup,
        # const 1, <the version>, iastore
        if insn == 'const %d' % EGL_CONTEXT_CLIENT_VERSION and i + 4 < len(listing):
            if listing[i + 3] != 'const 1':
                return 0
            m = re.match(r'const (\d+)$', listing[i + 4])
            if m:
                return int(m.group(1))
            if listing[i + 4] == 'iload p1' and argument is not None:
                return argument
            return 0
    return 1


def gles_contexts(classes, argument=None):
    """The OpenGL ES versions of the contexts OpenGLView makes: (start()'s,
    startGLES(argument)'s), each None where the view has no such method (or
    no argument is given) and 0 where this check cannot read it. start()
    may call startGLES with a constant, as this tree's does."""
    c = classes.get(GLES_CLASS)
    if c is None:
        return None, None

    def listing(name, desc):
        m = c.methods.get((name, desc))
        return None if m is None else code_listing(c, m[1], m[2], desc, False)
    plain, with_version = listing('start', '()V'), listing(GLES_WITH_VERSION, '(I)V')

    def started(value):
        return context_version(with_version, value) if with_version is not None else 0
    of_plain = None
    if plain is not None:
        call = 'invokevirtual %s.%s:(I)V' % (GLES_CLASS, GLES_WITH_VERSION)
        if call in plain:
            i = plain.index(call)
            m = re.match(r'const (\d+)$', plain[i - 1]) if i else None
            of_plain = started(int(m.group(1))) if m else 0
        else:
            of_plain = context_version(plain)
    of_version = started(argument) if argument is not None and with_version is not None else None
    return of_plain, of_version


def gles_version(classes):
    """The OpenGL ES version of the contexts OpenGLView.start() makes (see
    gles_contexts)."""
    return gles_contexts(classes)[0]


def source_gles_version(text=None):
    """The OpenGL ES version the engine's source asks OpenGLView for: None
    when it calls start(), kMCAndroidOpenGLESVersion when it calls
    startGLES with it, 0 when this check cannot tell."""
    if text is None:
        with open(os.path.join(REPO, GLES_SOURCE), encoding='utf-8', errors='replace') as f:
            text = f.read()
    if re.search(r'GetMethodID\(\s*\w+\s*,\s*"start"\s*,\s*"\(\)V"\s*\)', text):
        return None
    if not re.search(r'GetMethodID\(\s*\w+\s*,\s*"%s"\s*,\s*"\(I\)V"\s*\)' % GLES_WITH_VERSION, text):
        return 0
    m = re.search(r'static const jint kMCAndroidOpenGLESVersion = (\d+);', text)
    if not m or not re.search(r'CallVoidMethod\(\s*s_android_opengl_view\s*,\s*s_openglview_start_method\s*,'
                              r'\s*kMCAndroidOpenGLESVersion\s*\)', text):
        return 0
    return int(m.group(1))


def check_gles(classes, needed, source=None):
    """Problems and lines for the OpenGL ES version of the contexts
    OpenGLView makes against the library each engine loads ({abi: [the
    libraries it needs]}). An engine that loads libGLESv1_CM (or none) is
    LiveCode 9.6.3's, which calls start(); one that loads a later library
    is built from this tree, whose source asks for `source`
    (source_gles_version: None when it calls start())."""
    of_plain = gles_contexts(classes)[0]
    if of_plain is None:
        return ['the jar has no %s.start' % GLES_CLASS], []
    problems = []
    lines = []
    if of_plain:
        lines.append('OpenGLView.start() makes OpenGL ES %d contexts' % of_plain)
    else:
        problems.append('%s.start asks for an OpenGL ES version this check cannot read' % GLES_CLASS)
    for abi in sorted(needed):
        libs = [x for x in needed[abi] if x in GLES_LIBRARIES]
        engine = max(GLES_LIBRARIES[x] for x in libs) if libs else None
        drawn = '%s (%s)' % (engine, ', '.join(libs) or 'no OpenGL ES library')
        lines.append('%s: the engine loads %s' % (abi, ', '.join(libs) or 'no OpenGL ES library'))
        if engine is not None and engine > 1 and source is not None:
            # built from this tree: it calls what its source says
            if not source:
                problems.append('%s: %s asks OpenGLView for an OpenGL ES version this check cannot read'
                                % (abi, GLES_SOURCE))
                continue
            call = '%s(%d)' % (GLES_WITH_VERSION, source)
            made = gles_contexts(classes, source)[1]
            if made is None:
                problems.append('%s: the engine calls OpenGLView.%s (%s), which the jar does not have'
                                % (abi, call, GLES_SOURCE))
                continue
            if not made:
                problems.append('%s: OpenGLView.%s asks for an OpenGL ES version this check cannot read'
                                % (abi, call))
                continue
        else:
            call, made = 'start()', of_plain
            if not made:
                continue
        if engine != made:
            problems.append('%s: the engine draws with OpenGL ES %s, and OpenGLView.%s makes OpenGL ES %d '
                            'contexts' % (abi, drawn, call, made))
        else:
            lines.append('%s: it calls OpenGLView.%s, which makes OpenGL ES %d contexts' % (abi, call, made))
    return problems, lines


def report(sections):
    problems = []
    for title, p, lines in sections:
        log()
        log('== %s' % title)
        for line in lines:
            log(line)
        for x in p:
            log('PROBLEM: ' + x)
        problems.extend(p)
    return problems


def jni(args):
    jar = read_jar(args.classes)
    log('jar: %s (%d classes, %d native methods)' % (args.classes, len(jar), len(natives(jar))))
    classes = Classes(jar, args.android_jar)
    engines = {}
    needed = {}
    strings = None
    for abi in ABIS:
        path = os.path.join(args.runtime, abi, ENGINE_NAME)
        if not os.path.isfile(path):
            continue
        with open(path, 'rb') as f:
            data = f.read()
        engines[abi], needed[abi] = elf_dynamic(data)
        if abi == 'arm64-v8a' or strings is None:
            strings = data
    if not engines:
        raise CheckError('%s has no engine (%s) for any of %s' % (args.runtime, ENGINE_NAME, ', '.join(ABIS)))
    sections = []
    p, lines = check_exports(jar, engines)
    sections.append(('Java_* functions of the engines', p, lines))
    paths = []
    for pattern in NATIVE_SOURCES:
        paths.extend(sorted(glob.glob(os.path.join(REPO, pattern))))
    p, lines = check_calls(source_calls(paths), classes, strings)
    sections.append(('the engine\'s calls into Java', p, lines))
    p, lines = check_bindings(lcb_bindings(os.path.join(REPO, LCB_SOURCES)), classes)
    sections.append(('LCB bindings', p, lines))
    # This checkout's jar must have every class the builder can name
    # (--every-named); a release's may lack those the builder looks for
    p, lines = check_named(named_classes(args.runtime), classes,
                           () if args.every_named else looked_for_classes())
    sections.append(('classes named by the manifest and the builder', p, lines))
    p, lines = check_gles(classes, needed, source_gles_version())
    sections.append(('OpenGL ES', p, lines))
    return report(sections)


# ---------------------------------------------------------------------------
# rules: what Android asks of the code, read in its instructions

PENDING_INTENT_GETS = ('getActivity', 'getActivities', 'getBroadcast', 'getService', 'getForegroundService')
PENDING_INTENT_FLAGS = ('com/runrev/android/Utils.immutablePendingIntentFlags:(I)I',
                        'com/runrev/android/Utils.mutablePendingIntentFlags:(I)I')


def check_pending_intents(classes):
    """Every PendingIntent.get* call of the jar takes its flags (its last
    argument, so the instruction just before the call) from Utils's
    immutablePendingIntentFlags or mutablePendingIntentFlags: Android 12 and
    newer refuse a PendingIntent that says neither FLAG_IMMUTABLE nor
    FLAG_MUTABLE, for an app that targets API 31 or newer."""
    problems = []
    count = 0
    for name in sorted(classes):
        c = classes[name]
        for (m_name, desc), (acc, code, handlers) in sorted(c.methods.items()):
            listing = code_listing(c, code, handlers, desc, bool(acc & ACC_STATIC))
            for i, insn in enumerate(listing):
                parts = insn.split(' ', 1)
                if parts[0] != 'invokestatic' or not parts[1].startswith('android/app/PendingIntent.'):
                    continue
                method = parts[1].split('.', 1)[1].split(':')[0]
                if method not in PENDING_INTENT_GETS:
                    continue
                count += 1
                before = listing[i - 1] if i else ''
                if before.split(' ', 1)[-1] not in PENDING_INTENT_FLAGS or not before.startswith('invokestatic'):
                    problems.append('%s.%s:%s makes a PendingIntent (%s) with flags that are not '
                                    'Utils.immutablePendingIntentFlags or mutablePendingIntentFlags (the '
                                    'instruction before: %s)' % (name, m_name, desc, method, before or 'none'))
    return problems, ['%d PendingIntent.get* calls checked' % count]


def rules(args):
    jar = read_jar(args.classes)
    log('jar: %s (%d classes)' % (args.classes, len(jar)))
    p, lines = check_pending_intents(jar)
    return report([('PendingIntent mutability', p, lines)])


# ---------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='command', required=True)
    b = sub.add_parser('build')
    b.add_argument('--sdk', required=True)
    b.add_argument('--out', required=True)
    b.add_argument('--api', default=DEFAULT_API)
    b.add_argument('--jdk')
    c = sub.add_parser('compare')
    c.add_argument('--old', required=True)
    c.add_argument('--new', required=True)
    j = sub.add_parser('jni')
    j.add_argument('--classes', required=True)
    j.add_argument('--runtime', required=True, help='a Runtime/Android folder')
    j.add_argument('--android-jar', help="the SDK's android.jar, for methods of Android's own classes")
    j.add_argument('--every-named', action='store_true',
                   help='the jar must have every class the builder names, those it names only '
                        'where the jar has them too (for a jar built from this checkout)')
    r = sub.add_parser('rules')
    r.add_argument('--classes', required=True)
    args = ap.parse_args(argv)
    try:
        problems = {'build': build, 'compare': compare, 'jni': jni, 'rules': rules}[args.command](args)
    except CheckError as e:
        problems = [str(e)]
    log()
    if problems:
        for x in problems:
            log('PROBLEM: %s' % x)
            annotate('error', 'Android Java %s: %s' % (args.command, x.split('\n')[0]))
        summary('**Android Java %s**: %d problem(s)\n\n%s' % (
            args.command, len(problems), '\n'.join('- ' + x.split('\n')[0] for x in problems)))
        log('Android Java %s: failed' % args.command)
        return 1
    summary('**Android Java %s**: passed' % args.command)
    log('Android Java %s: passed' % args.command)
    return 0


if __name__ == '__main__':
    sys.exit(main())
