# cygwin-portable-installer

1. [What is it?](#what-is-it)
1. [Installation](#install)
1. [License](#license)


## <a name="what-is-it"></a>What is it?

cygwin-portable-installer is a self-containing Windows batch file perform an unattended installation of a portable [Cygwin](http://cygwin.org) environment.

### Features

* **portable**: you can e.g. install it on an USB sticks and use the same configuration on different computers
* **256-color multi-tabbed shell**: [ConEmu](https://conemu.github.io/) incl. [Cygwin Connector](https://github.com/Maximus5/cygwin-connector) is pre-configured as terminal
* **command-line package installer**: [apt-cyg](https://github.com/transcode-open/apt-cyg) package manager will be automatically installed
* **adaptive Bash prompt**: [bash-funk](https://github.com/vegardit/bash-funk) will be automatically installed


## <a name="install"></a>Installation

1. Create a local empty directory where Cygwin shall be installed, e.g. `C:\apps\cygwin-portable`
2. Download the [cygwin-portable-installer.cmd](https://github.com/vegardit/cygwin-portable-installer/blob/master/cygwin-portable-installer.cmd) file into that directory.
3. (Optional) Open the file in an text editor and adjust the configuration variables to e.g. set an HTTP Proxy, change the set of pre-installed Cygwin packages, select the terminal (ConEmu or Mintty).
4. Execute the `cygwin-portable-installer.cmd`. This will automatically:
    1. download the 32 or 64bit Cygwin setup.exe depending on your OS,
    2. install [Cygwin](http://cygwin.org) with the pre-selected set of packages,
    3. install the [ConEmu](https://conemu.github.io/) tabbed terminal,
    4. create an init scripts that will keep the installation portable,
    5. install the [apt-cyg](https://github.com/transcode-open/apt-cyg) package manager.
    6. install the [bash-funk](https://github.com/vegardit/bash-funk) Bash toolbox and adaptive Bash prompt.
5. Now you can launch your portable Cygwin environment using the newly created `cygwin-portable.cmd` batch file.


## <a name="license"></a>License

All files are released under the [Apache License 2.0](https://github.com/vegardit/bash-funk/blob/master/LICENSE.txt).
