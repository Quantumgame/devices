library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.GenericAERConfigRecords.all;

entity GenericAERSPIConfig is
	generic(
		ENABLE_STATISTICS : boolean := false);
	port(
		Clock_CI                       : in  std_logic;
		Reset_RI                       : in  std_logic;

		GenericAERConfig_DO            : out tGenericAERConfig;
		GenericAERConfigInfoOut_DI     : in  tGenericAERConfigInfoOut;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI         : in  unsigned(6 downto 0);
		ConfigParamAddress_DI          : in  unsigned(7 downto 0);
		ConfigParamInput_DI            : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI            : in  std_logic;
		GenericAERConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity GenericAERSPIConfig;

architecture Behavioral of GenericAERSPIConfig is
	signal LatchGenericAERReg_S                           : std_logic;
	signal GenericAEROutput_DP, GenericAEROutput_DN       : std_logic_vector(31 downto 0);
	signal GenericAERConfigReg_DP, GenericAERConfigReg_DN : tGenericAERConfig;
begin
	GenericAERConfig_DO            <= GenericAERConfigReg_DP;
	GenericAERConfigParamOutput_DO <= GenericAEROutput_DP;

	LatchGenericAERReg_S <= '1' when ConfigModuleAddress_DI = GENERICAERCONFIG_MODULE_ADDRESS else '0';

	aerIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, GenericAERConfigReg_DP, GenericAERConfigInfoOut_DI)
	begin
		GenericAERConfigReg_DN <= GenericAERConfigReg_DP;
		GenericAEROutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when GENERICAERCONFIG_PARAM_ADDRESSES.Run_S =>
				GenericAERConfigReg_DN.Run_S <= ConfigParamInput_DI(0);
				GenericAEROutput_DN(0)       <= GenericAERConfigReg_DP.Run_S;

			when GENERICAERCONFIG_PARAM_ADDRESSES.AckDelay_D =>
				GenericAERConfigReg_DN.AckDelay_D                       <= unsigned(ConfigParamInput_DI(tGenericAERConfig.AckDelay_D'range));
				GenericAEROutput_DN(tGenericAERConfig.AckDelay_D'range) <= std_logic_vector(GenericAERConfigReg_DP.AckDelay_D);

			when GENERICAERCONFIG_PARAM_ADDRESSES.AckExtension_D =>
				GenericAERConfigReg_DN.AckExtension_D                       <= unsigned(ConfigParamInput_DI(tGenericAERConfig.AckExtension_D'range));
				GenericAEROutput_DN(tGenericAERConfig.AckExtension_D'range) <= std_logic_vector(GenericAERConfigReg_DP.AckExtension_D);

			when GENERICAERCONFIG_PARAM_ADDRESSES.WaitOnTransferStall_S =>
				GenericAERConfigReg_DN.WaitOnTransferStall_S <= ConfigParamInput_DI(0);
				GenericAEROutput_DN(0)                       <= GenericAERConfigReg_DP.WaitOnTransferStall_S;

			when GENERICAERCONFIG_PARAM_ADDRESSES.ExternalAERControl_S =>
				GenericAERConfigReg_DN.ExternalAERControl_S <= ConfigParamInput_DI(0);
				GenericAEROutput_DN(0)                      <= GenericAERConfigReg_DP.ExternalAERControl_S;

			when GENERICAERCONFIG_PARAM_ADDRESSES.HasStatistics_S =>
				if ENABLE_STATISTICS = true then
					GenericAEROutput_DN(0) <= '1';
				end if;

			when GENERICAERCONFIG_PARAM_ADDRESSES.StatisticsEvents64_D =>
				if ENABLE_STATISTICS = true then
					GenericAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(GenericAERConfigInfoOut_DI.StatisticsEvents_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when GENERICAERCONFIG_PARAM_ADDRESSES.StatisticsEvents32_D =>
				if ENABLE_STATISTICS = true then
					GenericAEROutput_DN(31 downto 0) <= std_logic_vector(GenericAERConfigInfoOut_DI.StatisticsEvents_D(31 downto 0));
				end if;

			when GENERICAERCONFIG_PARAM_ADDRESSES.StatisticsEventsDropped64_D =>
				if ENABLE_STATISTICS = true then
					GenericAEROutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(GenericAERConfigInfoOut_DI.StatisticsEventsDropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when GENERICAERCONFIG_PARAM_ADDRESSES.StatisticsEventsDropped32_D =>
				if ENABLE_STATISTICS = true then
					GenericAEROutput_DN(31 downto 0) <= std_logic_vector(GenericAERConfigInfoOut_DI.StatisticsEventsDropped_D(31 downto 0));
				end if;

			when others => null;
		end case;
	end process aerIO;

	aerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			GenericAEROutput_DP <= (others => '0');

			GenericAERConfigReg_DP <= tGenericAERConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			GenericAEROutput_DP <= GenericAEROutput_DN;

			if LatchGenericAERReg_S = '1' and ConfigLatchInput_SI = '1' then
				GenericAERConfigReg_DP <= GenericAERConfigReg_DN;
			end if;
		end if;
	end process aerUpdate;
end architecture Behavioral;
