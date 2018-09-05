library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.EventCodes.all;
use work.FIFORecords.all;
use work.APSADCConfigRecords.all;
use work.ChipGeometry.AXES_KEEP;
use work.ChipGeometry.AXES_INVERT;
use work.Settings.ADC_CLOCK_FREQ_REAL;
use work.Settings.CHIP_APS_SIZE_COLUMNS;
use work.Settings.CHIP_APS_SIZE_ROWS;
use work.Settings.CHIP_APS_STREAM_START;
use work.Settings.CHIP_APS_AXES_INVERT;
use work.Settings.CHIP_APS_HAS_GLOBAL_SHUTTER;
use work.Settings.EXTERNAL_ADC_BUS_WIDTH;

-- Rolling shutter considerations: since the exposure is given by the
-- difference in time between the reset/reset read and the signal read (integration happens
-- while they are carried out), each pass of Reset->ResetRead->SignalRead must have exactly
-- the same timing characteristics, across all columns. This implies that the SignalRead must
-- always happen, so that there is no sudden offset introduced later when the SignalRead is
-- actually sampling values. A 'fake' SignalRead needs thus to be done to provide correct 'time
-- spacing', even when it has not yet been clocked into the column shift register itself.

-- Region Of Interest (ROI) support: both global and rolling shutter modes support specifying
-- a region of the full image to be scanned, instead of the full image. This enables skipping
-- certain sources of delay for pixels outside this given region, which makes for faster scan
-- times, and thus smaller delays and higher frame-rates.
-- In global shutter mode, since the reads are separated from each-other, from reset and from
-- integration, all pixels that are outside an interest region can be easily skipped. The
-- overall timing of the reset and signal reads will be the same.
-- In rolling shutter mode, things get more complex, given the precise 'time spacing' that must
-- be ovserved between the ResetRead and the SignalRead (see 'Rolling shutter considerations'
-- above). To guarantee this, all columns must take the same amount of time to be processed,
-- because if columns that are completely outside of the region of interest would take less time
-- (by just skipping them for example), then you have regions of the image that are traversed at
-- different speeds by the ResetReads and the successive SignalReads, since the SignalReads may
-- overlap with the ResetReads, and then could not just quickly advance the column shift register
-- like the ResetReads did, resulting in timing differences. An easy way to overcome this is by
-- just having all columns go through the same readout process, like if the region of interest
-- were always expanded to fit across all columns equally. This slightly mitigates the
-- advantages of ROI stated above, but is unavoidable with the current scheme.

entity APSADCStateMachineExternal is
	port(
		Clock_CI                    : in  std_logic; -- Clock for logic and chip internal ADC.
		Reset_RI                    : in  std_logic; -- This reset must be synchronized to the above clock.

		-- Fifo output (to Multiplexer, must be a dual-clock FIFO)
		OutFifoControl_SI           : in  tFromFifoWriteSide;
		OutFifoControl_SO           : out tToFifoWriteSide;
		OutFifoData_DO              : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		APSChipColSRClock_CO        : out std_logic;
		APSChipColSRIn_SO           : out std_logic;
		APSChipRowSRClock_CO        : out std_logic;
		APSChipRowSRIn_SO           : out std_logic;
		APSChipColMode_DO           : out std_logic_vector(1 downto 0);
		APSChipTXGate_SBO           : out std_logic;

		ExternalADCData_DI          : in  std_logic_vector(EXTERNAL_ADC_BUS_WIDTH - 1 downto 0);
		ExternalADCOutputEnable_SBO : out std_logic;
		ExternalADCStandby_SO       : out std_logic;

		-- Configuration input
		APSADCConfig_DI             : in  tAPSADCConfig);
end entity APSADCStateMachineExternal;

architecture Behavioral of APSADCStateMachineExternal is
	attribute syn_enum_encoding : string;

	type tColumnState is (stIdle, stWaitADCStartup, stStartFrame, stEndFrame, stWaitFrameDelay, stColSRFeedA0, stColSRFeedA0Tick, stColSRFeedA1, stColSRFeedA1Tick, stRSFeedTick, stRSReset, stRSSwitchToReadA, stRSReadA, stRSSwitchToReadB, stRSReadB, stGSReset, stGSReadA, stGSReadB, stGSSwitchToReadA,
	                      stGSSwitchToReadB, stGSStartExposure, stGSEndExposure, stGSReadAFeedTick, stGSReadBFeedTick, stGSColSRFeedB1, stGSColSRFeedB1Tick, stGSColSRFeedB0, stGSColSRFeedB0Tick, stGSSwitchToExposure, stRSSwitchToReset, stGSSwitchToReset, stRSColSRFeedB, stRSColSRFeedBTick, stGSResetClose,
	                      stROI0Info, stROI0InfoStartCol1, stROI0InfoStartCol2, stROI0InfoStartRow1, stROI0InfoStartRow2, stROI0InfoEndCol1, stROI0InfoEndCol2, stROI0InfoEndRow1, stROI0InfoEndRow2,
	                      stExposureInfo, stExposureValue0, stExposureValue1, stExposureValue2, stGSStartExposureTX);
	attribute syn_enum_encoding of tColumnState : type is "onehot";

	-- present and next state
	signal ColState_DP, ColState_DN : tColumnState;

	constant EXTERNAL_ADC_STARTUP_CYCLES      : integer := integer(ADC_CLOCK_FREQ_REAL * 15.0); -- At ADC_CLOCK, wait 15 microseconds.
	constant EXTERNAL_ADC_STARTUP_CYCLES_SIZE : integer := integer(ceil(log2(real(EXTERNAL_ADC_STARTUP_CYCLES))));

	constant COLMODE_NULL   : std_logic_vector(1 downto 0) := "00";
	constant COLMODE_READA  : std_logic_vector(1 downto 0) := "01";
	constant COLMODE_READB  : std_logic_vector(1 downto 0) := "10";
	constant COLMODE_RESETA : std_logic_vector(1 downto 0) := "11";

	-- Take note if the ADC is running already or not. If not, it has to be started.
	signal ExternalADCRunning_SP, ExternalADCRunning_SN : std_logic;

	signal ExternalADCStartupCount_S, ExternalADCStartupDone_S : std_logic;

	-- Exposure time counter.
	signal ExposureClear_S, ExposureDone_S : std_logic;

	-- Frame delay (between consecutive frames) counter.
	signal FrameDelayCount_S, FrameDelayDone_S : std_logic;

	-- Reset time counter (make bigger to allow for long resets if needed).
	signal ResetTimeCount_S, ResetTimeDone_S : std_logic;

	-- Lengthen the NULL states between different, active column states.
	signal NullTimeCount_S, NullTimeDone_S : std_logic;

	-- Column settle time (before first row is read, like an additional offset).
	signal ColSettleTimeCount_S, ColSettleTimeDone_S : std_logic;

	-- Column and row read counters.
	signal ColumnReadAPositionZero_S, ColumnReadAPositionInc_S : std_logic;
	signal ColumnReadAPosition_D                               : unsigned(CHIP_APS_SIZE_COLUMNS'range);
	signal ColumnReadBPositionZero_S, ColumnReadBPositionInc_S : std_logic;
	signal ColumnReadBPosition_D                               : unsigned(CHIP_APS_SIZE_COLUMNS'range);
	signal RowReadPositionZero_S, RowReadPositionInc_S         : std_logic;
	signal RowReadPosition_D                                   : unsigned(CHIP_APS_SIZE_ROWS'range);

	-- Communication between column and row state machines. Done through a register for full decoupling.
	signal RowReadInProgress_SP, RowReadStart_SN, RowReadDone_SN : std_logic;

	-- Wait for all row-read parts to be done before sending end-of-frame (EOF) event.
	signal RowReadsAllDone_S : std_logic;

	-- RS: the B read has several very special considerations that must be taken into account.
	-- First, it has to be done only after exposure time expires, before that, it must be faked
	-- to not throw off timing. Secondly, the B read binary pattern is a 1 with a 0 on either
	-- side, which means that it cannot come right after the A pattern; at least one 0 must be
	-- first shifted in. Also, it needs a further 0 to be shifted in after the 1, before B
	-- reads can really begin. We use the following two registers to control this.
	signal ReadBSRStatus_DP, ReadBSRStatus_DN : std_logic_vector(1 downto 0);

	constant RBSTAT_NEED_ZERO_ONE : std_logic_vector(1 downto 0) := "00";
	constant RBSTAT_NEED_ONE      : std_logic_vector(1 downto 0) := "01";
	constant RBSTAT_NEED_ZERO_TWO : std_logic_vector(1 downto 0) := "10";
	constant RBSTAT_NORMAL        : std_logic_vector(1 downto 0) := "11";

	-- Check column and row validity. Used for faster ROI.
	signal CurrentColumnAValid_S, CurrentColumnBValid_S : std_logic;
	signal CurrentRowValid_S                            : std_logic;

	-- ROI size information.
	signal ROI0StartColumn_D : unsigned(15 downto 0);
	signal ROI0StartRow_D    : unsigned(15 downto 0);
	signal ROI0EndColumn_D   : unsigned(15 downto 0);
	signal ROI0EndRow_D      : unsigned(15 downto 0);

	-- Register outputs to FIFO.
	signal OutFifoWriteReg_S, OutFifoWriteRegCol_S, OutFifoWriteRegRow_S                : std_logic;
	signal OutFifoDataRegEnable_S, OutFifoDataRegColEnable_S, OutFifoDataRegRowEnable_S : std_logic;
	signal OutFifoDataReg_D, OutFifoDataRegCol_D, OutFifoDataRegRow_D                   : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	-- Register all outputs to chip APS control for clean transitions.
	signal APSChipColSRClockReg_C, APSChipColSRInReg_S : std_logic;
	signal APSChipColModeReg_DP, APSChipColModeReg_DN  : std_logic_vector(1 downto 0);
	signal APSChipTXGateReg_SP, APSChipTXGateReg_SN    : std_logic;

	type tExtRowState is (stIdle, stRowDone, stRowStart, stRowSRFeedInit, stRowSRFeedInitTick, stRowSRFeedTick, stColSettleWait, stRowSettleWait, stRowWriteEvent, stRowFastJump);
	attribute syn_enum_encoding of tExtRowState : type is "onehot";

	-- present and next state
	signal ExtRowState_DP, ExtRowState_DN : tExtRowState;

	-- Row settle time counter.
	signal RowSettleTimeCount_S, RowSettleTimeDone_S : std_logic;

	-- Register all outputs to chip APS control for clean transitions.
	signal APSChipRowSRClockReg_C, APSChipRowSRInReg_S : std_logic;

	-- Double register configuration input, since it comes from a different clock domain (LogicClock), it
	-- needs to go through a double-flip-flop synchronizer to guarantee correctness.
	signal APSADCConfigSyncReg_D, APSADCConfigReg_D : tAPSADCConfig;
	signal APSADCConfigRegEnable_S                  : std_logic;
begin
	colReadAPosition : entity work.ContinuousCounter
		generic map(
			SIZE              => CHIP_APS_SIZE_COLUMNS'length,
			RESET_ON_OVERFLOW => false,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => ColumnReadAPositionZero_S,
			Enable_SI    => ColumnReadAPositionInc_S,
			DataLimit_DI => CHIP_APS_SIZE_COLUMNS,
			Overflow_SO  => open,
			Data_DO      => ColumnReadAPosition_D);

	colReadBPosition : entity work.ContinuousCounter
		generic map(
			SIZE              => CHIP_APS_SIZE_COLUMNS'length,
			RESET_ON_OVERFLOW => false,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => ColumnReadBPositionZero_S,
			Enable_SI    => ColumnReadBPositionInc_S,
			DataLimit_DI => CHIP_APS_SIZE_COLUMNS,
			Overflow_SO  => open,
			Data_DO      => ColumnReadBPosition_D);

	exposureCounter : entity work.ContinuousCounter
		generic map(
			SIZE              => APS_EXPOSURE_SIZE,
			RESET_ON_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => ExposureClear_S,
			Enable_SI    => '1',
			DataLimit_DI => APSADCConfigReg_D.Exposure_D,
			Overflow_SO  => ExposureDone_S,
			Data_DO      => open);

	frameDelayCounter : entity work.ContinuousCounter
		generic map(
			SIZE => APS_FRAMEDELAY_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => FrameDelayCount_S,
			DataLimit_DI => APSADCConfigReg_D.FrameDelay_D,
			Overflow_SO  => FrameDelayDone_S,
			Data_DO      => open);

	nullTimeCounter : entity work.ContinuousCounter
		generic map(
			SIZE => APS_NULLTIME_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => NullTimeCount_S,
			DataLimit_DI => APSADCConfigReg_D.NullSettle_D,
			Overflow_SO  => NullTimeDone_S,
			Data_DO      => open);

	resetTimeCounter : entity work.ContinuousCounter
		generic map(
			SIZE => APS_RESETTIME_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => ResetTimeCount_S,
			DataLimit_DI => APSADCConfigReg_D.ResetSettle_D,
			Overflow_SO  => ResetTimeDone_S,
			Data_DO      => open);

	columnMainStateMachine : process(ColState_DP, OutFifoControl_SI, ExternalADCRunning_SP, ExternalADCStartupDone_S, APSADCConfigReg_D, RowReadInProgress_SP, NullTimeDone_S, ResetTimeDone_S, APSChipTXGateReg_SP, ColumnReadAPosition_D, ColumnReadBPosition_D, ReadBSRStatus_DP, CurrentColumnAValid_S, CurrentColumnBValid_S, ExposureDone_S, FrameDelayDone_S, RowReadsAllDone_S, ROI0StartColumn_D, ROI0StartRow_D, ROI0EndColumn_D, ROI0EndRow_D)
	begin
		ColState_DN <= ColState_DP;     -- Keep current state by default.

		OutFifoWriteRegCol_S      <= '0';
		OutFifoDataRegColEnable_S <= '0';
		OutFifoDataRegCol_D       <= (others => '0');

		ExternalADCRunning_SN     <= ExternalADCRunning_SP;
		ExternalADCStartupCount_S <= '0';

		APSChipColSRClockReg_C <= '0';
		APSChipColSRInReg_S    <= '0';

		APSChipColModeReg_DN <= COLMODE_NULL;
		APSChipTXGateReg_SN  <= APSChipTXGateReg_SP;

		ExposureClear_S <= '0';

		FrameDelayCount_S <= '0';

		-- Colum counters.
		ColumnReadAPositionZero_S <= '0';
		ColumnReadAPositionInc_S  <= '0';
		ColumnReadBPositionZero_S <= '0';
		ColumnReadBPositionInc_S  <= '0';

		-- Reset time counter.
		ResetTimeCount_S <= '0';

		-- Null time counter.
		NullTimeCount_S <= '0';

		-- Row SM communication.
		RowReadStart_SN <= '0';

		-- Keep value by default.
		ReadBSRStatus_DN <= ReadBSRStatus_DP;

		-- Only update configuration when in Idle state. Doing so while the frame is being read out
		-- would cause different timing, exposure and read out types, resulting in corrupted frames.
		APSADCConfigRegEnable_S <= '0';

		case ColState_DP is
			when stIdle =>
				if APSADCConfigReg_D.Run_S = '1' then
					-- We want to take samples, so ensure the wanted ADC is working.
					if ExternalADCRunning_SP = '1' then
						-- External ADC wanted and already running, start right away.
						ColState_DN <= stExposureInfo;
					else
						-- External ADC wanted but not running, start and then wait.
						ExternalADCRunning_SN <= '1';

						ColState_DN <= stWaitADCStartup;
					end if;
				else
					-- Turn external ADC off when not running to reduce current consumption.
					ExternalADCRunning_SN <= '0';

					-- Update config, so that we get changes to Run_S especially.
					APSADCConfigRegEnable_S <= '1';
				end if;

			when stWaitADCStartup =>
				-- Wait 15 microseconds for ADC to start up and be ready for precise conversions.
				if ExternalADCStartupDone_S = '1' then
					ColState_DN <= stExposureInfo;
				end if;

				ExternalADCStartupCount_S <= '1';

			when stExposureInfo =>
				-- Write out Exposure information. Up to 30 bits value, divided in three parts.
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_INFO_EXPOSURE;

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stExposureValue0;
				end if;

			when stExposureValue0 =>
				-- Write out Exposure information. Up to 30 bits value, divided in three parts.
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA10 & EVENT_CODE_MISC_DATA10_APS_EXPOSURE & std_logic_vector(APSADCConfigReg_D.Exposure_D(9 downto 0));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stExposureValue1;
				end if;

			when stExposureValue1 =>
				-- Write out Exposure information. Up to 30 bits value, divided in three parts.
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA10 & EVENT_CODE_MISC_DATA10_APS_EXPOSURE & std_logic_vector(APSADCConfigReg_D.Exposure_D(19 downto 10));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stExposureValue2;
				end if;

			when stExposureValue2 =>
				-- Write out Exposure information. Up to 30 bits value, divided in three parts.
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA10 & EVENT_CODE_MISC_DATA10_APS_EXPOSURE & std_logic_vector(resize(APSADCConfigReg_D.Exposure_D(APS_EXPOSURE_SIZE - 1 downto 20), 10));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0Info;
				end if;

			when stROI0Info =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					if APSADCConfigReg_D.ROI0Enabled_S = '1' then
						OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_INFO_ROI0_ON;
					else
						OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_INFO_ROI0_OFF;
					end if;

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					if APSADCConfigReg_D.ROI0Enabled_S = '1' then
						ColState_DN <= stROI0InfoStartCol1;
					else
						ColState_DN <= stStartFrame;
					end if;
				end if;

			when stROI0InfoStartCol1 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_0 & std_logic_vector(ROI0StartColumn_D(15 downto 8));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoStartCol2;
				end if;

			when stROI0InfoStartCol2 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_1 & std_logic_vector(ROI0StartColumn_D(7 downto 0));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoStartRow1;
				end if;

			when stROI0InfoStartRow1 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_0 & std_logic_vector(ROI0StartRow_D(15 downto 8));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoStartRow2;
				end if;

			when stROI0InfoStartRow2 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_1 & std_logic_vector(ROI0StartRow_D(7 downto 0));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoEndCol1;
				end if;

			when stROI0InfoEndCol1 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_0 & std_logic_vector(ROI0EndColumn_D(15 downto 8));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoEndCol2;
				end if;

			when stROI0InfoEndCol2 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_1 & std_logic_vector(ROI0EndColumn_D(7 downto 0));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoEndRow1;
				end if;

			when stROI0InfoEndRow1 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_0 & std_logic_vector(ROI0EndRow_D(15 downto 8));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stROI0InfoEndRow2;
				end if;

			when stROI0InfoEndRow2 =>
				-- Write out APS frame size markers. The different ROI regions are notified separately.
				-- One size result is split into two, to support sizes up to 16 bits per side.
				-- This event is always delivered, like Start/End events!
				if OutFifoControl_SI.AlmostFull_S = '0' then
					OutFifoDataRegCol_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_APS_ROISIZE_1 & std_logic_vector(ROI0EndRow_D(7 downto 0));

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stStartFrame;
				end if;

			when stStartFrame =>
				-- Write out start of frame marker. This and the end of frame marker are the only
				-- two events from this SM that always have to be committed and are never dropped,
				-- together with the ROI size information markers.
				if OutFifoControl_SI.AlmostFull_S = '0' then
					if CHIP_APS_HAS_GLOBAL_SHUTTER = '1' and APSADCConfigReg_D.GlobalShutter_S = '1' then
						if APSADCConfigReg_D.ResetRead_S = '1' then
							OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_STARTFRAME_GS;
						else
							OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_STARTFRAME_GS_NORST;
						end if;
					else
						if APSADCConfigReg_D.ResetRead_S = '1' then
							OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_STARTFRAME_RS;
						else
							OutFifoDataRegCol_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_STARTFRAME_RS_NORST;
						end if;
					end if;

					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stColSRFeedA0;
				end if;

			when stColSRFeedA0 =>
				APSChipColSRClockReg_C <= '0';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stColSRFeedA0Tick;

			when stColSRFeedA0Tick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stColSRFeedA1;

			when stColSRFeedA1 =>
				APSChipColSRClockReg_C <= '0';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stColSRFeedA1Tick;

			when stColSRFeedA1Tick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '1';

				if CHIP_APS_HAS_GLOBAL_SHUTTER = '1' and APSADCConfigReg_D.GlobalShutter_S = '1' then
					-- Only switch to global shutter on chips supporting it.
					ColState_DN <= stGSSwitchToReset;
				else
					ColState_DN <= stRSSwitchToReset;
				end if;

			when stRSColSRFeedB =>
				APSChipColSRClockReg_C <= '0';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stRSColSRFeedBTick;

			when stRSColSRFeedBTick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stRSSwitchToReset;

			when stRSFeedTick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '0';

				-- A first zero has just been shifted in.
				if ReadBSRStatus_DP = RBSTAT_NEED_ZERO_ONE then
					ReadBSRStatus_DN <= RBSTAT_NEED_ONE;
				end if;

				-- Check if we're done (read B ended).
				if ColumnReadBPosition_D = CHIP_APS_SIZE_COLUMNS then
					ColState_DN <= stEndFrame;

					-- Reset ReadB status to initial (need at least a zero), for next frame.
					ReadBSRStatus_DN <= RBSTAT_NEED_ZERO_ONE;
				else
					ColState_DN <= stRSSwitchToReset;
				end if;

			when stRSSwitchToReset =>
				-- Ensure we go through another NULL state.
				if NullTimeDone_S = '1' then
					ColState_DN <= stRSReset;
				end if;

				NullTimeCount_S <= '1';

			when stRSReset =>
				if ColumnReadAPosition_D = CHIP_APS_SIZE_COLUMNS then
					APSChipColModeReg_DN <= COLMODE_NULL;
				else
					-- Do reset.
					APSChipColModeReg_DN <= COLMODE_RESETA;
				end if;

				if ResetTimeDone_S = '1' then
					-- Support not doing the reset read. Halves the traffic and time
					-- requirements, at the expense of image quality.
					if APSADCConfigReg_D.ResetRead_S = '1' then
						ColState_DN <= stRSSwitchToReadA;
					else
						ColState_DN <= stRSSwitchToReadB;

						-- In this case, we must do the things the read A state would
						-- normally do: increase read A position (used for resets).
						ColumnReadAPositionInc_S <= '1';
					end if;

					-- If this is the first A reset, we start exposure.
					-- Exposure starts right as reset is released.
					if ColumnReadAPosition_D = 0 then
						ExposureClear_S <= '1';
					end if;
				end if;

				ResetTimeCount_S <= '1';

			when stRSSwitchToReadA =>
				if NullTimeDone_S = '1' then
					-- Start off the Row SM.
					RowReadStart_SN <= '1';
					ColState_DN     <= stRSReadA;
				end if;

				NullTimeCount_S <= '1';

			when stRSReadA =>
				if ColumnReadAPosition_D = CHIP_APS_SIZE_COLUMNS or CurrentColumnAValid_S = '0' then
					APSChipColModeReg_DN <= COLMODE_NULL;
				else
					-- Do column read A.
					APSChipColModeReg_DN <= COLMODE_READA;
				end if;

				-- Wait for the Row SM to complete its readout.
				if RowReadInProgress_SP = '0' then
					ColState_DN              <= stRSSwitchToReadB;
					ColumnReadAPositionInc_S <= '1';
				end if;

			when stRSSwitchToReadB =>
				if NullTimeDone_S = '1' then
					-- Start off the Row SM.
					RowReadStart_SN <= '1';
					ColState_DN     <= stRSReadB;
				end if;

				NullTimeCount_S <= '1';

			when stRSReadB =>
				if ReadBSRStatus_DP /= RBSTAT_NORMAL or CurrentColumnBValid_S = '0' then
					APSChipColModeReg_DN <= COLMODE_NULL;
				else
					-- Do column read B.
					APSChipColModeReg_DN <= COLMODE_READB;
				end if;

				-- Wait for the Row SM to complete its readout.
				if RowReadInProgress_SP = '0' then
					-- If exposure time hasn't expired or we haven't yet even shifted in one
					-- 0 into the column SR, we first do that.
					if ExposureDone_S = '1' and ReadBSRStatus_DP /= RBSTAT_NEED_ZERO_ONE then
						if ReadBSRStatus_DP = RBSTAT_NEED_ONE then
							-- If the 1 that represents the B read hasn't yet been shifted
							-- in, do so now.
							ColState_DN      <= stRSColSRFeedB;
							ReadBSRStatus_DN <= RBSTAT_NEED_ZERO_TWO;
						elsif ReadBSRStatus_DP = RBSTAT_NEED_ZERO_TWO then
							-- Shift in the second 0 (the one after the 1) that is needed
							-- for a B read of the very first column to work.
							ColState_DN      <= stRSFeedTick;
							ReadBSRStatus_DN <= RBSTAT_NORMAL;
						else
							-- Finally, B reads are happening, their position is increasing.
							ColState_DN              <= stRSFeedTick;
							ColumnReadBPositionInc_S <= '1';
						end if;
					else
						-- Just shift in a zero.
						ColState_DN <= stRSFeedTick;
					end if;
				end if;

			when stGSSwitchToReset =>
				-- Ensure we go through another NULL state.
				if NullTimeDone_S = '1' then
					ColState_DN <= stGSReset;
				end if;

				NullTimeCount_S <= '1';

			when stGSReset =>
				-- Do reset.
				APSChipColModeReg_DN <= COLMODE_RESETA;

				if ResetTimeDone_S = '1' then
					ColState_DN <= stGSResetClose;
				end if;

				ResetTimeCount_S <= '1';

			when stGSResetClose =>
				-- Close TXGate after reset, don't want to transfer charge.
				APSChipTXGateReg_SN <= '0';

				if NullTimeDone_S = '1' then
					if APSADCConfigReg_D.ResetRead_S = '1' then
						ColState_DN <= stGSSwitchToReadA;
					else
						ColState_DN <= stGSSwitchToExposure;
					end if;
				end if;

				NullTimeCount_S <= '1';

			when stGSSwitchToReadA =>
				if CurrentColumnAValid_S = '1' then
					-- Start off the Row SM.
					RowReadStart_SN <= '1';
					ColState_DN     <= stGSReadA;
				else
					ColState_DN              <= stGSReadAFeedTick;
					ColumnReadAPositionInc_S <= '1';
				end if;

			when stGSReadA =>
				APSChipColModeReg_DN <= COLMODE_READA;

				if RowReadInProgress_SP = '0' then
					ColState_DN              <= stGSReadAFeedTick;
					ColumnReadAPositionInc_S <= '1';
				end if;

			when stGSReadAFeedTick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '0';

				if ColumnReadAPosition_D = CHIP_APS_SIZE_COLUMNS then
					-- Done with reset read.
					ColState_DN <= stGSStartExposure;
				else
					ColState_DN <= stGSSwitchToReadA;
				end if;

			when stGSSwitchToExposure =>
				-- When not doing any reset read, we need this state to clock in
				-- one zero into the column SR, so that the B pattern is present.
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '0';

				ColState_DN <= stGSStartExposure;

			when stGSStartExposure =>
				APSChipColModeReg_DN <= COLMODE_RESETA;

				if ResetTimeDone_S = '1' then
					ColState_DN <= stGSStartExposureTX;
				end if;

				ResetTimeCount_S <= '1';

			when stGSStartExposureTX =>
				-- TXGate must be open during exposure.
				APSChipTXGateReg_SN <= '1';

				-- Start exposure.
				ExposureClear_S <= '1';
				ColState_DN     <= stGSEndExposure;

			when stGSEndExposure =>
				if ExposureDone_S = '1' then
					-- Exposure completed, close TXGate for signal readout (ReadB)
					-- and shift in read pattern.
					APSChipTXGateReg_SN <= '0';
					ColState_DN         <= stGSColSRFeedB1;
				end if;

			when stGSColSRFeedB1 =>
				APSChipColSRClockReg_C <= '0';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stGSColSRFeedB1Tick;

			when stGSColSRFeedB1Tick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '1';

				ColState_DN <= stGSColSRFeedB0;

			when stGSColSRFeedB0 =>
				APSChipColSRClockReg_C <= '0';
				APSChipColSRInReg_S    <= '0';

				ColState_DN <= stGSColSRFeedB0Tick;

			when stGSColSRFeedB0Tick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '0';

				ColState_DN <= stGSSwitchToReadB;

			when stGSSwitchToReadB =>
				if CurrentColumnBValid_S = '1' then
					-- Start off the Row SM.
					RowReadStart_SN <= '1';
					ColState_DN     <= stGSReadB;
				else
					ColState_DN              <= stGSReadBFeedTick;
					ColumnReadBPositionInc_S <= '1';
				end if;

			when stGSReadB =>
				APSChipColModeReg_DN <= COLMODE_READB;

				if RowReadInProgress_SP = '0' then
					ColState_DN              <= stGSReadBFeedTick;
					ColumnReadBPositionInc_S <= '1';
				end if;

			when stGSReadBFeedTick =>
				APSChipColSRClockReg_C <= '1';
				APSChipColSRInReg_S    <= '0';

				if ColumnReadBPosition_D = CHIP_APS_SIZE_COLUMNS then
					-- Open TXGate again after signal readout (ReadB), to return to default state.
					APSChipTXGateReg_SN <= '1';

					-- Done with signal read.
					ColState_DN <= stEndFrame;
				else
					ColState_DN <= stGSSwitchToReadB;
				end if;

			when stEndFrame =>
				-- Zero column counters too.
				ColumnReadAPositionZero_S <= '1';
				ColumnReadBPositionZero_S <= '1';

				-- Write out end of frame marker. This and the start of frame marker are the only
				-- two events from this SM that always have to be committed and are never dropped,
				-- together with the ROI size information markers.
				if OutFifoControl_SI.AlmostFull_S = '0' and RowReadsAllDone_S = '1' then
					OutFifoDataRegCol_D       <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_ENDFRAME;
					OutFifoDataRegColEnable_S <= '1';
					OutFifoWriteRegCol_S      <= '1';

					ColState_DN <= stWaitFrameDelay;
				end if;

			when stWaitFrameDelay =>
				-- Wait until enough time has passed between frames.
				if FrameDelayDone_S = '1' then
					ColState_DN <= stIdle;

					-- Ensure config reg is up-to-date when entering Idle state.
					APSADCConfigRegEnable_S <= '1';
				end if;

				FrameDelayCount_S <= '1';

			when others => null;
		end case;
	end process columnMainStateMachine;

	-- Region of Interest 0 is always present, as it is the default frame.
	-- Here we define all regions of interest so that the signals are always defined,
	-- but ROI Regions 1/2/3 will not be used if QUAD_ROI is disabled.
	axesNormal : if CHIP_APS_AXES_INVERT = AXES_KEEP generate
	begin
		ROI0StartColumn_D <= resize(APSADCConfigReg_D.StartColumn0_D, 16);
		ROI0StartRow_D    <= resize(APSADCConfigReg_D.StartRow0_D, 16);
		ROI0EndColumn_D   <= resize(APSADCConfigReg_D.EndColumn0_D, 16);
		ROI0EndRow_D      <= resize(APSADCConfigReg_D.EndRow0_D, 16);
	end generate axesNormal;

	axesInverted : if CHIP_APS_AXES_INVERT = AXES_INVERT generate
	begin
		ROI0StartColumn_D <= resize(APSADCConfigReg_D.StartRow0_D, 16);
		ROI0StartRow_D    <= resize(APSADCConfigReg_D.StartColumn0_D, 16);
		ROI0EndColumn_D   <= resize(APSADCConfigReg_D.EndRow0_D, 16);
		ROI0EndRow_D      <= resize(APSADCConfigReg_D.EndColumn0_D, 16);
	end generate axesInverted;

	-- Concurrently calculate if the current column or row has to be read out or not.
	-- If not (like with ROI), we can just fast jump past it.
	apsColumnROI : if CHIP_APS_STREAM_START(1) = '0' generate
	begin
		CurrentColumnAValid_S <= '1' when (ColumnReadAPosition_D >= ROI0StartColumn_D and ColumnReadAPosition_D <= ROI0EndColumn_D and APSADCConfigReg_D.ROI0Enabled_S = '1') else '0';
		CurrentColumnBValid_S <= '1' when (ColumnReadBPosition_D >= ROI0StartColumn_D and ColumnReadBPosition_D <= ROI0EndColumn_D and APSADCConfigReg_D.ROI0Enabled_S = '1') else '0';
	end generate apsColumnROI;

	apsColumnROIInverted : if CHIP_APS_STREAM_START(1) = '1' generate
		signal StartColumn0Inverted_S : unsigned(15 downto 0);
		signal EndColumn0Inverted_S   : unsigned(15 downto 0);
	begin
		StartColumn0Inverted_S <= resize(CHIP_APS_SIZE_COLUMNS - 1, 16) - ROI0StartColumn_D;
		EndColumn0Inverted_S   <= resize(CHIP_APS_SIZE_COLUMNS - 1, 16) - ROI0EndColumn_D;

		CurrentColumnAValid_S <= '1' when (ColumnReadAPosition_D >= EndColumn0Inverted_S and ColumnReadAPosition_D <= StartColumn0Inverted_S and APSADCConfigReg_D.ROI0Enabled_S = '1') else '0';
		CurrentColumnBValid_S <= '1' when (ColumnReadBPosition_D >= EndColumn0Inverted_S and ColumnReadBPosition_D <= StartColumn0Inverted_S and APSADCConfigReg_D.ROI0Enabled_S = '1') else '0';
	end generate apsColumnROIInverted;

	apsRowROI : if CHIP_APS_STREAM_START(0) = '0' generate
	begin
		CurrentRowValid_S <= '1' when (RowReadPosition_D >= ROI0StartRow_D and RowReadPosition_D <= ROI0EndRow_D) else '0';
	end generate apsRowROI;

	apsRowROIInverted : if CHIP_APS_STREAM_START(0) = '1' generate
		signal StartRow0Inverted_S : unsigned(15 downto 0);
		signal EndRow0Inverted_S   : unsigned(15 downto 0);
	begin
		StartRow0Inverted_S <= resize(CHIP_APS_SIZE_ROWS - 1, 16) - ROI0StartRow_D;
		EndRow0Inverted_S   <= resize(CHIP_APS_SIZE_ROWS - 1, 16) - ROI0EndRow_D;

		CurrentRowValid_S <= '1' when (RowReadPosition_D >= EndRow0Inverted_S and RowReadPosition_D <= StartRow0Inverted_S) else '0';
	end generate apsRowROIInverted;

	rowReadPosition : entity work.ContinuousCounter
		generic map(
			SIZE              => CHIP_APS_SIZE_ROWS'length,
			RESET_ON_OVERFLOW => false,
			GENERATE_OVERFLOW => false)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => RowReadPositionZero_S,
			Enable_SI    => RowReadPositionInc_S,
			DataLimit_DI => CHIP_APS_SIZE_ROWS,
			Overflow_SO  => open,
			Data_DO      => RowReadPosition_D);

	columnSettleTimeCounter : entity work.ContinuousCounter
		generic map(
			SIZE => APS_COLSETTLETIME_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => ColSettleTimeCount_S,
			DataLimit_DI => APSADCConfigReg_D.ColumnSettle_D,
			Overflow_SO  => ColSettleTimeDone_S,
			Data_DO      => open);

	-- Signal when all row-reads are done and we can send EOF.
	RowReadsAllDone_S <= not RowReadInProgress_SP;

	rowSettleTimeCounter : entity work.ContinuousCounter
		generic map(
			SIZE => APS_ROWSETTLETIME_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => RowSettleTimeCount_S,
			DataLimit_DI => APSADCConfigReg_D.RowSettle_D,
			Overflow_SO  => RowSettleTimeDone_S,
			Data_DO      => open);

	externalADCRowReadoutStateMachine : process(ExtRowState_DP, APSADCConfigReg_D, ExternalADCData_DI, OutFifoControl_SI, APSChipColModeReg_DP, CurrentRowValid_S, RowReadInProgress_SP, RowReadPosition_D, ColSettleTimeDone_S, RowSettleTimeDone_S)
	begin
		ExtRowState_DN <= ExtRowState_DP;

		OutFifoWriteRegRow_S      <= '0';
		OutFifoDataRegRowEnable_S <= '0';
		OutFifoDataRegRow_D       <= (others => '0');

		APSChipRowSRClockReg_C <= '0';
		APSChipRowSRInReg_S    <= '0';

		-- Row counters.
		RowReadPositionZero_S <= '0';
		RowReadPositionInc_S  <= '0';

		-- Settle times counters (column and row).
		ColSettleTimeCount_S <= '0';
		RowSettleTimeCount_S <= '0';

		-- Column SM communication.
		RowReadDone_SN <= '0';

		case ExtRowState_DP is
			when stIdle =>
				-- Wait until the main column state machine signals us to do a row read.
				if RowReadInProgress_SP = '1' then
					ExtRowState_DN <= stRowSRFeedInit;
				end if;

			when stRowSRFeedInit =>
				-- We first feed in the row register pattern, since the column settle time
				-- has to pass _after_ the first row has been selected.
				APSChipRowSRClockReg_C <= '0';
				APSChipRowSRInReg_S    <= '1';

				ExtRowState_DN <= stRowSRFeedInitTick;

			when stRowSRFeedInitTick =>
				APSChipRowSRClockReg_C <= '1';
				APSChipRowSRInReg_S    <= '1';

				ExtRowState_DN <= stColSettleWait;

			when stColSettleWait =>
				-- Additional wait for the column selection to be valid, once both the colum and
				-- the current row pattern have been shifted in. We do this here, because the row
				-- pattern also has to have been shifted in for this to be effective.
				if ColSettleTimeDone_S = '1' then
					ExtRowState_DN <= stRowStart;
				end if;

				ColSettleTimeCount_S <= '1';

			when stRowStart =>
				-- Write event only if FIFO has place, else wait.
				-- If fake read (COLMODE_NULL), don't write anything.
				if OutFifoControl_SI.AlmostFull_S = '0' and APSChipColModeReg_DP /= COLMODE_NULL then
					if APSChipColModeReg_DP = COLMODE_READA then
						OutFifoDataRegRow_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_STARTRESETCOL;
					else
						OutFifoDataRegRow_D <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_STARTSIGNALCOL;
					end if;
					OutFifoDataRegRowEnable_S <= '1';
					OutFifoWriteRegRow_S      <= '1';
				end if;

				if OutFifoControl_SI.AlmostFull_S = '0' or APSChipColModeReg_DP = COLMODE_NULL or APSADCConfigReg_D.WaitOnTransferStall_S = '0' then
					-- Same decision to do here as in stRowSRFeedTick.
					if CurrentRowValid_S = '1' then
						ExtRowState_DN <= stRowSettleWait;
					else
						ExtRowState_DN <= stRowFastJump;
					end if;
				end if;

			when stRowSRFeedTick =>
				APSChipRowSRClockReg_C <= '1';
				APSChipRowSRInReg_S    <= '0';

				-- Check if we're done. This means that we just clock the 1 in the RowSR out,
				-- leaving it clean at only zeros. Further, the row read position is at the
				-- maximum, so we can detect that, zero it and exit.
				if RowReadPosition_D = CHIP_APS_SIZE_ROWS then
					ExtRowState_DN        <= stRowDone;
					RowReadPositionZero_S <= '1';
				else
					if CurrentRowValid_S = '1' then
						ExtRowState_DN <= stRowSettleWait;
					else
						ExtRowState_DN <= stRowFastJump;
					end if;
				end if;

			when stRowSettleWait =>
				-- Wait for the row selection to be valid.
				if RowSettleTimeDone_S = '1' then
					ExtRowState_DN <= stRowWriteEvent;
				end if;

				RowSettleTimeCount_S <= '1';

			when stRowWriteEvent =>
				-- Write event only if FIFO has place, else wait.
				if OutFifoControl_SI.AlmostFull_S = '0' and APSChipColModeReg_DP /= COLMODE_NULL then
					OutFifoDataRegRow_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) <= EVENT_CODE_ADC_SAMPLE;
					OutFifoDataRegRow_D(EXTERNAL_ADC_BUS_WIDTH - 1 downto 0)    <= ExternalADCData_DI;

					OutFifoDataRegRowEnable_S <= '1';
					OutFifoWriteRegRow_S      <= '1';
				end if;

				if OutFifoControl_SI.AlmostFull_S = '0' or APSChipColModeReg_DP = COLMODE_NULL or APSADCConfigReg_D.WaitOnTransferStall_S = '0' then
					ExtRowState_DN       <= stRowSRFeedTick;
					RowReadPositionInc_S <= '1';
				end if;

			when stRowFastJump =>
				ExtRowState_DN       <= stRowSRFeedTick;
				RowReadPositionInc_S <= '1';

			when stRowDone =>
				-- Write event only if FIFO has place, else wait.
				if OutFifoControl_SI.AlmostFull_S = '0' and APSChipColModeReg_DP /= COLMODE_NULL then
					OutFifoDataRegRow_D       <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_APS_ENDCOL;
					OutFifoDataRegRowEnable_S <= '1';
					OutFifoWriteRegRow_S      <= '1';
				end if;

				if OutFifoControl_SI.AlmostFull_S = '0' or APSChipColModeReg_DP = COLMODE_NULL or APSADCConfigReg_D.WaitOnTransferStall_S = '0' then
					ExtRowState_DN <= stIdle;
					RowReadDone_SN <= '1';
				end if;

			when others => null;
		end case;
	end process externalADCRowReadoutStateMachine;

	externalADCRegisterUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			ExtRowState_DP <= stIdle;

			APSChipRowSRClock_CO <= '0';
			APSChipRowSRIn_SO    <= '0';
		elsif rising_edge(Clock_CI) then
			ExtRowState_DP <= ExtRowState_DN;

			APSChipRowSRClock_CO <= APSChipRowSRClockReg_C;
			APSChipRowSRIn_SO    <= APSChipRowSRInReg_S;
		end if;
	end process externalADCRegisterUpdate;

	adcStartupCounter : entity work.ContinuousCounter
		generic map(
			SIZE => EXTERNAL_ADC_STARTUP_CYCLES_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => ExternalADCStartupCount_S,
			DataLimit_DI => to_unsigned(EXTERNAL_ADC_STARTUP_CYCLES - 1, EXTERNAL_ADC_STARTUP_CYCLES_SIZE),
			Overflow_SO  => ExternalADCStartupDone_S,
			Data_DO      => open);

	-- FIFO output can be driven by both the column or the row state machines.
	-- Care must be taken to never have both at the same time output meaningful data.
	OutFifoWriteReg_S      <= OutFifoWriteRegCol_S or OutFifoWriteRegRow_S;
	OutFifoDataRegEnable_S <= OutFifoDataRegColEnable_S or OutFifoDataRegRowEnable_S;
	OutFifoDataReg_D       <= OutFifoDataRegCol_D or OutFifoDataRegRow_D;

	outputDataRegister : entity work.SimpleRegister
		generic map(
			SIZE => EVENT_WIDTH)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Enable_SI => OutFifoDataRegEnable_S,
			Input_SI  => OutFifoDataReg_D,
			Output_SO => OutFifoData_DO);

	-- Change state on clock edge (synchronous).
	registerUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			ColState_DP <= stIdle;

			ExternalADCRunning_SP <= '0';

			RowReadInProgress_SP <= '0';

			ReadBSRStatus_DP <= RBSTAT_NEED_ZERO_ONE;

			OutFifoControl_SO.Write_S <= '0';

			APSChipColSRClock_CO <= '0';
			APSChipColSRIn_SO    <= '0';
			APSChipColModeReg_DP <= COLMODE_NULL;
			APSChipTXGateReg_SP  <= '1'; -- RS: always open. GS: always open, only closed during ReadA or ReadB.

			-- APS ADC config from another clock domain.
			APSADCConfigReg_D     <= tAPSADCConfigDefault;
			APSADCConfigSyncReg_D <= tAPSADCConfigDefault;
		elsif rising_edge(Clock_CI) then
			ColState_DP <= ColState_DN;

			ExternalADCRunning_SP <= ExternalADCRunning_SN;

			RowReadInProgress_SP <= RowReadInProgress_SP xor (RowReadStart_SN or RowReadDone_SN);

			ReadBSRStatus_DP <= ReadBSRStatus_DN;

			OutFifoControl_SO.Write_S <= OutFifoWriteReg_S;

			APSChipColSRClock_CO <= APSChipColSRClockReg_C;
			APSChipColSRIn_SO    <= APSChipColSRInReg_S;
			APSChipColModeReg_DP <= APSChipColModeReg_DN;
			APSChipTXGateReg_SP  <= APSChipTXGateReg_SN;

			-- APS ADC config from another clock domain.
			if APSADCConfigRegEnable_S = '1' then
				APSADCConfigReg_D <= APSADCConfigSyncReg_D;
			end if;
			APSADCConfigSyncReg_D <= APSADCConfig_DI;
		end if;
	end process registerUpdate;

	-- The output of this register goes to an intermediate signal, since we need to access it
	-- inside this module. That's not possible with 'out' signal directly.
	APSChipColMode_DO <= APSChipColModeReg_DP;
	APSChipTXGate_SBO <= not APSChipTXGateReg_SP;

	-- Enabling the external ADC depends on wheter we want to run it or not.
	ExternalADCOutputEnable_SBO <= not ExternalADCRunning_SP;
	ExternalADCStandby_SO       <= not ExternalADCRunning_SP;
end architecture Behavioral;
