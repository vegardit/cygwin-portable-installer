@echo off

::
:: Copyright 2017-2020 by Vegard IT GmbH (https://vegardit.com) and the cygwin-portable-installer contributors.
:: SPDX-License-Identifier: Apache-2.0
::
:: @author Sebastian Thomschke, Vegard IT GmbH


:: ABOUT
:: =====
:: This self-contained Windows batch file creates a portable Cygwin (https://cygwin.com/mirrors.html) installation.
:: By default it automatically installs :
:: - apt-cyg (cygwin command-line package manager, see https://github.com/kou1okada/apt-cyg)
:: - bash-funk (Bash toolbox and adaptive Bash prompt, see https://github.com/vegardit/bash-funk)
:: - ConEmu (multi-tabbed terminal, https://conemu.github.io/)
:: - Ansible (deployment automation tool, see https://github.com/ansible/ansible)
:: - AWS CLI (AWS cloud command line tool, see https://github.com/aws/aws-cli)
:: - testssl.sh (command line tool to check SSL/TLS configurations of servers, see https://testssl.sh/)

:: if executed with "--debug" print all executed commands
if [%1]==[--debug] echo on


:: ============================================================================================================
:: CONFIG CUSTOMIZATION START
:: ============================================================================================================

:: You can customize the following variables to your needs before running the batch file:

:: set proxy if required (unfortunately Cygwin setup.exe does not have commandline options to specify proxy user credentials)
set PROXY_HOST=
set PROXY_PORT=8080

:: change the URL to the closest mirror https://cygwin.com/mirrors.html
set CYGWIN_MIRROR=https://linux.rz.ruhr-uni-bochum.de/download/cygwin

:: one of: auto,64,32 - specifies if 32 or 64 bit version should be installed or automatically detected based on current OS architecture
set CYGWIN_ARCH=auto

:: choose a user name under Cygwin
set CYGWIN_USERNAME=root

:: select the packages to be installed automatically via apt-cyg
set CYGWIN_PACKAGES=bash-completion,bc,curl,expect,git,git-svn,gnupg,inetutils,lz4,mc,nc,openssh,openssl,perl,psmisc,python37,pv,rsync,ssh-pageant,screen,subversion,unzip,vim,wget,zip,zstd

:: if set to 'yes' the local package cache created by cygwin setup will be deleted after installation/update
set DELETE_CYGWIN_PACKAGE_CACHE=no

:: if set to 'yes' the apt-cyg command line package manager (https://github.com/kou1okada/apt-cyg) will be installed automatically
set INSTALL_APT_CYG=yes

:: if set to 'yes' the bash-funk adaptive Bash prompt (https://github.com/vegardit/bash-funk) will be installed automatically
set INSTALL_BASH_FUNK=yes

:: if set to 'yes' Node.js (https://nodejs.org/) will be installed automatically
set INSTALL_NODEJS=yes
:: Use of the folder names found here https://nodejs.org/dist/ as version name.
set NODEJS_VERSION=latest-v12.x
:: one of: auto,64,32 - specifies if 32 or 64 bit version should be installed or automatically detected based on current OS architecture
set NODEJS_ARCH=auto

:: if set to 'yes' Ansible (https://github.com/ansible/ansible) will be installed automatically
set INSTALL_ANSIBLE=yes
set ANSIBLE_GIT_BRANCH=stable-2.9

:: if set to 'yes' AWS CLI (https://github.com/aws/aws-cli) will be installed automatically
set INSTALL_AWS_CLI=yes

:: if set to 'yes' testssl.sh (https://testssl.sh/) will be installed automatically
set INSTALL_TESTSSL_SH=yes
:: name of the GIT branch to install from, see https://github.com/drwetter/testssl.sh/
set TESTSSL_GIT_BRANCH=3.0

:: use ConEmu based tabbed terminal instead of Mintty based single window terminal, see https://conemu.github.io/
set INSTALL_CONEMU=yes
set CON_EMU_OPTIONS=-Title cygwin-portable ^
 -QuitOnClose

:: add more path if required, but at the cost of runtime performance (e.g. slower forks)
set "CYGWIN_PATH=%%SystemRoot%%\system32;%%SystemRoot%%"

:: set Mintty options, see https://cdn.rawgit.com/mintty/mintty/master/docs/mintty.1.html#CONFIGURATION
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

:: ============================================================================================================
:: CONFIG CUSTOMIZATION END
:: ============================================================================================================

echo.
echo ###########################################################
echo # Installing [Cygwin Portable]...
echo ###########################################################
echo.

set "INSTALL_ROOT=%~dp0"

:: load customizations from separate file if exists
set "custom_config_file=%INSTALL_ROOT%cygwin-portable-installer-config.cmd"
if exist "%custom_config_file%" (
  echo Loading configuration from [%custom_config_file%]...
  call "%custom_config_file%"
)

set "CYGWIN_ROOT=%INSTALL_ROOT%cygwin"
if not exist "%CYGWIN_ROOT%" (
    echo Creating Cygwin root [%CYGWIN_ROOT%]...
    md "%CYGWIN_ROOT%" || goto :fail
) else (
    echo Granting user [%USERNAME%] full access to Cygwin root [%CYGWIN_ROOT%]...
    icacls "%CYGWIN_ROOT%" /T /grant "%USERNAME%:(CI)(OI)(F)"
)


:: https://blogs.msdn.microsoft.com/david.wang/2006/03/27/howto-detect-process-bitness/
if "%CYGWIN_ARCH%" == "auto" (
    if "%PROCESSOR_ARCHITECTURE%" == "x86" (
        if defined PROCESSOR_ARCHITEW6432 (
            set CYGWIN_ARCH=64
        ) else (
            set CYGWIN_ARCH=32
        )
    ) else (
        set CYGWIN_ARCH=64
    )
)

:: download Cygwin 32 or 64 setup exe depending on detected architecture
if "%CYGWIN_ARCH%" == "64" (
    set CYGWIN_SETUP_EXE=setup-x86_64.exe
) else (
    set CYGWIN_SETUP_EXE=setup-x86.exe
)
call :download "https://cygwin.org/%CYGWIN_SETUP_EXE%" "%CYGWIN_ROOT%\%CYGWIN_SETUP_EXE%"

:: Cygwin command line options: https://cygwin.com/faq/faq.html#faq.setup.cli
if "%PROXY_HOST%" == "" (
    set CYGWIN_PROXY=
) else (
    set CYGWIN_PROXY=--proxy "%PROXY_HOST%:%PROXY_PORT%"
)

if "%INSTALL_APT_CYG%" == "yes" (
   set CYGWIN_PACKAGES=wget,ca-certificates,gnupg,%CYGWIN_PACKAGES%
)

:: https://blogs.msdn.microsoft.com/david.wang/2006/03/27/howto-detect-process-bitness/
if "%INSTALL_NODEJS%" == "yes" (
    set CYGWIN_PACKAGES=unzip,%CYGWIN_PACKAGES%

    if "%NODEJS_ARCH%" == "auto" (
        if "%PROCESSOR_ARCHITECTURE%" == "x86" (
            if defined PROCESSOR_ARCHITEW6432 (
                set NODEJS_ARCH=64
            ) else (
                set NODEJS_ARCH=86
            )
        ) else (
            set NODEJS_ARCH=64
        )
    ) else if "%NODEJS_ARCH%" == "32" (
        set NODEJS_ARCH=86
    )
)

if "%INSTALL_ANSIBLE%" == "yes" (
    set CYGWIN_PACKAGES=git,openssh,python37,python37-jinja2,python37-six,python37-yaml,%CYGWIN_PACKAGES%
)

if "%INSTALL_AWS_CLI%" == "yes" (
   set CYGWIN_PACKAGES=python37,%CYGWIN_PACKAGES%
)

:: if conemu install is selected we need to be able to extract 7z archives, otherwise we need to install mintty
if "%INSTALL_CONEMU%" == "yes" (
    set CYGWIN_PACKAGES=bsdtar,%CYGWIN_PACKAGES%
) else (
    set CYGWIN_PACKAGES=mintty,%CYGWIN_PACKAGES%
)

if "%INSTALL_TESTSSL_SH%" == "yes" (
    set CYGWIN_PACKAGES=bind-utils,%CYGWIN_PACKAGES%
)


echo Running Cygwin setup...
"%CYGWIN_ROOT%\%CYGWIN_SETUP_EXE%" --no-admin ^
 --site %CYGWIN_MIRROR% %CYGWIN_PROXY% ^
 --root "%CYGWIN_ROOT%" ^
 --local-package-dir "%CYGWIN_ROOT%\.pkg-cache" ^
 --no-shortcuts ^
 --no-desktop ^
 --delete-orphans ^
 --upgrade-also ^
 --no-replaceonreboot ^
 --quiet-mode ^
 --packages dos2unix,wget,%CYGWIN_PACKAGES% || goto :fail

if "%DELETE_CYGWIN_PACKAGE_CACHE%" == "yes" (
    rd /s /q "%CYGWIN_ROOT%\.pkg-cache"
)

set "Updater_cmd=%INSTALL_ROOT%cygwin-portable-updater.cmd"
echo Creating updater [%Updater_cmd%]...
(
    echo @echo off
    echo set "CYGWIN_ROOT=%%~dp0cygwin"
    echo.
    echo echo.
    echo echo ###########################################################
    echo echo # Updating [Cygwin Portable]...
    echo echo ###########################################################
    echo.
    echo echo Granting user [%%USERNAME%%] full access to [%%CYGWIN_ROOT%%]...
    echo icacls "%%CYGWIN_ROOT%%" /T /grant "%%USERNAME%%:(CI)(OI)(F)"
    echo.
    echo "%%CYGWIN_ROOT%%\%CYGWIN_SETUP_EXE%" --no-admin ^^
    echo --site %CYGWIN_MIRROR% %CYGWIN_PROXY% ^^
    echo --root "%%CYGWIN_ROOT%%" ^^
    echo --local-package-dir "%%CYGWIN_ROOT%%\.pkg-cache" ^^
    echo --no-shortcuts ^^
    echo --no-desktop ^^
    echo --delete-orphans ^^
    echo --upgrade-also ^^
    echo --no-replaceonreboot ^^
    echo --quiet-mode ^|^| goto :fail
    if "%DELETE_CYGWIN_PACKAGE_CACHE%" == "yes" (
        echo rd /s /q "%%CYGWIN_ROOT%%\.pkg-cache"
    )
    echo.
    echo echo.
    echo echo ###########################################################
    echo echo # Updating [Cygwin Portable] succeeded.
    echo echo ###########################################################
    echo timeout /T 60
    echo goto :eof
    echo.
    echo :fail
    echo echo.
    echo echo ###########################################################
    echo echo # Updating [Cygwin Portable] FAILED!
    echo echo ###########################################################
    echo timeout /T 60
    echo exit /1
) >"%Updater_cmd%" || goto :fail

set "Cygwin_bat=%CYGWIN_ROOT%\Cygwin.bat"
if exist "%Cygwin_bat%" (
    echo Disabling default Cygwin launcher [%Cygwin_bat%]...
    if exist "%Cygwin_bat%.disabled" (
        del "%Cygwin_bat%.disabled" || goto :fail
    )
    rename "%Cygwin_bat%" Cygwin.bat.disabled || goto :fail
)

set "Init_sh=%CYGWIN_ROOT%\portable-init.sh"
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
    echo cp -rnv /etc/skel/. /home/$USERNAME
    echo.
    echo # already set in cygwin-portable.cmd:
    echo # export CYGWIN_ROOT=$(cygpath -w /^)
    echo.
    echo #
    echo # adjust Cygwin packages cache path
    echo #
    echo pkg_cache_dir=$(cygpath -w "$CYGWIN_ROOT/.pkg-cache"^)
    echo sed -i -E "s/.*\\\.pkg-cache/"$'\t'"${pkg_cache_dir//\\/\\\\}/" /etc/setup/setup.rc
    echo.
    echo #
    echo # Make python3 available as python if python2 is not installed
    echo #
    echo python3=$(/usr/bin/find /usr/bin -maxdepth 1 -name "python3.*" -print -quit ^| head -1^)
    echo if [[ -e $python3 ]] ^> /dev/null; then
    echo     [[ -e /usr/bin/python3 ]] ^|^| /usr/sbin/update-alternatives --install /usr/bin/python3 python3 "$python3" 1
    echo     [[ -e /usr/bin/python  ]] ^|^| /usr/sbin/update-alternatives --install /usr/bin/python  python  "$python3" 1
    echo fi
    echo.
    if not "%PROXY_HOST%" == "" (
        echo if [[ $HOSTNAME == "%COMPUTERNAME%" ]]; then
        echo     export http_proxy=http://%PROXY_HOST%:%PROXY_PORT%
        echo     export https_proxy=$http_proxy
        echo fi
    )
    if "%INSTALL_CONEMU%" == "yes" (
        echo #
        echo # Installing conemu if required
        echo #
        echo conemu_dir=$(cygpath -w "$CYGWIN_ROOT/../conemu"^)
        echo if [[ ! -e $conemu_dir ]]; then
        echo     echo "*******************************************************************************"
        echo     echo "* Installing ConEmu..."
        echo     echo "*******************************************************************************"
        echo     conemu_url="https://github.com$(wget https://github.com/Maximus5/ConEmu/releases/latest -O - 2>/dev/null | egrep '/.*/releases/download/.*/.*7z' -o)" ^&^& \
        echo     echo "Download URL=$conemu_url" ^&^& \
        echo     wget -O "${conemu_dir}.7z" $conemu_url ^&^& \
        echo     mkdir "$conemu_dir" ^&^& \
        echo     bsdtar -xvf "${conemu_dir}.7z" -C "$conemu_dir" ^&^& \
        echo     rm "${conemu_dir}.7z"
        echo fi
    )
    if "%INSTALL_ANSIBLE%" == "yes" (
        echo.
        echo #
        echo # Installing Ansible if not yet installed
        echo #
        echo if [[ ! -e /opt/ansible ]]; then
        echo     echo "*******************************************************************************"
        echo     echo "* Installing [Ansible - %ANSIBLE_GIT_BRANCH%]..."
        echo     echo "*******************************************************************************"
        echo     [[ -e /opt ]] ^|^| mkdir /opt
        echo     git clone https://github.com/ansible/ansible --branch %ANSIBLE_GIT_BRANCH% --single-branch --depth 1 --shallow-submodules /opt/ansible
        echo fi
        echo.
    )
    if "%INSTALL_AWS_CLI%" == "yes" (
        echo.
        echo #
        echo # Installing AWS CLI if not yet installed
        echo #
        echo if ! hash aws 2^>/dev/null; then
        echo     echo "*******************************************************************************"
        echo     echo "* Installing [AWS CLI]..."
        echo     echo "*******************************************************************************"
        echo     export PYTHONHOME=/usr
        echo     python3 -m ensurepip --default-pip
        echo     pip3 install --upgrade pip
        echo     pip3 install --upgrade awscli
        echo fi
        echo.
    )
    if "%INSTALL_APT_CYG%" == "yes" (
        echo #
        echo # Installing apt-cyg package manager if not yet installed
        echo #
        echo if [[ ! -x /usr/local/bin/apt-cyg ]]; then
        echo     echo "*******************************************************************************"
        echo     echo "* Installing apt-cyg..."
        echo     echo "*******************************************************************************"
        echo     wget -O /usr/local/bin/apt-cyg https://raw.githubusercontent.com/kou1okada/apt-cyg/master/apt-cyg
        echo     chmod +x /usr/local/bin/apt-cyg
        echo fi
        echo.
    )
    if "%INSTALL_BASH_FUNK%" == "yes" (
        echo.
        echo #
        echo # Installing bash-funk if not yet installed
        echo #
        echo if [[ ! -e /opt/bash-funk/bash-funk.sh ]]; then
        echo     echo "*******************************************************************************"
        echo     echo "* Installing [bash-funk]..."
        echo     echo "*******************************************************************************"
        echo     [[ -e /opt ]] ^|^| mkdir /opt
        echo     if hash git ^&^>/dev/null; then
        echo         git clone https://github.com/vegardit/bash-funk --branch master --single-branch --depth 1 --shallow-submodules /opt/bash-funk
        echo     elif hash svn ^&^>/dev/null; then
        echo         svn checkout https://github.com/vegardit/bash-funk/trunk /opt/bash-funk
        echo     else
        echo         mkdir /opt/bash-funk ^&^& \
        echo         cd /opt/bash-funk ^&^& \
        echo         wget -qO- --show-progress https://github.com/vegardit/bash-funk/tarball/master ^| tar -xzv --strip-components 1
        echo     fi
        echo fi
    )
    if "%INSTALL_NODEJS%" == "yes" (
        echo #
        echo # Installing NodeJS if not yet installed
        echo #
        REM TODO requires gcc-g++, git, python
        REM echo export NVM_DIR=/opt/nvm
        REM echo if [[ ! -e $NVM_DIR ]]; then
        REM echo     nvm_version=$^(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest ^| grep -Po 'tag_name": "\Kv[0-9.]+'^)
        REM echo     mkdir /opt/nvm
        REM echo     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh ^| bash
        REM echo fi
        echo if [[ ! -e /opt/nodejs/current ]]; then
        echo     nodejs_ver=%NODEJS_VERSION%
        echo     if [[ $nodejs_ver == latest* ]]; then
        echo         nodejs_ver=$^(curl -s https://nodejs.org/dist/$nodejs_ver/ ^| grep -oP 'node-^(\K[v0-9.]+[0-9]^)' ^| head -n1^)
        echo     fi
        echo     node_js_root="/opt/nodejs/node-${nodejs_ver}-win-x%NODEJS_ARCH%"
        echo     echo "*******************************************************************************"
        echo     echo "* Installing [Node.js]..."
        echo     echo "*******************************************************************************"
        echo     curl https://nodejs.org/dist/${nodejs_ver}/node-${nodejs_ver}-win-x%NODEJS_ARCH%.zip -o nodejs.zip
        echo     mkdir -p /opt/nodejs
        echo     echo "Extracting Node.js $nodejs_ver to '$node_js_root'..."
        echo     unzip -q -d /opt/nodejs/ nodejs.zip
        echo     rm -f nodejs.zip
        echo     rm -f /opt/nodejs/current
        echo     ln -s $node_js_root /opt/nodejs/current
        echo     chmod 755 /opt/nodejs/current/node.exe
        echo     chmod 755 /opt/nodejs/current/npm
        echo     chmod 755 /opt/nodejs/current/npx
        echo fi
    )
    if "%INSTALL_TESTSSL_SH%" == "yes" (
        echo.
        echo #
        echo # Installing testssl.sh if not yet installed
        echo #
        echo if [[ ! -e /opt/testssl/testssl.sh ]]; then
        echo     echo "*******************************************************************************"
        echo     echo "* Installing [testssl.sh - %TESTSSL_GIT_BRANCH%]..."
        echo     echo "*******************************************************************************"
        echo     [[ -e /opt ]] ^|^| mkdir /opt
        echo     if hash git ^&^>/dev/null; then
        echo         git clone https://github.com/drwetter/testssl.sh --branch %TESTSSL_GIT_BRANCH% --single-branch --depth 1 --shallow-submodules /opt/testssl
        echo     elif hash svn ^&^>/dev/null; then
        echo         svn checkout https://github.com/drwetter/testssl.sh/tags/%TESTSSL_GIT_BRANCH% /opt/testssl
        echo     else
        echo         mkdir /opt/testssl ^&^& \
        echo         cd /opt/testssl ^&^& \
        echo         wget -qO- --show-progress https://github.com/drwetter/testssl.sh/tarball/%TESTSSL_GIT_BRANCH% ^| tar -xzv --strip-components 1
        echo     fi
        echo     chmod +x /opt/testssl/testssl.sh
        echo fi
    )

) >"%Init_sh%" || goto :fail
"%CYGWIN_ROOT%\bin\dos2unix" "%Init_sh%" || goto :fail

set "Start_cmd=%INSTALL_ROOT%cygwin-portable.cmd"
echo Creating launcher [%Start_cmd%]...
(
    echo @echo off
    echo setlocal enabledelayedexpansion
    echo set "CWD=%%cd%%"
    echo set CYGWIN_DRIVE=%%~d0
    echo set "CYGWIN_ROOT=%%~dp0cygwin"
    echo.
    echo set "CYGWIN_PATH=%CYGWIN_PATH%;%%CYGWIN_ROOT%%\bin"
    echo for /f "tokens=*" %%%%i in ^('where adb.exe 2^^^>NUL'^) do set "CYGWIN_PATH=%%CYGWIN_PATH%%;%%%%i\.."
    echo for /f "tokens=*" %%%%i in ^('where docker.exe 2^^^>NUL'^) do set "CYGWIN_PATH=%%CYGWIN_PATH%%;%%%%i\.."
    echo set "PATH=%%CYGWIN_PATH%%"
    echo.
    echo set "ALLUSERSPROFILE=%%CYGWIN_ROOT%%\.ProgramData"
    echo set "ProgramData=%%ALLUSERSPROFILE%%"
    echo set CYGWIN=nodosfilewarning
    echo.
    echo set "USERNAME=%CYGWIN_USERNAME%"
    echo set "HOME=/home/%%USERNAME%%"
    echo set SHELL=/bin/bash
    echo set HOMEDRIVE=%%CYGWIN_DRIVE%%
    echo set "HOMEPATH=%%CYGWIN_ROOT%%\home\%%USERNAME%%"
    echo set GROUP=None
    echo set GRP=
    echo.
    echo echo Replacing [/etc/fstab]...
    echo ^(
    echo     echo # /etc/fstab
    echo     echo # IMPORTANT: this files is recreated on each start by cygwin-portable.cmd
    echo     echo #
    echo     echo #    This file is read once by the first process in a Cygwin process tree.
    echo     echo #    To pick up changes, restart all Cygwin processes.  For a description
    echo     echo #    see https://cygwin.com/cygwin-ug-net/using.html#mount-table
    echo     echo.
    echo     echo # noacl = disable Cygwin's - apparently broken - special ACL treatment which prevents apt-cyg and other programs from working
    echo     echo none /cygdrive cygdrive binary,noacl,posix=0,user 0 0
    echo ^) ^> "%%CYGWIN_ROOT%%\etc\fstab"
    echo.
    echo %%CYGWIN_DRIVE%%
    echo chdir "%%CYGWIN_ROOT%%\bin"
    echo echo Loading [%%CYGWIN_ROOT%%\portable-init.sh]...
    echo bash "%%CYGWIN_ROOT%%\portable-init.sh"
    echo.
    :: https://stackoverflow.com/a/8452363/5116073
    echo set "arg1=%%~1"
    echo setlocal EnableDelayedExpansion
    echo if "!arg1!" == "" (
    if "%INSTALL_CONEMU%" == "yes" (
        if "%CYGWIN_ARCH%" == "64" (
            echo   start "" "%%~dp0conemu\ConEmu64.exe" %CON_EMU_OPTIONS%
        ) else (
            echo   start "" "%%~dp0conemu\ConEmu.exe" %CON_EMU_OPTIONS%
        )
    ) else (
        echo   mintty --nopin %MINTTY_OPTIONS% --icon %%CYGWIN_ROOT%%\Cygwin-Terminal.ico -
    )
    echo ^) else (
    echo   if "!arg1!" == "no-mintty" (
    echo     bash --login -i
    echo   ^) else (
    echo     bash --login -c %%*
    echo   ^)
    echo ^)
    echo.
    echo cd "%%CWD%%"
) >"%Start_cmd%" || goto :fail

:: launching Bash once to initialize user home dir
call "%Start_cmd%" whoami

set "conemu_config=%INSTALL_ROOT%conemu\ConEmu.xml"
if "%INSTALL_CONEMU%" == "yes" (
    (
        echo ^<?xml version="1.0" encoding="UTF-8"?^>
        echo ^<key name="Software"^>^<key name="ConEmu"^>^<key name=".Vanilla" build="170622"^>
        echo    ^<value name="StartTasksName" type="string" data="{Bash::CygWin bash}"/^>
        echo    ^<value name="ColorTable00" type="dword" data="00000000"/^>
        echo    ^<value name="ColorTable01" type="dword" data="00ee0000"/^>
        echo    ^<value name="ColorTable02" type="dword" data="0000cd00"/^>
        echo    ^<value name="ColorTable03" type="dword" data="00cdcd00"/^>
        echo    ^<value name="ColorTable04" type="dword" data="000000cd"/^>
        echo    ^<value name="ColorTable05" type="dword" data="00cd00cd"/^>
        echo    ^<value name="ColorTable06" type="dword" data="0000cdcd"/^>
        echo    ^<value name="ColorTable07" type="dword" data="00e5e5e5"/^>
        echo    ^<value name="ColorTable08" type="dword" data="007f7f7f"/^>
        echo    ^<value name="ColorTable09" type="dword" data="00ff5c5c"/^>
        echo    ^<value name="ColorTable10" type="dword" data="0000ff00"/^>
        echo    ^<value name="ColorTable11" type="dword" data="00ffff00"/^>
        echo    ^<value name="ColorTable12" type="dword" data="000000ff"/^>
        echo    ^<value name="ColorTable13" type="dword" data="00ff00ff"/^>
        echo    ^<value name="ColorTable14" type="dword" data="0000ffff"/^>
        echo    ^<value name="ColorTable15" type="dword" data="00ffffff"/^>
        echo    ^<value name="KeyboardHooks" type="hex" data="01"/^>
        echo    ^<value name="UseInjects" type="hex" data="01"/^>
        echo    ^<value name="Update.CheckOnStartup" type="hex" data="00"/^>
        echo    ^<value name="Update.CheckHourly" type="hex" data="00"/^>
        echo    ^<value name="Update.UseBuilds" type="hex" data="02"/^>
        echo    ^<value name="FontUseUnits" type="hex" data="01"/^>
        echo    ^<value name="FontSize" type="ulong" data="13"/^>
        echo    ^<value name="StatusFontHeight" type="long" data="12"/^>
        echo    ^<value name="TabFontHeight" type="long" data="12"/^>
        echo    ^<key name="HotKeys"^>
        echo        ^<value name="KeyMacro01" type="dword" data="00001157"/^>
        echo        ^<value name="KeyMacro01.Text" type="string" data="Close(1,1)"/^>
        echo    ^</key^>
        echo    ^<value name="FontName" type="string" data="Courier New"/^>
        echo    ^<value name="Anti-aliasing" type="ulong" data="3"/^>
        echo    ^<value name="DefaultBufferHeight" type="long" data="9999"/^>
        echo    ^<value name="ClipboardConfirmEnter" type="hex" data="00"/^>
        echo    ^<value name="StatusBar.Flags" type="dword" data="00000003"/^>
        echo    ^<value name="StatusFontFace" type="string" data="Tahoma"/^>
        echo    ^<value name="StatusBar.Color.Back" type="dword" data="007f7f7f"/^>
        echo    ^<value name="StatusBar.Color.Light" type="dword" data="00ffffff"/^>
        echo    ^<value name="StatusBar.Color.Dark" type="dword" data="00000000"/^>
        echo    ^<value name="StatusBar.Hide.VCon" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.CapsL" type="hex" data="00"/^>
        echo    ^<value name="StatusBar.Hide.ScrL" type="hex" data="00"/^>
        echo    ^<value name="StatusBar.Hide.ABuf" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.Srv" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.Transparency" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.New" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.Sync" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.Proc" type="hex" data="01"/^>
        echo    ^<value name="StatusBar.Hide.Title" type="hex" data="00"/^>
        echo    ^<value name="StatusBar.Hide.Time" type="hex" data="00"/^>
        echo    ^<value name="TabFontFace" type="string" data="Tahoma"/^>
        echo    ^<key name="Tasks"^>
        echo        ^<value name="Count" type="long" data="1"/^>
        echo        ^<key name="Task1"^>
        echo            ^<value name="Name" type="string" data="{Bash::CygWin bash}"/^>
        echo            ^<value name="Flags" type="dword" data="00000005"/^>
        echo            ^<value name="Hotkey" type="dword" data="0000a254"/^>
        echo            ^<value name="GuiArgs" type="string" data=""/^>
        echo            ^<value name="Cmd1" type="string" data="%%ConEmuBaseDirShort%%\conemu-cyg-%CYGWIN_ARCH%.exe -new_console:m:/cygdrive -new_console:p1:C:&quot;%%ConEmuDir%%\..\cygwin\Cygwin.ico&quot;:d:&quot;%%ConEmuDir%%\..\cygwin\home\%CYGWIN_USERNAME%&quot;"/^>
        echo            ^<value name="Active" type="long" data="0"/^>
        echo            ^<value name="Count" type="long" data="1"/^>
        echo        ^</key^>
        echo    ^</key^>
        echo ^</key^>^</key^>^</key^>
    )> "%conemu_config%" || goto :fail
)

set "Bashrc_sh=%CYGWIN_ROOT%\home\%CYGWIN_USERNAME%\.bashrc"

find "export PYTHONHOME" "%Bashrc_sh%" >NUL || (
    echo.
    echo export PYTHONHOME=/usr
) >>"%Bashrc_sh%" || goto :fail

if not "%CYGWIN_PACKAGES%" == "%CYGWIN_PACKAGES:ssh-pageant=%" (
    :: https://github.com/cuviper/ssh-pageant
    echo Adding ssh-pageant to [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "ssh-pageant" "%Bashrc_sh%" >NUL || (
        echo.
        echo eval $(/usr/bin/ssh-pageant -r -a "/tmp/.ssh-pageant-$USERNAME"^)
    ) >>"%Bashrc_sh%" || goto :fail
)

if not "%PROXY_HOST%" == "" (
    echo Adding proxy settings for host [%COMPUTERNAME%] to [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "export http_proxy" "%Bashrc_sh%" >NUL || (
        echo.
        echo if [[ $HOSTNAME == "%COMPUTERNAME%" ]]; then
        echo     export http_proxy=http://%PROXY_HOST%:%PROXY_PORT%
        echo     export https_proxy=$http_proxy
        echo     export no_proxy="::1,127.0.0.1,localhost,169.254.169.254,%COMPUTERNAME%,*.%USERDNSDOMAIN%"
        echo     export HTTP_PROXY=$http_proxy
        echo     export HTTPS_PROXY=$http_proxy
        echo     export NO_PROXY=$no_proxy
        echo fi
    ) >>"%Bashrc_sh%" || goto :fail
)

if "%INSTALL_ANSIBLE%" == "yes" (
    echo Adding Ansible to PATH in [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "ansible" "%Bashrc_sh%" >NUL || (
        (
            echo.
            echo export PYTHONPATH="$PYTHONPATH:/opt/ansible/lib"
            echo export PATH="$PATH:/opt/ansible/bin"
        ) >>"%Bashrc_sh%" || goto :fail
    )
)

if "%INSTALL_NODEJS%" == "yes" (
    echo Adding Node.js to PATH in [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "NODEJS_HOME" "%Bashrc_sh%" >NUL || (
        (
            echo.
            REM TODO
            REM echo export NVM_DIR="/opt/nvm"
            REM echo [ -s "$NVM_DIR/nvm.sh" ] ^&^& \. "$NVM_DIR/nvm.sh"  # This loads nvm
            echo export NODEJS_HOME=/opt/nodejs/current
            echo export PATH="$PATH:$NODEJS_HOME"
        ) >>"%Bashrc_sh%" || goto :fail
    )
)

if "%INSTALL_TESTSSL_SH%" == "yes" (
    echo Adding testssl.sh to PATH in [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "testssl" "%Bashrc_sh%" >NUL || (
        (
            echo.
            echo export PATH="$PATH:/opt/testssl"
        ) >>"%Bashrc_sh%" || goto :fail
    )
)

if "%INSTALL_BASH_FUNK%" == "yes" (
    echo Adding bash-funk to [/home/%CYGWIN_USERNAME%/.bashrc]...
    find "bash-funk" "%Bashrc_sh%" >NUL || (
        (
            echo.
            echo source /opt/bash-funk/bash-funk.sh
        ) >>"%Bashrc_sh%" || goto :fail
    )
)

"%CYGWIN_ROOT%\bin\dos2unix" "%Bashrc_sh%" || goto :fail

:: execute custom commands after installation
set "custom_tasks_file=%INSTALL_ROOT%cygwin-portable-installer-post-tasks.cmd"
if exist "%custom_tasks_file%" (
  echo Executing post installation tasks [%custom_tasks_file%]...
  call "%custom_tasks_file%"
)

echo.
echo ###########################################################
echo # Installing [Cygwin Portable] succeeded.
echo ###########################################################
echo.
echo Use [%Start_cmd%] to launch Cygwin Portable.
echo.
timeout /T 60
goto :eof

:fail
    if exist "%DOWNLOADER%" (
        del "%DOWNLOADER%"
    )
    echo.
    echo ###########################################################
    echo # Installing [Cygwin Portable] FAILED!
    echo ###########################################################
    echo.
    timeout /T 60
    exit /b 1

:download
    if exist %2 (
        echo Deleting existing [%2]...
        del %2 || goto :fail
    )

    where /q curl
    if %ERRORLEVEL% EQU 0 (
        call :download_with_curl %1 %2
    ) else (
        call :download_with_vbs %1 %2
    )
    exit /b 0

:download_with_curl
    if "%PROXY_HOST%" == "" (
        set "http_proxy="
        set "https_proxy="
    ) else (
        set http_proxy=http://%PROXY_HOST%:%PROXY_PORT%
        set https_proxy=http://%PROXY_HOST%:%PROXY_PORT%
    )
    echo Downloading %1 to %2 using curl...
    curl %1 -# -o %2 || goto :fail
    exit /b 0

:download_with_vbs
    :: create VB script that can download files
    :: not using PowerShell which may be blocked by group policies
    set DOWNLOADER=%INSTALL_ROOT%downloader.vbs
    echo Creating [%DOWNLOADER%] script...
    if "%PROXY_HOST%" == "" (
        set DOWNLOADER_PROXY=.
    ) else (
        set DOWNLOADER_PROXY= req.SetProxy 2, "%PROXY_HOST%:%PROXY_PORT%", ""
    )

    (
        echo url = Wscript.Arguments(0^)
        echo target = Wscript.Arguments(1^)
        echo On Error Resume Next
        echo reqType = "WinHttp.WinHttpRequest.5.1"
        echo Set req = CreateObject(reqType^)
        echo On Error GoTo 0
        echo If req Is Nothing Then
        echo   reqType = "MSXML2.XMLHTTP.6.0"
        echo   Set req = CreateObject(reqType^)
        echo End If
        echo WScript.Echo "Downloading '" ^& url ^& "' to '" ^& target ^& "' using '" ^& reqType ^& "'..."
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

    cscript //Nologo "%DOWNLOADER%" %1 %2 || goto :fail
    del "%DOWNLOADER%"
    exit /b 0
