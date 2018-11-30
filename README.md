unifi-pfsense
=============

A script that installs the UniFi Controller software on pfSense and other FreeBSD systems

Purpose
-------

The objective of this project is to develop and maintain a script that installs [Ubiquiti's](http://www.ubnt.com/) UniFi Controller software on FreeBSD-based systems, particularly the [pfSense](http://www.pfsense.org/) firewall.

Status
------

The project provides an rc script to start and stop the UniFi controller, and an installation script to automatically download and install everything, including the rc script.

This project uses the latest branch from Ubiquiti rather than the LTS branch.

Challenges
----------

Because the UniFi Controller software is proprietary, it cannot be built from source and cannot be included directly in a package. To work around this, we can download the UniFi controller software directly from Ubiquiti during the installation process.

Because Ubiquiti does not provide a standard way to fetch the software (not even a "latest" symlink), we cannot identify the appropriate version to download from Ubiquiti programmatically. It will be up to the package maintainers to keep the package up to date with the latest version of the software available from Ubiquiti.

Licensing
---------

This project itself is licensed according to the two-clause BSD license.

The UniFi Controller software is licensed as-is with no warranty, according to the README included with the software.

[Ubiquiti has indicated via email](https://github.com/gozoinks/unifi-pfsense/wiki/Tacit-Approval) that acceptance of the EULA on the web site is not required before downloading the software.

Upgrading
------------------

At the very least, backup your configuration before proceeding.

Be sure to track Ubiquiti's release notes for information on the changes and what to expect. Updates, even minor ones, sometimes involve database upgrades that can take some time. Features come and go, and behaviors change. Proceed with caution.

If you are still on 3.2, you should know by now that upgrading will be no small task, as the current software is many generations ahead of you. Proceed with caution.


Usage
------------

To install the controller software and the rc script:

1. Log in to the pfSense command line shell as root.
2. Run this one-line command, which downloads the install script from Github and executes it with sh:

  ```
    fetch -o - https://git.io/j7Jy | sh -s
  ```

The install script will install dependencies, download the UniFi controller software, make some adjustments, and start the UniFi controller.

The git.io link above should point to `https://raw.githubusercontent.com/gozoinks/unifi-pfsense/master/install-unifi/install-unifi.sh`


Starting and Stopping
---------------------

To start and stop the controller, use the `service` command from the command line.

- To start the controller:

  ```
    service unifi.sh start
  ```
  The UniFi controller takes a few minutes to start. The 'start' command exits immediately while the startup continues in the background.

- To stop the controller:

  ```
    service unifi.sh stop
  ```
  The the stop command takes a while to execute, and then the shutdown continues for several minutes in the background. The rc script will wait until the command received and the shutdown is finished. The idea is to hold up system shutdown until the UniFi controller has a chance to exit cleanly.

pfSense Package Conflicts
---------------------

The version of icu installed for boost, a requirement of mongodb, is newer than what is used by many packages, pfSense or otherwise. Installing packages from the pfSense web UI should be considered **dangerous** and avoided after installing the controller software as pfSense can and will uninstall mongodb while the controller is running.

To check package compatability, first go to the command line and locate your package with `pkg search PKG_NAME`. pfSense packages are of the form `pfSense-pkg-PKG_NAME`, such as `pfSense-pkg-pfBlockerNG`. Check the install with `pkg install --dry-run PKG_NAME`. If you recieve a message saying that icu is to be downgraded and boost and mongodb will be removed, you need to do a manual forced install:

```
$ pkg install --dry-run pfSense-pkg-syslog-ng
Updating pfSense-core repository catalogue...
pfSense-core repository is up to date.
Updating pfSense repository catalogue...
pfSense repository is up to date.
All repositories are up to date.
The following 9 package(s) will be affected (of 0 checked):

Installed packages to be REMOVED:
	boost-libs-1.68.0_3
	mongodb34-3.4.16_1

New packages to be INSTALLED:
	pfSense-pkg-syslog-ng: 1.15_2 [pfSense]
	syslog-ng: 3.14.1_1 [pfSense]
	e2fsprogs-libuuid: 1.44.4 [pfSense]
	libbson: 1.8.1 [pfSense]
	logrotate: 3.13.0_1 [pfSense]
	popt: 1.16_2 [pfSense]

Installed packages to be DOWNGRADED:
	icu: 63.1,1 -> 62.1_1,1 [pfSense]

Number of packages to be removed: 2
Number of packages to be installed: 6
Number of packages to be downgraded: 1

The operation will free 285 MiB.
901 KiB to be downloaded.
```

To force an install, fetch each package listed under `New packages to be INSTALLED` with `pkg fetch PKG_NAME`. Once you have fetched all the packages, go to `/var/cache/pkg` and force install each package with `pkg add -f PKG_NAME.txz`. This is obviously not ideal, and packages **may not work correctly** if they rely on something speciffic to icu 62.

Contributing
------------

### UniFi controller updates

The main area of concern is keeping up with Ubiquiti's updates. I don't know of a way to automatically grab the URL to the current version; UBNT posts updates only to their blog and their forums, and they don't seem to have a link alias to the current release. That means we have to commit an update directly to the install.sh script with every release.

If you're aware of an update before I am:

1. Create a branch from master, named for the version you are about to test.
2. Update the URL in install.sh to the latest version.
3. Test it on your pfSense system.
4. Optional, but ideal: test it on a fresh pfSense system, as in a VM.
5. If it checks out, submit a pull request from your branch. This helps bring my attention to the update and lets me know that you have tested the new version.

I will then test on my own systems and merge the PR.

### Other enhancements

Other enhancements are most welcome. Much of the script's most intelligent behavior is the work of contributors, including the package dependency resolution and the java version spoofing. This project would not be alive without these efforts. I am excited by this support, and I can't wait to see what else develops.

Potential areas of improvement include but are not limited to:

- Error handling
- Automatic latest-version detection
- More robust backup and restore
- LTS/Latest branch selection options and defaults. Command line options? Prompts?
- What else?

### Issues and pull requests

Of course. That's why it's on github.

Roadmap
-------

This project may never reach its original goal of becoming a pfSense package. The packaging scheme for pfSense has changed. Doing this as a pfSense package requires doing it as a FreeBSD package first. Doing it as a FreeBSD package means we may as well make it portable to other FreeBSD systems. All of this changes how this would be implemented. Some of the concepts we can borrow, but it's substantially new work. Moreover, because the requirements of the UniFi controller deviate from what's strictly available in the FreeBSD package repos, I'm not even sure it's possible.

As a helper script for installing the UniFi controller, this tool remains effective and robust, which is great. I see no reason not to continue development here.

It is also less pfsense-specific than originally imagined. If you're here to run UniFi on your NAS, welcome!

With all this in mind, the future of this project is clearly as an installation tool, and I envision enhancements to it as such. So let's just make it a smart and capable installer for UniFi Controller on FreeBSD-type systems.

Resources
----------

- [UniFi product information page](https://www.ubnt.com/software/)
- [UniFI download and documentation](https://www.ubnt.com/download/unifi)
- [UniFi updates blog](https://community.ubnt.com/t5/UniFi-Updates-Blog/bg-p/Blog_UniFi)
