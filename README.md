# README.md
## Installing and uninstalling modsecurity for LiteSpeed and Nginx for http2benchmark
The purpose of this directory is to house the scripts to install and uninstall modsecurity into Nginx and LiteSpeed Enterprise for the purposes of benchmarking.  It is part of the http2benchmark suite of benchmarks.

There are two user scripts in this directory:
* **modsec.sh**: Installs and configures modsecurity for Nginx and LiteSpeed
* **uninstall_modsec.sh**: Uninstalls and unconfigures modsecurity for Nginx and Litespeed.  It does not completely return the system to a pre-install state as it leaves a few system libraries install, but all of the rules and configurations are removed.

This script is particularly important for Nginx as modsecurity support must be compiled with the source for the entire Nginx product.

Once `modsec.sh` has been run successfully you can run the http2benchmarks and compare Nginx and Litespeed performance.  Since modsecurity is in effect you will see significantly different performance than without modsecurity installed and configured.

What `modsec.sh` does is:
* Install compilation pre-requisites.
* Creates a `temp` directory to hold just about everything downloaded.
* Install the OWASP rules into it.
* Install the source for Nginx and it's modsecurity module into it,  compile them and copy them over.
* For Nginx, save a copy of the existing configuration files and then modify them to use the installed modsecurity modules with OWASP rules.
* For LiteSpeed, save a copy of the existing configuration files and then modify them to use the modsecurity function and the OWASP rules.

What `uninstall_modsec.sh` does is:
* Copy back the saved configuration files for LiteSpeed.
* Copy back the saved configuration files for Nginx.
* Remove the `temp` directory

