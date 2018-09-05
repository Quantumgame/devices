library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Settings.USB_CLOCK_FREQ_REAL;

package FX3ConfigRecords is
	constant FX3CONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(9, 7);

	type tFX3ConfigParamAddresses is record
		Run_S              : unsigned(7 downto 0);
		EarlyPacketDelay_D : unsigned(7 downto 0);
	end record tFX3ConfigParamAddresses;

	constant FX3CONFIG_PARAM_ADDRESSES : tFX3ConfigParamAddresses := (
		Run_S              => to_unsigned(0, 8),
		EarlyPacketDelay_D => to_unsigned(1, 8));

	constant USB_CLOCK_FREQ_SIZE   : integer := integer(ceil(log2(real(USB_CLOCK_FREQ_REAL + 1.0))));
	constant USB_EARLY_PACKET_SIZE : integer := 20 + USB_CLOCK_FREQ_SIZE; -- Up to about one second.

	type tFX3Config is record
		Run_S              : std_logic;
		EarlyPacketDelay_D : unsigned(USB_EARLY_PACKET_SIZE - 1 downto 0);
	end record tFX3Config;

	constant tFX3ConfigDefault : tFX3Config := (
		Run_S              => '1',
		EarlyPacketDelay_D => to_unsigned(integer(1000.0 * USB_CLOCK_FREQ_REAL), tFX3Config.EarlyPacketDelay_D'length));
end package FX3ConfigRecords;
