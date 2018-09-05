library ieee;
use ieee.std_logic_1164.all;

entity SATAPortStatusClockSynchronizer is
	port(
		PCSTXClock_CI                                  : in  std_logic;
		Reset_RI                                       : in  std_logic;
		ResetSync_RO                                   : out std_logic;

		-- Signals to synchronize and their synchronized counterparts.
		PCSLossOfSignal_SI                             : in  std_logic;
		PCSLossOfSignalSync_SO                         : out std_logic;
		PCSClockToleranceCompensationUnderrun_SI       : in  std_logic;
		PCSClockToleranceCompensationUnderrunSync_SO   : out std_logic;
		PCSClockToleranceCompensationOverrun_SI        : in  std_logic;
		PCSClockToleranceCompensationOverrunSync_SO    : out std_logic;
		PCSClockToleranceCompensationSKInserted_SI     : in  std_logic;
		PCSClockToleranceCompensationSKInsertedSync_SO : out std_logic;
		PCSClockToleranceCompensationSKDeleted_SI      : in  std_logic;
		PCSClockToleranceCompensationSKDeletedSync_SO  : out std_logic;
		PCSLossOfRXCDRLock_SI                          : in  std_logic;
		PCSLossOfRXCDRLockSync_SO                      : out std_logic;
		PCSLossOfTXPLLLock_SI                          : in  std_logic;
		PCSLossOfTXPLLLockSync_SO                      : out std_logic);
end SATAPortStatusClockSynchronizer;

architecture Structural of SATAPortStatusClockSynchronizer is
	signal ResetSync_R : std_logic;
begin
	-- Synchronize the reset signal to the PCS clock.
	ResetSync_RO <= ResetSync_R;

	syncReset : entity work.ResetSynchronizer
		port map(
			ExtClock_CI  => PCSTXClock_CI,
			ExtReset_RI  => Reset_RI,
			SyncReset_RO => ResetSync_R);

	-- Ensure synchronization of PCS status outputs. According to Lattice documentation,
	-- this should always be done to avoid problems.
	syncPCSLossOfSignal : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSLossOfSignal_SI,
			SyncedSignal_SO(0) => PCSLossOfSignalSync_SO);

	syncPCSClockToleranceCompensationUnderrun : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSClockToleranceCompensationUnderrun_SI,
			SyncedSignal_SO(0) => PCSClockToleranceCompensationUnderrunSync_SO);

	syncPCSClockToleranceCompensationOverrun : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSClockToleranceCompensationOverrun_SI,
			SyncedSignal_SO(0) => PCSClockToleranceCompensationOverrunSync_SO);

	syncPCSClockToleranceCompensationSKInserted : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSClockToleranceCompensationSKInserted_SI,
			SyncedSignal_SO(0) => PCSClockToleranceCompensationSKInsertedSync_SO);

	syncPCSClockToleranceCompensationSKDeleted : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSClockToleranceCompensationSKDeleted_SI,
			SyncedSignal_SO(0) => PCSClockToleranceCompensationSKDeletedSync_SO);

	syncPCSLossOfRXCDRLock : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSLossOfRXCDRLock_SI,
			SyncedSignal_SO(0) => PCSLossOfRXCDRLockSync_SO);

	syncPCSLossOfTXPLLLock : entity work.DFFSynchronizer
		port map(
			SyncClock_CI       => PCSTXClock_CI,
			Reset_RI           => ResetSync_R,
			SignalToSync_SI(0) => PCSLossOfTXPLLLock_SI,
			SyncedSignal_SO(0) => PCSLossOfTXPLLLockSync_SO);
end Structural;
