library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Settings.ADC_DATA_LENGTH;
use work.ADCConfigRecords.ADCCONFIG_MODULE_ADDRESS;


package ADCStatusRecords is
	constant ADCSTATUS_MODULE_ADDRESS : unsigned(6 downto 0) := ADCCONFIG_MODULE_ADDRESS;

	type tADCStatusParamAddresses is record
		NSamplesDropped_D : unsigned(7 downto 0);
		Reserved_S        : unsigned(7 downto 0);
	end record tADCStatusParamAddresses;

	constant ADCSTATUS_PARAM_ADDRESSES : tADCStatusParamAddresses := (
		-- 0: See ADCCONFIG_PARAM_ADDRESSES
		-- 1: See ADCCONFIG_PARAM_ADDRESSES
		-- 2: See ADCCONFIG_PARAM_ADDRESSES
		NSamplesDropped_D => to_unsigned(3, 8),
		Reserved_S        => to_unsigned(4, 8));

	type tADCStatus is record
		NSamplesDropped_D : unsigned(31 downto 0);
		Reserved_S        : std_logic;
	end record tADCStatus;

	constant tADCStatusDefault : tADCStatus := (
		NSamplesDropped_D  => (others => '0'),
		Reserved_S         => '1');
end package ADCStatusRecords;
