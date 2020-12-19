unifi-pfsense
=============

A script that installs the UniFi Controller software on pfSense and other FreeBSD systems

Purpose
-------

The objective of this project is to develop and maintain a script that installs [Ubiquiti's](http://www.ubnt.com/) UniFi Controller software on FreeBSD-based systems, particularly the [pfSense](http://www.pfsense.org/) firewall.

Status
------

The project provides an rc script to start and stop the UniFi controller, and an installation script to automatically download and install everything, including the rc script.

This project unlike Gozoinks offers current beta versions as well as Official Releases 6.0.x and 5.14.23. This project has also fixed all the dependency errors that were encountered on gozoinks current commit by reordering all of the packages, including png as freetype2 is dependent on it. I have also added a pkg unlock before the pkg add and a pkg lock following the pkg add. The unlock and lock was added to prevent FreeBSD from possibly reinstalling or upgrading packages that were used in the script. This behavior was first founded by @tong2x in OPNSense, OPNSense has an update feature that will also attempt to upgrade or reinstall packages, if FreeBSD or OPNSense in this case does a reinstall of a package it can and will break the UniFi controller. These patches fix this issue from occuring.

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
2. Run this one-line command, which downloads the install script from Github and executes it with sh (choose which version of the controller you want, and run that fetch link):

UniFi Controller 6.0.42 Beta
```
   fetch -o - https://git.io/JIE8U | sh -s
```
UniFi Controller 6.1.26 Beta
```
   fetch -o - https://git.io/Jk8AT | sh -s
```
UniFi Controller 5.14.23 Official Release
```
   fetch -o - https://git.io/JTPRo | sh -s
```
UniFi Controller 6.0.43 Official Release
```
   fetch -o - https://git.io/JLuRW | sh -s
```

The install script will install dependencies, download the UniFi controller software, make some adjustments, and start the UniFi controller.

The git.io link above should point to the respective directories under this fork for whatever version you are installing:
`https://raw.githubusercontent.com/gnkidwell/unifi-pfsense/beta/`


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


After Installing
----------------

After using this script to install the UniFi Controller software, check the UniFi controller documentation for next steps, which would include how to access the controller (https://firewall.example.com:8443/), how to perform initial configuration, how to restore from a backup, and all the other things you would need to know and need to do to manage a UniFi system that are not specific to running UniFi Controller on FreeBSD.


Troubleshooting
---------------

Step one is to determine whether the issue you’ve encountered is with this script or with the UniFi controller software. 

Issues with the script  might include problems downloading packages, installing packages, interactions with pfSense such as dependency packages being deleted after updates, or incorrect dependencies being downloaded. Feel free to open an issue for anything like this.

Issues with the UniFi Controller software or its various dependencies might include not starting up, not listening on port 8443, exiting with a port conflict, crashing after startup, database errors, memory issues, file permissions, dependency conflicts, or the weather. You should troubleshoot these issues as you would on any other installation of UniFi Controller. For some, the first stop is UniFi technical support; for others, ready answers to most questions about setting up UniFi controller are found most quickly on the UniFi forums.




To uninstall UniFi controller (completely remove, Please backup your config first):
----------------
  ```
    rm -rf /usr/local/UniFi
    rm /usr/local/etc/rc.d/unifi.sh
  ```



To uninstall Java (for OPNSense firewall/Sensei plugin user with broken java link):
----------------
  ```
    pkg remove -y javavmwrapper
    pkg remove -y java-zoneinfo
  ```




Contributing
------------

### UniFi controller updates

The main area of concern is keeping up with Ubiquiti's updates. I don't know of a way to automatically grab the URL to the current version, though there has been work done on this. For now we have to commit an update directly to the install.sh script with every UniFi release.

If you're aware of an update before I am:

1. Create a branch from beta, named for the version you are about to test.
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
