unifi-pfsense
=============

A pfSense package that provides the UniFi Controller software.

Purpose
-------

The UniFi Controller software from [Ubiquiti Networks](http://www.ubnt.com/) runs well on the underlying FreeBSD operating system used by [pfSense](http://www.pfsense.org/), but no package yet exists (publicly) for installing the UniFi Controller on pfSense. The objective of this project is to develop and maintain a package that provides the UniFi Controller software on pfSense platforms.

Milestones
----------

As a work in progress starting from scratch, the future is wide-open. Here is what is planned so far:

1. A simple, automated installation script that is concise, consistent, and reliable.
2. A FreeBSD-style rc.d startup and shutdown script for starting and stopping the UniFi Controller software using the standard BSD services framework.
3. A FreeBSD port and package that specifies dependencies and automates installation of the UniFi Controller software.
4. User-interface elements for pfSense for starting and stopping the UniFi Controller service and reporting on its status.
5. A complete pfSense-style package.

From there, we have a lot of other big ideas that may or may not ever happen or even be possible:

- Details in the pfSense side of the UI, including active APs, clients, and WLANs
- Getting graph data for RRDtool
- pfSense dashboard widget indicating AP status and users
- Automated integration of UniFi's captive portal features with the corresponding features in pfSense
- Other automated configuration, perhaps via the pfSense "wireless" tools
- Backup and restore integration
- Whatever else we can dig out of the API and mongodb

Challenges
----------

- Because the UniFi Controller software is proprietary, it cannot be built from source and cannot be included directly.
- Because Ubiquiti does not provide a standard way to fetch the software (not even a "latest" symlink), we cannot identify the appropriate version to download from Ubiquiti programmatically.
- It is not clear whether we can even download the software automatically from Ubiquiti according to the terms of the relevant licenses.
- Version 3 of the UniFI software has just been released, and it is not clear what the differences are from v2 for the purposes of this project.

References
----------

These sources of information immediately come to mind:

- [UniFi product information page](http://www.ubnt.com/unifi#UnifiSoftware)
- [UniFI download and documentation](http://www.ubnt.com/download#UniFi:AP)
- [UniFi updates blog](http://community.ubnt.com/t5/UniFi-Updates-Blog/bg-p/Blog_UniFi)
- [pfSense: Developing Packages](https://doc.pfsense.org/index.php/Developing_Packages)