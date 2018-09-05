library ieee;
use ieee.std_logic_1164.all;

entity LogicClockSynchronizer is
	port(
		LogicClock_CI          : in  std_logic;
		LogicReset_RI          : in  std_logic;

		-- Signals to synchronize and their synchronized counterparts.
		SPISlaveSelect_SBI     : in  std_logic;
		SPISlaveSelectSync_SBO : out std_logic;
		SPIClock_CI            : in  std_logic;
		SPIClockSync_CO        : out std_logic;
		SPIMOSI_DI             : in  std_logic;
		SPIMOSISync_DO         : out std_logic;
		DVSAERReq_SBI          : in  std_logic;
		DVSAERReqSync_SBO      : out std_logic;
		IMUInterrupt_SI        : in  std_logic;
		IMUInterruptSync_SO    : out std_logic;
		SyncInClock_CI         : in  std_logic;
		SyncInClockSync_CO     : out std_logic;
		SyncInSignal_SI        : in  std_logic;
		SyncInSignalSync_SO    : out std_logic;
		SyncInSignal1_SI       : in  std_logic;
		SyncInSignal1Sync_SO   : out std_logic;
		SyncInSignal2_SI       : in  std_logic;
		SyncInSignal2Sync_SO   : out std_logic);
end LogicClockSynchronizer;

architecture Structural of LogicClockSynchronizer is
begin
	-- Ensure synchronization of FX2/FX3 inputs related to logic control.
	syncSPISlaveSelect : entity work.DFFSynchronizer
		generic map(
			RESET_VALUE => '1')         -- active-low signal
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SPISlaveSelect_SBI,
			SyncedSignal_SO(0) => SPISlaveSelectSync_SBO);

	syncSPIClock : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SPIClock_CI,
			SyncedSignal_SO(0) => SPIClockSync_CO);

	syncSPIMOSI : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SPIMOSI_DI,
			SyncedSignal_SO(0) => SPIMOSISync_DO);

	syncDVSAERReq : entity work.DFFSynchronizer
		generic map(
			RESET_VALUE => '1')         -- active-low signal
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => DVSAERReq_SBI,
			SyncedSignal_SO(0) => DVSAERReqSync_SBO);

	syncIMUInterrupt : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => IMUInterrupt_SI,
			SyncedSignal_SO(0) => IMUInterruptSync_SO);

	syncSyncInClock : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SyncInClock_CI,
			SyncedSignal_SO(0) => SyncInClockSync_CO);

	syncSyncInSignal : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SyncInSignal_SI,
			SyncedSignal_SO(0) => SyncInSignalSync_SO);

	syncSyncInSignal1 : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SyncInSignal1_SI,
			SyncedSignal_SO(0) => SyncInSignal1Sync_SO);

	syncSyncInSignal2 : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => LogicClock_CI,
			Reset_RI           => LogicReset_RI,
			SignalToSync_SI(0) => SyncInSignal2_SI,
			SyncedSignal_SO(0) => SyncInSignal2Sync_SO);
end Structural;
