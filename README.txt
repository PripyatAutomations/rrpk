Rusty Rig Remote Packaging Kit (R3PK)
-------------------------------------
You'll need to drop ISOs for the desired targets in iso/

For now only fedora and win64 use VM building.

It should automatically pull needed sources and build/install packages


This folder contains everything but the needed iso's to automate building packages
for RustyRig remote for the following targets:
	* Debian
	* Fedora
	* Win64
	* ArchLinux

Right now the scripts do the following:
	build-debs.sh		Build deb packages (and install them!)
	build-nopkg.sh		Build and install without a package manager
	cleanup.sh		Cleanup the tree
	fetch-all.sh		Fetch all source modules
	uninstall-nopkg.sh	Uninstall unpackaged builds
	update-all.sh		Update all sources


USAGE
=====
 When first cloned, do ./fetch-all.sh to grab the sources.


After that, you will probably want to use build-deb.sh or similar script for
your distro. It will build packages and install them as they are built,
since the libraries must be installed to build the rest of this mess.

sudo will be used by default to accomplish installation -- sorry!
