# Quick Start #

## Download ##

As the source is currently actively worked on, there is no official release to download pre-packaged.  You're encouraged to browse the source to download the very latest version of the few files this project consists of.

## Requirements ##

Obviously, if you're here, it is assumed you have a Zephyr HxM device (**not** the more recent HxM Smart) and a functioning Bluetooth interface on your computer.

This software has only been tested on Debian Linux, but it is expected to run wherever Perl, hcitool and rfcomm are available.

In order to run HRV Monitor yourself, you will need the following software:

  * Bluetooth command-line tools "hcitool" and "rfcomm" (for Zephyr HxM support);
  * Perl 5+;
  * The "PDL" Perl library.

If you want to use the browser-based GUI version, additional requirements:

  * A modern HTML5 browser (i.e. Chrome 8+, Firefox 4+);
  * Perl libraries:
    * HTTP::Daemon (may be part of libwww-perl in some distributions);
    * JSON;

More specifically, on a Debian or Ubuntu system you should need the following in addition to Bluetooth to get going:

```
$ apt-get install libmath-round-perl pdl libdigest-perl libdigest-crc-perl libio-pty-perl libhttp-daemon-perl libjson-perl
```

### Bluetooth ###

In addition to the command-line tools "hcitool" and "rfcomm" under Linux for initial pairing (and perhaps periodically thereafter?) there seems to be a need for a "Bluetooth agent".

In my case, the first time I wanted to access my Zephyr HxM device, I needed to run the following command in the background:

```
$ sudo bluetooth-agent 1234
```

While I expected to need to do this every time, I actually haven't needed to in a few weeks.  Not sure who's remembering what...

## Starting HRV Monitor ##

Simply launch the software without any arguments to see a summary of available options:

```
$ ./hrvmonitor 
Options:
	--cli          Enable text output here.
	--gui          Enable HTTP daemon for GUI.
	--both         Shortcut to enable both text and HTTP.
	--host=host    Set GUI HTTP host.  (Default: localhost) 
	--port=port    Set GUI HTTP port.  (Default: 6060)
```

I typically just run `hrvmonitor --gui` or `hrvmonitor --both` and point my browser to `http://localhost:6060/` to see the user interface.
