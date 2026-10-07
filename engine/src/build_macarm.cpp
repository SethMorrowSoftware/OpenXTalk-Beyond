/* Copyright (C) 2003-2015 LiveCode Ltd.
 * Copyright (C) 2024-2026 OpenXTalk Contributors.

This file is part of LiveCode / OpenXTalk.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

////////////////////////////////////////////////////////////////////////////////
//
//  Private Source File:
//    build_macarm.cpp
//
//  Description:
//    Implementation of _internal build MacARM command.
//    Uses the engine's own MCDeployToMacOSX to embed a .oxtstack file
//    into a blank ARM64 standalone binary, producing a self-contained
//    macOS application on the Desktop.
//
//    Usage from script:
//      _internal build MacARM "test-stack"
//
//    This looks for ~/Desktop/<name>/ containing:
//      - A .oxtstack file
//      - A blank .app bundle (Standalone-blank.app or similar)
//    And produces ~/Desktop/<name>.app
//
////////////////////////////////////////////////////////////////////////////////

#include "prefix.h"

#include "globdefs.h"
#include "objdefs.h"
#include "parsedef.h"
#include "filedefs.h"
#include "mcio.h"

#include "exec.h"
#include "handler.h"
#include "scriptpt.h"
#include "newobj.h"
#include "cmds.h"
#include "mcerror.h"
#include "globals.h"
#include "express.h"
#include "internal.h"

#include "deploy.h"
#include "stacksecurity.h"

#include <string>
#include <vector>
#include <dirent.h>
#include <sys/stat.h>

#include "build_macarm.h"

////////////////////////////////////////////////////////////////////////////////
// Filesystem helpers
////////////////////////////////////////////////////////////////////////////////

static bool build_is_directory(const std::string &path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

static bool build_is_file(const std::string &path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

static bool build_ends_with_ci(const std::string &str, const std::string &suffix) {
    if (suffix.size() > str.size()) return false;
    for (size_t i = 0; i < suffix.size(); i++) {
        if (tolower(str[str.size() - suffix.size() + i]) != tolower(suffix[i]))
            return false;
    }
    return true;
}

static std::vector<std::string> build_find_files(const std::string &dir, const std::string &suffix) {
    std::vector<std::string> results;
    DIR *d = opendir(dir.c_str());
    if (!d) return results;
    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr) {
        std::string name(entry->d_name);
        if (name == "." || name == "..") continue;
        if (build_ends_with_ci(name, suffix))
            results.push_back(dir + "/" + name);
    }
    closedir(d);
    return results;
}

static std::vector<std::string> build_find_files_multi(const std::string &dir, const std::vector<std::string> &suffixes) {
    std::vector<std::string> results;
    DIR *d = opendir(dir.c_str());
    if (!d) return results;
    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr) {
        std::string name(entry->d_name);
        if (name == "." || name == "..") continue;
        for (const auto &suffix : suffixes) {
            if (build_ends_with_ci(name, suffix)) {
                results.push_back(dir + "/" + name);
                break;
            }
        }
    }
    closedir(d);
    return results;
}

static std::vector<std::string> build_find_app_bundles(const std::string &dir) {
    std::vector<std::string> results;
    DIR *d = opendir(dir.c_str());
    if (!d) return results;
    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr) {
        std::string name(entry->d_name);
        if (!build_ends_with_ci(name, ".app")) continue;
        std::string app_path = dir + "/" + name;
        std::string macos_dir = app_path + "/Contents/MacOS";
        if (!build_is_directory(macos_dir)) continue;
        DIR *md = opendir(macos_dir.c_str());
        if (!md) continue;
        struct dirent *me;
        while ((me = readdir(md)) != nullptr) {
            if (me->d_name[0] == '.') continue;
            std::string bin_path = macos_dir + "/" + me->d_name;
            if (build_is_file(bin_path)) {
                results.push_back(app_path);
                break;
            }
        }
        closedir(md);
    }
    closedir(d);
    return results;
}

static std::string build_find_binary_in_app(const std::string &app_path) {
    std::string macos_dir = app_path + "/Contents/MacOS";
    DIR *d = opendir(macos_dir.c_str());
    if (!d) return "";
    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr) {
        if (entry->d_name[0] == '.') continue;
        std::string bin_path = macos_dir + "/" + entry->d_name;
        if (build_is_file(bin_path)) {
            closedir(d);
            return bin_path;
        }
    }
    closedir(d);
    return "";
}

static std::string build_basename(const std::string &path) {
    size_t pos = path.rfind('/');
    if (pos == std::string::npos) return path;
    return path.substr(pos + 1);
}

static std::string build_remove_extension(const std::string &name) {
    size_t pos = name.rfind('.');
    if (pos == std::string::npos) return name;
    return name.substr(0, pos);
}

////////////////////////////////////////////////////////////////////////////////
// MCInternalBuildMacARM implementation
////////////////////////////////////////////////////////////////////////////////

MCInternalBuildMacARM::MCInternalBuildMacARM(void)
{
    m_folder_name = nil;
}

MCInternalBuildMacARM::~MCInternalBuildMacARM(void)
{
    delete m_folder_name;
}

Parse_stat MCInternalBuildMacARM::parse(MCScriptPoint& sp)
{
    if (sp.parseexp(False, True, &m_folder_name) != PS_NORMAL)
    {
        MCperror->add(PE_PUT_BADEXP, sp);
        return PS_ERROR;
    }
    return PS_NORMAL;
}

void MCInternalBuildMacARM::exec_ctxt(MCExecContext &ctxt)
{
#ifndef _MACOSX
    ctxt.SetTheResultToCString("build MacARM is only supported on macOS");
    return;
#else
    // Evaluate the folder name parameter
    MCAutoStringRef t_folder_name;
    if (!ctxt.EvalExprAsStringRef(m_folder_name, EE_UNDEFINED, &t_folder_name))
        return;

    // Convert to C string for file operations
    MCAutoStringRefAsCString t_folder_cstr;
    t_folder_cstr.Lock(*t_folder_name);

    // Build the desktop path
    const char *home = getenv("HOME");
    if (home == nullptr)
    {
        ctxt.SetTheResultToCString("cannot determine home directory");
        return;
    }

    std::string desktop = std::string(home) + "/Desktop";
    std::string work_dir = desktop + "/" + *t_folder_cstr;

    if (!build_is_directory(work_dir))
    {
        ctxt.SetTheResultToCString("folder not found on Desktop");
        return;
    }

    // Find .oxtstack file
    auto stacks = build_find_files(work_dir, ".oxtstack");
    if (stacks.empty())
    {
        ctxt.SetTheResultToCString("no .oxtstack file found in folder");
        return;
    }
    if (stacks.size() > 1)
    {
        ctxt.SetTheResultToCString("multiple .oxtstack files found - keep only one");
        return;
    }

    std::string stack_path = stacks[0];
    std::string stack_name = build_remove_extension(build_basename(stack_path));

    // Find auxiliary stack files (other .oxtstack, .livecode, .rev files)
    std::vector<std::string> t_aux_paths;
    std::vector<std::string> t_stack_suffixes = {".oxtstack", ".livecode", ".rev"};
    auto t_all_stacks = build_find_files_multi(work_dir, t_stack_suffixes);
    for (const auto &t_s : t_all_stacks) {
        if (t_s != stack_path)
            t_aux_paths.push_back(t_s);
    }
    // Also check inclusions/ subfolder
    std::string t_incl_dir = work_dir + "/inclusions";
    if (build_is_directory(t_incl_dir)) {
        auto t_incl_stacks = build_find_files_multi(t_incl_dir, t_stack_suffixes);
        t_aux_paths.insert(t_aux_paths.end(), t_incl_stacks.begin(), t_incl_stacks.end());
    }

    // Find .app bundles, filtering out previous output
    auto apps_all = build_find_app_bundles(work_dir);
    std::vector<std::string> apps;
    for (auto &a : apps_all) {
        std::string name = build_basename(a);
        if (build_remove_extension(name) == stack_name)
            continue;
        apps.push_back(a);
    }

    if (apps.empty())
    {
        ctxt.SetTheResultToCString("no blank .app bundle found in folder");
        return;
    }

    // If multiple, prefer one with "blank" or "Standalone" in name
    std::string app_path = apps[0];
    if (apps.size() > 1) {
        bool found = false;
        for (auto &a : apps) {
            std::string name = build_basename(a);
            if (name.find("lank") != std::string::npos ||
                name.find("tandalone") != std::string::npos) {
                app_path = a;
                found = true;
                break;
            }
        }
        if (!found) {
            ctxt.SetTheResultToCString("multiple .app bundles found - keep only the blank standalone");
            return;
        }
    }

    std::string engine_binary = build_find_binary_in_app(app_path);
    if (engine_binary.empty())
    {
        ctxt.SetTheResultToCString("no binary found in blank .app bundle");
        return;
    }

    // Output app on Desktop
    std::string output_app = desktop + "/" + stack_name + ".app";

    // Remove existing output
    if (build_is_directory(output_app))
    {
        std::string rm_cmd = "rm -rf '" + output_app + "'";
        system(rm_cmd.c_str());
    }

    // Copy blank app bundle to output
    std::string cp_cmd = "cp -R '" + app_path + "' '" + output_app + "'";
    if (system(cp_cmd.c_str()) != 0)
    {
        ctxt.SetTheResultToCString("failed to copy app bundle");
        return;
    }

    // Find binary in output app
    std::string output_binary = build_find_binary_in_app(output_app);
    if (output_binary.empty())
    {
        ctxt.SetTheResultToCString("no binary found in copied app bundle");
        return;
    }

    // Use the engine's own deploy infrastructure (MCDeployToMacOSX)
    // to correctly build the capsule and embed it into the Mach-O binary.
    MCDeployParameters t_params;

    // Set the engine (blank standalone binary)
    MCAutoStringRef t_engine_str;
    MCStringCreateWithCString(engine_binary.c_str(), &t_engine_str);
    MCValueRelease(t_params.engine);
    t_params.engine = MCValueRetain(*t_engine_str);

    // Set the stackfile
    MCAutoStringRef t_stack_str;
    MCStringCreateWithCString(stack_path.c_str(), &t_stack_str);
    MCValueRelease(t_params.stackfile);
    t_params.stackfile = MCValueRetain(*t_stack_str);

    // Set the output (the binary inside the copied app bundle)
    MCAutoStringRef t_output_str;
    MCStringCreateWithCString(output_binary.c_str(), &t_output_str);
    MCValueRelease(t_params.output);
    t_params.output = MCValueRetain(*t_output_str);

    // Build auxiliary_stackfiles array if any were found
    if (!t_aux_paths.empty())
    {
        MCArrayRef t_aux_array = nil;
        /* UNCHECKED */ MCArrayCreateMutable(t_aux_array);
        for (uindex_t i = 0; i < t_aux_paths.size(); i++)
        {
            MCAutoStringRef t_aux_str;
            MCStringCreateWithCString(t_aux_paths[i].c_str(), &t_aux_str);
            /* UNCHECKED */ MCArrayStoreValueAtIndex(t_aux_array, i + 1, *t_aux_str);
        }
        MCValueRelease(t_params.auxiliary_stackfiles);
        t_params.auxiliary_stackfiles = MCValueRetain(t_aux_array);
        MCValueRelease(t_aux_array);
    }

    // Run the security pre-deploy step (no-op for community)
    MCStackSecurityPreDeploy(kMCLicenseDeployToMacOSX, t_params);

    // Clear the result before deploying
    ctxt.SetTheResultToEmpty();

    // Call the engine's own macOS deploy function
    Exec_stat t_stat;
    t_stat = MCDeployToMacOSX(t_params);

    // Check for deploy errors
    MCDeployError t_error;
    t_error = MCDeployCatch();
    if (t_error != kMCDeployErrorNone)
    {
        ctxt.SetTheResultToCString(MCDeployErrorToString(t_error));
        return;
    }

    if (t_stat != ES_NORMAL)
    {
        ctxt.SetTheResultToCString("deploy failed");
        return;
    }

    // Make executable
    chmod(output_binary.c_str(), 0755);

    // Re-sign
    std::string sign_cmd = "codesign --force --deep --sign - '" + output_app + "' 2>/dev/null";
    system(sign_cmd.c_str());

    // Success - set the result to the output path
    MCAutoStringRef t_result;
    MCStringCreateWithCString(output_app.c_str(), &t_result);
    ctxt.SetTheResultToValue(*t_result);
#endif
}
