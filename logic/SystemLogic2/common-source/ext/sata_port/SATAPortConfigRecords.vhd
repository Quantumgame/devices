library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package SATAPortConfigRecords is
	constant SATAPORTCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(16, 7);

	constant SATAPORTCONFIG_COUNTER_WIDTH : integer := 38;

	type tSATAPortConfigParamAddresses is record
		-- Output (info).
		PCSLossOfSignal_D                           : unsigned(7 downto 0);
		PCSLossOfSignalCount64_D                    : unsigned(7 downto 0);
		PCSLossOfSignalCount32_D                    : unsigned(7 downto 0);
		PCSLossOfRXCDRLock_D                        : unsigned(7 downto 0);
		PCSLossOfRXCDRLockCount64_D                 : unsigned(7 downto 0);
		PCSLossOfRXCDRLockCount32_D                 : unsigned(7 downto 0);
		PCSLossOfTXPLLLock_D                        : unsigned(7 downto 0);
		PCSLossOfTXPLLLockCount64_D                 : unsigned(7 downto 0);
		PCSLossOfTXPLLLockCount32_D                 : unsigned(7 downto 0);
		PCSLossOfSync_D                             : unsigned(7 downto 0);
		PCSLossOfSyncCount64_D                      : unsigned(7 downto 0);
		PCSLossOfSyncCount32_D                      : unsigned(7 downto 0);
		PCSDisparityError64_D                       : unsigned(7 downto 0);
		PCSDisparityError32_D                       : unsigned(7 downto 0);
		PCSCodeViolationError64_D                   : unsigned(7 downto 0);
		PCSCodeViolationError32_D                   : unsigned(7 downto 0);
		PCSClockToleranceCompensationUnderrun64_D   : unsigned(7 downto 0);
		PCSClockToleranceCompensationUnderrun32_D   : unsigned(7 downto 0);
		PCSClockToleranceCompensationOverrun64_D    : unsigned(7 downto 0);
		PCSClockToleranceCompensationOverrun32_D    : unsigned(7 downto 0);
		PCSClockToleranceCompensationSKInserted64_D : unsigned(7 downto 0);
		PCSClockToleranceCompensationSKInserted32_D : unsigned(7 downto 0);
		PCSClockToleranceCompensationSKDeleted64_D  : unsigned(7 downto 0);
		PCSClockToleranceCompensationSKDeleted32_D  : unsigned(7 downto 0);
		TXClockCorrection64_D                       : unsigned(7 downto 0);
		TXClockCorrection32_D                       : unsigned(7 downto 0);
		TXHandshake64_D                             : unsigned(7 downto 0);
		TXHandshake32_D                             : unsigned(7 downto 0);
		TXData64_D                                  : unsigned(7 downto 0);
		TXData32_D                                  : unsigned(7 downto 0);
		TXIdle64_D                                  : unsigned(7 downto 0);
		TXIdle32_D                                  : unsigned(7 downto 0);
		RXClockCorrectionSymbols64_D                : unsigned(7 downto 0);
		RXClockCorrectionSymbols32_D                : unsigned(7 downto 0);
		RXCommaSymbols64_D                          : unsigned(7 downto 0);
		RXCommaSymbols32_D                          : unsigned(7 downto 0);
		RXDataWords64_D                             : unsigned(7 downto 0);
		RXDataWords32_D                             : unsigned(7 downto 0);
		RXDataHandshake64_D                         : unsigned(7 downto 0);
		RXDataHandshake32_D                         : unsigned(7 downto 0);
		RXDataIdle64_D                              : unsigned(7 downto 0);
		RXDataIdle32_D                              : unsigned(7 downto 0);
		RXDataData64_D                              : unsigned(7 downto 0);
		RXDataData32_D                              : unsigned(7 downto 0);
		RXDataDropped64_D                           : unsigned(7 downto 0);
		RXDataDropped32_D                           : unsigned(7 downto 0);
		HandshakeComplete_D                         : unsigned(7 downto 0);
		HandshakeVersionMismatch_D                  : unsigned(7 downto 0);
		HandshakeResetCount64_D                     : unsigned(7 downto 0);
		HandshakeResetCount32_D                     : unsigned(7 downto 0);
		RXSymbols64_D                               : unsigned(7 downto 0);
		RXSymbols32_D                               : unsigned(7 downto 0);
		-- Input (params).
		ClockCorrectionInterval_D                   : unsigned(7 downto 0);
		HandshakeConsecutiveNeeded_D                : unsigned(7 downto 0);
		IdleDataPart_D                              : unsigned(7 downto 0);
	end record tSATAPortConfigParamAddresses;

	constant SATAPORTCONFIG_PARAM_ADDRESSES : tSATAPortConfigParamAddresses := (
		-- Output starts at 0.
		PCSLossOfSignal_D                           => to_unsigned(0, 8),
		PCSLossOfSignalCount64_D                    => to_unsigned(1, 8),
		PCSLossOfSignalCount32_D                    => to_unsigned(2, 8),
		PCSLossOfRXCDRLock_D                        => to_unsigned(3, 8),
		PCSLossOfRXCDRLockCount64_D                 => to_unsigned(4, 8),
		PCSLossOfRXCDRLockCount32_D                 => to_unsigned(5, 8),
		PCSLossOfTXPLLLock_D                        => to_unsigned(6, 8),
		PCSLossOfTXPLLLockCount64_D                 => to_unsigned(7, 8),
		PCSLossOfTXPLLLockCount32_D                 => to_unsigned(8, 8),
		PCSLossOfSync_D                             => to_unsigned(9, 8),
		PCSLossOfSyncCount64_D                      => to_unsigned(10, 8),
		PCSLossOfSyncCount32_D                      => to_unsigned(11, 8),
		PCSDisparityError64_D                       => to_unsigned(12, 8),
		PCSDisparityError32_D                       => to_unsigned(13, 8),
		PCSCodeViolationError64_D                   => to_unsigned(14, 8),
		PCSCodeViolationError32_D                   => to_unsigned(15, 8),
		PCSClockToleranceCompensationUnderrun64_D   => to_unsigned(16, 8),
		PCSClockToleranceCompensationUnderrun32_D   => to_unsigned(17, 8),
		PCSClockToleranceCompensationOverrun64_D    => to_unsigned(18, 8),
		PCSClockToleranceCompensationOverrun32_D    => to_unsigned(19, 8),
		PCSClockToleranceCompensationSKInserted64_D => to_unsigned(20, 8),
		PCSClockToleranceCompensationSKInserted32_D => to_unsigned(21, 8),
		PCSClockToleranceCompensationSKDeleted64_D  => to_unsigned(22, 8),
		PCSClockToleranceCompensationSKDeleted32_D  => to_unsigned(23, 8),
		TXClockCorrection64_D                       => to_unsigned(24, 8),
		TXClockCorrection32_D                       => to_unsigned(25, 8),
		TXHandshake64_D                             => to_unsigned(26, 8),
		TXHandshake32_D                             => to_unsigned(27, 8),
		TXData64_D                                  => to_unsigned(28, 8),
		TXData32_D                                  => to_unsigned(29, 8),
		TXIdle64_D                                  => to_unsigned(30, 8),
		TXIdle32_D                                  => to_unsigned(31, 8),
		RXClockCorrectionSymbols64_D                => to_unsigned(32, 8),
		RXClockCorrectionSymbols32_D                => to_unsigned(33, 8),
		RXCommaSymbols64_D                          => to_unsigned(34, 8),
		RXCommaSymbols32_D                          => to_unsigned(35, 8),
		RXDataWords64_D                             => to_unsigned(36, 8),
		RXDataWords32_D                             => to_unsigned(37, 8),
		RXDataHandshake64_D                         => to_unsigned(38, 8),
		RXDataHandshake32_D                         => to_unsigned(39, 8),
		RXDataIdle64_D                              => to_unsigned(40, 8),
		RXDataIdle32_D                              => to_unsigned(41, 8),
		RXDataData64_D                              => to_unsigned(42, 8),
		RXDataData32_D                              => to_unsigned(43, 8),
		RXDataDropped64_D                           => to_unsigned(44, 8),
		RXDataDropped32_D                           => to_unsigned(45, 8),
		HandshakeComplete_D                         => to_unsigned(46, 8),
		HandshakeVersionMismatch_D                  => to_unsigned(47, 8),
		HandshakeResetCount64_D                     => to_unsigned(48, 8),
		HandshakeResetCount32_D                     => to_unsigned(49, 8),
		RXSymbols64_D                               => to_unsigned(50, 8),
		RXSymbols32_D                               => to_unsigned(51, 8),
		-- Input starts at 64.
		ClockCorrectionInterval_D                   => to_unsigned(64, 8),
		HandshakeConsecutiveNeeded_D                => to_unsigned(65, 8),
		IdleDataPart_D                              => to_unsigned(66, 8));

	type tSATAPortConfigOut is record
		PCSLossOfSignal_D                         : std_logic;
		PCSLossOfSignalCount_D                    : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSLossOfRXCDRLock_D                      : std_logic;
		PCSLossOfRXCDRLockCount_D                 : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSLossOfTXPLLLock_D                      : std_logic;
		PCSLossOfTXPLLLockCount_D                 : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSLossOfSync_D                           : std_logic;
		PCSLossOfSyncCount_D                      : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSDisparityError_D                       : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSCodeViolationError_D                   : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSClockToleranceCompensationUnderrun_D   : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSClockToleranceCompensationOverrun_D    : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSClockToleranceCompensationSKInserted_D : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		PCSClockToleranceCompensationSKDeleted_D  : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		TXClockCorrection_D                       : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		TXHandshake_D                             : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		TXData_D                                  : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		TXIdle_D                                  : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXClockCorrectionSymbols_D                : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXCommaSymbols_D                          : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXDataWords_D                             : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXDataHandshake_D                         : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXDataIdle_D                              : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXDataData_D                              : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXDataDropped_D                           : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		HandshakeComplete_D                       : std_logic;
		HandshakeVersionMismatch_D                : std_logic;
		HandshakeResetCount_D                     : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
		RXSymbols_D                               : unsigned(SATAPORTCONFIG_COUNTER_WIDTH - 1 downto 0);
	end record tSATAPortConfigOut;

	constant tSATAPortConfigOutDefault : tSATAPortConfigOut := (
		PCSLossOfSignal_D                         => '0',
		PCSLossOfSignalCount_D                    => (others => '0'),
		PCSLossOfRXCDRLock_D                      => '0',
		PCSLossOfRXCDRLockCount_D                 => (others => '0'),
		PCSLossOfTXPLLLock_D                      => '0',
		PCSLossOfTXPLLLockCount_D                 => (others => '0'),
		PCSLossOfSync_D                           => '0',
		PCSLossOfSyncCount_D                      => (others => '0'),
		PCSDisparityError_D                       => (others => '0'),
		PCSCodeViolationError_D                   => (others => '0'),
		PCSClockToleranceCompensationUnderrun_D   => (others => '0'),
		PCSClockToleranceCompensationOverrun_D    => (others => '0'),
		PCSClockToleranceCompensationSKInserted_D => (others => '0'),
		PCSClockToleranceCompensationSKDeleted_D  => (others => '0'),
		TXClockCorrection_D                       => (others => '0'),
		TXHandshake_D                             => (others => '0'),
		TXData_D                                  => (others => '0'),
		TXIdle_D                                  => (others => '0'),
		RXClockCorrectionSymbols_D                => (others => '0'),
		RXCommaSymbols_D                          => (others => '0'),
		RXDataWords_D                             => (others => '0'),
		RXDataHandshake_D                         => (others => '0'),
		RXDataIdle_D                              => (others => '0'),
		RXDataData_D                              => (others => '0'),
		RXDataDropped_D                           => (others => '0'),
		HandshakeComplete_D                       => '0',
		HandshakeVersionMismatch_D                => '0',
		HandshakeResetCount_D                     => (others => '0'),
		RXSymbols_D                               => (others => '0'));

	type tSATAPortConfigIn is record
		ClockCorrectionInterval_D    : unsigned(15 downto 0);
		HandshakeConsecutiveNeeded_D : unsigned(15 downto 0);
		IdleDataPart_D               : std_logic_vector(15 downto 0);
	end record tSATAPortConfigIn;

	constant tSATAPortConfigInDefault : tSATAPortConfigIn := (
		ClockCorrectionInterval_D    => to_unsigned(1000, 16),
		HandshakeConsecutiveNeeded_D => to_unsigned(100, 16),
		IdleDataPart_D               => "0101010101010101");
end package SATAPortConfigRecords;
