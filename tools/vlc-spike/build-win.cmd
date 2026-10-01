@echo off
rem Builds vlcspike.exe with the Visual Studio 2022 x64 compiler.
setlocal
rem vcvars64.bat needs where, reg and findstr from System32.
set "PATH=%SystemRoot%\System32;%SystemRoot%;%PATH%"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq delims=" %%i in (`call "%VSWHERE%" -latest -products * -property installationPath`) do set "VSDIR=%%i"
if not exist "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" (
  echo Visual Studio with the C++ tools was not found.
  exit /b 1
)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /O2 /W3 /D_CRT_SECURE_NO_WARNINGS vlcspike.c advapi32.lib
