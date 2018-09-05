library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Settings.USB_CLOCK_FREQ_REAL;

package FX2ConfigRecords is
	constant FX2CONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(9, 7);

	type tFX2ConfigParamAddresses is record
		Run_S              : unsigned(7 downto 0);
		EarlyPacketDelay_D : unsigned(7 downto 0);
	end record tFX2ConfigParamAddresses;

	constant FX2CONFIG_PARAM_ADDRESSES : tFX2ConfigParamAddresses := (
		Run_S              => to_unsigned(0, 8),
		EarlyPacketDelay_D => to_unsigned(1, 8));

	constant USB_CLOCK_FREQ_SIZE : integer := integer(ceil(log2(real(USB_CLOCK_FREQ_REAL + 1.0))));
	constant USB_EARLY_PACKET_SIZE : integer := 20 + USB_CLOCK_FREQ_SIZE; -- Up to about one second.

	type tFX2Config is record
		Run_S              : std_logic;
		EarlyPacketDelay_D : unsigned(USB_EARLY_PACKET_SIZE - 1 downto 0);
	end record tFX2Config;

	constant tFX2ConfigDefault : tFX2Config := (
		Run_S              => '1',
		EarlyPacketDelay_D => to_unsigned(integer(1000.0 * USB_CLOCK_FREQ_REAL), tFX2Config.EarlyPacketDelay_D'length));
end package FX2ConfigRecords;
