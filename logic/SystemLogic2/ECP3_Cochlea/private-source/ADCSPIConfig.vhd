library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.ADCConfigRecords.all;
use work.ADCStatusRecords.all;

entity ADCSPIConfig is
	port(
		Clock_CI                : in  std_logic;
		Reset_RI                : in  std_logic;
		ADCConfig_DO            : out tADCConfig;
		ADCStatus_DI            : in  tADCStatus;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI  : in  unsigned(6 downto 0);
		ConfigParamAddress_DI   : in  unsigned(7 downto 0);
		ConfigParamInput_DI     : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI     : in  std_logic;
		ADCConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity ADCSPIConfig;

architecture Behavioral of ADCSPIConfig is
	signal LatchADCReg_S                    : std_logic;
	signal ADCInput_DP, ADCInput_DN         : std_logic_vector(31 downto 0);
	signal ADCOutput_DP, ADCOutput_DN       : std_logic_vector(31 downto 0);
	signal ADCConfigReg_DP, ADCConfigReg_DN : tADCConfig;
begin
	ADCConfig_DO            <= ADCConfigReg_DP;
	ADCConfigParamOutput_DO <= ADCOutput_DP;

	LatchADCReg_S <= '1' when ConfigModuleAddress_DI = ADCCONFIG_MODULE_ADDRESS else '0';

	ADCIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, ADCInput_DP, ADCConfigReg_DP, ADCStatus_DI.NSamplesDropped_D, ADCStatus_DI.Reserved_S)
	begin
		ADCConfigReg_DN <= ADCConfigReg_DP;
		ADCInput_DN     <= ConfigParamInput_DI;
		ADCOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when ADCCONFIG_PARAM_ADDRESSES.Run_S =>
				ADCConfigReg_DN.Run_S <= ADCInput_DP(0);
				ADCOutput_DN(0)       <= ADCConfigReg_DP.Run_S;

			when ADCCONFIG_PARAM_ADDRESSES.ADCChanEn_S =>
				ADCConfigReg_DN.ADCChanEn_S                      <= ADCInput_DP(tADCConfig.ADCChanEn_S'range);
				ADCOutput_DN(tADCConfig.ADCChanEn_S'range)       <= ADCConfigReg_DP.ADCChanEn_S;

			when ADCCONFIG_PARAM_ADDRESSES.ADCSamplingFreq_D =>
				ADCConfigReg_DN.ADCSamplingFreq_D                <= ADCInput_DP(0);
				ADCOutput_DN(0)                                  <= ADCConfigReg_DP.ADCSamplingFreq_D;

			when ADCSTATUS_PARAM_ADDRESSES.NSamplesDropped_D =>
				ADCOutput_DN(tADCStatus.NSamplesDropped_D'range) <= std_logic_vector(ADCStatus_DI.NSamplesDropped_D);

			when ADCSTATUS_PARAM_ADDRESSES.Reserved_S =>
				ADCOutput_DN(0)                                  <= ADCStatus_DI.Reserved_S;

			when others => null;
		end case;
	end process ADCIO;

	ADCUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			ADCInput_DP  <= (others => '0');
			ADCOutput_DP <= (others => '0');

			ADCConfigReg_DP <= tADCConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			ADCInput_DP  <= ADCInput_DN;
			ADCOutput_DP <= ADCOutput_DN;
			if LatchADCReg_S = '1' and ConfigLatchInput_SI = '1' then
				ADCConfigReg_DP <= ADCConfigReg_DN;
			end if;
		end if;
	end process ADCUpdate;
end architecture Behavioral;
