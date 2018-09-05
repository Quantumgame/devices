library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package InvenSenseMicConfigRecords is
	constant INVENSENSEMICCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(7, 7);

	type tInvenSenseMicConfigParamAddresses is record
		Run_S             : unsigned(7 downto 0);
		SampleFrequency_D : unsigned(7 downto 0);
	end record tInvenSenseMicConfigParamAddresses;

	constant INVENSENSEMICCONFIG_PARAM_ADDRESSES : tInvenSenseMicConfigParamAddresses := (
		Run_S             => to_unsigned(0, 8),
		SampleFrequency_D => to_unsigned(1, 8));

	type tInvenSenseMicConfig is record
		Run_S          : std_logic;
		SampleCycles_D : unsigned(7 downto 0);
	end record tInvenSenseMicConfig;

	constant tInvenSenseMicConfigDefault : tInvenSenseMicConfig := (
		Run_S          => '0',
		SampleCycles_D => to_unsigned(32, tInvenSenseMicConfig.SampleCycles_D'length));
	-- Default to 48KHz sampling frequency.
end package InvenSenseMicConfigRecords;
