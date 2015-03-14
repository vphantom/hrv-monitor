# Device Support #

This protocol described by Zephyr applies to their 1st generation devices which use older, high-power Bluetooth with a virtual serial port.  It does **not** describe how their "HxM2" devices such as the Zephyr HxM Smart, which are Bluetooth 4.0 Low Energy a.k.a. Smart compatible.

# Serial Layer #

Link: 115,200 bps, 8N1

The device deafly sends one packet per second.


# Data Packet Format #

"All bytes are little endian."  (I assume they mean all "integers".)  All 16-bit integers are unsigned, LSB first.

The standard packet for heart rate, speed and distance is 60 bytes long.

```
Byte  Type    Description
-----+-------+--------------------------------
  0   char    STX "Start of Text"  ASCII 0x02
  1   char    Message ID           ASCII 0x26 = Heart rate, Speed & Distance packet
  2   uint8   Data Length Code     0..128, standard heart rate is 0x37 (55 bytes of payload)
-----
  3   uint16  Firmware ID
  5   char(2) Firmware version     (First is major, second is minor)
  7   Hardware ID
  9   Hardware version
 11   uint8   Battery charge indicator     (Percentage 0..100)
 12   uint8   Heart rate                   (30..240 BPM, 0 = undetected)
 13   uint8   Heart beat number    (0..255, rolls over continuously)
 14   uint16  Heart beat timestamp 1 (newest)
 16   uint16  Heart beat timestamp 2
 18   uint16  Heart beat timestamp 3
 20   uint16  Heart beat timestamp 4
 22   uint16  Heart beat timestamp 5
 24   uint16  Heart beat timestamp 6
 26   uint16  Heart beat timestamp 7
 28   uint16  Heart beat timestamp 8
 30   uint16  Heart beat timestamp 9
 32   uint16  Heart beat timestamp 10
 34   uint16  Heart beat timestamp 11
 36   uint16  Heart beat timestamp 12
 38   uint16  Heart beat timestamp 13
 40   uint16  Heart beat timestamp 14
 42   uint16  Heart beat timestamp 15 (oldest)
 44   char(6) Reserved
 50           Distance
 52           Instantaneous speed
 54           Strides
 55   char    Reserved
 56   char(2) Reserved
-----
 58           CRC
 59           ETX                    ASCII 0x03
```

Use the heart beat number to determine how many new beats are in the latest packet.  There may be none (BPM < 60), one or several (BPM > 60) and this also helps with possibly dropped packets.

Heart beat timestamps are ABSOLUTE timestamps in milliseconds 0..65535.  They roll over continuously, so in our backtracking we need to add 65536 each time we go negative.

With 15 timestamps, we can monitor 240 BPM despite 3 consecutive lost packets.

Distance is in 16th of a meter 0..4095, thus rolling over every 256m.

Instantaneous speed is in 1/256th of a m/s 0..4095, or up to 15.995m/s.

Strides since unit was powered on, range is 0..255 but doc rolls over at 128.

## CRC-8 ##

(I was unable to make Digest::CRC::crc8() produce a match with what my HxM unit returns, so I am ignoring it in this version.)

The CRC-8 is calculated over the payload, thus from the 60-byte packet, it excludes the first 3 bytes and the last 2 bytes.  On those 55 bytes, official implementation from Zephyr, combined into a single function:

```
/* Block:  Pointer to the block of data.
 * Count:  The number of bytes.
 * Return: The computed CRC.
 */
uint8_t crc8(uint8_t *block, uint16_t count)
{
	uint8_t crc = 0, i = 0;
	for (crc = 0;  count > 0;  --count, block++) {
		crc = crc ^ *block;
		for (i = 0;  i < 8;  i++) {
			if (crc & 1) {
				crc = (crc >> 1) ^ 0x8C;
			} else {
				crc = (crc >> 1);
			};
		};
	};
	return(crc);
}
```