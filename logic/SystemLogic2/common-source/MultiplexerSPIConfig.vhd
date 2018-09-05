library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MultiplexerConfigRecords.all;

entity MultiplexerSPIConfig is
	generic(
		ENABLE_INPUT_5    : boolean := false;
		ENABLE_INPUT_6    : boolean := false;
		ENABLE_STATISTICS : boolean := false);
	port(
		Clock_CI                        : in  std_logic;
		Reset_RI                        : in  std_logic;

		MultiplexerConfig_DO            : out tMultiplexerConfig;
		MultiplexerConfigInfoOut_DI     : in  tMultiplexerConfigInfoOut;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI          : in  unsigned(6 downto 0);
		ConfigParamAddress_DI           : in  unsigned(7 downto 0);
		ConfigParamInput_DI             : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI             : in  std_logic;
		MultiplexerConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity MultiplexerSPIConfig;

architecture Behavioral of MultiplexerSPIConfig is
	signal LatchMultiplexerReg_S                            : std_logic;
	signal MultiplexerOutput_DP, MultiplexerOutput_DN       : std_logic_vector(31 downto 0);
	signal MultiplexerConfigReg_DP, MultiplexerConfigReg_DN : tMultiplexerConfig;
begin
	MultiplexerConfig_DO            <= MultiplexerConfigReg_DP;
	MultiplexerConfigParamOutput_DO <= MultiplexerOutput_DP;

	LatchMultiplexerReg_S <= '1' when ConfigModuleAddress_DI = MULTIPLEXERCONFIG_MODULE_ADDRESS else '0';

	multiplexerIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, MultiplexerConfigReg_DP, MultiplexerConfigInfoOut_DI)
	begin
		MultiplexerConfigReg_DN <= MultiplexerConfigReg_DP;
		MultiplexerOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.Run_S =>
				MultiplexerConfigReg_DN.Run_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)       <= MultiplexerConfigReg_DP.Run_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.TimestampRun_S =>
				MultiplexerConfigReg_DN.TimestampRun_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                <= MultiplexerConfigReg_DP.TimestampRun_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.TimestampReset_S =>
				MultiplexerConfigReg_DN.TimestampReset_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                  <= MultiplexerConfigReg_DP.TimestampReset_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.ForceChipBiasEnable_S =>
				MultiplexerConfigReg_DN.ForceChipBiasEnable_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                       <= MultiplexerConfigReg_DP.ForceChipBiasEnable_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.DropInput1OnTransferStall_S =>
				MultiplexerConfigReg_DN.DropInput1OnTransferStall_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                             <= MultiplexerConfigReg_DP.DropInput1OnTransferStall_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.DropInput2OnTransferStall_S =>
				MultiplexerConfigReg_DN.DropInput2OnTransferStall_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                             <= MultiplexerConfigReg_DP.DropInput2OnTransferStall_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.DropInput3OnTransferStall_S =>
				MultiplexerConfigReg_DN.DropInput3OnTransferStall_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                             <= MultiplexerConfigReg_DP.DropInput3OnTransferStall_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.DropInput4OnTransferStall_S =>
				MultiplexerConfigReg_DN.DropInput4OnTransferStall_S <= ConfigParamInput_DI(0);
				MultiplexerOutput_DN(0)                             <= MultiplexerConfigReg_DP.DropInput4OnTransferStall_S;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.DropInput5OnTransferStall_S =>
				if ENABLE_INPUT_5 = true then
					MultiplexerConfigReg_DN.DropInput5OnTransferStall_S <= ConfigParamInput_DI(0);
					MultiplexerOutput_DN(0)                             <= MultiplexerConfigReg_DP.DropInput5OnTransferStall_S;
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.DropInput6OnTransferStall_S =>
				if ENABLE_INPUT_6 = true then
					MultiplexerConfigReg_DN.DropInput6OnTransferStall_S <= ConfigParamInput_DI(0);
					MultiplexerOutput_DN(0)                             <= MultiplexerConfigReg_DP.DropInput6OnTransferStall_S;
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.HasStatistics_S =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(0) <= '1';
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput1Dropped64_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput1Dropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput1Dropped32_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(31 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput1Dropped_D(31 downto 0));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput2Dropped64_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput2Dropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput2Dropped32_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(31 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput2Dropped_D(31 downto 0));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput3Dropped64_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput3Dropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput3Dropped32_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(31 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput3Dropped_D(31 downto 0));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput4Dropped64_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput4Dropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput4Dropped32_D =>
				if ENABLE_STATISTICS = true then
					MultiplexerOutput_DN(31 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput4Dropped_D(31 downto 0));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput5Dropped64_D =>
				if ENABLE_STATISTICS = true and ENABLE_INPUT_5 = true then
					MultiplexerOutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput5Dropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput5Dropped32_D =>
				if ENABLE_STATISTICS = true and ENABLE_INPUT_5 = true then
					MultiplexerOutput_DN(31 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput5Dropped_D(31 downto 0));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput6Dropped64_D =>
				if ENABLE_STATISTICS = true and ENABLE_INPUT_6 = true then
					MultiplexerOutput_DN(TRANSACTION_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput6Dropped_D(TRANSACTION_COUNTER_WIDTH - 1 downto 32));
				end if;

			when MULTIPLEXERCONFIG_PARAM_ADDRESSES.StatisticsInput6Dropped32_D =>
				if ENABLE_STATISTICS = true and ENABLE_INPUT_6 = true then
					MultiplexerOutput_DN(31 downto 0) <= std_logic_vector(MultiplexerConfigInfoOut_DI.StatisticsInput6Dropped_D(31 downto 0));
				end if;
			when others => null;
		end case;
	end process multiplexerIO;

	multiplexerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			MultiplexerOutput_DP <= (others => '0');

			MultiplexerConfigReg_DP <= tMultiplexerConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			MultiplexerOutput_DP <= MultiplexerOutput_DN;

			if LatchMultiplexerReg_S = '1' and ConfigLatchInput_SI = '1' then
				MultiplexerConfigReg_DP <= MultiplexerConfigReg_DN;
			end if;
		end if;
	end process multiplexerUpdate;
end architecture Behavioral;
