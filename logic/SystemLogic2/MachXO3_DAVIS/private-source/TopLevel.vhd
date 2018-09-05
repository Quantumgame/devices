library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.EventCodes.all;
use work.Settings.all;
use work.FIFORecords.all;
use work.MultiplexerConfigRecords.all;
use work.DVSAERConfigRecords.all;
use work.APSADCConfigRecords.all;
use work.IMUConfigRecords.all;
use work.ExtInputConfigRecords.all;
use work.InvenSenseMicConfigRecords.all;
use work.ChipBiasConfigRecords.all;
use work.SystemInfoConfigRecords.all;
use work.FX3ConfigRecords.all;

entity TopLevel is
	port(
		USBClock_CI              : in    std_logic;
		Reset_RI                 : in    std_logic;

		SPISlaveSelect_ABI       : in    std_logic;
		SPIClock_AI              : in    std_logic;
		SPIMOSI_AI               : in    std_logic;
		SPIMISO_DZO              : out   std_logic;

		USBFifoData_DO           : out   std_logic_vector(15 downto 0);
		USBFifoChipSelect_SBO    : out   std_logic;
		USBFifoWrite_SBO         : out   std_logic;
		USBFifoRead_SBO          : out   std_logic;
		USBFifoPktEnd_SBO        : out   std_logic;
		USBFifoAddress_DO        : out   std_logic_vector(1 downto 0);
		USBFifoThr0Ready_SI      : in    std_logic;
		USBFifoThr0Watermark_SI  : in    std_logic;
		USBFifoThr1Ready_SI      : in    std_logic;
		USBFifoThr1Watermark_SI  : in    std_logic;

		LED1_SO                  : out   std_logic;
		LED2_SO                  : out   std_logic;

		ChipBiasEnable_SO        : out   std_logic;
		ChipBiasDiagSelect_SO    : out   std_logic;
		ChipBiasAddrSelect_SBO   : out   std_logic;
		ChipBiasClock_CBO        : out   std_logic;
		ChipBiasBitIn_DO         : out   std_logic;
		ChipBiasLatch_SBO        : out   std_logic;
		-- ChipBiasBitOut_DI : in std_logic;

		DVSAERData_AI            : in    std_logic_vector(DVS_AER_BUS_WIDTH - 1 downto 0);
		DVSAERReq_ABI            : in    std_logic;
		DVSAERAck_SBO            : out   std_logic;
		DVSAERReset_SBO          : out   std_logic;

		APSChipColSRClock_CO     : out   std_logic;
		APSChipColSRIn_SO        : out   std_logic;
		APSChipRowSRClock_CO     : out   std_logic;
		APSChipRowSRIn_SO        : out   std_logic;
		APSChipColMode_DO        : out   std_logic_vector(1 downto 0);
		APSChipTXGate_SBO        : out   std_logic;

		ChipADCData_DI           : in    std_logic_vector(APS_ADC_BUS_WIDTH - 1 downto 0);
		ChipADCRampClear_SO      : out   std_logic;
		ChipADCRampClock_CO      : out   std_logic;
		ChipADCRampBitIn_SO      : out   std_logic;
		ChipADCScanClock_CO      : out   std_logic;
		ChipADCScanControl_SO    : out   std_logic;
		ChipADCSample_SO         : out   std_logic;
		ChipADCGrayCounter_DO    : out   std_logic_vector(APS_ADC_BUS_WIDTH - 1 downto 0);

		IMUClock_CZO             : out   std_logic;
		IMUData_DZIO             : inout std_logic;
		IMUInterrupt_AI          : in    std_logic;
		IMUFSync_SO              : out   std_logic;

		SyncOutClock_CO          : out   std_logic;
		SyncOutSignal_SO         : out   std_logic;
		SyncInClock_AI           : in    std_logic;
		SyncInSignal_AI          : in    std_logic;

		MicrophoneClock_CO       : out   std_logic;
		MicrophoneData_DI        : in    std_logic;
		MicrophoneSelectRight_SO : out   std_logic;
		MicrophoneSelectLeft_SO  : out   std_logic;

		IOPortClock_CO           : out   std_logic;
		IOPortSelect_SBO         : out   std_logic;
		IOPort_DO                : out   std_logic_vector(17 downto 0));
end TopLevel;

architecture Structural of TopLevel is
	signal USBReset_R   : std_logic;
	signal LogicClock_C : std_logic;
	signal LogicReset_R : std_logic;
	signal ADCClock_C   : std_logic;
	signal ADCReset_R   : std_logic;

	signal USBFifoThr0ReadySync_S, USBFifoThr0WatermarkSync_S, USBFifoThr1ReadySync_S, USBFifoThr1WatermarkSync_S : std_logic;
	signal DVSAERReqSync_SB, IMUInterruptSync_S                                                                   : std_logic;
	signal SyncInClockSync_C, SyncInSignalSync_S                                                                  : std_logic;
	signal SPISlaveSelectSync_SB, SPIClockSync_C, SPIMOSISync_D                                                   : std_logic;
	signal DeviceIsMaster_S, DeviceIsMasterBuffer_S                                                               : std_logic;

	signal In1Timestamp_S, In2Timestamp_S, In3Timestamp_S, In4Timestamp_S, In5Timestamp_S : std_logic;

	signal LogicUSBFifoControlIn_S  : tToFifo;
	signal LogicUSBFifoControlOut_S : tFromFifo;
	signal LogicUSBFifoDataIn_D     : std_logic_vector(FULL_EVENT_WIDTH - 1 downto 0);
	signal LogicUSBFifoDataOut_D    : std_logic_vector(USB_FIFO_WIDTH - 1 downto 0);

	signal DVSAERFifoControlIn_S  : tToFifo;
	signal DVSAERFifoControlOut_S : tFromFifo;
	signal DVSAERFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal DVSAERFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal APSADCFifoControlIn_S  : tToFifo;
	signal APSADCFifoControlOut_S : tFromFifo;
	signal APSADCFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal APSADCFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal IMUFifoControlIn_S  : tToFifo;
	signal IMUFifoControlOut_S : tFromFifo;
	signal IMUFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal IMUFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal ExtInputFifoControlIn_S  : tToFifo;
	signal ExtInputFifoControlOut_S : tFromFifo;
	signal ExtInputFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal ExtInputFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal MicrophoneFifoControlIn_S  : tToFifo;
	signal MicrophoneFifoControlOut_S : tFromFifo;
	signal MicrophoneFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal MicrophoneFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal ConfigModuleAddress_D : unsigned(6 downto 0);
	signal ConfigParamAddress_D  : unsigned(7 downto 0);
	signal ConfigParamInput_D    : std_logic_vector(31 downto 0);
	signal ConfigLatchInput_S    : std_logic;
	signal ConfigParamOutput_D   : std_logic_vector(31 downto 0);

	signal MultiplexerConfigParamOutput_D : std_logic_vector(31 downto 0);
	signal DVSAERConfigParamOutput_D      : std_logic_vector(31 downto 0);
	signal APSADCConfigParamOutput_D      : std_logic_vector(31 downto 0);
	signal IMUConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal ExtInputConfigParamOutput_D    : std_logic_vector(31 downto 0);
	signal SystemInfoConfigParamOutput_D  : std_logic_vector(31 downto 0);
	signal FX3ConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal MicrophoneConfigParamOutput_D  : std_logic_vector(31 downto 0);

	signal MultiplexerConfig_D : tMultiplexerConfig;
	signal DVSAERConfig_D      : tDVSAERConfig;
	signal APSADCConfig_D      : tAPSADCConfig;
	signal IMUConfig_D         : tIMUConfig;
	signal ExtInputConfig_D    : tExtInputConfig;
	signal FX3Config_D         : tFX3Config;
	signal MicrophoneConfig_D  : tInvenSenseMicConfig;

	signal DVSAERConfigInfoOut_D      : tDVSAERConfigInfoOut;
	signal MultiplexerConfigInfoOut_D : tMultiplexerConfigInfoOut;
begin
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
			DVSAERReq_SBI          => DVSAERReq_ABI,
			DVSAERReqSync_SBO      => DVSAERReqSync_SB,
			IMUInterrupt_SI        => IMUInterrupt_AI,
			IMUInterruptSync_SO    => IMUInterruptSync_S,
			SyncInClock_CI         => SyncInClock_AI,
			SyncInClockSync_CO     => SyncInClockSync_C,
			SyncInSignal_SI        => SyncInSignal_AI,
			SyncInSignalSync_SO    => SyncInSignalSync_S,
			SyncInSignal1_SI       => '0',
			SyncInSignal1Sync_SO   => open,
			SyncInSignal2_SI       => '0',
			SyncInSignal2Sync_SO   => open);

	-- Third: set all constant outputs.
	IMUFSync_SO <= '0';                 -- Not used, tie to ground according to docs.

	USBFifoChipSelect_SBO <= '0';       -- Always keep USB chip selected (active-low).
	USBFifoRead_SBO       <= '1';       -- We never read from the USB data path (active-low).
	USBFifoData_DO        <= LogicUSBFifoDataOut_D;

	-- Always enable chip if it is needed (for DVS or APS or forced).
	chipBiasEnableBuffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => DVSAERConfig_D.Run_S or APSADCConfig_D.Run_S or MultiplexerConfig_D.ForceChipBiasEnable_S,
			Output_SO(0) => ChipBiasEnable_SO);

	-- Wire all LEDs.
	led1Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => DeviceIsMasterBuffer_S,
			Output_SO(0) => LED1_SO);

	led2Buffer : entity work.SimpleRegister
		port map(
			Clock_CI     => USBClock_CI,
			Reset_RI     => USBReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => LogicUSBFifoControlOut_S.ReadSide.Empty_S,
			Output_SO(0) => LED2_SO);

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

	-- Generate ADC clock (using a PLL).
	adccClock : entity work.ClockDomainGenerator
		generic map(
			CLOCK_FREQ     => USB_CLOCK_FREQ,
			OUT_CLOCK_FREQ => ADC_CLOCK_FREQ)
		port map(
			Clock_CI        => USBClock_CI,
			Reset_RI        => Reset_RI,
			NewClock_CO     => ADCClock_C,
			NewClockHalf_CO => open,
			NewReset_RO     => ADCReset_R);

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
			InFifoControl_SI            => LogicUSBFifoControlOut_S.ReadSide,
			InFifoControl_SO            => LogicUSBFifoControlIn_S.ReadSide,
			FX3Config_DI                => FX3Config_D);

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
			WrClock_CI     => LogicClock_C,
			WrReset_RI     => LogicReset_R,
			RdClock_CI     => USBClock_CI,
			RdReset_RI     => USBReset_R,
			FifoControl_SI => LogicUSBFifoControlIn_S,
			FifoControl_SO => LogicUSBFifoControlOut_S,
			FifoData_DI    => LogicUSBFifoDataIn_D,
			FifoData_DO    => LogicUSBFifoDataOut_D);

	-- In1 is DVS, TS Y addresses. In2 is APS, TS special. In3 is IMU, TS special.
	-- In4 is ExtInput, TS all. In5 is Microphone, TS First_Left/Right events.
	In1Timestamp_S <= '1' when DVSAERFifoDataOut_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) = EVENT_CODE_Y_ADDR else '0';
	In2Timestamp_S <= '1' when APSADCFifoDataOut_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) = EVENT_CODE_SPECIAL else '0';
	In3Timestamp_S <= '1' when IMUFifoDataOut_D(EVENT_WIDTH - 1 downto EVENT_WIDTH - 3) = EVENT_CODE_SPECIAL else '0';
	In4Timestamp_S <= '1';

	multiplexerSM : entity work.MultiplexerStateMachine
		generic map(
			ENABLE_INPUT_5    => MICROPHONES_ENABLE,
			ENABLE_STATISTICS => true)
		port map(
			Clock_CI                    => LogicClock_C,
			Reset_RI                    => LogicReset_R,
			SyncInClock_CI              => SyncInClockSync_C,
			SyncOutClock_CO             => SyncOutClock_CO,
			DeviceIsMaster_SO           => DeviceIsMaster_S,
			OutFifoControl_SI           => LogicUSBFifoControlOut_S.WriteSide,
			OutFifoControl_SO           => LogicUSBFifoControlIn_S.WriteSide,
			OutFifoData_DO              => LogicUSBFifoDataIn_D,
			In1FifoControl_SI           => DVSAERFifoControlOut_S.ReadSide,
			In1FifoControl_SO           => DVSAERFifoControlIn_S.ReadSide,
			In1FifoData_DI              => DVSAERFifoDataOut_D,
			In1Timestamp_SI             => In1Timestamp_S,
			In2FifoControl_SI           => APSADCFifoControlOut_S.ReadSide,
			In2FifoControl_SO           => APSADCFifoControlIn_S.ReadSide,
			In2FifoData_DI              => APSADCFifoDataOut_D,
			In2Timestamp_SI             => In2Timestamp_S,
			In3FifoControl_SI           => IMUFifoControlOut_S.ReadSide,
			In3FifoControl_SO           => IMUFifoControlIn_S.ReadSide,
			In3FifoData_DI              => IMUFifoDataOut_D,
			In3Timestamp_SI             => In3Timestamp_S,
			In4FifoControl_SI           => ExtInputFifoControlOut_S.ReadSide,
			In4FifoControl_SO           => ExtInputFifoControlIn_S.ReadSide,
			In4FifoData_DI              => ExtInputFifoDataOut_D,
			In4Timestamp_SI             => In4Timestamp_S,
			In5FifoControl_SI           => MicrophoneFifoControlOut_S.ReadSide,
			In5FifoControl_SO           => MicrophoneFifoControlIn_S.ReadSide,
			In5FifoData_DI              => MicrophoneFifoDataOut_D,
			In5Timestamp_SI             => In5Timestamp_S,
			In6FifoControl_SI           => (others => '1'),
			In6FifoControl_SO           => open,
			In6FifoData_DI              => (others => '0'),
			In6Timestamp_SI             => '0',
			MultiplexerConfig_DI        => MultiplexerConfig_D,
			MultiplexerConfigInfoOut_DO => MultiplexerConfigInfoOut_D);

	multiplexerSPIConfig : entity work.MultiplexerSPIConfig
		generic map(
			ENABLE_INPUT_5    => MICROPHONES_ENABLE,
			ENABLE_STATISTICS => true)
		port map(
			Clock_CI                        => LogicClock_C,
			Reset_RI                        => LogicReset_R,
			MultiplexerConfig_DO            => MultiplexerConfig_D,
			MultiplexerConfigInfoOut_DI     => MultiplexerConfigInfoOut_D,
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
			FifoControl_SI => DVSAERFifoControlIn_S,
			FifoControl_SO => DVSAERFifoControlOut_S,
			FifoData_DI    => DVSAERFifoDataIn_D,
			FifoData_DO    => DVSAERFifoDataOut_D);

	dvsAerSM : entity work.DVSAERStateMachine
		generic map(
			ENABLE_ROI_FILTERING       => true,
			ENABLE_PIXEL_FILTERING     => true,
			ENABLE_BA_REFR_FILTERING   => DVS_BAFILTER_ENABLE,
			BA_FILTER_SUBSAMPLE_COLUMN => DVS_BAFILTER_SUBSAMPLE_COL,
			BA_FILTER_SUBSAMPLE_ROW    => DVS_BAFILTER_SUBSAMPLE_ROW,
			ENABLE_STATISTICS          => true)
		port map(
			Clock_CI               => LogicClock_C,
			Reset_RI               => LogicReset_R,
			OutFifoControl_SI      => DVSAERFifoControlOut_S.WriteSide,
			OutFifoControl_SO      => DVSAERFifoControlIn_S.WriteSide,
			OutFifoData_DO         => DVSAERFifoDataIn_D,
			DVSAERData_DI          => DVSAERData_AI,
			DVSAERReq_SBI          => DVSAERReqSync_SB,
			DVSAERAck_SBO          => DVSAERAck_SBO,
			DVSAERReset_SBO        => DVSAERReset_SBO,
			DVSAERConfig_DI        => DVSAERConfig_D,
			DVSAERConfigInfoOut_DO => DVSAERConfigInfoOut_D);

	dvsaerSPIConfig : entity work.DVSAERSPIConfig
		generic map(
			ENABLE_ROI_FILTERING     => true,
			ENABLE_PIXEL_FILTERING   => true,
			ENABLE_BA_REFR_FILTERING => DVS_BAFILTER_ENABLE,
			ENABLE_STATISTICS        => true)
		port map(
			Clock_CI                   => LogicClock_C,
			Reset_RI                   => LogicReset_R,
			DVSAERConfig_DO            => DVSAERConfig_D,
			DVSAERConfigInfoOut_DI     => DVSAERConfigInfoOut_D,
			ConfigModuleAddress_DI     => ConfigModuleAddress_D,
			ConfigParamAddress_DI      => ConfigParamAddress_D,
			ConfigParamInput_DI        => ConfigParamInput_D,
			ConfigLatchInput_SI        => ConfigLatchInput_S,
			DVSAERConfigParamOutput_DO => DVSAERConfigParamOutput_D);

	-- Dual-clock FIFO is needed to bridge from ADC clock (ADCClock_C in this case) to logic clock.
	apsAdcFifo : entity work.FIFODualClock
		generic map(
			DATA_WIDTH        => EVENT_WIDTH,
			DATA_DEPTH        => APSADC_FIFO_SIZE,
			ALMOST_EMPTY_FLAG => APSADC_FIFO_ALMOST_EMPTY_SIZE,
			ALMOST_FULL_FLAG  => APSADC_FIFO_ALMOST_FULL_SIZE)
		port map(
			WrClock_CI     => ADCClock_C,
			WrReset_RI     => ADCReset_R,
			RdClock_CI     => LogicClock_C,
			RdReset_RI     => LogicReset_R,
			FifoControl_SI => APSADCFifoControlIn_S,
			FifoControl_SO => APSADCFifoControlOut_S,
			FifoData_DI    => APSADCFifoDataIn_D,
			FifoData_DO    => APSADCFifoDataOut_D);

	apsAdcSM : entity work.APSADCStateMachine
		generic map(
			ENABLE_QUAD_ROI => true)
		port map(
			Clock_CI              => ADCClock_C,
			Reset_RI              => ADCReset_R,
			OutFifoControl_SI     => APSADCFifoControlOut_S.WriteSide,
			OutFifoControl_SO     => APSADCFifoControlIn_S.WriteSide,
			OutFifoData_DO        => APSADCFifoDataIn_D,
			APSChipColSRClock_CO  => APSChipColSRClock_CO,
			APSChipColSRIn_SO     => APSChipColSRIn_SO,
			APSChipColMode_DO     => APSChipColMode_DO,
			APSChipTXGate_SBO     => APSChipTXGate_SBO,
			ChipADCData_DI        => ChipADCData_DI,
			ChipADCRampClear_SO   => ChipADCRampClear_SO,
			ChipADCRampClock_CO   => ChipADCRampClock_CO,
			ChipADCRampBitIn_SO   => ChipADCRampBitIn_SO,
			ChipADCScanClock_CO   => ChipADCScanClock_CO,
			ChipADCScanControl_SO => ChipADCScanControl_SO,
			ChipADCSample_SO      => ChipADCSample_SO,
			ChipADCGrayCounter_DO => ChipADCGrayCounter_DO,
			APSADCConfig_DI       => APSADCConfig_D);

	APSChipRowSRClock_CO <= '0';
	APSChipRowSRIn_SO    <= '0';

	apsAdcSPIConfig : entity work.APSADCSPIConfig
		generic map(
			ENABLE_QUAD_ROI => true)
		port map(
			Clock_CI                   => LogicClock_C,
			Reset_RI                   => LogicReset_R,
			APSADCConfig_DO            => APSADCConfig_D,
			ConfigModuleAddress_DI     => ConfigModuleAddress_D,
			ConfigParamAddress_DI      => ConfigParamAddress_D,
			ConfigParamInput_DI        => ConfigParamInput_D,
			ConfigLatchInput_SI        => ConfigLatchInput_S,
			APSADCConfigParamOutput_DO => APSADCConfigParamOutput_D);

	imuFifo : entity work.FIFO
		generic map(
			DATA_WIDTH        => EVENT_WIDTH,
			DATA_DEPTH        => IMU_FIFO_SIZE,
			ALMOST_EMPTY_FLAG => IMU_FIFO_ALMOST_EMPTY_SIZE,
			ALMOST_FULL_FLAG  => IMU_FIFO_ALMOST_FULL_SIZE)
		port map(
			Clock_CI       => LogicClock_C,
			Reset_RI       => LogicReset_R,
			FifoControl_SI => IMUFifoControlIn_S,
			FifoControl_SO => IMUFifoControlOut_S,
			FifoData_DI    => IMUFifoDataIn_D,
			FifoData_DO    => IMUFifoDataOut_D);

	imuSM : entity work.IMUStateMachine
		port map(
			Clock_CI          => LogicClock_C,
			Reset_RI          => LogicReset_R,
			OutFifoControl_SI => IMUFifoControlOut_S.WriteSide,
			OutFifoControl_SO => IMUFifoControlIn_S.WriteSide,
			OutFifoData_DO    => IMUFifoDataIn_D,
			IMUClock_CZO      => IMUClock_CZO,
			IMUData_DZIO      => IMUData_DZIO,
			IMUInterrupt_SI   => IMUInterruptSync_S,
			IMUConfig_DI      => IMUConfig_D);

	imuSPIConfig : entity work.IMUSPIConfig
		generic map(
			IMU_ORIENTATION => "110")
		port map(
			Clock_CI                => LogicClock_C,
			Reset_RI                => LogicReset_R,
			IMUConfig_DO            => IMUConfig_D,
			ConfigModuleAddress_DI  => ConfigModuleAddress_D,
			ConfigParamAddress_DI   => ConfigParamAddress_D,
			ConfigParamInput_DI     => ConfigParamInput_D,
			ConfigLatchInput_SI     => ConfigLatchInput_S,
			IMUConfigParamOutput_DO => IMUConfigParamOutput_D);

	extInputFifo : entity work.FIFO
		generic map(
			DATA_WIDTH        => EVENT_WIDTH,
			DATA_DEPTH        => EXT_INPUT_FIFO_SIZE,
			ALMOST_EMPTY_FLAG => EXT_INPUT_FIFO_ALMOST_EMPTY_SIZE,
			ALMOST_FULL_FLAG  => EXT_INPUT_FIFO_ALMOST_FULL_SIZE)
		port map(
			Clock_CI       => LogicClock_C,
			Reset_RI       => LogicReset_R,
			FifoControl_SI => ExtInputFifoControlIn_S,
			FifoControl_SO => ExtInputFifoControlOut_S,
			FifoData_DI    => ExtInputFifoDataIn_D,
			FifoData_DO    => ExtInputFifoDataOut_D);

	extInputSM : entity work.ExtInputStateMachine
		port map(
			Clock_CI              => LogicClock_C,
			Reset_RI              => LogicReset_R,
			OutFifoControl_SI     => ExtInputFifoControlOut_S.WriteSide,
			OutFifoControl_SO     => ExtInputFifoControlIn_S.WriteSide,
			OutFifoData_DO        => ExtInputFifoDataIn_D,
			ExtInputSignal_SI     => SyncInSignalSync_S,
			ExtInputSignal1_SI    => '0',
			ExtInputSignal2_SI    => '0',
			CustomOutputSignal_SI => '1',
			ExtInputSignal_SO     => SyncOutSignal_SO,
			ExtInputConfig_DI     => ExtInputConfig_D);

	extInputSPIConfig : entity work.ExtInputSPIConfig
		port map(
			Clock_CI                     => LogicClock_C,
			Reset_RI                     => LogicReset_R,
			ExtInputConfig_DO            => ExtInputConfig_D,
			ConfigModuleAddress_DI       => ConfigModuleAddress_D,
			ConfigParamAddress_DI        => ConfigParamAddress_D,
			ConfigParamInput_DI          => ConfigParamInput_D,
			ConfigLatchInput_SI          => ConfigLatchInput_S,
			ExtInputConfigParamOutput_DO => ExtInputConfigParamOutput_D);

	deviceIsMasterBuffer : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => DeviceIsMaster_S,
			Output_SO(0) => DeviceIsMasterBuffer_S);

	systemInfoSPIConfig : entity work.SystemInfoSPIConfig
		port map(
			Clock_CI                       => LogicClock_C,
			Reset_RI                       => LogicReset_R,
			DeviceIsMaster_SI              => DeviceIsMasterBuffer_S,
			ConfigParamAddress_DI          => ConfigParamAddress_D,
			SystemInfoConfigParamOutput_DO => SystemInfoConfigParamOutput_D);

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

	spiConfigurationOutputSelect : process(ConfigModuleAddress_D, MultiplexerConfigParamOutput_D, DVSAERConfigParamOutput_D, APSADCConfigParamOutput_D, IMUConfigParamOutput_D, ExtInputConfigParamOutput_D, SystemInfoConfigParamOutput_D, FX3ConfigParamOutput_D, MicrophoneConfigParamOutput_D)
	begin
		-- Output side select.
		ConfigParamOutput_D <= (others => '0');

		case ConfigModuleAddress_D is
			when MULTIPLEXERCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= MultiplexerConfigParamOutput_D;

			when DVSAERCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= DVSAERConfigParamOutput_D;

			when APSADCCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= APSADCConfigParamOutput_D;

			when IMUCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= IMUConfigParamOutput_D;

			when EXTINPUTCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= ExtInputConfigParamOutput_D;

			when SYSTEMINFOCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= SystemInfoConfigParamOutput_D;

			when FX3CONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= FX3ConfigParamOutput_D;

			when INVENSENSEMICCONFIG_MODULE_ADDRESS =>
				if MICROPHONES_ENABLE = true then
					ConfigParamOutput_D <= MicrophoneConfigParamOutput_D;
				end if;

			when others => null;
		end case;
	end process spiConfigurationOutputSelect;

	chipBiasGenericSM : entity work.ChipBiasGenericStateMachine
		port map(
			Clock_CI               => LogicClock_C,
			Reset_RI               => LogicReset_R,
			ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
			ChipBiasAddrSelect_SBO => ChipBiasAddrSelect_SBO,
			ChipBiasClock_CBO      => ChipBiasClock_CBO,
			ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
			ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
			ConfigModuleAddress_DI => ConfigModuleAddress_D,
			ConfigParamAddress_DI  => ConfigParamAddress_D,
			ConfigParamInput_DI    => ConfigParamInput_D,
			ConfigLatchInput_SI    => ConfigLatchInput_S);

	microphonesEnabled : if MICROPHONES_ENABLE = true generate
		In5Timestamp_S <= '1' when MicrophoneFifoDataOut_D(EVENT_WIDTH - 4 downto EVENT_WIDTH - 6) = "010" else '0';

		-- Stereo microphones support (InvenSense ICS-43432).
		microphoneFifo : entity work.FIFO
			generic map(
				DATA_WIDTH        => EVENT_WIDTH,
				DATA_DEPTH        => MICROPHONE_FIFO_SIZE,
				ALMOST_EMPTY_FLAG => MICROPHONE_FIFO_ALMOST_EMPTY_SIZE,
				ALMOST_FULL_FLAG  => MICROPHONE_FIFO_ALMOST_FULL_SIZE)
			port map(
				Clock_CI       => LogicClock_C,
				Reset_RI       => LogicReset_R,
				FifoControl_SI => MicrophoneFifoControlIn_S,
				FifoControl_SO => MicrophoneFifoControlOut_S,
				FifoData_DI    => MicrophoneFifoDataIn_D,
				FifoData_DO    => MicrophoneFifoDataOut_D);

		microphoneSM : entity work.InvenSenseMicStateMachine
			port map(
				Clock_CI                 => LogicClock_C,
				Reset_RI                 => LogicReset_R,
				OutFifoControl_SI        => MicrophoneFifoControlOut_S.WriteSide,
				OutFifoControl_SO        => MicrophoneFifoControlIn_S.WriteSide,
				OutFifoData_DO           => MicrophoneFifoDataIn_D,
				MicrophoneClock_CO       => MicrophoneClock_CO,
				MicrophoneData_DI        => MicrophoneData_DI,
				MicrophoneSelectRight_SO => MicrophoneSelectRight_SO,
				MicrophoneSelectLeft_SO  => MicrophoneSelectLeft_SO,
				MicConfig_DI             => MicrophoneConfig_D);

		microphoneSPIConfig : entity work.InvenSenseMicSPIConfig
			port map(
				Clock_CI                          => LogicClock_C,
				Reset_RI                          => LogicReset_R,
				InvenSenseMicConfig_DO            => MicrophoneConfig_D,
				ConfigModuleAddress_DI            => ConfigModuleAddress_D,
				ConfigParamAddress_DI             => ConfigParamAddress_D,
				ConfigParamInput_DI               => ConfigParamInput_D,
				ConfigLatchInput_SI               => ConfigLatchInput_S,
				InvenSenseMicConfigParamOutput_DO => MicrophoneConfigParamOutput_D);
	end generate microphonesEnabled;

	microphonesDisabled : if MICROPHONES_ENABLE = false generate
		MicrophoneFifoControlOut_S.ReadSide <= (others => '1');
		MicrophoneFifoDataOut_D             <= (others => '0');
		In5Timestamp_S                      <= '0';

		MicrophoneClock_CO       <= '0';
		MicrophoneSelectRight_SO <= '0';
		MicrophoneSelectLeft_SO  <= '0';
	end generate microphonesDisabled;

	-- Nothing to output on GPIO port right now.
	IOPortClock_CO   <= '0';
	IOPortSelect_SBO <= '1';
	IOPort_DO        <= (others => '0');
end Structural;
