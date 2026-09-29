; OXT-Beyond installer for Windows x86-64 (Inno Setup 6.3 or later).
;
; Packs the staged installed layout written by tools/oxt/package.py
; (dist/stage/OXT-Beyond-<version>/) into OXT-Beyond-<version>-win-x86_64-setup.exe.
; tools/ci/build-installer.ps1 runs the compiler with these defines:
;
;   /DAppVersion=<version>      product version (ide/.version), for example 0.0.1
;   /DBuildNumber=<number>      build number (the staged .buildnumber)
;   /DStageDir=<folder>         the staged installed layout
;   /DOutputDir=<folder>        where the setup program is written (dist)
;   /DRepoRoot=<folder>         repository root (for ide/OXT-Beyond.ico)
;   /DWizardImageFile=<list>    optional: comma-separated wizard images
;   /DWizardSmallImageFile=<list>  optional: comma-separated small wizard images
;
; Without the defines, the version is read from ide/.version, the stage is
; expected in dist/stage/OXT-Beyond-<version>, the build number is read
; from the stage and Inno Setup's built-in wizard images are used, so the
; script can also be compiled on its own from the Inno Setup IDE.
;
; Setup first asks whether to install for all users (Program Files, needs
; administrator rights; the default) or for the current user only
; (%LOCALAPPDATA%\Programs); /ALLUSERS or /CURRENTUSER on the command line
; choose without asking. HKA and the {auto...} constants follow the chosen
; mode. The uninstaller removes the
; program files, shortcuts and file associations, but not the IDE's
; preferences (%APPDATA%\OXT-Beyond) or caches (%LOCALAPPDATA%\OXT-Beyond).

#if VER < EncodeVer(6, 3, 0, 0)
  #error Inno Setup 6.3 or later is required to compile this script.
#endif

#define AppName "OXT-Beyond"
#define AppExeName "OXT-Beyond.exe"
#define RepoUrl "https://github.com/SethMorrowSoftware/winoxt"

#ifndef RepoRoot
  #define RepoRoot AddBackslash(SourcePath) + "..\.."
#endif

#ifndef AppVersion
  #define VersionFile RepoRoot + "\ide\.version"
  #if !FileExists(VersionFile)
    #error AppVersion was not defined and ide/.version was not found.
  #endif
  #define VersionHandle FileOpen(VersionFile)
  #define AppVersion Trim(FileRead(VersionHandle))
  #expr FileClose(VersionHandle)
#endif

#ifndef StageDir
  #define StageDir RepoRoot + "\dist\stage\" + AppName + "-" + AppVersion
#endif

#ifndef OutputDir
  #define OutputDir RepoRoot + "\dist"
#endif

#if !DirExists(StageDir)
  #pragma message "Staged layout not found: " + StageDir
  #error The staged installed layout does not exist. Run tools/oxt/package.py first (see tools/ci/build-installer.ps1).
#endif
#if !FileExists(StageDir + "\" + AppExeName)
  #pragma message "Missing: " + StageDir + "\" + AppExeName
  #error The staged layout has no OXT-Beyond.exe.
#endif
#if !FileExists(StageDir + "\LICENSE")
  #error The staged layout has no LICENSE file.
#endif

#ifndef BuildNumber
  #if FileExists(StageDir + "\.buildnumber")
    #define BuildNumberHandle FileOpen(StageDir + "\.buildnumber")
    #define BuildNumber Trim(FileRead(BuildNumberHandle))
    #expr FileClose(BuildNumberHandle)
  #else
    #define BuildNumber "0"
  #endif
#endif

; Windows version resources take numbers only: drop a pre-release or build
; suffix (0.1.0-beta.1 -> 0.1.0).
#define NumericVersion AppVersion
#if Pos("-", NumericVersion) > 0
  #define NumericVersion Copy(NumericVersion, 1, Pos("-", NumericVersion) - 1)
#endif
#if Pos("+", NumericVersion) > 0
  #define NumericVersion Copy(NumericVersion, 1, Pos("+", NumericVersion) - 1)
#endif

#define SetupIcon RepoRoot + "\ide\OXT-Beyond.ico"
#if !FileExists(SetupIcon)
  #pragma message "Missing: " + SetupIcon
  #error ide/OXT-Beyond.ico was not found.
#endif

[Setup]
; Fixed for every release: it names the uninstall registry key
; ({6CB5C1F5-4B20-43EF-B5F6-1C0C2C07B803}_is1) and lets a new version
; replace an installed one. Never change it.
AppId={{6CB5C1F5-4B20-43EF-B5F6-1C0C2C07B803}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=OXT-Beyond contributors
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
AppComments=xTalk IDE, continuing OpenXTalk Lite by Terry Little, Tom Perry and the OpenXTalk contributors, based on LiveCode Community.
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExeName}
; The engine and all externals are 64-bit (x64). x64compatible also admits
; Windows 11 on Arm64, which runs x64 programs.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
LicenseFile={#StageDir}\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename={#AppName}-{#AppVersion}-win-x86_64-setup
SetupIconFile={#SetupIcon}
WizardStyle=modern
#ifdef WizardImageFile
WizardImageFile={#WizardImageFile}
#endif
#ifdef WizardSmallImageFile
WizardSmallImageFile={#WizardSmallImageFile}
#endif
Compression=lzma2/max
SolidCompression=yes
; Compress two blocks of the solid stream in parallel (each block also uses
; two match-finder threads); the compressor runs as a separate 64-bit process.
LZMANumBlockThreads=2
LZMAUseSeparateProcess=yes
ChangesAssociations=yes
; Always write a Setup log to %TEMP%, for bug reports.
SetupLogging=yes
VersionInfoVersion={#NumericVersion}
VersionInfoProductVersion={#NumericVersion}
VersionInfoTextVersion={#AppVersion}
VersionInfoProductTextVersion={#AppVersion} (build {#BuildNumber})
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} Setup
VersionInfoCompany=OXT-Beyond contributors

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "fileassoc"; Description: "Open .oxtstack and .oxtscript files with {#AppName}"; GroupDescription: "File associations:"

[InstallDelete]
; When a new version is installed over an older one, remove the program
; folders that the IDE and engine load by listing their contents (every
; palette and library under Toolset, every extension under Extensions,
; every external under Externals), so files that a newer version no longer
; ships are not picked up. These folders hold program files only: the IDE
; keeps user extensions, plugins and preferences in the user's own folders.
Type: filesandordirs; Name: "{app}\Toolset"
Type: filesandordirs; Name: "{app}\Extensions"
Type: filesandordirs; Name: "{app}\Externals"
Type: filesandordirs; Name: "{app}\Toolchain"
Type: filesandordirs; Name: "{app}\Runtime"

[Dirs]
; The IDE writes to these places inside the program folder at run time.
; An install for all users goes to Program Files, where standard users
; cannot write, so the Users group gets Modify on them. They hold text data
; only; no folder or file with scripts, stacks or binaries is made writable.
;
; Dictionary (Documentation/html_viewer/resources/data/api/oxt_dictionary.oxtstack):
; every time it opens, tRegenerateIndex deletes and rewrites
; exports/<xtalk|builder|datagrid>/index.txt and creates
; exports/<...>/plugins if it is missing; the entry and plugin files under
; exports are read with "open file" without a mode, which opens them for
; update (read and write), so reading an entry also needs write access.
Name: "{app}\Documentation\html_viewer\resources\data\api\exports"; Permissions: users-modify

[Files]
; The whole staged layout, including the two empty dictionary plugin
; folders. The files listed in Excludes are installed by the entries below,
; with extra permissions. (.buildnumber needs none: revmenubar reads it with
; url "binfile:", which does not open it for writing.)
Source: "{#StageDir}\*"; DestDir: "{app}"; Excludes: "\Toolset\palettes\updates\whatsnew.txt,\Toolset\palettes\updates\updatehistory\*.txt"; Flags: ignoreversion recursesubdirs createallsubdirs
; Opened in update mode by the Preferences window (readLastUpd in
; revpreferencesgui.rev) and by Help > Release Notes
; (Toolset/palettes/updates/ReleaseNotes.oxtstack).
Source: "{#StageDir}\Toolset\palettes\updates\whatsnew.txt"; DestDir: "{app}\Toolset\palettes\updates"; Flags: ignoreversion skipifsourcedoesntexist; Permissions: users-modify
Source: "{#StageDir}\Toolset\palettes\updates\updatehistory\*.txt"; DestDir: "{app}\Toolset\palettes\updates\updatehistory"; Flags: ignoreversion skipifsourcedoesntexist; Permissions: users-modify

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Comment: "Start the {#AppName} IDE"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Comment: "Start the {#AppName} IDE"; Tasks: desktopicon

[Registry]
; File associations, in HKLM (install for all users) or HKCU (install for
; the current user) through HKA. The programmatic identifiers are our own
; (OXTBeyond.*), so they do not collide with the OXTStack identifier that
; the OpenXTalk Lite IDE registers for itself. Icon 1 of the executable is
; the document icon (engine/rsrc/development.rc).
Root: HKA; Subkey: "Software\Classes\.oxtstack"; ValueType: string; ValueName: ""; ValueData: "OXTBeyond.Stack"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\.oxtstack\OpenWithProgids"; ValueType: string; ValueName: "OXTBeyond.Stack"; ValueData: ""; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OXTBeyond.Stack"; ValueType: string; ValueName: ""; ValueData: "{#AppName} Stack"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OXTBeyond.Stack\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},1"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OXTBeyond.Stack\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\.oxtscript"; ValueType: string; ValueName: ""; ValueData: "OXTBeyond.Script"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\.oxtscript\OpenWithProgids"; ValueType: string; ValueName: "OXTBeyond.Script"; ValueData: ""; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OXTBeyond.Script"; ValueType: string; ValueName: ""; ValueData: "{#AppName} Script-Only Stack"; Flags: uninsdeletekey; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OXTBeyond.Script\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},1"; Tasks: fileassoc
Root: HKA; Subkey: "Software\Classes\OXTBeyond.Script\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Tasks: fileassoc
; "Open with" support for both types, whether or not the task is selected.
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".oxtstack"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".oxtscript"; ValueData: ""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

; [UninstallDelete] is not used. The IDE creates nothing inside the program
; folder that Setup did not install: the dictionary's index.txt files and
; plugins folders are installed (and removed) by Setup, and preferences,
; caches, logs and user extensions live in the user's own folders.
; Dictionary entries a user adds under exports\<...>\plugins are the user's
; data and are left in place.
