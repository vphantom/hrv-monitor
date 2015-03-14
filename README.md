# Heart Rate Variability Monitor #

Cross-platform tool for monitoring real-time R-R measurements and analyzing variability and coherence aspects of heart rate over time.

![![](http://wiki.hrv-monitor.googlecode.com/git/hrvmonitor-beta-thumb.png)](http://wiki.hrv-monitor.googlecode.com/git/hrvmonitor-beta.png)

For more details, please see:

  * [Introduction](Introduction.md) What HRV Monitor is intended for, screenshots, etc.
  * [Uses](Uses.md) What HRV Monitor could be useful for.
  * [QuickStart](QuickStart.md) System requirements, how to launch the software.

For developers interested in my little ZephyrHxM.pm module:

  * [ZephyrProtocol](ZephyrProtocol.md) Summary compiled from Zephyr's official documentation.

**IMPORTANT NOTE:** This initial version of ZephyrHxM.pm is designed for Zephyr's 1st generation Bluetooth transmitters, which use a serial protocol.

The newer Zephyr Smart generation uses Bluetooth 4 Low Energy's standard protocols for heart rate, battery level and device information reporting, which I have not yet had an opportunity to experiment with hands-on.

On the plus side, it looks like supporting Bluetooth 4 LE a.k.a. "Smart" sensors from Zephyr will also add support for Polar's Smart sensors (not their previous-generation "W.I.N.D." ones though of course).