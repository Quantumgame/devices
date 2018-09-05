library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Settings.ADC_CHAN_NUMBER;


package ADCConfigRecords is
	constant ADCCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(10, 7);

	type tADCConfigParamAddresses is record
		Run_S             : unsigned(7 downto 0);
		ADCChanEn_S       : unsigned(7 downto 0);
		ADCSamplingFreq_D : unsigned(7 downto 0);
	end record tADCConfigParamAddresses;

	constant ADCCONFIG_PARAM_ADDRESSES : tADCConfigParamAddresses := (
		Run_S             => to_unsigned(0, 8),
		ADCChanEn_S       => to_unsigned(1, 8),
		ADCSamplingFreq_D => to_unsigned(2, 8));
		-- 3: See ADCSTATUS_PARAM_ADDRESSES
		-- 4: See ADCSTATUS_PARAM_ADDRESSES

	type tADCConfig is record
		Run_S             : std_logic;
		ADCChanEn_S       : std_logic_vector(ADC_CHAN_NUMBER - 1 downto 0); -- Enable up to 4 ADCs.
		ADCSamplingFreq_D : std_logic;                                      -- 0 - 16kHz, 1 - 44.1kHz
	end record tADCConfig;

	constant tADCConfigDefault : tADCConfig := (
		Run_S             => '0',
		ADCChanEn_S       => (others => '1'),
		ADCSamplingFreq_D => '0');
end package ADCConfigRecords;
