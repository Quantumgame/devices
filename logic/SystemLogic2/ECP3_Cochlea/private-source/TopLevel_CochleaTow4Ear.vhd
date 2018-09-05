library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.EventCodes.all;
use work.Settings.all;
use work.FIFORecords.all;
use work.MultiplexerConfigRecords.all;
use work.GenericAERConfigRecords.all;
use work.SystemInfoConfigRecords.all;
use work.FX3ConfigRecords.all;
use work.ChipBiasConfigRecords.all;
use work.CochleaTow4EarChipBiasConfigRecords.all;
use work.DACConfigRecords.all;
use work.ADCConfigRecords.all;
use work.ADCStatusRecords.all;
use work.ScannerConfigRecords.all;

entity TopLevel_CochleaTow4Ear is
	port(
		USBClock_CI                : in    std_logic;
		Reset_RI                   : in    std_logic;

		SPISlaveSelect_ABI         : in    std_logic;
		SPIClock_AI                : in    std_logic;
		SPIMOSI_AI                 : in    std_logic;
		SPIMISO_DZO                : out   std_logic;

		USBFifoData_DO             : out   std_logic_vector(USB_FIFO_WIDTH - 1 downto 0);
		USBFifoChipSelect_SBO      : out   std_logic;
		USBFifoWrite_SBO           : out   std_logic;
		USBFifoRead_SBO            : out   std_logic;
		USBFifoPktEnd_SBO          : out   std_logic;
		USBFifoAddress_DO          : out   std_logic_vector(1 downto 0);
		USBFifoThr0Ready_SI        : in    std_logic;
		USBFifoThr0Watermark_SI    : in    std_logic;
		USBFifoThr1Ready_SI        : in    std_logic;
		USBFifoThr1Watermark_SI    : in    std_logic;

		LED1_SO                    : out   std_logic;
		LED2_SO                    : out   std_logic;
		LED3_SO                    : out   std_logic;
		LED4_SO                    : out   std_logic;
		LED5_SO                    : out   std_logic;
		LED6_SO                    : out   std_logic;

		SERDESClockOutputEnable_SO : out   std_logic;
		AuxClockOutputEnable_SO    : out   std_logic;

		SRAMChipEnable1_SBO        : out   std_logic;
		SRAMOutputEnable1_SBO      : out   std_logic;
		SRAMWriteEnable1_SBO       : out   std_logic;
		SRAMChipEnable2_SBO        : out   std_logic;
		SRAMOutputEnable2_SBO      : out   std_logic;
		SRAMWriteEnable2_SBO       : out   std_logic;
		SRAMChipEnable3_SBO        : out   std_logic;
		SRAMOutputEnable3_SBO      : out   std_logic;
		SRAMWriteEnable3_SBO       : out   std_logic;
		SRAMChipEnable4_SBO        : out   std_logic;
		SRAMOutputEnable4_SBO      : out   std_logic;
		SRAMWriteEnable4_SBO       : out   std_logic;
		SRAMAddress_DO             : out   std_logic_vector(20 downto 0);
		SRAMData_DZIO              : inout std_logic_vector(15 downto 0);

		ChipBiasEnable_SO          : out   std_logic;
		ChipBiasDiagSelect_SO      : out   std_logic;
		ChipBiasAddrSelect_SO      : out   std_logic;
		ChipBiasClock_CBO          : out   std_logic;
		ChipBiasBitIn_DO           : out   std_logic;
		ChipBiasLatch_SBO          : out   std_logic;

		SelResSw_SO                : out   std_logic;
		VresetBn_SO                : out   std_logic; -- if set High, all AER local request signals are reset

		SelectAER_SBO              : out   std_logic;
		AERKillBit_SO              : out   std_logic;

		AERData_AI                 : in    std_logic_vector(AER_BUS_WIDTH - 1 downto 0);
		AERReq_ABI                 : in    std_logic;
		AERAck_SBO                 : out   std_logic;
		AERReset_SBO               : out   std_logic;

		AEROutData_DO              : out   std_logic_vector(AER_OUT_BUS_WIDTH - 1 downto 0);
		AEROutReq_SBO              : out   std_logic;
		AEROutAck_ABI              : in    std_logic;

		-- AERTestData_AI             : in    std_logic; -- Not implemented
		-- AERTestReq_ABI             : in    std_logic;
		-- AERTestAck_SBO             : out   std_logic;

		ScannerClock_CO            : out   std_logic;
		ScannerBitIn_DO            : out   std_logic;
		ScannerBitOut_DI           : in    std_logic;

		DACClock_CO                : out   std_logic;
		DAC1Sync_SBO               : out   std_logic;
		DAC2Sync_SBO               : out   std_logic;
		DACDataOut_DO              : out   std_logic;

		ADCClock_CO                : out   std_logic;
		ADCConvert_SO              : out   std_logic;
		ADC1RightDataOut_DO        : out   std_logic;
		ADC1LeftDataOut_DO         : out   std_logic;
		ADC2RightDataOut_DO        : out   std_logic;
		ADC2LeftDataOut_DO         : out   std_logic;
		ADCDataIn_DI               : in    std_logic;

		SyncOutClock_CO            : out   std_logic;
		SyncOutSignal_SO           : out   std_logic;
		SyncInClock_AI             : in    std_logic;
		SyncInSignal_AI            : in    std_logic;
		SyncInSignal1_AI           : in    std_logic;
		SyncInSignal2_AI           : in    std_logic;

		-- Debug
		debug_wire0_SO             : out   std_logic;
		debug_wire1_SO             : out   std_logic;
		debug_wire2_SO             : out   std_logic);
end TopLevel_CochleaTow4Ear;

architecture Structural of TopLevel_CochleaTow4Ear is
	signal USBReset_R   : std_logic;
	signal LogicClock_C : std_logic;
	signal LogicReset_R : std_logic;

	signal USBFifoThr0ReadySync_S, USBFifoThr0WatermarkSync_S, USBFifoThr1ReadySync_S, USBFifoThr1WatermarkSync_S : std_logic;
	signal AERReqSync_SB                                                                                          : std_logic;
	--signal SyncOutSwitchSync_S, SyncInClockSync_C, SyncInSwitchSync_S, SyncInSignalSync_S                         : std_logic;
	signal SyncInClockSync_C, SyncInSignalSync_S                                                                  : std_logic;
	signal SPISlaveSelectSync_SB, SPIClockSync_C, SPIMOSISync_D                                                   : std_logic;
	signal DeviceIsMaster_S                                                                                       : std_logic;

	signal DACSelect_SB : std_logic_vector(3 downto 0);
	signal ADCSelect_SB : std_logic_vector(ADC_CHAN_NUMBER - 1 downto 0);

	signal AERData_A          : std_logic_vector(AER_BUS_WIDTH - 1 downto 0);
	signal AERReq_AB          : std_logic;
	signal AERAckSM_SB        : std_logic;
	signal AERAck_SB          : std_logic;
	signal AERAckReg_SB       : std_logic;
	signal AEROutAckSync_SB   : std_logic;
	signal AERAckSourceMux_SB : std_logic;
	--signal AERTestAckReg_SB   : std_logic;
	--signal TestAEREnableReg_S : std_logic;

	signal In1Timestamp_S : std_logic;
	signal In2Timestamp_S : std_logic;

	signal LogicUSBFifoControlIn_S  : tToFifo;
	signal LogicUSBFifoControlOut_S : tFromFifo;
	signal LogicUSBFifoDataIn_D     : std_logic_vector(FULL_EVENT_WIDTH - 1 downto 0);
	signal LogicUSBFifoDataOut_D    : std_logic_vector(USB_FIFO_WIDTH - 1 downto 0);

	signal ADCFifoControlIn_S  : tToFifo;
	signal ADCFifoControlOut_S : tFromFifo;
	signal ADCFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal AERFifoControlIn_S  : tToFifo;
	signal AERFifoControlOut_S : tFromFifo;
	signal AERFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal AERFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal ConfigModuleAddress_D : unsigned(6 downto 0);
	signal ConfigParamAddress_D  : unsigned(7 downto 0);
	signal ConfigParamInput_D    : std_logic_vector(31 downto 0);
	signal ConfigLatchInput_S    : std_logic;
	signal ConfigParamOutput_D   : std_logic_vector(31 downto 0);

	signal MultiplexerConfigParamOutput_D : std_logic_vector(31 downto 0);
	signal AERConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal BiasConfigParamOutput_D        : std_logic_vector(31 downto 0);
	signal ChipConfigParamOutput_D        : std_logic_vector(31 downto 0);
	signal ChannelConfigParamOutput_D     : std_logic_vector(31 downto 0);
	signal SystemInfoConfigParamOutput_D  : std_logic_vector(31 downto 0);
	signal FX3ConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal DACConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal ScannerConfigParamOutput_D     : std_logic_vector(31 downto 0);
	signal ADCConfigParamOutput_D         : std_logic_vector(31 downto 0);

	signal MultiplexerConfig_D, MultiplexerConfigReg_D, MultiplexerConfigReg2_D : tMultiplexerConfig;
	signal AERConfig_D, AERConfigReg_D, AERConfigReg2_D                         : tGenericAERConfig;
	signal FX3Config_D, FX3ConfigReg_D, FX3ConfigReg2_D                         : tFX3Config;
	signal DACConfig_D, DACConfigReg_D, DACConfigReg2_D                         : tDACConfig;
	signal ADCConfig_D, ADCConfigReg_D, ADCConfigReg2_D                         : tADCConfig;
	signal ADCStatus_D                                                          : tADCStatus;
	signal ScannerConfig_D, ScannerConfigReg_D, ScannerConfigReg2_D             : tScannerConfig;

	signal CochleaTow4EarBiasConfig_D, CochleaTow4EarBiasConfigReg_D       : tCochleaTow4EarBiasConfig;
	signal CochleaTow4EarChipConfig_D, CochleaTow4EarChipConfigReg_D       : tCochleaTow4EarChipConfig;
	signal CochleaTow4EarChannelConfig_D, CochleaTow4EarChannelConfigReg_D : tCochleaTow4EarChannelConfig;

	signal debug_reg2_D : std_logic;
begin
	SelectAER_SBO <= '1';               -- Not used

	-- First: synchronize all USB-related inputs to the USB clock.
	syncInputsToUSBClock : entity work.FX3USBClockSynchronizer
		port map(
			USBClock_CI                 => USBClock_CI,
			Reset_RI                    => Reset_RI,
			ResetSync_RO                => USBReset_R,
			USBFifoThr0Ready_SI         => USBFifoThr0Ready_SI,
			USBFifoThr0ReadySync_SO     => USBFifoThr0ReadySync_S,
			USBFifoThr0Watermark_SI     => USBFifoThr0Watermark_SI,
			USBFifoThr0WatermarkSync_SO => USBFifoThr0WatermarkSync_S,
			USBFifoThr1Ready_SI         => USBFifoThr1Ready_SI,
			USBFifoThr1ReadySync_SO     => USBFifoThr1ReadySync_S,
			USBFifoThr1Watermark_SI     => USBFifoThr1Watermark_SI,
			USBFifoThr1WatermarkSync_SO => USBFifoThr1WatermarkSync_S);

	-- Second: synchronize all logic-related inputs to the logic clock.
	syncInputsToLogicClock : entity work.LogicClockSynchronizer
		port map(
			LogicClock_CI          => LogicClock_C,
			LogicReset_RI          => LogicReset_R,
			SPISlaveSelect_SBI     => SPISlaveSelect_ABI,
			SPISlaveSelectSync_SBO => SPISlaveSelectSync_SB,
			SPIClock_CI            => SPIClock_AI,
			SPIClockSync_CO        => SPIClockSync_C,
			SPIMOSI_DI             => SPIMOSI_AI,
			SPIMOSISync_DO         => SPIMOSISync_D,
			DVSAERReq_SBI          => AERReq_AB,
			DVSAERReqSync_SBO      => AERReqSync_SB,
			IMUInterrupt_SI        => '0',
			IMUInterruptSync_SO    => open,
			SyncInClock_CI         => SyncInClock_AI,
			SyncInClockSync_CO     => SyncInClockSync_C,
			SyncInSignal_SI        => SyncInSignal_AI,
			SyncInSignalSync_SO    => SyncInSignalSync_S,
			SyncInSignal1_SI       => '0',
			SyncInSignal1Sync_SO   => open,
			SyncInSignal2_SI       => '0',
			SyncInSignal2Sync_SO   => open);

	syncAEROutAck : entity work.DFFSynchronizer
		generic map(
			RESET_VALUE => '1')         -- active-low signal
		port map(
			SyncClock_CI       => LogicClock_C,
			Reset_RI           => LogicReset_R,
			SignalToSync_SI(0) => AEROutAck_ABI,
			SyncedSignal_SO(0) => AEROutAckSync_SB);

	-- Third: set all constant outputs.
	SyncOutSignal_SO <= SyncInSignalSync_S; -- Pass external input signal through.

	USBFifoChipSelect_SBO <= '0';       -- Always keep USB chip selected (active-low).
	USBFifoRead_SBO       <= '1';       -- We never read from the USB data path (active-low).
	USBFifoData_DO        <= LogicUSBFifoDataOut_D;

	-- Always enable chip if it is needed (for DVS or APS or forced).
	chipBiasEnableBuffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => AERConfig_D.Run_S or MultiplexerConfig_D.ForceChipBiasEnable_S,
			Output_SO(0) => ChipBiasEnable_SO);

	-- Keep external clocks disabled.
	SERDESClockOutputEnable_SO <= '0';
	AuxClockOutputEnable_SO    <= '0';

	-- Keep SRAM disabled.
	SRAMChipEnable1_SBO   <= '1';
	SRAMOutputEnable1_SBO <= '1';
	SRAMWriteEnable1_SBO  <= '1';
	SRAMChipEnable2_SBO   <= '1';
	SRAMOutputEnable2_SBO <= '1';
	SRAMWriteEnable2_SBO  <= '1';
	SRAMChipEnable3_SBO   <= '1';
	SRAMOutputEnable3_SBO <= '1';
	SRAMWriteEnable3_SBO  <= '1';
	SRAMChipEnable4_SBO   <= '1';
	SRAMOutputEnable4_SBO <= '1';
	SRAMWriteEnable4_SBO  <= '1';
	SRAMAddress_DO        <= (others => '0');
	SRAMData_DZIO         <= (others => '0');

	-- Test AER bus support.
	--	AERData_A      <= AERData_AI when TestAEREnableReg_S = '0' else "0000000" & AERTestData_AI;
	--	AERReq_AB      <= AERReq_ABI when TestAEREnableReg_S = '0' else AERTestReq_ABI;
	--	AERAck_SBO     <= AERAckReg_SB when TestAEREnableReg_S = '0' else '1';
	--	AERTestAck_SBO <= '1' when TestAEREnableReg_S = '0' else AERTestAckReg_SB;

	-- Cochlea AER pass through
	AEROutData_DO(AER_BUS_WIDTH - 1 downto 0)                 <= AERData_AI;
	AEROutData_DO(AER_OUT_BUS_WIDTH - 1 downto AER_BUS_WIDTH) <= (others => '0');
	AEROutReq_SBO                                             <= AERReqSync_SB;

	-- Select the source for AER event acknowlege - internal or external (from AER OUT bus)
	AERAckSourceMux_SB <= AEROutAckSync_SB when AERConfigReg2_D.ExternalAERControl_S = '1' else AERAckReg_SB;

	AERData_A  <= AERData_AI;
	AERReq_AB  <= AERReq_ABI;
	AERAck_SBO <= AERAckSourceMux_SB;

	-- Timing for AERAck is too tight when sent to both normal AER bus and test
	-- AER bus, so we add a register on each branch to improve the situation.
	-- Adding a 1-cycle delay to AER has no negative effects.
	aerACKReg : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => AERAck_SB,
			Output_SO(0) => AERAckReg_SB);

	-- Due to special AER circuit design, the AERAck_SB from FPGA must also go _LOW_
	-- when AERReset_SB goes low to reset the array. Else AERReq_SB is incorrect.
	-- AER Ack should also be asserted one cycle before reset goes low, but this is
	-- already the case with the following code. AERAck is set to low right away when
	-- the right parameters are present in AERConfigReg2_D, and then there is one more
	-- delay cycle due to above timing registers. BUT the AER state machine itself will
	-- take at least two cycles to react to this change, because AERConfigReg2_D is
	-- registered once inside the SM, and then the AER Reset output is also registered.
	-- This way, we're sure ACK goes low at least one cycle before always.
	AERAck_SB <= '0' when (AERConfigReg2_D.Run_S = '0' and AERConfigReg2_D.ExternalAERControl_S = '0') else AERAckSM_SB;

	-- Wire all LEDs.
	led1Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => MultiplexerConfig_D.Run_S,
			Output_SO(0) => LED1_SO);

	led2Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => USBClock_CI,
			Reset_RI     => USBReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => LogicUSBFifoControlOut_S.ReadSide.Empty_S,
			Output_SO(0) => LED2_SO);

	led3Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => not SPISlaveSelectSync_SB,
			Output_SO(0) => LED3_SO);

	led4Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => LogicUSBFifoControlOut_S.WriteSide.Full_S,
			Output_SO(0) => LED4_SO);

	led5Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => '0',
			Output_SO(0) => LED5_SO);

	led6Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => '0',
			Output_SO(0) => LED6_SO);

	-- Generate logic clock (using a PLL).
	logicClock : entity work.ClockDomainGenerator
		generic map(
			CLOCK_FREQ     => USB_CLOCK_FREQ,
			OUT_CLOCK_FREQ => LOGIC_CLOCK_FREQ)
		port map(
			Clock_CI        => USBClock_CI,
			Reset_RI        => Reset_RI,
			NewClock_CO     => LogicClock_C,
			NewClockHalf_CO => open,
			NewReset_RO     => LogicReset_R);

	usbFX3SM : entity work.FX3Statemachine
		port map(
			Clock_CI                    => USBClock_CI,
			Reset_RI                    => USBReset_R,
			USBFifoThread0Full_SI       => USBFifoThr0ReadySync_S,
			USBFifoThread0AlmostFull_SI => USBFifoThr0WatermarkSync_S,
			USBFifoThread1Full_SI       => USBFifoThr1ReadySync_S,
			USBFifoThread1AlmostFull_SI => USBFifoThr1WatermarkSync_S,
			USBFifoWrite_SBO            => USBFifoWrite_SBO,
			USBFifoPktEnd_SBO           => USBFifoPktEnd_SBO,
			USBFifoAddress_DO           => USBFifoAddress_DO,
			InFifoControl_SI            => LogicUSBFifoControlOut_S.ReadSide, -- tFromFifo Empty_S
			InFifoControl_SO            => LogicUSBFifoControlIn_S.ReadSide, -- tToFifo   Read_S
			FX3Config_DI                => FX3ConfigReg2_D);

	fx3SPIConfig : entity work.FX3SPIConfig
		port map(
			Clock_CI                => LogicClock_C,
			Reset_RI                => LogicReset_R,
			FX3Config_DO            => FX3Config_D,
			ConfigModuleAddress_DI  => ConfigModuleAddress_D,
			ConfigParamAddress_DI   => ConfigParamAddress_D,
			ConfigParamInput_DI     => ConfigParamInput_D,
			ConfigLatchInput_SI     => ConfigLatchInput_S,
			FX3ConfigParamOutput_DO => FX3ConfigParamOutput_D);

	-- Instantiate one FIFO to hold all the events coming out of the mixer-producer state machine.
	logicUSBFifo : entity work.FIFODualClock
		generic map(
			DATA_WIDTH        => USB_FIFO_WIDTH,
			DATA_DEPTH        => USBLOGIC_FIFO_SIZE,
			ALMOST_EMPTY_FLAG => USBLOGIC_FIFO_ALMOST_EMPTY_SIZE,
			ALMOST_FULL_FLAG  => USBLOGIC_FIFO_ALMOST_FULL_SIZE)
		port map(
			Reset_RI       => LogicReset_R,
			WrClock_CI     => LogicClock_C,
			RdClock_CI     => USBClock_CI,
			FifoControl_SI => LogicUSBFifoControlIn_S, -- tToFifo
			FifoControl_SO => LogicUSBFifoControlOut_S, -- tFromFifo
			FifoData_DI    => LogicUSBFifoDataIn_D,
			FifoData_DO    => LogicUSBFifoDataOut_D);

	-- In1 is ADC samples, timestamp all events.
	In1Timestamp_S <= '1';

	-- In2 is AER from Cochlea, timestamp all events.
	In2Timestamp_S <= '1';

	multiplexerSM : entity work.MultiplexerStateMachine
		port map(
			Clock_CI             => LogicClock_C,
			Reset_RI             => LogicReset_R,
			SyncInClock_CI       => SyncInClockSync_C,
			SyncOutClock_CO      => SyncOutClock_CO,
			DeviceIsMaster_SO    => DeviceIsMaster_S,
			OutFifoControl_SI    => LogicUSBFifoControlOut_S.WriteSide, -- tFromFifo Full_S
			OutFifoControl_SO    => LogicUSBFifoControlIn_S.WriteSide, -- tToFifo   Write_S
			OutFifoData_DO       => LogicUSBFifoDataIn_D,
			In1FifoControl_SI    => ADCFifoControlOut_S.ReadSide, -- tFromFifo Empty_S
			In1FifoControl_SO    => ADCFifoControlIn_S.ReadSide, -- tToFifo   Read_S
			In1FifoData_DI       => ADCFifoDataOut_D,
			In1Timestamp_SI      => In1Timestamp_S,
			In2FifoControl_SI    => AERFifoControlOut_S.ReadSide, -- tFromFifo Empty_S
			In2FifoControl_SO    => AERFifoControlIn_S.ReadSide, -- tToFifo   Read_S
			In2FifoData_DI       => AERFifoDataOut_D,
			In2Timestamp_SI      => In2Timestamp_S,
			In3FifoControl_SI    => (others => '1'),
			In3FifoControl_SO    => open,
			In3FifoData_DI       => (others => '0'),
			In3Timestamp_SI      => '0',
			In4FifoControl_SI    => (others => '1'),
			In4FifoControl_SO    => open,
			In4FifoData_DI       => (others => '0'),
			In4Timestamp_SI      => '0',
			In5FifoControl_SI    => (others => '1'),
			In5FifoControl_SO    => open,
			In5FifoData_DI       => (others => '0'),
			In5Timestamp_SI      => '0',
			In6FifoControl_SI    => (others => '1'),
			In6FifoControl_SO    => open,
			In6FifoData_DI       => (others => '0'),
			In6Timestamp_SI      => '0',
			MultiplexerConfig_DI => MultiplexerConfigReg2_D);

	multiplexerSPIConfig : entity work.MultiplexerSPIConfig
		port map(
			Clock_CI                        => LogicClock_C,
			Reset_RI                        => LogicReset_R,
			MultiplexerConfig_DO            => MultiplexerConfig_D,
			ConfigModuleAddress_DI          => ConfigModuleAddress_D,
			ConfigParamAddress_DI           => ConfigParamAddress_D,
			ConfigParamInput_DI             => ConfigParamInput_D,
			ConfigLatchInput_SI             => ConfigLatchInput_S,
			MultiplexerConfigParamOutput_DO => MultiplexerConfigParamOutput_D);

	dvsAerFifo : entity work.FIFO
		generic map(
			DATA_WIDTH        => EVENT_WIDTH,
			DATA_DEPTH        => DVSAER_FIFO_SIZE,
			ALMOST_EMPTY_FLAG => DVSAER_FIFO_ALMOST_EMPTY_SIZE,
			ALMOST_FULL_FLAG  => DVSAER_FIFO_ALMOST_FULL_SIZE)
		port map(
			Clock_CI       => LogicClock_C,
			Reset_RI       => LogicReset_R,
			FifoControl_SI => AERFifoControlIn_S,
			FifoControl_SO => AERFifoControlOut_S,
			FifoData_DI    => AERFifoDataIn_D,
			FifoData_DO    => AERFifoDataOut_D);

	cochleaAerSM : entity work.GenericAERStateMachine
		generic map(
			AER_BUS_WIDTH => AER_BUS_WIDTH)
		port map(
			Clock_CI          => LogicClock_C,
			Reset_RI          => LogicReset_R,
			OutFifoControl_SI => AERFifoControlOut_S.WriteSide,
			OutFifoControl_SO => AERFifoControlIn_S.WriteSide,
			OutFifoData_DO    => AERFifoDataIn_D,
			AERData_DI        => AERData_A,
			AERReq_SBI        => AERReqSync_SB,
			AERAck_SBO        => AERAckSM_SB,
			AERReset_SBO      => AERReset_SBO,
			AERConfig_DI      => AERConfigReg2_D);

	cochleaAerSPIConfig : entity work.GenericAERSPIConfig
		port map(
			Clock_CI                       => LogicClock_C,
			Reset_RI                       => LogicReset_R,
			GenericAERConfig_DO            => AERConfig_D,
			ConfigModuleAddress_DI         => ConfigModuleAddress_D,
			ConfigParamAddress_DI          => ConfigParamAddress_D,
			ConfigParamInput_DI            => ConfigParamInput_D,
			ConfigLatchInput_SI            => ConfigLatchInput_S,
			GenericAERConfigParamOutput_DO => AERConfigParamOutput_D);

	dacSM : entity work.DACStateMachine
		port map(
			Clock_CI      => LogicClock_C,
			Reset_RI      => LogicReset_R,
			DACSelect_SBO => DACSelect_SB,
			DACClock_CO   => DACClock_CO,
			DACDataOut_DO => DACDataOut_DO,
			DACConfig_DI  => DACConfigReg2_D);

	-- Connect DAC select signals to outputs.
	DAC1Sync_SBO <= DACSelect_SB(0);
	DAC2Sync_SBO <= DACSelect_SB(1);

	dacSPIConfig : entity work.DACSPIConfig
		port map(
			Clock_CI                => LogicClock_C,
			Reset_RI                => LogicReset_R,
			DACConfig_DO            => DACConfig_D,
			ConfigModuleAddress_DI  => ConfigModuleAddress_D,
			ConfigParamAddress_DI   => ConfigParamAddress_D,
			ConfigParamInput_DI     => ConfigParamInput_D,
			ConfigLatchInput_SI     => ConfigLatchInput_S,
			DACConfigParamOutput_DO => DACConfigParamOutput_D);

	scannerSM : entity work.ScannerStateMachine
		port map(
			Clock_CI         => LogicClock_C,
			Reset_RI         => LogicReset_R,
			ScannerClock_CO  => ScannerClock_CO,
			ScannerBitIn_DO  => ScannerBitIn_DO,
			ScannerConfig_DI => ScannerConfigReg2_D
			, debug_wire0 => debug_wire0_SO
			, debug_wire1 => debug_wire1_SO
		--, debug_wire0	 => open
		--, debug_wire1	 => open
		);

	scannerSPIConfig : entity work.ScannerSPIConfig
		port map(
			Clock_CI                    => LogicClock_C,
			Reset_RI                    => LogicReset_R,
			ScannerConfig_DO            => ScannerConfig_D,
			ConfigModuleAddress_DI      => ConfigModuleAddress_D,
			ConfigParamAddress_DI       => ConfigParamAddress_D,
			ConfigParamInput_DI         => ConfigParamInput_D,
			ConfigLatchInput_SI         => ConfigLatchInput_S,
			ScannerConfigParamOutput_DO => ScannerConfigParamOutput_D);

	adcSM : entity work.ADCStateMachine
		port map(
			Clock_CI        => LogicClock_C,
			Reset_RI        => LogicReset_R,
			ADC_SCK_CO      => ADCClock_CO,
			ADC_CNV_SO      => ADCConvert_SO,
			ADC_SDI_SBO     => ADCSelect_SB,
			ADC_SDO_DI      => ADCDataIn_DI,
			ADCDataRead_SI  => ADCFifoControlIn_S.ReadSide, -- tToFIFO   Read_S
			ADCDataEmpty_SO => ADCFifoControlOut_S.ReadSide, -- tFromFIFO Empty_S
			ADCEventData_DO => ADCFifoDataOut_D,
			ADCConfig_DI    => ADCConfigReg2_D,
			ADCStatus_DO    => ADCStatus_D);

	-- Connect ADC select signals to outputs.
	ADC1LeftDataOut_DO  <= ADCSelect_SB(0);
	ADC1RightDataOut_DO <= ADCSelect_SB(1);
	ADC2LeftDataOut_DO  <= ADCSelect_SB(2);
	ADC2RightDataOut_DO <= ADCSelect_SB(3);

	adcSPIConfig : entity work.ADCSPIConfig
		port map(
			Clock_CI                => LogicClock_C,
			Reset_RI                => LogicReset_R,
			ADCConfig_DO            => ADCConfig_D,
			ADCStatus_DI            => ADCStatus_D,
			ConfigModuleAddress_DI  => ConfigModuleAddress_D,
			ConfigParamAddress_DI   => ConfigParamAddress_D,
			ConfigParamInput_DI     => ConfigParamInput_D,
			ConfigLatchInput_SI     => ConfigLatchInput_S,
			ADCConfigParamOutput_DO => ADCConfigParamOutput_D);

	systemInfoSPIConfig : entity work.SystemInfoSPIConfig
		port map(
			Clock_CI                       => LogicClock_C,
			Reset_RI                       => LogicReset_R,
			DeviceIsMaster_SI              => DeviceIsMaster_S,
			ConfigParamAddress_DI          => ConfigParamAddress_D,
			SystemInfoConfigParamOutput_DO => SystemInfoConfigParamOutput_D);

	configRegisters : process(LogicClock_C, LogicReset_R) is
	begin
		if LogicReset_R = '1' then
			MultiplexerConfigReg2_D <= tMultiplexerConfigDefault;
			AERConfigReg2_D         <= tGenericAERConfigDefault;
			FX3ConfigReg2_D         <= tFX3ConfigDefault;
			DACConfigReg2_D         <= tDACConfigDefault;
			ADCConfigReg2_D         <= tADCConfigDefault;
			ScannerConfigReg2_D     <= tScannerConfigDefault;

			MultiplexerConfigReg_D <= tMultiplexerConfigDefault;
			AERConfigReg_D         <= tGenericAERConfigDefault;
			FX3ConfigReg_D         <= tFX3ConfigDefault;
			DACConfigReg_D         <= tDACConfigDefault;
			ADCConfigReg_D         <= tADCConfigDefault;
			ScannerConfigReg_D     <= tScannerConfigDefault;

		elsif rising_edge(LogicClock_C) then
			MultiplexerConfigReg2_D <= MultiplexerConfigReg_D;
			AERConfigReg2_D         <= AERConfigReg_D;
			FX3ConfigReg2_D         <= FX3ConfigReg_D;
			DACConfigReg2_D         <= DACConfigReg_D;
			ADCConfigReg2_D         <= ADCConfigReg_D;
			ScannerConfigReg2_D     <= ScannerConfigReg_D;

			MultiplexerConfigReg_D <= MultiplexerConfig_D;
			AERConfigReg_D         <= AERConfig_D;
			FX3ConfigReg_D         <= FX3Config_D;
			DACConfigReg_D         <= DACConfig_D;
			ADCConfigReg_D         <= ADCConfig_D;
			ScannerConfigReg_D     <= ScannerConfig_D;
		end if;
	end process configRegisters;

	spiConfiguration : entity work.SPIConfig
		port map(
			Clock_CI               => LogicClock_C,
			Reset_RI               => LogicReset_R,
			SPISlaveSelect_SBI     => SPISlaveSelectSync_SB,
			SPIClock_CI            => SPIClockSync_C,
			SPIMOSI_DI             => SPIMOSISync_D,
			SPIMISO_DZO            => SPIMISO_DZO,
			ConfigModuleAddress_DO => ConfigModuleAddress_D,
			ConfigParamAddress_DO  => ConfigParamAddress_D,
			ConfigParamInput_DO    => ConfigParamInput_D,
			ConfigLatchInput_SO    => ConfigLatchInput_S,
			ConfigParamOutput_DI   => ConfigParamOutput_D);

	spiConfigurationOutputSelect : process(ConfigModuleAddress_D, ConfigParamAddress_D, MultiplexerConfigParamOutput_D, AERConfigParamOutput_D, BiasConfigParamOutput_D, ChipConfigParamOutput_D, ChannelConfigParamOutput_D, SystemInfoConfigParamOutput_D, FX3ConfigParamOutput_D, DACConfigParamOutput_D, ScannerConfigParamOutput_D, ADCConfigParamOutput_D)
	begin
		-- Output side select.
		ConfigParamOutput_D <= (others => '0');

		case ConfigModuleAddress_D is
			when MULTIPLEXERCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= MultiplexerConfigParamOutput_D;

			when GENERICAERCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= AERConfigParamOutput_D;

			when CHIPBIASCONFIG_MODULE_ADDRESS =>
				if ConfigParamAddress_D(7) = '0' then
					ConfigParamOutput_D <= BiasConfigParamOutput_D; -- ParamAddress = [0 .. 127]
				else
					if ConfigParamAddress_D(7 downto 5) = "100" then -- ParamAddress = [128 .. 159]
						ConfigParamOutput_D <= ChipConfigParamOutput_D;
					else                -- ParamAddress = [160 .. 255]
						ConfigParamOutput_D <= ChannelConfigParamOutput_D;
					end if;
				end if;

			when SYSTEMINFOCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= SystemInfoConfigParamOutput_D;

			when DACCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= DACConfigParamOutput_D;

			when SCANNERCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= ScannerConfigParamOutput_D;

			when FX3CONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= FX3ConfigParamOutput_D;

			when ADCCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= ADCConfigParamOutput_D;

			when others => null;
		end case;
	end process spiConfigurationOutputSelect;

	chipBiasSM : entity work.CochleaTow4EarStateMachine
		port map(
			Clock_CI               => LogicClock_C,
			Reset_RI               => LogicReset_R,
			ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
			ChipBiasAddrSelect_SO  => ChipBiasAddrSelect_SO,
			ChipBiasClock_CBO      => ChipBiasClock_CBO,
			ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
			ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
			SelResSw_SO            => SelResSw_SO,
			BiasConfig_DI          => CochleaTow4EarBiasConfigReg_D,
			ChipConfig_DI          => CochleaTow4EarChipConfigReg_D,
			ChannelConfig_DI       => CochleaTow4EarChannelConfigReg_D,
			AERKillBit_SO          => AERKillBit_SO,
			VresetBn_SO            => VresetBn_SO);

	--debug_wire0_SO <= '0';
	--debug_wire1_SO <= ConfigParamInput_D(0);
	debug_wire2_SO <= debug_reg2_D;

	chipBiasConfigRegisters : process(LogicClock_C, LogicReset_R) is
	begin
		if LogicReset_R = '1' then
			CochleaTow4EarBiasConfigReg_D    <= tCochleaTow4EarBiasConfigDefault;
			CochleaTow4EarChipConfigReg_D    <= tCochleaTow4EarChipConfigDefault;
			CochleaTow4EarChannelConfigReg_D <= tCochleaTow4EarChannelConfigDefault;
			debug_reg2_D                     <= '0';
		elsif rising_edge(LogicClock_C) then
			CochleaTow4EarBiasConfigReg_D    <= CochleaTow4EarBiasConfig_D;
			CochleaTow4EarChipConfigReg_D    <= CochleaTow4EarChipConfig_D;
			CochleaTow4EarChannelConfigReg_D <= CochleaTow4EarChannelConfig_D;
			debug_reg2_D                     <= not debug_reg2_D;
		end if;
	end process chipBiasConfigRegisters;

	chipBiasSPIConfig : entity work.CochleaTow4EarSPIConfig
		port map(
			Clock_CI                    => LogicClock_C,
			Reset_RI                    => LogicReset_R,
			BiasConfig_DO               => CochleaTow4EarBiasConfig_D,
			ChipConfig_DO               => CochleaTow4EarChipConfig_D,
			ChannelConfig_DO            => CochleaTow4EarChannelConfig_D,
			ConfigModuleAddress_DI      => ConfigModuleAddress_D,
			ConfigParamAddress_DI       => ConfigParamAddress_D,
			ConfigParamInput_DI         => ConfigParamInput_D,
			ConfigLatchInput_SI         => ConfigLatchInput_S,
			BiasConfigParamOutput_DO    => BiasConfigParamOutput_D,
			ChipConfigParamOutput_DO    => ChipConfigParamOutput_D,
			ChannelConfigParamOutput_DO => ChannelConfigParamOutput_D);

end Structural;
