# README.md
## Installing and uninstalling modsecurity for LiteSpeed, Nginx, OpenLitespeed and Apache for http2benchmark
The purpose of this directory is to house the scripts to install and uninstall modsecurity into LiteSpeed Enterprise, Nginx, OpenLitespeed and Apache for the purposes of benchmarking.  It is part of the http2benchmark suite of benchmarks.

There are three user scripts in this directory:
* **modsec.sh**: Installs and configures modsecurity for each of the servers installed
* **uninstall_modsec.sh**: Uninstalls and unconfigures modsecurity for each of the servers installed.  It does not completely return the system to a pre-install state as it leaves a few system libraries install, but all of the rules and configurations are removed.
* **modsec_ctl.sh**: When run with a control parameter does the requested function.  Must be run after running a successful `modsec.sh`:
  - **unconfig**: Removes the modsecurity definitions from each of the server configurations, but leaves the files around which allow it to be run with the `config` parameter later.
  - **config**: If you have done an `unconfig`, reconfigures each of the server configurations for OWASP modsecurity.
  - **comodo**: If you have done an `unconfig`, reconfigures each of the server configurations for Comodo modsecurity.  For Litespeed Enterprise and Apache, you must have installed the v2 Apache Comodo definitions in a `comodo_apache` directory; for OpenLitespeed and Nginx you must have installed the v3 Nginx definitions in a `comodo_nginx` directory.

Once `modsec.sh` has been run successfully you can run the /opt/benchmark.sh script on the client machine and compare the various servers performance.  Since modsecurity is in effect you will see significantly different performance than without modsecurity installed and configured.

What `modsec.sh` does is:
* Install compilation pre-requisites.
* Creates a `temp` directory to hold just about everything downloaded.
* Install the OWASP rules into it.
* Install the source for Nginx and it's modsecurity module into it,  compile them and copy them over.
* For each server it saves a copy of the existing configuration files and then modify them to use the installed modsecurity modules with OWASP rules.

What `uninstall_modsec.sh` does is:
* Copy back the saved configuration files for each of the server types
* Remove the `temp` directory

What `modsec_ctl.sh` does is:
* **unconfig**: Copy back the saved configuration files for each of the server types
* **config**: Saves a copy of the existing configuration files and reconfigures the server configuration files in the same way as `modsec.sh`
* **comodo**: Saves a copy of the existing configuration files and reconfigures the server configuration files specifically for the Comodo rule sets.
