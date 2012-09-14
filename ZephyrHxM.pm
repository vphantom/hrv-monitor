package ZephyrHxM;

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

use 5.008;
use strict;
use warnings;

use Carp;
use Digest::CRC qw(crc8);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use POSIX;

our $VERSION = '0.01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>


=head1 NAME

ZephyrHxM - Perl extension for receiving data from Zephyr HxM

=head1 SYNOPSIS

  use ZephyrHxM;

  my $device = new ZephyrHxM;

  # Wait for and fetch latest packet
  my $packet = $device->fetch_latest();

  print "Battery status: " . $packet->{battery_charge} . "%\n";

  # FIXME: How do I then close the TTY?  unset($device) or what?

=head1 DESCRIPTION

This module provides a simple interface to listen to and decode Zephyr HxM
packets from the first available unit on the first available Bluetooth
interface.  It is up to the caller to invoke bluetooth-agent as necessary.
For example:

  $ sudo bluetooth-agent 1234 &  # Needs to run in the background.
  $ hrvmonitor
  ...progress here
  $ sudo killall bluetooth-agent

This module strictly supports standard "heart rate, speed and distance"
packets.

Note that this module invokes "hcitool" and "sudo rfcomm" at start-up and
shutdown so you may need to configure sudo accordingly.

=head1 CONSTRUCTOR

=over 4

=item new([I<verbose>])

Creates and returns a new C<ZephyrHxM> object, connecting to the
first-available Zephyr HxM device available via Bluetooth.  If I<verbose> is
supplied and true, then a few status and error messages will be printed out as
appropriate.  Fatal error messages are always printed.

=cut

use IO::Tty 'B115200';
sub new {
	my ($class, $verbose) = @_;
	my $self = bless {}, $class;

	## Bluetooth level connection
	# Tried Net::Bluetooth, but its sdp_search() fails.  Too bad.

	my $localdevices_raw  = qx/hcitool dev/;
	my ($hci_device, $hci_addr) = $localdevices_raw =~ /\s*([a-zA-Z0-9]+)\s+([a-fA-F0-9:]+)\s*/;
	croak "Cannot find Bluetooth interface." unless defined($hci_device);

	print "Scanning for Bluetooth devices...\n" if $verbose;
	my $remotedevices_raw = qx/hcitool scan/;
	my ($zephyr_addr, $zephyr_id) = $remotedevices_raw =~ /\s*([a-fA-F0-9:]+)\s+(HXM[0-9a-zA-Z]+)\s*/;
	croak "Cannot find a Zephyr HxM unit." unless defined($zephyr_addr);

	print "Connecting to $zephyr_id...\n" if $verbose;
	system("sudo rfcomm release $zephyr_addr");
	system("sudo rfcomm bind $hci_device $zephyr_addr");


	## RS-232 level connection

	my $tty;
	my $rfcomms = qx/rfcomm |grep $zephyr_addr/;
	my ($rfcomm_device) = $rfcomms =~ /^(rfcomm[^:]+):/;
	unless (defined($rfcomm_device)) {
		system("sudo rfcomm release $zephyr_addr");
		croak "Unable to figure out RFCOMM device.";
	}
	sysopen($tty, '/dev/'.$rfcomm_device, O_RDONLY) or croak "Cannot open /dev/$rfcomm_device: $!";
	binmode $tty;

	my $termios = new POSIX::Termios;

	# 115,200 8N1, ignore modem status lines, enable receiver
	$termios->setcflag(CS8 | CLOCAL | CREAD);
	$termios->setiflag(0);
	$termios->setoflag(0);
	$termios->setlflag(0);
	$termios->setospeed(B115200);
	$termios->setispeed(B115200);
	$termios->setattr(fileno($tty), TCSANOW)
		or croak "tcsetattr() failed: $!";
	
	$self->{_tty} = $tty;
	$self->{_device_name} = $zephyr_id;
	$self->{_device} = $rfcomm_device;
	$self->{_last_beatnum}  = -1;

	return $self;
}

sub _tty { shift->{_tty} }

=back

=head1 METHODS

=over 4

=item close()

Cleanly close communication channel.

=cut

sub close {
	my ($self) = @_;
	close($self->{_tty});
	system("sudo rfcomm release ". $self->{_device});
}

=item fetch_latest()

Reads any pending input from the device and parses the last packet available.
If no data is waiting for us or if the last packet was invalid, wait for the
very next valid packet.  The parsed packet returned is in the form of a hash
with the following keys:

=over 4

=item B<error>: Error message if we couldn't get a valid packet and timed out.

=item B<device_name>: Name of the Bluetooth device.

=item B<firmware_id>

=item B<firmware_version>

=item B<hardware_id>

=item B<hardware_version>

=item B<battery_charge>: Percentage of battery charge remaining.

=item B<heart_rate>: As computed by the device.

=item B<new_beats>: Chronological ordered list of new R-R durations, in msec.

=item B<distance>: I<Not yet implemented>

=item B<speed>: I<Not yet implemented>

=item B<strides>: I<Not yet implemented>

=back

=cut

sub fetch_latest {
	my ($self) = @_;

	my $packet = {
		error            => 0,
		device_name      => $self->{_device_name},
		firmware_id      => 0,
		firmware_version => 0,
		hardware_id      => 0,
		hardware_version => 0,
		battery_charge   => 0,
		heart_rate       => 0,
		new_beats        => [],
		distance         => 0,
		speed            => 0,
		strides          => 0,
	};

	my $input = $self->_fetch_packet();
	if (length($input) != 60) {
		$packet->{error} = 'TTY read yielded a '. length($input) .'-byte packet.';
		return $packet;
	}

	my @struct = unpack("CCCvCCvvCCCvvvvvvvvvvvvvvvCCCCCCvvCCCCCC", $input);

	# FIXME: Wasn't I supposed to try again if it's invalid?
	my $stx = shift @struct;
	my $msgid = shift @struct;
	my $dlc = shift @struct;
	my $etx = pop @struct;
	my $crc = pop @struct;
	unless ($stx == 0x02  &&  $msgid == 0x26  &&  $dlc == 0x37  &&  $etx == 0x03) {
		$packet->{error} = 'Packet not valid HxM format.';
		return $packet;
	}
	# FIXME: I always get CRC mismatches; disabling for now.
	#my $mycrc = crc8(substr($input, 3, 55));
	#unless ($crc == $mycrc) {
	#	$packet->{error} = 'Packet CRC mismatch.  Got '. $crc .', expected '. $mycrc .'.';
	#	return $packet;
	#}

	# FIXME: I don't know how to possibly implement the CRC in Perl.  I don't
	# even know how I could extract the payload from $input to feed to it!

	$packet->{firmware_id} = shift @struct;
	my $fv_major = shift @struct;
	my $fv_minor = shift @struct;
	$packet->{firmware_version} = $fv_major .'.'. $fv_minor;

	$packet->{hardware_id} = shift @struct;
	$packet->{hardware_version} = shift @struct;

	$packet->{battery_charge} = shift @struct;

	$packet->{heart_rate} = shift @struct;


	## Handle beat timestamps

	# Fetch from packet
	my $beatnumber = shift @struct;
	my @beattimes;
	for (my $i = 0; $i < 15; $i++) {
		# Remove the 15 timestamps from @struct, store in same
		# reverse-chronological order as source.
		push @beattimes, shift @struct;
	}

	# Beat number:     ABSOLUTE 0..255,   rolls over continuously
	# $self->{_last_beatnum} = -1  # at startup
	my $new_count = $beatnumber - $self->{_last_beatnum};
	$new_count = $new_count + 256  if $new_count < 0;
	$self->{_last_beatnum} = $beatnumber;

	# Beat timestamps: ABSOLUTE 0..65535, roll  over continuously
	for (my $i = 0; $i < $new_count; $i++) {
		my $new_time = shift @beattimes
			or last;
		last if scalar(@beattimes) <= 0;  # We need to look one earlier to calculate R-R.
		my $new_rr = $new_time - $beattimes[0];
		$new_rr = $new_rr + 65536  if $new_rr < 0;
		unshift @{ $packet->{new_beats} }, $new_rr;
	}

	# Dump 6 reserved characters.
	shift @struct;
	shift @struct;
	shift @struct;
	shift @struct;
	shift @struct;
	shift @struct;

	$packet->{distance} = shift @struct;
	$packet->{speed}    = shift @struct;
	$packet->{strides}  = shift @struct;

	return $packet;
}

# Just try getting 60 bytes out of the TTY, wait for them a second.
sub _fetch_packet {
	my ($self) = @_;

	# I can't think of an intelligent way to split packets properly...
	tcflush(fileno($self->_tty), TCIFLUSH);

	# fd_set to be used with select()
	my $readfds = '';
	vec($readfds, fileno($self->_tty), 1) = 1;

	# We should receive packets every second, so 1200ms should be plenty.
	my $timeout = 1.2;
	my $last_time = time;

	# It's not even funny how little I know what I'm doing in Perl I/O. :(
	my $input = '';
	while (($timeout > 0) && select($readfds, undef, undef, $timeout)) {
		if (sysread($self->_tty, $input, 60 - length($input), length($input))) {
			last if length($input) >= 60;
		}
	}

	# FIXME: How do I know if there was a fatal I/O error?
	return $input;
}

=back

=cut

1;
