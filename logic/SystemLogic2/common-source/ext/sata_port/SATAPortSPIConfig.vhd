library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.SATAPortConfigRecords.all;

entity SATAPortSPIConfig is
	port(
		Clock_CI                     : in  std_logic;
		Reset_RI                     : in  std_logic;

		SATAPortConfigOut_DI         : in  tSATAPortConfigOut;
		SATAPortConfigIn_DO          : out tSATAPortConfigIn;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI       : in  unsigned(6 downto 0);
		ConfigParamAddress_DI        : in  unsigned(7 downto 0);
		ConfigParamInput_DI          : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI          : in  std_logic;
		SATAPortConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity SATAPortSPIConfig;

architecture Behavioral of SATAPortSPIConfig is
	signal LatchSATAPortReg_S                               : std_logic;
	signal SATAPortInput_DP, SATAPortInput_DN               : std_logic_vector(31 downto 0);
	signal SATAPortOutput_DP, SATAPortOutput_DN             : std_logic_vector(31 downto 0);
	signal SATAPortConfigInReg_DP, SATAPortConfigInReg_DN   : tSATAPortConfigIn;
	signal SATAPortConfigOutReg_DP, SATAPortConfigOutReg_DN : tSATAPortConfigOut;
begin
	SATAPortConfigIn_DO          <= SATAPortConfigInReg_DP;
	SATAPortConfigParamOutput_DO <= SATAPortOutput_DP;

	LatchSATAPortReg_S <= '1' when ConfigModuleAddress_DI = SATAPORTCONFIG_MODULE_ADDRESS else '0';

	sataPortIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, SATAPortInput_DP, SATAPortConfigInReg_DP, SATAPortConfigOutReg_DP, SATAPortConfigOut_DI)
	begin
		SATAPortConfigInReg_DN  <= SATAPortConfigInReg_DP;
		SATAPortConfigOutReg_DN <= SATAPortConfigOut_DI;
		SATAPortInput_DN        <= ConfigParamInput_DI;
		SATAPortOutput_DN       <= (others => '0');

		case ConfigParamAddress_DI is
			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfSignal_D =>
				SATAPortOutput_DN(0) <= SATAPortConfigOutReg_DP.PCSLossOfSignal_D;

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfSignalCount64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfSignalCount_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfSignalCount32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfSignalCount_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfRXCDRLock_D =>
				SATAPortOutput_DN(0) <= SATAPortConfigOutReg_DP.PCSLossOfRXCDRLock_D;

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfRXCDRLockCount64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfRXCDRLockCount_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfRXCDRLockCount32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfRXCDRLockCount_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfTXPLLLock_D =>
				SATAPortOutput_DN(0) <= SATAPortConfigOutReg_DP.PCSLossOfTXPLLLock_D;

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfTXPLLLockCount64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfTXPLLLockCount_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfTXPLLLockCount32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfTXPLLLockCount_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfSync_D =>
				SATAPortOutput_DN(0) <= SATAPortConfigOutReg_DP.PCSLossOfSync_D;

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfSyncCount64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfSyncCount_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSLossOfSyncCount32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSLossOfSyncCount_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSDisparityError64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSDisparityError_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSDisparityError32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSDisparityError_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSCodeViolationError64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSCodeViolationError_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSCodeViolationError32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSCodeViolationError_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationUnderrun64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationUnderrun_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationUnderrun32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationUnderrun_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationOverrun64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationOverrun_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationOverrun32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationOverrun_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationSKInserted64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationSKInserted_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationSKInserted32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationSKInserted_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationSKDeleted64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationSKDeleted_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.PCSClockToleranceCompensationSKDeleted32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.PCSClockToleranceCompensationSKDeleted_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXClockCorrection64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXClockCorrection_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXClockCorrection32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXClockCorrection_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXHandshake64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXHandshake_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXHandshake32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXHandshake_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXData64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXData_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXData32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXData_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXIdle64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXIdle_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.TXIdle32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.TXIdle_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXClockCorrectionSymbols64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXClockCorrectionSymbols_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXClockCorrectionSymbols32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXClockCorrectionSymbols_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXCommaSymbols64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXCommaSymbols_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXCommaSymbols32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXCommaSymbols_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataWords64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataWords_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataWords32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataWords_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataHandshake64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataHandshake_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataHandshake32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataHandshake_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataIdle64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataIdle_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataIdle32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataIdle_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataData64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataData_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataData32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataData_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataDropped64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataDropped_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXDataDropped32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXDataDropped_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.HandshakeComplete_D =>
				SATAPortOutput_DN(0) <= SATAPortConfigOutReg_DP.HandshakeComplete_D;

			when SATAPORTCONFIG_PARAM_ADDRESSES.HandshakeVersionMismatch_D =>
				SATAPortOutput_DN(0) <= SATAPortConfigOutReg_DP.HandshakeVersionMismatch_D;

			when SATAPORTCONFIG_PARAM_ADDRESSES.HandshakeResetCount64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.HandshakeResetCount_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.HandshakeResetCount32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.HandshakeResetCount_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXSymbols64_D =>
				SATAPortOutput_DN(SATAPORTCONFIG_COUNTER_WIDTH - 1 - 32 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXSymbols_D(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 32));

			when SATAPORTCONFIG_PARAM_ADDRESSES.RXSymbols32_D =>
				SATAPortOutput_DN(31 downto 0) <= std_logic_vector(SATAPortConfigOutReg_DP.RXSymbols_D(31 downto 0));

			when SATAPORTCONFIG_PARAM_ADDRESSES.ClockCorrectionInterval_D =>
				SATAPortConfigInReg_DN.ClockCorrectionInterval_D                     <= unsigned(SATAPortInput_DP(tSATAPortConfigIn.ClockCorrectionInterval_D'range));
				SATAPortOutput_DN(tSATAPortConfigIn.ClockCorrectionInterval_D'range) <= std_logic_vector(SATAPortConfigInReg_DP.ClockCorrectionInterval_D);

			when SATAPORTCONFIG_PARAM_ADDRESSES.HandshakeConsecutiveNeeded_D =>
				SATAPortConfigInReg_DN.HandshakeConsecutiveNeeded_D                     <= unsigned(SATAPortInput_DP(tSATAPortConfigIn.HandshakeConsecutiveNeeded_D'range));
				SATAPortOutput_DN(tSATAPortConfigIn.HandshakeConsecutiveNeeded_D'range) <= std_logic_vector(SATAPortConfigInReg_DP.HandshakeConsecutiveNeeded_D);

			when SATAPORTCONFIG_PARAM_ADDRESSES.IdleDataPart_D =>
				SATAPortConfigInReg_DN.IdleDataPart_D                     <= SATAPortInput_DP(tSATAPortConfigIn.IdleDataPart_D'range);
				SATAPortOutput_DN(tSATAPortConfigIn.IdleDataPart_D'range) <= SATAPortConfigInReg_DP.IdleDataPart_D;

			when others => null;
		end case;
	end process sataPortIO;

	sataPortUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			SATAPortInput_DP  <= (others => '0');
			SATAPortOutput_DP <= (others => '0');

			SATAPortConfigInReg_DP <= tSATAPortConfigInDefault;

			SATAPortConfigOutReg_DP <= tSATAPortConfigOutDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			SATAPortInput_DP  <= SATAPortInput_DN;
			SATAPortOutput_DP <= SATAPortOutput_DN;

			if LatchSATAPortReg_S = '1' and ConfigLatchInput_SI = '1' then
				SATAPortConfigInReg_DP <= SATAPortConfigInReg_DN;
			end if;

			SATAPortConfigOutReg_DP <= SATAPortConfigOutReg_DN;
		end if;
	end process sataPortUpdate;
end architecture Behavioral;
