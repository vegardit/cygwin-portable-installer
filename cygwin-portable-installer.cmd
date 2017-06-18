@echo off
::
:: Copyright (c) 2017 Vegard IT GmbH, http://vegardit.com
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::      http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.
::
:: @author Sebastian Thomschke, Vegard IT GmbH

:: ABOUT
:: =====
:: This self-contained Windows batch file creates a portable Cygwin (https://cygwin.com/mirrors.html) installation.
:: By default it automatically installs :
:: - apt-cyg (a cygwin command-line package manager, see https://github.com/transcode-open/apt-cyg) and
:: - bash-funk (a Bash toolbox and adaptive Bash prompt, see https://github.com/vegardit/bash-funk)

:: You can customize the following variables to your needs before running the batch file:

:: choose a user name under Cygwin
set CYGWIN_USERNAME=root

:: change the URL to the closest mirror https://cygwin.com/mirrors.html
set CYGWIN_MIRROR=http://ftp.inf.tu-dresden.de/software/windows/cygwin32

:: select the packages to be installed automatically via apt-cyg
set CYGWIN_PACKAGES=bash-completion,bc,curl,expect,git,git-svn,gnupg,inetutils,mc,nc,openssh,openssl,perl,python,subversion,unzip,vim,zip

:: if set to 'yes' the apt-cyg command line package manager (https://github.com/transcode-open/apt-cyg) will be installed automatically
set INSTALL_APT_CYG=yes

:: if set to 'yes' the bash-funk adaptive Bash prompt (https://github.com/vegardit/bash-funk) will be installed automatically
set INSTALL_BASH_FUNK=yes

:: add more path if required, but at the cost of runtime performance (e.g. slower forks)
set CYGWIN_PATH=%%SystemRoot%%\system32;%%SystemRoot%%

:: set proxy if required (unfortunately Cygwin setup.exe does not have commandline options to specify proxy user credentials)
set PROXY_HOST=
set PROXY_PORT=8080

:: set mintty options, see https://cdn.rawgit.com/mintty/mintty/master/docs/mintty.1.html#CONFIGURATION
set MINTTY_OPTIONS=--Title cygwin-portable ^
  -o Columns=160 ^
  -o Rows=50 ^
  -o BellType=0 ^
  -o ClicksPlaceCursor=yes ^
  -o CursorBlinks=yes ^
  -o CursorColour=96,96,255 ^
  -o CursorType=Block ^
  -o CopyOnSelect=yes ^
  -o RightClickAction=Paste ^
  -o Font="Courier New" ^
  -o FontHeight=10 ^
  -o FontSmoothing=None ^
  -o ScrollbackLines=10000 ^
  -o Transparency=off ^
  -o Term=xterm-256color ^
  -o Charset=UTF-8 ^
  -o Locale=C


echo.
echo ###########################################################
echo # Installing [Cygwin Portable]...
echo ###########################################################
echo.

set CYGWIN_ROOT=%~dp0cygwin
if not exist "%CYGWIN_ROOT%" (
    md "%CYGWIN_ROOT%"
)

:: create VB script that can download files
:: not using PowerShell which may be blocked by group policies
set DOWNLOADER=%~dp0downloader.vbs
echo Creating [%DOWNLOADER%] script...
if "%PROXY_HOST%" == "" (
    set DOWNLOADER_PROXY=.
) else (
    set DOWNLOADER_PROXY= req.SetProxy 2, "%PROXY_HOST%:%PROXY_PORT%", ""
)

(
    echo url = Wscript.Arguments(0^)
    echo target = Wscript.Arguments(1^)
    echo WScript.Echo "Downloading '" ^& url ^& "' to '" ^& target ^& "'..."
    echo Set req = CreateObject("WinHttp.WinHttpRequest.5.1"^)
    echo%DOWNLOADER_PROXY%
    echo req.Open "GET", url, False
    echo req.Send
    echo If req.Status ^<^> 200 Then
    echo    WScript.Echo "FAILED to download: HTTP Status " ^& req.Status
    echo    WScript.Quit 1
    echo End If
    echo Set buff = CreateObject("ADODB.Stream"^)
    echo buff.Open
    echo buff.Type = 1
    echo buff.Write req.ResponseBody
    echo buff.Position = 0
    echo buff.SaveToFile target
    echo buff.Close
    echo.
) >"%DOWNLOADER%" || goto :fail

:: download Cygwin 32 or 64 setup exe

if "%PROCESSOR_ARCHITEW6432%" == "AMD64" (
    set CYGWIN_SETUP=setup-x86_64.exe
) else (
    if "%PROCESSOR_ARCHITECTURE%" == "x86" (
        set CYGWIN_SETUP=setup-x86.exe )
    else (
        set CYGWIN_SETUP=setup-x86_64.exe
    )
)

if exist "%CYGWIN_ROOT%\%CYGWIN_SETUP%" (
    del "%CYGWIN_ROOT%\%CYGWIN_SETUP%" || goto :fail
)
cscript //Nologo %DOWNLOADER% http://cygwin.org/%CYGWIN_SETUP% "%CYGWIN_ROOT%\%CYGWIN_SETUP%" || goto :fail
del "%DOWNLOADER%"

:: Cygwin command line options: https://cygwin.com/faq/faq.html#faq.setup.cli
if "%PROXY_HOST%" == "" (
    set CYGWIN_PROXY=
) else (
    set CYGWIN_PROXY=--proxy "%PROXY_HOST%:%PROXY_PORT%"
)

echo Running Cygwin setup...
"%CYGWIN_ROOT%\%CYGWIN_SETUP%" --no-admin ^
 --arch x86_64 ^
 --site http://ftp.inf.tu-dresden.de/software/windows/cygwin32 %CYGWIN_PROXY% ^
 --root "%CYGWIN_ROOT%" ^
 --local-package-dir "%CYGWIN_ROOT%-pkg-cache" ^
 --no-shortcuts ^
 --no-desktop ^
 --delete-orphans ^
 --upgrade-also ^
 --no-replaceonreboot ^
 --quiet-mode ^
 --packages dos2unix,mintty,wget,%CYGWIN_PACKAGES% || goto :fail

set Cygwin_bat=%CYGWIN_ROOT%\Cygwin.bat
if exist "%Cygwin_bat%" (
    echo Disabling [%Cygwin_bat%]...
    if exist "%Cygwin_bat%.disabled" (
        del "%Cygwin_bat%.disabled" || goto :fail
    )
    rename %Cygwin_bat% Cygwin.bat.disabled || goto :fail
)

:configure

set Init_sh=%CYGWIN_ROOT%\portable-init.sh
echo Creating [%Init_sh%]...
(
    echo #!/usr/bin/env bash
    echo.
    echo #
    echo # Map Current Windows User to root user
    echo #
    echo.
    echo # Check if current Windows user is in /etc/passwd
    echo USER_SID="$(mkpasswd -c | cut -d':' -f 5)"
    echo if ! grep -F "$USER_SID" /etc/passwd ^&^>/dev/null; then
    echo     echo "Mapping Windows user '$USER_SID' to cygwin '$USERNAME' in /etc/passwd..."
    echo     GID="$(mkpasswd -c | cut -d':' -f 4)"
    echo     echo $USERNAME:unused:1001:$GID:$USER_SID:$HOME:/bin/bash ^>^> /etc/passwd
    echo fi
    echo.
    echo #
    echo # disable Cygwin's - apparently broken - special ACL treatment which prevents apt-cyg and other programs from working
    echo #
    echo sed -i -e "s/cygdrive binary,posix/cygdrive binary,noacl,posix/" /etc/fstab
    echo mount -a
    echo.
    echo #
    echo # adjust Cygwin packages cache path
    echo #
    echo pkg_cache_dir=$(cygpath -w "$(cygpath -w /)/../cygwin-pkg-cache"^)
    echo sed -i -E "s/.*\\\cygwin-pkg-cache/        ${pkg_cache_dir//\\/\\\\}/" /etc/setup/setup.rc
    echo.
    if "%INSTALL_APT_CYG%" == "yes" (
        echo #
        echo # Installing apt-cyg package manager if required
        echo #
        echo if ! [[ -x /usr/local/bin/apt-cyg ]]; then
        if not "%PROXY_HOST%" == "" (
            echo     # temporary proxy settings during initial installation
            echo     export http_proxy=http://%PROXY_HOST%:%PROXY_PORT%
            echo     export https_proxy=$http_proxy
        )
        echo     echo "Installing apt-cyg..."
        echo     wget -O /usr/local/bin/apt-cyg https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg
        echo     chmod +x /usr/local/bin/apt-cyg
        echo fi
        echo.
    )
    if "%INSTALL_BASH_FUNK%" == "yes" (
        echo.
        echo #
        echo # Installing bash-funk if required
        echo #
        echo if [[ ! -e /opt/bash-funk/bash-funk.sh ]]; then
        if not "%PROXY_HOST%" == "" (
            echo   # temporary proxy settings during initial installation
            echo   export http_proxy=http://%PROXY_HOST%:%PROXY_PORT%
            echo   export https_proxy=$http_proxy
        )
        echo   echo Installing [bash-funk]...
        echo   if hash git ^&^>/dev/null; then
        echo     git clone https://github.com/vegardit/bash-funk --branch master --single-branch /opt/bash-funk
        echo   elif hash svn ^&^>/dev/null; then
        echo     svn checkout https://github.com/vegardit/bash-funk/trunk /opt/bash-funk
        echo   else
        echo     mkdir /opt/bash-funk ^&^& \
        echo     cd /opt/bash-funk ^&^& \
        echo     wget -qO- --show-progress https://github.com/vegardit/bash-funk/tarball/master ^| tar -xzv --strip-components 1
        echo   fi
        echo fi
    )
) >"%Init_sh%" || goto :fail
"%CYGWIN_ROOT%\bin\dos2unix" "%Init_sh%" || goto :fail

set Start_cmd=%~dp0cygwin-portable.cmd
echo Creating [%Start_cmd%]...
(
    echo @echo off
    echo set CWD="%%cd%%"
    echo set CYGWIN_DRIVE=%%~d0
    echo set CYGWIN_ROOT=%%~dp0cygwin
    echo.
    echo set PATH=%%CYGWIN_ROOT%%\bin;%CYGWIN_PATH%
    echo set ALLUSERSPROFILE=%%CYGWIN_ROOT%%.ProgramData
    echo set ProgramData=%%ALLUSERSPROFILE%%
    echo set CYGWIN=nodosfilewarning
    echo.
    echo set USERNAME=%CYGWIN_USERNAME%
    echo set HOME=/home/%%USERNAME%%
    echo set SHELL=/bin/bash
    echo set HOMEDRIVE=%%CYGWIN_DRIVE%%
    echo set HOMEPATH=%%CYGWIN_ROOT%%\home\%%USERNAME%%
    echo set GROUP=None
    echo set GRP=
    echo.
    echo %%CYGWIN_DRIVE%%
    echo chdir "%%CYGWIN_ROOT%%\bin"
    echo bash "%%CYGWIN_ROOT%%\portable-init.sh"
    echo.
    echo if "%%1" == "" (
    echo   mintty --nopin %MINTTY_OPTIONS% --icon %CYGWIN_ROOT%\Cygwin-Terminal.ico -
    echo ^) else (
    echo   if "%%1" == "no-mintty" (
    echo     bash --login -i
    echo   ^) else (
    echo     bash --login -c %%*
    echo   ^)
    echo ^)
    echo.
    echo cd "%%cwd%%"
) >"%Start_cmd%" || goto :fail

:: launching bash once to initialize user home dir
call %Start_cmd% whoami

set Bashrc_sh=%CYGWIN_ROOT%\home\%CYGWIN_USERNAME%\.bashrc

if not "%PROXY_HOST%" == "" (
    echo Adding proxy settings for host [%COMPUTERNAME%] to [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "export http_proxy" "%Bashrc_sh%" >NUL || (
        echo.
        echo if [[ $HOSTMAME == "%COMPUTERNAME%" ]]; then
        echo     export http_proxy=http://%PROXY_HOST%:%PROXY_PORT%
        echo     export https_proxy=$http_proxy
        echo     export no_proxy="::1,127.0.0.1,localhost,169.254.169.254,%COMPUTERNAME%,*.%USERDNSDOMAIN%"
        echo     export HTTP_PROXY=$http_proxy
        echo     export HTTPS_PROXY=$http_proxy
        echo     export NO_PROXY=$no_proxy
        echo fi
    ) >>"%Bashrc_sh%" || goto :fail
)
if "%INSTALL_BASH_FUNK%" == "yes" (
    echo Adding bash-funk to [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "bash-funk" "%Bashrc_sh%" >NUL || (
        (
            echo.
            echo source /opt/bash-funk/bash-funk.sh
        ) >>"%Bashrc_sh%" || goto :fail
        "%CYGWIN_ROOT%\bin\dos2unix" "%Bashrc_sh%" || goto :fail
    )
)
"%CYGWIN_ROOT%\bin\dos2unix" "%Bashrc_sh%" || goto :fail

echo.
echo ###########################################################
echo # Installing [Cygwin Portable] succeeded.
echo ###########################################################
echo.
echo Use [%Start_cmd%] to launch Cygwin Portable.
echo.
pause
goto :eof

:fail
    if exist "%DOWNLOADER%" (
        del "%DOWNLOADER%"
    )
    echo.
    echo ###########################################################
    echo #Installing [Cygwin Portable] FAILED!
    echo ###########################################################
    echo.
    pause
    exit /b 1
