/*                                                                     -*-c++-*-

Copyright (C) 2015 LiveCode Ltd.

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

/* Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
   (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
   Seth Morrow (2026) and Emily-Elizabeth Howard (2026); its Git history and
   CHANGELOG.md say what changed. */

#include "prefix.h"

#include "em-system.h"
#include "em-javascript.h"
#include "em-filehandle.h"
#include "em-util.h"
#include "em-dc.h"
#include "em-async.h"

#include "filedefs.h"
#include "objdefs.h"
#include "text.h"
#include "mcutility.h"
#include "mcstring.h"
#include "osspec.h"
#include "globals.h"
#include "variable.h"

#include "globals.h"
#include "variable.h"

#include <foundation-system.h>
#include <foundation-unicode.h>

#include <errno.h>
#include <fcntl.h>
#include <dirent.h>
#include <iconv.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <emscripten.h>

/* ----------------------------------------------------------------
 * Functions implemented in em-system.js
 * ---------------------------------------------------------------- */

extern "C" bool MCEmscriptenSystemInitializeJS(void);
extern "C" void MCEmscriptenSystemFinalizeJS(void);
extern "C" int32_t MCEmscriptenSystemLaunchUrl(const unichar_t *p_url, size_t p_url_length);
extern "C" void MCEmscriptenSystemGetHostName(unichar_t **r_chars, uint32_t *r_length);

/* ================================================================
 * System abstraction layer
 * ================================================================ */

/* Directories understood by MCEmscriptenSystem::GetStandardFolder() */
#define kMCEmscriptenStandardFolderEngine "/boot"
#define kMCEmscriptenStandardFolderResources "/boot/standalone"
#define kMCEmscriptenStandardFolderFonts "/boot/fonts"
#define kMCEmscriptenStandardFolderTemporary "/tmp"
/* OXT-Beyond: the home folder was /livecode until 0.2.7-rc.6.2, and
 * /livecode is still a link to it (em-system.js, LiveCodeStorage) */
#define kMCEmscriptenStandardFolderHome "/openxtalk"
#define kMCEmscriptenStandardFolderDocuments "/openxtalk/Documents"
#define kMCEmscriptenStandardFolderDesktop "/openxtalk/Desktop"
#define kMCEmscriptenStandardFolderPreferences "/openxtalk/Preferences"
#define kMCEmscriptenStandardFolderSupport "/openxtalk/Support"

/* ----------------------------------------------------------------
 * Utility functions
 * ---------------------------------------------------------------- */

/* Return a new Emscripten system interface instance */
MCSystemInterface *
MCDesktopCreateEmscriptenSystem(void)
{
	return new MCEmscriptenSystem;
}

/* Helper for resolving a path and converting to a system string in
 * one go, since this is needed very often. */
class MCEmscriptenAutoStringRefAsSysPath
	: public MCAutoStringRefAsSysString
{
public:
	bool LockPath(MCStringRef p_path)
	{
		MCAutoStringRef t_resolved;
		if (!MCS_resolvepath(p_path, &t_resolved)) {
			return false;
		}

		return Lock(*t_resolved);
	}
};

/* Helper for stat()-ing a file */
static inline bool
MCEmscriptenStatPath(MCStringRef p_path, struct stat & x_stat_buf)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_path))
	{
		return false;
	}

	return (0 == stat(*t_path_sys, &x_stat_buf));
}

/* ----------------------------------------------------------------
 * Start up and tear down
 * ---------------------------------------------------------------- */

MCEmscriptenSystem::MCEmscriptenSystem()
{
}

MCEmscriptenSystem::~MCEmscriptenSystem()
{
}

bool
MCEmscriptenSystem::Initialize()
{
	IO_stdout = OpenFd(1, kMCOpenFileModeWrite);
	IO_stderr = OpenFd(2, kMCOpenFileModeWrite);

	/* The folders that scripts keep files in: the user's (as on Linux,
	 * with the preferences and support folders of the Mac and Windows),
	 * the folder of the files the user gives the page, and the folder
	 * whose files the page gives the user (em-dc.h). They exist for as
	 * long as the page is open. */
	static const char * const kFolders[] =
	{
		kMCEmscriptenStandardFolderHome,
		kMCEmscriptenStandardFolderDocuments,
		kMCEmscriptenStandardFolderDesktop,
		kMCEmscriptenStandardFolderPreferences,
		kMCEmscriptenStandardFolderSupport,
		kMCEmscriptenUploadsFolder,
		kMCEmscriptenDownloadsFolder,
	};
	for (size_t i = 0; i < sizeof(kFolders) / sizeof(kFolders[0]); ++i)
	{
		/* EEXIST when the standalone brought it */
		mkdir(kFolders[i], 0777);
	}

	MCEmscriptenSystemInitializeJS();
	return true;
}

void
MCEmscriptenSystem::Finalize()
{
	MCEmscriptenSystemFinalizeJS();
}

/* ----------------------------------------------------------------
 * System error handling
 * ---------------------------------------------------------------- */

uint32_t
MCEmscriptenSystem::GetSystemError()
{
	return GetErrno();
}

int
MCEmscriptenSystem::GetErrno()
{
	return errno;
}

void
MCEmscriptenSystem::SetErrno(int p_errno)
{
	errno = p_errno;
}

/* ----------------------------------------------------------------
 * Debugging
 * ---------------------------------------------------------------- */

void
MCEmscriptenSystem::Debug(MCStringRef p_string)
{
	MCAutoStringRefAsUTF8String t_utf8_string;

	if (!t_utf8_string.Lock(p_string))
	{
		return;
	}

	emscripten_log(0, "%s", *t_utf8_string);
}

/* ----------------------------------------------------------------
 * Date & time
 * ---------------------------------------------------------------- */

real64_t
MCEmscriptenSystem::GetCurrentTime()
{
	struct timeval t_time;

	gettimeofday(&t_time, NULL);

	return t_time.tv_sec + (t_time.tv_usec / 1000000.0);
}

/* ----------------------------------------------------------------
 * System information
 * ---------------------------------------------------------------- */

bool
MCEmscriptenSystem::GetVersion(MCStringRef & r_string)
{
	return MCStringCopy(kMCEmptyString, r_string);
}

bool
MCEmscriptenSystem::GetMachine(MCStringRef & r_string)
{
	return MCStringCopy(kMCEmptyString, r_string);
}

bool
MCEmscriptenSystem::GetAddress(MCStringRef & r_address)
{
	/* As on Linux: the machine's name (the page's host), a colon and
	 * the engine's path */
	unichar_t *t_chars = nil;
	uint32_t t_length = 0;
	MCEmscriptenSystemGetHostName(&t_chars, &t_length);

	MCAutoStringRef t_host;
	if (!MCStringCreateWithCharsAndRelease(t_chars, t_length, &t_host))
	{
		return false;
	}

	return MCStringFormat(r_address, "%@:%@", *t_host, MCcmd);
}

MCServiceInterface *
MCEmscriptenSystem::QueryService(MCServiceType type)
{
	/* No Emscripten-specific services */
	return NULL;
}

/* ----------------------------------------------------------------
 * Engine process information
 * ---------------------------------------------------------------- */

uint32_t
MCEmscriptenSystem::GetProcessId()
{
	/* Emscripten usually returns 42.  The PID is a fairly meaningless
	 * value. */
	return getpid();
}

/* ----------------------------------------------------------------
 * Scheduling
 * ---------------------------------------------------------------- */

void
MCEmscriptenSystem::Alarm(real64_t p_when)
{
	/* According to Mark Waddingham, this is supposed to be a no-op.
	 * It's used for <Ctrl+.> processing, which isn't relevant on
	 * Emscripten. */
}

void
MCEmscriptenSystem::Sleep(real64_t p_when)
{
	MCEmscriptenNotImplemented();
}

/* ----------------------------------------------------------------
 * Environment variables
 * ---------------------------------------------------------------- */

/* Environment variables are meaningless when running on emscripten */

void
MCEmscriptenSystem::SetEnv(MCStringRef p_name,
                           MCStringRef p_value)
{
	/* No environment variables */
}

bool
MCEmscriptenSystem::GetEnv(MCStringRef p_name,
                           MCStringRef & r_value)
{
	/* No environment variables */
	r_value = MCValueRetain(kMCEmptyString);
	return true;
}

/* ----------------------------------------------------------------
 * Filesystem interface
 * ---------------------------------------------------------------- */

/* Tells the page when a file or folder changes, so that the home folder
 * is kept (em-system.js); a file written tells it when it is closed
 * (em-filehandle.cpp). Returns p_changed. */
static bool
MCEmscriptenSystemChanged(bool p_changed)
{
	if (p_changed)
	{
		MCEmscriptenStorageChanged();
	}
	return p_changed;
}

Boolean
MCEmscriptenSystem::CreateFolder(MCStringRef p_path)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_path))
	{
		return false;
	}

	errno = 0;
	return MCEmscriptenSystemChanged(0 == mkdir(*t_path_sys, 0777));
}

Boolean
MCEmscriptenSystem::DeleteFolder(MCStringRef p_path)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_path))
	{
		return false;
	}

	errno = 0;
	return MCEmscriptenSystemChanged(0 == rmdir(*t_path_sys));
}

Boolean
MCEmscriptenSystem::DeleteFile(MCStringRef p_path)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_path))
	{
		return false;
	}

	errno = 0;
	return MCEmscriptenSystemChanged(0 == unlink(*t_path_sys));
}

Boolean
MCEmscriptenSystem::RenameFileOrFolder(MCStringRef p_old_name,
                                       MCStringRef p_new_name)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_old, t_path_new;
	if (!t_path_old.LockPath(p_old_name))
	{
		return false;
	}
	if (!t_path_new.LockPath(p_new_name))
	{
		return false;
	}

	errno = 0;
	return MCEmscriptenSystemChanged(0 == rename(*t_path_old, *t_path_new));
}

/* As on Linux: save stack moves the stack file it replaces aside
 * ("<name>~") while it writes the new one, and back if that fails */
Boolean
MCEmscriptenSystem::BackupFile(MCStringRef p_old_name,
                               MCStringRef p_new_name)
{
	return RenameFileOrFolder(p_old_name, p_new_name);
}

Boolean
MCEmscriptenSystem::UnbackupFile(MCStringRef p_old_name,
                                 MCStringRef p_new_name)
{
	return RenameFileOrFolder(p_old_name, p_new_name);
}

Boolean
MCEmscriptenSystem::CreateAlias(MCStringRef p_target,
                                MCStringRef p_alias)
{
	/* FIXME Implement CreateAlias() using symlink(2) */
	/* The filesystem containing p_alias does not support the creation
	 * of aliases */
	SetErrno(ENOSYS);
	return false;
}

Boolean
MCEmscriptenSystem::ResolveAlias(MCStringRef p_target,
                                 MCStringRef & r_dest)
{
	/* FIXME Implement ResolveAlias() using readlink(2) */
	/* N.b. returns a standard path (i.e. not a native path) */
	return MCS_resolvepath(p_target, r_dest);
}

bool
MCEmscriptenSystem::GetCurrentFolder(MCStringRef & r_path)
{
	return MCSFileGetCurrentDirectory(r_path);

	/* FIXME use get_current_dir_name() once it's available in Emscripten's
	 * libc. */

	/* We have to call getcwd() in a loop, expanding the output buffer
	 * if necessary.  Starting off with a PATH_MAX-sized buffer means
	 * that expanding is unlikely. */
	MCAutoArray<char> t_cwd_sys;

	/* Allocate initial buffer */
	if (!t_cwd_sys.New(PATH_MAX))
	{
		return false;
	}

	bool t_got_cwd = false;
	while (!t_got_cwd)
	{
		errno = 0;
		if (t_cwd_sys.Ptr() == getcwd(t_cwd_sys.Ptr(), t_cwd_sys.Size()))
		{
			t_got_cwd = true;
		}
		else if (errno == ERANGE)
		{
			/* The buffer wasn't large enough! */

			uindex_t t_new_size;
			/* Check that the buffer can actually be expanded */
			if (t_cwd_sys.Size() == UINDEX_MAX)
			{
				/* Buffer is already maximum size */
				return false;
			}
			else if (UINDEX_MAX / 2 < t_cwd_sys.Size())
			{
				t_new_size = UINDEX_MAX;
			}
			else
			{
				t_new_size = t_cwd_sys.Size() * 2;
			}

			/* Resize the buffer */
			if (!t_cwd_sys.Resize(t_new_size))
			{
				return false;
			}

			errno = 0;
		}
		else
		{
			return false;
		}
	}

	/* Convert to engine string */
	return MCStringCreateWithSysString(t_cwd_sys.Ptr(), r_path);
}

Boolean
MCEmscriptenSystem::SetCurrentFolder(MCStringRef p_path)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_path))
	{
		return false;
	}

	errno = 0;
	return (0 == chdir(*t_path_sys));
}

bool
MCEmscriptenSystem::ListFolderEntries(MCStringRef p_folder,
                                      MCSystemListFolderEntriesCallback p_callback,
                                      void *x_context)
{
	/* Cope with legacy usage of ListFolderEntries() without a
	 * specific target directory path. */
	if (NULL == p_folder)
	{
		return ListFolderEntries(MCSTR("."), p_callback, x_context);
	}

	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_folder))
	{
		return false;
	}

	bool t_success = true;

	/* Get a list of all the directory entries.  Using scandir() means
	 * we get reentrancy without having to fuss around figuring out
	 * how much memory to allocate. */
	/* FIXME use scandirat() once it's available in emscripten's libc */
	struct dirent **t_entries = NULL;
	int t_num_entries = -1;
	if (t_success)
	{
		errno = 0;
		t_num_entries = scandir(*t_path_sys, &t_entries, NULL, alphasort);
		t_success = (t_num_entries >= 0);
	}

	/* Create a buffer in which to build the full path to each entry in the
	 * directory.  It'll be expanded as we go. */
	size_t t_folder_len = strlen(*t_path_sys);

	/* May need an extra separator to ensure that the folder's path ends with
	 * a separator. */
	bool t_need_sep = ((*t_path_sys)[t_folder_len - 1] != '/');
	size_t t_base_len = t_folder_len + (t_need_sep ? 1 : 0);

	MCAutoArray<char> t_entry_path_sys;
	if (t_success)
	{
		/* Overflow check (allowing space for trailing null) */
		t_success = (t_base_len < UINDEX_MAX - 1);
	}
	if (t_success)
	{
		/* Allocate buffer */
		t_success = t_entry_path_sys.New(t_base_len + 1);
	}
	if (t_success)
	{
		/* Copy in base path */
		MCMemoryCopy(t_entry_path_sys.Ptr(), *t_path_sys, t_folder_len);
		/* Ensure trailing separator */
		t_entry_path_sys[t_folder_len] = '/';
		/* Ensure nul termination */
		t_entry_path_sys[t_base_len] = '\0';
	}


	/* Check the properties of each entry in the directory */
	for (int i = 0; i < t_num_entries && t_success; ++i)
	{
		const char *t_entry_name = t_entries[i]->d_name;

		/* Skip directory entries with null names */
		if (NULL == t_entry_name)
		{
			continue;
		}

		/* Skip the current directory itself */
		if (MCCStringEqual(t_entry_name, "."))
		{
			continue;
		}

		/* Build the full path to each entry.  We may need to expand the buffer. */
		size_t t_entry_name_len = strlen(t_entry_name);
		if (t_entry_name_len > t_entry_path_sys.Size() - t_base_len - 1)
		{
			/* Overflow check */
			if (t_entry_name_len > UINDEX_MAX - t_base_len - 1)
			{
				t_success = false;
				continue;
			}

			/* Expand buffer */
			if (!t_entry_path_sys.Extend(t_base_len + t_entry_name_len + 1))
			{
				t_success = false;
				continue;
			}
		}
		/* Copy in entry name after base path */
		MCMemoryCopy(t_entry_path_sys.Ptr() + t_base_len,
		             t_entry_name, t_entry_name_len);
		/* Ensure nul termination */
		t_entry_path_sys[t_base_len + t_entry_name_len] = '\0';

		struct stat t_stat_buf;

		/* This is sort of racy because the directory being scanned
		 * could move between scandir() and fstat(). */
		errno = 0;
		if (0 != stat(t_entry_path_sys.Ptr(), &t_stat_buf))
		{
			/* If the directory entry has gone away (e.g. because it's
			 * been deleted) just skip it. */
			t_success = (errno == ENOENT);
			continue;
		}

		MCSystemFolderEntry t_engine_entry;
		if (!MCStringCreateWithSysString(t_entry_name, t_engine_entry.name))
		{
			t_success = false;
			continue;
		}

		t_engine_entry.data_size = t_stat_buf.st_size;
		t_engine_entry.modification_time = uint64_t(t_stat_buf.st_mtime);
		t_engine_entry.access_time = uint64_t(t_stat_buf.st_atime);
		t_engine_entry.group_id = t_stat_buf.st_gid;
		t_engine_entry.user_id = t_stat_buf.st_uid;
		t_engine_entry.permissions = t_stat_buf.st_mode & 0777;
		t_engine_entry.is_folder = S_ISDIR(t_stat_buf.st_mode);

		/* Run callback */
		t_success = p_callback(x_context, &t_engine_entry);

		MCValueRelease (t_engine_entry.name);
	}

	/* Clean up the buffer allocated by scandir() */
	if (NULL != t_entries)
	{
		free(t_entries);
	}

	return t_success;
}

/* Resolve the path of a standard system directory, by name.
 *
 * Normally, sets r_folder to the native filesystem path of the
 * standard system directory named by p_type, and returns true.
 *
 * If p_type is not recognised, or its corresponding filesystem path
 * does not exist on the current system, sets r_folder to the empty
 * string and returns true.
 *
 * If an unexpected error occurs, returns false.
 */
Boolean
MCEmscriptenSystem::GetStandardFolder(MCNameRef p_type,
                                      MCStringRef & r_folder)
{
	const char *t_path_chars;
	MCAutoStringRef t_path;

	/* Decode the requested standard folder name */
	if (MCNameIsEqualToCaseless(p_type, MCN_engine))
	{
		t_path_chars = kMCEmscriptenStandardFolderEngine;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_resources))
	{
		t_path_chars = kMCEmscriptenStandardFolderResources;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_temporary))
	{
		t_path_chars = kMCEmscriptenStandardFolderTemporary;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_fonts))
	{
		t_path_chars = kMCEmscriptenStandardFolderFonts;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_home))
	{
		t_path_chars = kMCEmscriptenStandardFolderHome;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_documents))
	{
		t_path_chars = kMCEmscriptenStandardFolderDocuments;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_desktop))
	{
		t_path_chars = kMCEmscriptenStandardFolderDesktop;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_preferences))
	{
		t_path_chars = kMCEmscriptenStandardFolderPreferences;
	}
	else if (MCNameIsEqualToCaseless(p_type, MCN_support))
	{
		t_path_chars = kMCEmscriptenStandardFolderSupport;
	}
	else if (MCStringIsEqualToCString(MCNameGetString(p_type), "downloads",
	                                  kMCStringOptionCompareCaseless))
	{
		t_path_chars = kMCEmscriptenDownloadsFolder;
	}
	else if (MCStringIsEqualToCString(MCNameGetString(p_type), "uploads",
	                                  kMCStringOptionCompareCaseless))
	{
		t_path_chars = kMCEmscriptenUploadsFolder;
	}
	else
	{
		/* We don't know anything about the requested folder */
		return MCStringCopy(kMCEmptyString, r_folder);
	}

	if (!MCStringCreateWithCString(t_path_chars, &t_path))
	{
		return false;
	}

	/* Check that the directory actually exists */
	if (!FolderExists(*t_path))
	{
		return MCStringCopy(kMCEmptyString, r_folder);
	}

	return MCStringCopy(*t_path, r_folder);
}

real64_t
MCEmscriptenSystem::GetFreeDiskSpace()
{
	/* FIXME Implement GetFreeDiskSpace() */
	/* The filesystem does not support this call */
	SetErrno(ENOSYS);
	return 0.0;
}

Boolean
MCEmscriptenSystem::GetDevices(MCStringRef & r_devices)
{
	/* FIXME Implement GetDevices() */
	/* No devices */
	r_devices = MCValueRetain(kMCEmptyString);
	return true;
}

Boolean
MCEmscriptenSystem::GetDrives(MCStringRef & r_drives)
{
	/* FIXME Implement GetDrives() */
	/* No drives */
	SetErrno(0);
	r_drives = MCValueRetain(kMCEmptyString);
	return true;
}

Boolean
MCEmscriptenSystem::FileExists(MCStringRef p_path)
{
	struct stat t_stat_buf;
	errno = 0;
	if (!MCEmscriptenStatPath(p_path, t_stat_buf))
	{
		/* If the error is ENOENT, then consume the error; we've
		 * successfully detected that the file does not exist. */
		if (errno == ENOENT)
		{
			errno = 0;
		}
		return false;
	}

	return S_ISREG(t_stat_buf.st_mode);
}

Boolean
MCEmscriptenSystem::FolderExists(MCStringRef p_path)
{
	struct stat t_stat_buf;
	errno = 0;
	if (!MCEmscriptenStatPath(p_path, t_stat_buf))
	{
		/* If the error is ENOENT, then consume the error; we've
		 * successfully detected that the file does not exist. */
		if (errno == ENOENT)
		{
			errno = 0;
		}
		return false;
	}

	return S_ISDIR(t_stat_buf.st_mode);
}

Boolean
MCEmscriptenSystem::FileNotAccessible(MCStringRef p_path)
{
	/* This is only ever used to introduce TOCTTOU errors, so just
	 * pretend that files are always present/accessible. */
	return false;
}

Boolean
MCEmscriptenSystem::ChangePermissions(MCStringRef p_path, uint16_t p_mask)
{
	MCEmscriptenAutoStringRefAsSysPath t_path_sys;
	if (!t_path_sys.LockPath(p_path))
	{
		return false;
	}

	errno = 0;
	return MCEmscriptenSystemChanged(0 == chmod(*t_path_sys, p_mask));
}

uint16_t
MCEmscriptenSystem::UMask(uint16_t p_mask)
{
	return umask(p_mask);
}

IO_handle
MCEmscriptenSystem::OpenFile(MCStringRef p_path,
                             intenum_t p_mode,
                             Boolean p_map)
{
	MCAutoStringRefAsUTF8String t_path_sys;
	if (!t_path_sys.Lock(p_path))
	{
		return NULL;
	}

	int t_fd = -1;
	int t_open_flags = 0;

	switch (p_mode)
	{
	case kMCOpenFileModeRead:
		t_open_flags = O_RDONLY;
		break;
	case kMCOpenFileModeWrite:
		t_open_flags = O_WRONLY | O_TRUNC | O_CREAT;
		break;
	case kMCOpenFileModeUpdate:
		t_open_flags = O_RDWR | O_CREAT;
		break;
	case kMCOpenFileModeAppend:
		t_open_flags = O_RDWR | O_APPEND | O_CREAT;
		break;
	default:
		MCUnreachable();
		return NULL;
	}

	errno = 0;
	t_fd = open(*t_path_sys, t_open_flags, 0666);
	if (0 > t_fd)
	{
		return NULL;
	}

	/* A file opened for writing under /downloads goes to the user when
	 * it is closed (em-filehandle.cpp). Its path is the one open() found,
	 * with no "..", ".", "//" or symbolic link left in it. */
	if (p_mode != kMCOpenFileModeRead)
	{
		char *t_real_path = realpath(*t_path_sys, NULL);
		if (t_real_path != NULL &&
		    0 == strncmp(t_real_path, kMCEmscriptenDownloadsFolder "/",
		                 strlen(kMCEmscriptenDownloadsFolder "/")))
		{
			MCAutoStringRef t_download;
			bool t_have_download =
				MCStringCreateWithBytes(reinterpret_cast<const byte_t *>(t_real_path),
				                        strlen(t_real_path),
				                        kMCStringEncodingUTF8, false,
				                        &t_download);
			free(t_real_path);

			if (t_have_download)
			{
				return new MCEmscriptenFileHandle(t_fd, *t_download,
				                                  p_mode == kMCOpenFileModeWrite);
			}
		}
		else
		{
			free(t_real_path);
		}

		/* Opening a file for writing empties it: it has changed */
		return new MCEmscriptenFileHandle(t_fd, nil,
		                                  p_mode == kMCOpenFileModeWrite);
	}

	return new MCEmscriptenFileHandle(t_fd);
}

IO_handle
MCEmscriptenSystem::OpenFd(uint32_t p_fd,
                           intenum_t p_mode)
{
	return new MCEmscriptenFileHandle(p_fd);
}

IO_handle
MCEmscriptenSystem::OpenDevice(MCStringRef p_path,
                               intenum_t p_mode)
{
	/* FIXME Implement OpenDevice() */
	MCEmscriptenNotImplemented();
	return NULL;
}

bool
MCEmscriptenSystem::GetTemporaryFileName(MCStringRef & r_tmp_name)
{
	/* OXT-Beyond: a name in /tmp that no file has, as the Linux engine
	 * makes it (dsklnx.cpp), which the tempname gives. Before, it was
	 * never implemented, and the tempname was empty: a script that saved
	 * a stack or exported to a file the tempname named failed. The
	 * engine is the page's only program, so nothing can take the name
	 * before the script uses it. */
	char t_filename[] = "/tmp/prefXXXXXX";
	int t_fd = mkstemp(t_filename);
	bool t_success = t_fd != -1;

	if (t_success)
	{
		close(t_fd);
		t_success = unlink(t_filename) == 0;
	}

	if (t_success)
		t_success = MCStringCreateWithSysString(t_filename, r_tmp_name);

	if (!t_success)
		r_tmp_name = MCValueRetain(kMCEmptyString);

	return t_success;
}

bool
MCEmscriptenSystem::PathToNative(MCStringRef p_path,
                                 MCStringRef & r_path)
{
	/* Emscripten paths are internal paths */
	return MCStringCopy(p_path, r_path);
}

bool
MCEmscriptenSystem::PathFromNative(MCStringRef p_native_path,
                                   MCStringRef & r_path)
{
	/* Emscripten paths are internal paths */
	return MCStringCopy(p_native_path, r_path);
}

bool
MCEmscriptenSystem::ResolvePath(MCStringRef p_path,
                                MCStringRef & r_resolved_path)
{
	/* FIXME Implement ResolvePath() */
	/* This should do the following:
	 * 1) Expand user prefix:
	 *    a) If the prefix is ~/, expand to current user home dir
	 *    b) If the prefix is ~foo/, and foo is a user, expand to its home dir
	 *    c) If the prefix is ~foo/, and foo isn't a user, leave unchanged
	 * 2) Make absolute, by prepending CWD if necessary
	 * 3) Follow all symlinks
	 *
	 * If a system error occurs (e.g. due to a dangling symlink),
	 * return the "best" expansion found so far.
	 */

	/* ---------- 1. Expand user prefix */
	MCAutoStringRef t_user_expand;

	/* Check for a user prefix */
	if (MCStringBeginsWithCString(p_path, (const char_t *) "~",
	                              kMCStringOptionCompareExact))
	{
		/* Split into user part and rest of path */
		MCAutoStringRef t_user_part;
		MCAutoStringRef t_rel_part;
		uindex_t t_sep_offset;
		bool t_have_rel_part;

		if (MCStringFirstIndexOfChar(p_path, '/', 0,
		                             kMCStringOptionCompareExact,
		                             t_sep_offset))
		{
			t_have_rel_part = true;

			if (!MCStringDivideAtIndex(p_path, t_sep_offset,
			                           &t_user_part, &t_rel_part))
			{
				return false;
			}
		}
		else
		{
			t_have_rel_part = false;
			t_user_part = p_path;
			t_rel_part = kMCEmptyString;
		}

		/* At the moment, no user exists other than the current user,
		 * whose home directory is "/openxtalk" (OXT-Beyond: named
		 * ~openxtalk too, and still ~livecode) */
		if (MCStringIsEqualToCString(*t_user_part, "~",
		                             kMCStringOptionCompareExact) ||
		    MCStringIsEqualToCString(*t_user_part, "~livecode",
		                             kMCStringOptionCompareExact) ||
		    MCStringIsEqualToCString(*t_user_part, "~openxtalk",
		                             kMCStringOptionCompareExact))
		{
			if (t_have_rel_part)
			{
				if (!MCStringFormat(&t_user_expand, "%s/%@",
				                    kMCEmscriptenStandardFolderHome,
				                    *t_rel_part))
				{
					return false;
				}
			}
			else
			{
				t_user_expand = MCSTR(kMCEmscriptenStandardFolderHome);
			}
		}
		else
		{
			/* User prefix doesn't correspond to an actual username */
			t_user_expand = p_path;
		}
	}
	else
	{
		/* No user prefix */
		t_user_expand = p_path;
	}

	/* ---------- 2. Make absolute */
	MCAutoStringRef t_absolute;

	if (MCStringBeginsWithCString(*t_user_expand, (const char_t *) "/",
	                              kMCStringOptionCompareExact))
	{
		/* Absolute paths always begin with "/" */
		if (!MCStringCopy(*t_user_expand, &t_absolute))
		{
			return false;
		}
	}
	else
	{
		/* Make absolute by prepending the CWD, adding a separator if
		 * necessary */
		MCAutoStringRef t_cwd;
		if (!GetCurrentFolder(&t_cwd))
		{
			/* System error -> return "best" expansion */
			return MCStringCopy(*t_user_expand, r_resolved_path);
		}

		const char *t_fmt;
		if (MCStringEndsWithCString(*t_cwd, (const char_t *) "/",
		                            kMCStringOptionCompareExact))
		{
			t_fmt = "%@%@";
		}
		else
		{
			t_fmt = "%@/%@";
		}

		if (!MCStringFormat(&t_absolute, t_fmt, *t_cwd, *t_user_expand))
		{
			return false;
		}
	}

	/* ---------- 3. Follow all symlinks */

	MCAutoStringRefAsSysString t_absolute_sys;
	if (!t_absolute_sys.Lock(*t_absolute))
	{
		return false;
	}

	/* Use realpath(3) to recursively resolve symlinks */
	errno = 0;
	char *t_realpath_buf = realpath(*t_absolute_sys, NULL);
	if (NULL == t_realpath_buf)
	{
		/* System error -> return "best" expansion */
		return MCStringCopy(*t_absolute, r_resolved_path);
	}

	MCAutoStringRef t_realpath;
	bool t_realpath_ok = MCStringCreateWithSysString(t_realpath_buf,
	                                                 &t_realpath);

	free(t_realpath_buf);

	if (!t_realpath_ok)
	{
		return false;
	}


	return MCStringCopy(*t_realpath, r_resolved_path);
}

bool
MCEmscriptenSystem::LongFilePath(MCStringRef p_path,
                                 MCStringRef & r_long_path)
{
	return MCStringCopy(p_path, r_long_path);
}

bool
MCEmscriptenSystem::ShortFilePath(MCStringRef p_path,
                                  MCStringRef & r_short_path)
{
	return MCStringCopy(p_path, r_short_path);
}

/* ----------------------------------------------------------------
 * Text codecs
 * ---------------------------------------------------------------- */

/* OXT-Beyond: between UTF-16 and a single-byte charset, a byte to a
 * character and back, as the Linux engine converts (dsklnx.cpp), for
 * uniEncode and uniDecode with a language. Before, nothing was converted,
 * and they gave empty. */
uint32_t
MCEmscriptenSystem::TextConvert(const void *p_string,
                                uint32_t p_string_length,
                                void *r_buffer,
                                uint32_t p_buffer_length,
                                uint32_t p_from_charset,
                                uint32_t p_to_charset)
{
	uint32_t t_used = 0;
	if (p_to_charset == LCH_UNICODE)
	{
		if (p_buffer_length == 0)
			t_used = p_string_length * 2;
		else
		{
			const unsigned char *t_input = (const unsigned char *)p_string;
			uint16_t *t_output = (uint16_t *)r_buffer;
			uint32_t t_count = MCU_min(p_string_length, p_buffer_length / 2);
			for (uint32_t i = 0; i < t_count; ++i)
				t_output[i] = t_input[i];
			t_used = t_count * 2;
		}
	}
	else if (p_from_charset == LCH_UNICODE)
	{
		if (p_buffer_length == 0)
			t_used = p_string_length / 2;
		else
		{
			const uint16_t *t_input = (const uint16_t *)p_string;
			unsigned char *t_output = (unsigned char *)r_buffer;
			uint32_t t_count = MCU_min(p_string_length / 2, p_buffer_length);
			for (uint32_t i = 0; i < t_count; ++i)
				t_output[i] = (unsigned char)t_input[i];
			t_used = t_count;
		}
	}
	return t_used;
}

/* OXT-Beyond: text in a Windows or Mac code page to UTF-16, for the RTF
 * reader, which reads the text of each font in its charset (\ansi,
 * \ansicpg, \mac, \fcharset). As the Linux engine converts (dsklnx.cpp),
 * with iconv: the page's C library (musl) has the Windows and DOS code
 * pages, and those of Japan, China, Korea and Taiwan, but not MacRoman,
 * which comes from libfoundation's table here, nor Johab (1361), whose
 * text is left out. Before, nothing was converted, and setting the
 * rtfText of a field left it empty. */
static iconv_t
em_fetch_converter(const char *p_encoding)
{
	struct ConverterRecord
	{
		const char *encoding;
		iconv_t converter;
	};
	static ConverterRecord s_records[32];
	static uint32_t s_record_count = 0;

	for (uint32_t i = 0; i < s_record_count; ++i)
		if (s_records[i].encoding == p_encoding)
			return s_records[i].converter;

	/* UTF-16LE, so that iconv puts no byte order mark first (as Linux's) */
	iconv_t t_converter = iconv_open("UTF-16LE", p_encoding);
	if (s_record_count < sizeof(s_records) / sizeof(s_records[0]))
	{
		s_records[s_record_count].encoding = p_encoding;
		s_records[s_record_count].converter = t_converter;
		s_record_count += 1;
	}
	else if (t_converter != (iconv_t)-1)
	{
		/* Never kept: there are fewer code pages than records */
		iconv_close(t_converter);
		t_converter = (iconv_t)-1;
	}
	return t_converter;
}

bool
MCEmscriptenSystem::TextConvertToUnicode(uint32_t p_input_encoding,
                                         const void *p_input,
                                         uint32_t p_input_length,
                                         void *p_output,
                                         uint32_t & p_output_length,
                                         uint32_t & r_used)
{
	if (p_input_length == 0)
	{
		r_used = 0;
		return true;
	}

	if (p_output_length == 0)
	{
		r_used = p_input_length * 4;
		return false;
	}

	/* MacRoman: a character a byte */
	if (p_input_encoding >= kMCTextEncodingMacNative &&
	    p_input_encoding < kMCTextEncodingWindowsNative)
	{
		if (p_output_length < p_input_length * 2)
		{
			r_used = p_input_length * 2;
			return false;
		}
		const char_t *t_input = (const char_t *)p_input;
		unichar_t *t_output = (unichar_t *)p_output;
		for (uint32_t i = 0; i < p_input_length; ++i)
			t_output[i] = unichar_t(MCUnicodeMapFromNative_MacRoman(t_input[i]));
		r_used = p_input_length * 2;
		return true;
	}

	const char *t_encoding = nullptr;
	if (p_input_encoding >= kMCTextEncodingWindowsNative)
	{
		static const struct { uint32_t codepage; const char *encoding; } s_codepage_map[] =
		{
			{437, "CP437" },
			{850, "CP850" },
			{932, "CP932" },
			{949, "CP949" },
			{1361, "CP1361" },
			{936, "CP936" },
			{950, "CP950" },
			{1253, "WINDOWS-1253" },
			{1254, "WINDOWS-1254" },
			{1258, "WINDOWS-1258" },
			{1255, "WINDOWS-1255" },
			{1256, "WINDOWS-1256" },
			{1257, "WINDOWS-1257" },
			{1251, "WINDOWS-1251" },
			{874, "CP874" },
			{1250, "WINDOWS-1250" },
			{1252, "WINDOWS-1252" },
		};

		for (uint32_t i = 0; i < sizeof(s_codepage_map) / sizeof(s_codepage_map[0]); ++i)
			if (s_codepage_map[i].codepage == p_input_encoding - kMCTextEncodingWindowsNative)
			{
				t_encoding = s_codepage_map[i].encoding;
				break;
			}
	}

	/* No converter: nothing comes out, as on Linux */
	iconv_t t_converter = (iconv_t)-1;
	if (t_encoding != nullptr)
		t_converter = em_fetch_converter(t_encoding);
	if (t_converter == (iconv_t)-1)
	{
		r_used = 0;
		return true;
	}

	char *t_in_bytes = (char *)p_input;
	size_t t_in_bytes_left = p_input_length;
	char *t_out_bytes = (char *)p_output;
	size_t t_out_bytes_left = p_output_length;

	iconv(t_converter, nullptr, nullptr, &t_out_bytes, &t_out_bytes_left);

	while (iconv(t_converter, &t_in_bytes, &t_in_bytes_left, &t_out_bytes, &t_out_bytes_left) == (size_t)-1)
	{
		/* Not room enough, or too little for U+FFFD below: the caller
		 * asks again with room enough for any of these code pages */
		if (errno == E2BIG || t_out_bytes_left < 2)
		{
			r_used = 4 * p_input_length;
			return false;
		}

		/* A byte the code page has no character for, or a character
		 * cut off at the end: U+FFFD for it, and on with the next.
		 * (Linux's engine stops, and its RTF reader then takes what
		 * the rest of its buffer held.) */
		t_out_bytes[0] = char(0xFD);
		t_out_bytes[1] = char(0xFF);
		t_out_bytes += 2;
		t_out_bytes_left -= 2;
		t_in_bytes += 1;
		t_in_bytes_left -= 1;
	}

	r_used = p_output_length - t_out_bytes_left;
	return true;
}

/* ----------------------------------------------------------------
 * Subprocesses
 * ---------------------------------------------------------------- */

/* Emscripten doesn't support subprocesses */

bool
MCEmscriptenSystem::Shell(MCStringRef p_filename,
                          MCDataRef & r_data,
                          int & r_retcode)
{
	return false;
}

void
MCEmscriptenSystem::CheckProcesses()
{
	/* Successfully do nothing */
}

bool
MCEmscriptenSystem::StartProcess(MCNameRef p_name,
                                 MCStringRef p_doc,
                                 intenum_t p_mode,
                                 Boolean p_elevated)
{
	return false;
}

void
MCEmscriptenSystem::CloseProcess(uint16_t p_index)
{
	/* Successfully do nothing */
}

void
MCEmscriptenSystem::Kill(int32_t p_pid,
                         int32_t p_signal)
{
	/* Successfully do nothing */
}

void
MCEmscriptenSystem::KillAll()
{
	/* Successfully do nothing */
}

/* OXT-Beyond: when Poll() last gave the browser a turn */
static real64_t s_poll_turn_time = 0.0;

Boolean
MCEmscriptenSystem::Poll(real64_t p_delay,
                         int p_fd)
{
	/* OXT-Beyond: only the wait of an engine without a user interface
	 * (MCUIDC::wait) polls, and on the web that is the engine of a web
	 * worker (em-dc-mainloop.cpp). It returned false at once, so such a
	 * wait went round and round, and gave the worker no turn to hear the
	 * page. It gives the browser its turn now, for the time that it is
	 * asked or until the page's message resumes the engine (true), as
	 * the screen's wait does (em-dc.cpp): a wait of no time only when a
	 * frame has gone by since the last turn, so that a run of messages
	 * is not slowed by a turn for each. It cannot while JavaScript has
	 * called into the engine, and then ends a wait at once, as the
	 * screen's wait does there. */
	if (!MCEmscriptenAsyncCanYield())
	{
		return True;
	}

	if (!(p_delay > 0.0) &&
	    GetCurrentTime() - s_poll_turn_time < 1.0 / 60.0)
	{
		return False;
	}

	int t_event = MCEmscriptenAsyncYield(MCMax(p_delay, 0.0));
	s_poll_turn_time = GetCurrentTime();
	return t_event != 0;
}

Boolean
MCEmscriptenSystem::IsInteractiveConsole(int p_fd)
{
	return false;
}

/* ----------------------------------------------------------------
 * Miscellanous
 * ---------------------------------------------------------------- */

/* A file of the engine's file system opens in a new tab of the
 * browser, which shows what it can show (a picture, a PDF, a text, a
 * page) and downloads the rest */
void
MCEmscriptenSystem::LaunchDocument(MCStringRef p_document)
{
	MCAutoStringRef t_path;
	if (!MCS_resolvepath(p_document, &t_path) || !FileExists(*t_path))
	{
		/* As on the Mac */
		MCresult->sets("can't open file");
		return;
	}

	if (!MCEmscriptenShowDocument(*t_path))
	{
		MCresult->sets("no association");
	}
}

/* A URL opens in a new tab of the browser, and a file: URL names a file
 * of the engine's file system (as on the Mac, it is not URL-encoded).
 * The browser opens a tab only while the page answers a click or a key:
 * without one (a handler that a timer sent), the page asks the user,
 * and its Open button opens it (em-system.js). */
void
MCEmscriptenSystem::LaunchUrl(MCStringRef p_url)
{
	if (MCStringBeginsWithCString(p_url, (const char_t *) "file:",
	                              kMCStringOptionCompareCaseless))
	{
		uindex_t t_start = 5;
		if (MCStringBeginsWithCString(p_url, (const char_t *) "file:///",
		                              kMCStringOptionCompareCaseless))
		{
			t_start = 7;
		}

		MCAutoStringRef t_path;
		if (!MCStringCopySubstring(p_url,
		                           MCRangeMakeMinMax(t_start, MCStringGetLength(p_url)),
		                           &t_path))
		{
			MCresult->sets("no association");
			return;
		}

		LaunchDocument(*t_path);
		return;
	}

	MCAutoStringRefAsUTF16String t_url_u16;
	if (!t_url_u16.Lock(p_url) ||
	    0 == MCEmscriptenSystemLaunchUrl(t_url_u16.Ptr(), t_url_u16.Size()))
	{
		/* javascript: and data: URLs are refused, as is what is not a
		 * URL */
		MCresult->sets("no association");
	}
}

bool
MCEmscriptenSystem::GetDNSservers(MCListRef & r_list)
{
	/* DNS servers aren't available */
	return false;
}

// These functions is implemented in javascript
extern "C" int32_t MCEmscriptenDialogShowAlert(const unichar_t* p_message, size_t p_message_length);

void
MCEmscriptenSystem::ShowMessageDialog(MCStringRef p_title,
                                      MCStringRef p_message)
{
	MCAutoStringRefAsUTF16String t_message_u16;
	t_message_u16.Lock(p_message);
	MCEmscriptenDialogShowAlert(t_message_u16.Ptr(), t_message_u16.Size());
}

/* ----------------------------------------------------------------
 * Interface with browser JavaScript
 * ---------------------------------------------------------------- */

void
MCEmscriptenSystem::DoAlternateLanguage(MCStringRef p_script,
                    MCStringRef p_language)
{
	if (!MCStringIsEqualToCString(p_language, "javascript", kMCStringOptionCompareCaseless))
	{
		MCresult -> sets("alternate language not found");
		return;
	}

	bool t_success = true;

	MCAutoValueRef t_result;
	t_success = MCEmscriptenJSEvaluateScript(p_script, &t_result);

	if (!t_success)
	{
		MCresult->sets("execution error");
		return;
	}

	/* OXT-Beyond: the result is the script's value when it is a string, a
	 * number, a boolean, binary data (a Uint8Array), or undefined or null
	 * (empty), as the dictionary says; a JavaScript array, object or
	 * function is not supported, and gives "execution error". Before, the
	 * result held the engine's own value for it, a list or an object that
	 * a script could not use: comparing the result with anything threw an
	 * error. */
	switch (MCValueGetTypeCode(*t_result))
	{
		case kMCValueTypeCodeNull:
		case kMCValueTypeCodeBoolean:
		case kMCValueTypeCodeNumber:
		case kMCValueTypeCodeName:
		case kMCValueTypeCodeString:
		case kMCValueTypeCodeData:
			MCresult->setvalueref(*t_result);
			break;
		default:
			MCresult->sets("execution error");
			break;
	}
}

bool
MCEmscriptenSystem::AlternateLanguages(MCListRef & r_list)
{
	MCAutoListRef t_list;
	MCAutoStringRef t_js_string;

	return MCStringCreateWithCString("javascript", &t_js_string) && \
		MCListCreateMutable('\n', &t_list) && \
		MCListAppend(*t_list, *t_js_string) && \
		MCListCopy(*t_list, r_list);
}

//////////

#include "dispatch.h"

MCStack* _emscripten_get_stack(void *p_stack_ptr)
{
	MCStack *t_stacks = MCdispatcher->getstacks();
	
	MCStack *t_stack = t_stacks;
	do
	{
		if (t_stack == p_stack_ptr)
			return t_stack;
		
		t_stack = t_stack->next();
	}
	while (t_stack != t_stacks);
	
	return nil;
}

extern "C" MC_DLLEXPORT_DEF
MCProperListRef MCEmscriptenSystemGetJavascriptHandlersOfStack(void *p_stack)
{
	MCStackHandle t_stack(_emscripten_get_stack(p_stack));

	// Ensure stack pointer is valid
	if (!t_stack.IsValid())
		return MCValueRetain(kMCEmptyProperList);
	
	bool t_success = true;
	
	// get javascripthandlers property
	MCExecValue t_value;
	MCExecContext ctxt(nil, nil, nil);
	bool t_lock_messages = MClockmessages;
	MClockmessages = true;
	t_success = t_stack->getcustomprop(ctxt, t_stack->getdefaultpropsetname(), MCNAME("cjavascripthandlers"), nil, t_value);
	MClockmessages = t_lock_messages;
	
	MCAutoStringRef t_prop_string;
	if (t_success)
	{
		MCExecTypeConvertAndReleaseAlways(ctxt, t_value.type, &t_value, kMCExecValueTypeStringRef, &(&t_prop_string));
		t_success = *t_prop_string != nil;
	}

	MCAutoProperListRef t_list;
	if (t_success)
		t_success = MCStringSplitByDelimiter(*t_prop_string, kMCLineEndString, kMCStringOptionCompareExact, &t_list);
	
	if (!t_success)
		return MCValueRetain(kMCEmptyProperList);
	
	return t_list.Take();
}

extern void MCEngineFreeScriptParameters(MCParameter* p_params);
extern bool MCEngineConvertToScriptParameters(MCExecContext& ctxt, MCProperListRef p_arguments, MCParameter*& r_script_params);

extern Exec_stat _MCEngineExecDoDispatch(MCExecContext &ctxt, int p_handler_type, MCNameRef p_message, MCObjectPtr *p_target, MCParameter *p_parameters);

extern "C" MC_DLLEXPORT_DEF
MCValueRef MCEmscriptenSystemCallStackHandler(void *p_stack, MCStringRef p_handler, MCProperListRef p_params)
{
	bool t_success = true;
	
	// Ensure stack pointer is valid
	MCStackHandle t_stack;
	
	if (t_success)
	{
		t_stack = _emscripten_get_stack(p_stack);
		t_success = t_stack.IsValid();
	}
	
	// Ensure handler is allowed to be called from JavaScript
	if (t_success)
	{
		MCAutoProperListRef t_handler_list;
		t_handler_list.Give(MCEmscriptenSystemGetJavascriptHandlersOfStack(p_stack));
		bool t_found = false;
		for (uint32_t i = 0; !t_found && i < MCProperListGetLength(*t_handler_list); i++)
		{
			MCStringRef t_handler = static_cast<MCStringRef>(MCProperListFetchElementAtIndex(*t_handler_list, i));
			t_found = MCStringIsEqualTo(t_handler, p_handler, kMCStringOptionCompareCaseless);
		}
		
		t_success = t_found;
	}
	
	MCNewAutoNameRef t_handler_name;
	if (t_success)
		t_success = MCNameCreate(p_handler, &t_handler_name);
	
	MCExecContext ctxt;
	MCAutoCustomPointer<MCParameter, MCEngineFreeScriptParameters> t_params;
	if (t_success)
		t_success = MCEngineConvertToScriptParameters(ctxt, p_params, &t_params);

	if (t_success)
	{
		MCObjectPtr t_stack_obj(t_stack, 0);
		MCresult->clear();
		
		Exec_stat t_stat;
		// try to dispatch handler as message
		t_stat = _MCEngineExecDoDispatch(ctxt, HT_MESSAGE, *t_handler_name, &t_stack_obj, *t_params);
		t_success = t_stat != ES_ERROR;
		
		if (t_success && t_stat != ES_NORMAL)
		{
			// not handled as message, try as function
			t_stat = _MCEngineExecDoDispatch(ctxt, HT_FUNCTION, *t_handler_name, &t_stack_obj, *t_params);
			t_success = t_stat != ES_ERROR;
		}
	}
	
	// fetch result (as string)
	MCAutoValueRef t_result;
	if (t_success)
		t_success = MCresult->eval(ctxt, &t_result);
	
	if (!t_success)
		return nil;
	
	return t_result.Take();
}

// Return the named stack, or NULL if not found
extern "C" MC_DLLEXPORT_DEF
MCStack *MCEmscriptenResolveStack(MCStringRef p_name)
{
	MCNewAutoNameRef t_name;
	if (!MCNameCreate(p_name, &t_name))
		return nil;
	
	return MCdispatcher->findstackname(*t_name);
}

//////////

extern "C" MC_DLLEXPORT_DEF
MCValueRef MCEmscriptenSystemCallHandler(MCHandlerRef p_handler, MCProperListRef p_params)
{
	MCProperListRef t_in_out_params = MCValueRetain(p_params);
	
	MCErrorRef t_error = nil;
	MCValueRef t_result = nil;
	t_error = MCHandlerTryToInvokeWithList(p_handler, t_in_out_params, t_result);
	
	MCValueRelease(t_in_out_params);
	
	if (t_error)
	{
		MCValueRelease(t_error);
		return nil;
	}
	
	return t_result;
}

//////////

extern "C" MC_DLLEXPORT_DEF
MCNullRef MCEmscriptenUtilCreateNull()
{
	return MCValueRetain(kMCNull);
}

extern "C" MC_DLLEXPORT_DEF
MCBooleanRef MCEmscriptenUtilCreateBoolean(bool p_value)
{
	MCBooleanRef t_boolean;
	if (!MCBooleanCreateWithBool(p_value, t_boolean))
		return nil;
	
	return t_boolean;
}

extern "C" MC_DLLEXPORT_DEF
bool MCEmscriptenUtilGetBooleanValue(MCBooleanRef p_boolean)
{
	return p_boolean == kMCTrue;
}

extern "C" MC_DLLEXPORT_DEF
MCNumberRef MCEmscriptenUtilCreateNumberWithReal(real64_t p_value)
{
	MCNumberRef t_number = nil;
	if (!MCNumberCreateWithReal(p_value, t_number))
		return nil;
		
	return t_number;
}

extern "C" MC_DLLEXPORT_DEF
MCStringRef MCEmscriptenUtilCreateStringWithCharsAndRelease(unichar_t *p_utf16_string, uint32_t p_length)
{
	MCStringRef t_string = nil;
	if (!MCStringCreateWithCharsAndRelease(p_utf16_string, p_length, t_string))
		return nil;
	
	return t_string;
}

extern "C" MC_DLLEXPORT_DEF
MCStringRef MCEmscriptenUtilFormatAsString(MCValueRef p_value)
{
	MCStringRef t_string = nil;
	if (!MCStringFormat(t_string, "%@", p_value))
		return nil;
	return t_string;
}

extern "C" MC_DLLEXPORT_DEF
MCProperListRef MCEmscriptenUtilCreateMutableProperList()
{
	MCProperListRef t_list = nil;
	if (!MCProperListCreateMutable(t_list))
		return nil;
	
	return t_list;
}

extern "C" MC_DLLEXPORT_DEF
MCDataRef MCEmscriptenUtilCreateDataWithBytesAndRelease(byte_t *p_bytes, uindex_t p_byte_count)
{
	MCDataRef t_data = nil;
	if (!MCDataCreateWithBytesAndRelease(p_bytes, p_byte_count, t_data))
		return nil;
	
	return t_data;
}
