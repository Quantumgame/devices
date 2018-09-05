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
use work.SampleProbChipBiasConfigRecords.all;
use work.DACConfigRecords.all;

entity TopLevel is
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

		ChipPowerDown_SO           : out   std_logic;
		ChipBiasSelect_SO          : out   std_logic;
		ChipBiasClock_CBO          : out   std_logic;
		ChipBiasBitIn_DO           : out   std_logic;
		ChipBiasLatch_SBO          : out   std_logic;

		AERData_AI                 : in    std_logic_vector(AER_BUS_WIDTH - 1 downto 0);
		AERReq_ABI                 : in    std_logic;
		AERAck_SBO                 : out   std_logic;
		AERReset_SO                : out   std_logic;

		DACSync1_SBO               : out   std_logic;
		DACSync2_SBO               : out   std_logic;
		DACSync3_SBO               : out   std_logic;
		DACClock_CO                : out   std_logic;
		DACDataOut_DO              : out   std_logic;

		ClockRNG_CO                : out   std_logic;
		ClockHazardExt_CO          : out   std_logic;

		SyncOutClock_CO            : out   std_logic;
		SyncOutSignal_SO           : out   std_logic;
		SyncInClock_AI             : in    std_logic;
		SyncInSignal_AI            : in    std_logic;
		SyncInSignal1_AI           : in    std_logic;
		SyncInSignal2_AI           : in    std_logic;

		-- Debug
		
		--Chen-Han Chien add
		Exp_W1					: out std_logic;
		Exp_W1_Rising			: out std_logic;
		AERReq_SBI_Mid			: out std_logic;
		AERAck_SBO_Mid          : out std_logic;
		Cs						: out std_logic_vector(2 downto 0);
		Bit_To_Chip_A			: out std_logic_vector(5 downto 0);
		Bit_To_Chip_B			: out std_logic_vector(5 downto 0)
		);
end TopLevel;

architecture Structural of TopLevel is
	signal USBReset_R   : std_logic;
	signal LogicClock_C : std_logic;
	signal LogicReset_R : std_logic;

	signal USBFifoThr0ReadySync_S, USBFifoThr0WatermarkSync_S, USBFifoThr1ReadySync_S, USBFifoThr1WatermarkSync_S : std_logic;
	signal AERReqSync_SB                                                                                          : std_logic;
	signal SyncInClockSync_C, SyncInSignalSync_S                                                                  : std_logic;
	signal SPISlaveSelectSync_SB, SPIClockSync_C, SPIMOSISync_D                                                   : std_logic;
	signal DeviceIsMaster_S                                                                                       : std_logic;

	signal DACSelect_SB        : std_logic_vector(3 downto 0);
	signal AERReset_SB         : std_logic;
	signal ClockPulsePeriod_D  : unsigned(CLOCK_PERIOD_LENGTH - 1 downto 0);
	signal ClockPulseEnable_S  : std_logic;
	signal DistributionReset_S : std_logic_vector(CHANNEL_NUMBER - 1 downto 0);

	signal In1Timestamp_S : std_logic;
	signal In2Timestamp_S : std_logic;

	signal LogicUSBFifoControlIn_S  : tToFifo;
	signal LogicUSBFifoControlOut_S : tFromFifo;
	signal LogicUSBFifoDataIn_D     : std_logic_vector(FULL_EVENT_WIDTH - 1 downto 0);
	signal LogicUSBFifoDataOut_D    : std_logic_vector(USB_FIFO_WIDTH - 1 downto 0);

	signal AERFifoControlIn_S  : tToFifo;
	signal AERFifoControlOut_S : tFromFifo;
	signal AERFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal AERFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal AERFifo2ControlIn_S  : tToFifo;
	signal AERFifo2ControlOut_S : tFromFifo;
	signal AERFifo2DataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal AERFifo2DataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal RandomDACFifoControlIn_S  : tToFifo;
	signal RandomDACFifoControlOut_S : tFromFifo;
	signal RandomDACFifoDataIn_D     : std_logic_vector(EVENT_WIDTH - 1 downto 0);
	signal RandomDACFifoDataOut_D    : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	signal ConfigModuleAddress_D : unsigned(6 downto 0);
	signal ConfigParamAddress_D  : unsigned(7 downto 0);
	signal ConfigParamInput_D    : std_logic_vector(31 downto 0);
	signal ConfigLatchInput_S    : std_logic;
	signal ConfigParamOutput_D   : std_logic_vector(31 downto 0);

	signal MultiplexerConfigParamOutput_D : std_logic_vector(31 downto 0);
	signal AERConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal BiasConfigParamOutput_D        : std_logic_vector(31 downto 0);
	signal ChipConfigParamOutput_D        : std_logic_vector(31 downto 0);
	signal SystemInfoConfigParamOutput_D  : std_logic_vector(31 downto 0);
	signal FX3ConfigParamOutput_D         : std_logic_vector(31 downto 0);
	signal DACConfigParamOutput_D         : std_logic_vector(31 downto 0);

	signal MultiplexerConfig_D, MultiplexerConfigReg_D, MultiplexerConfigReg2_D : tMultiplexerConfig;
	signal AERConfig_D, AERConfigReg_D, AERConfigReg2_D                         : tGenericAERConfig;
	signal FX3Config_D, FX3ConfigReg_D, FX3ConfigReg2_D                         : tFX3Config;
	signal DACConfig_D, DACConfigReg_D, DACConfigReg2_D                         : tDACConfig;

	signal SampleProbBiasConfig_D, SampleProbBiasConfigReg_D, SampleProbBiasConfigReg2_D : tSampleProbBiasConfig;
	signal SampleProbChipConfig_D, SampleProbChipConfigReg_D                             : tSampleProbChipConfig;

	signal BiasSMInUse_S                                                                                                             : std_logic;
	signal ChipBiasSelectFromBiasSM_S, ChipBiasClockFromBiasSM_CB, ChipBiasBitInFromBiasSM_D, ChipBiasLatchFromBiasSM_SB             : std_logic;
	signal ChipBiasSelectFromVerilogSM_S, ChipBiasClockFromVerilogSM_CB, ChipBiasBitInFromVerilogSM_D, ChipBiasLatchFromVerilogSM_SB : std_logic;
	signal ClockRNGFromBiasSM_C, ClockHazardExtFromBiasSM_C                                                                          : std_logic;
	signal ClockRNGFromVerilogSM_C, ClockHazardExtFromVerilogSM_C                                                                    : std_logic;

	signal DACSMInUse_S                                    : std_logic;
	signal DACSelectFromDACSM_SB, DACSelectFromRandomSM_SB : std_logic_vector(3 downto 0);
	signal DACClockFromDACSM_C, DACClockFromRandomSM_C     : std_logic;
	signal DACDataOutFromDACSM_D, DACDataOutFromRandomSM_D : std_logic;
	
	-- Debug
	signal Timestep_S              : std_logic;
	signal SlowClock_S, AnyReset_S : std_logic;
	signal DistribReset_SO         : std_logic_vector(15 downto 0);
	signal Timestep_SO             : std_logic;

	-- Chen-Han Chien add
	signal AERExtraBit_S			: std_logic_vector(5 downto 0);
	signal Addr_Exp_W1				: std_logic_vector(3 downto 0);
	signal Req_Exp_W1_N				: std_logic;
	signal AERData_DI_Mid			: std_logic_vector(AER_BUS_WIDTH+6 downto 0);
	
	component Top
		port(
			clk_main     : in  std_logic;
			rst          : in  std_logic;
			aer_in       : in  std_logic_vector(15 downto 0);
			clk_rng      : out std_logic;
			clk_low      : out std_logic;
			clk_data_de2 : out std_logic;
			latch        : out std_logic;
			data_to_chip : out std_logic;
			exp_w1       : out std_logic;
			exp_w1_rising: out std_logic;
			req_exp_w1_n : out std_logic;
			addr_exp_w1  : out std_logic_vector(3 downto 0);
			cs           : out std_logic_vector(2 downto 0);
			bit_to_chip_a: out std_logic_vector(5 downto 0);
			bit_to_chip_b: out std_logic_vector(5 downto 0)
			);
	end component;
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
			DVSAERReq_SBI          => AERReq_ABI,
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
			Input_SI(0)  => AERConfig_D.Run_S nor MultiplexerConfig_D.ForceChipBiasEnable_S,
			Output_SO(0) => ChipPowerDown_SO); -- This is negative, thus the above 'nor' instead of 'or'.

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
			Clock_CI    => USBClock_CI,
			Reset_RI    => Reset_RI,
			NewClock_CO => LogicClock_C,
			NewReset_RO => LogicReset_R);

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
			FifoControl_SI => LogicUSBFifoControlIn_S,
			FifoControl_SO => LogicUSBFifoControlOut_S,
			FifoData_DI    => LogicUSBFifoDataIn_D,
			FifoData_DO    => LogicUSBFifoDataOut_D);

	-- In1 is random numbers from RandomDAC, timestamp all events.
	In1Timestamp_S <= '1';

	-- In2 is AER from SampleProb, timestamp all events.
	In2Timestamp_S <= '1';

	multiplexerSM : entity work.MultiplexerStateMachine
		port map(
			Clock_CI             => LogicClock_C,
			Reset_RI             => LogicReset_R,
			SyncInClock_CI       => SyncInClockSync_C,
			SyncOutClock_CO      => SyncOutClock_CO,
			DeviceIsMaster_SO    => DeviceIsMaster_S,
			OutFifoControl_SI    => LogicUSBFifoControlOut_S.WriteSide,
			OutFifoControl_SO    => LogicUSBFifoControlIn_S.WriteSide,
			OutFifoData_DO       => LogicUSBFifoDataIn_D,
			In1FifoControl_SI    => RandomDACFifoControlOut_S.ReadSide,
			In1FifoControl_SO    => RandomDACFifoControlIn_S.ReadSide,
			In1FifoData_DI       => RandomDACFifoDataOut_D,
			In1Timestamp_SI      => In1Timestamp_S,
			In2FifoControl_SI    => AERFifo2ControlOut_S.ReadSide,
			In2FifoControl_SO    => AERFifo2ControlIn_S.ReadSide,
			In2FifoData_DI       => AERFifo2DataOut_D,
			In2Timestamp_SI      => In2Timestamp_S,
			In3FifoControl_SI    => (others => '1'),
			In3FifoControl_SO    => open,
			In3FifoData_DI       => (others => '0'),
			In3Timestamp_SI      => '0',
			In4FifoControl_SI    => (others => '1'),
			In4FifoControl_SO    => open,
			In4FifoData_DI       => (others => '0'),
			In4Timestamp_SI      => '0',
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

	dvsAerFifo2 : entity work.FIFO
		generic map(
			DATA_WIDTH        => EVENT_WIDTH,
			DATA_DEPTH        => DVSAER_FIFO_SIZE,
			ALMOST_EMPTY_FLAG => DVSAER_FIFO_ALMOST_EMPTY_SIZE,
			ALMOST_FULL_FLAG  => DVSAER_FIFO_ALMOST_FULL_SIZE)
		port map(
			Clock_CI       => LogicClock_C,
			Reset_RI       => LogicReset_R,
			FifoControl_SI => AERFifo2ControlIn_S,
			FifoControl_SO => AERFifo2ControlOut_S,
			FifoData_DI    => AERFifo2DataIn_D,
			FifoData_DO    => AERFifo2DataOut_D);

	distributionResetSM : entity work.DistributionResetStateMachine
		port map(
			Clock_CI             => LogicClock_C,
			Reset_RI             => LogicReset_R,
			OutFifoEnable_SI     => AERConfigReg2_D.Run_S,
			OutFifoControl_SI    => AERFifo2ControlOut_S.WriteSide,
			OutFifoControl_SO    => AERFifo2ControlIn_S.WriteSide,
			OutFifoData_DO       => AERFifo2DataIn_D,
			InFifoControl_SI     => AERFifoControlOut_S.ReadSide,
			InFifoControl_SO     => AERFifoControlIn_S.ReadSide,
			InFifoData_DI        => AERFifoDataOut_D,
			DistributionReset_SO => DistributionReset_S);

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

	sampleProbAerSM : entity work.GenericAERStateMachine
		generic map(
			AER_BUS_WIDTH => AER_BUS_WIDTH + 7)
		port map(
			Clock_CI          => LogicClock_C,
			Reset_RI          => LogicReset_R,
			OutFifoControl_SI => AERFifoControlOut_S.WriteSide,
			OutFifoControl_SO => AERFifoControlIn_S.WriteSide,
			OutFifoData_DO    => AERFifoDataIn_D,
			AERData_DI        => AERData_DI_Mid, 						--Chen-Han Chien modifies
			AERReq_SBI        => AERReq_SBI_Mid,						--Chen-Han Chien modifies
			AERAck_SBO        => AERAck_SBO_Mid,						--Chen-Han Chien modifies
			AERReset_SBO      => AERReset_SB,
			AERConfig_DI      => AERConfigReg2_D);
			
			AERReq_SBI_Mid <= (AERReqSync_SB and (not Exp_W1_Rising)) or (Req_Exp_W1_N and Exp_W1_Rising);	--Chen-Han Chien modifies
			--from AERReqSync_SB if Exp_W1_Rising is low
			--from Req_Exp_W1_N if Exp_W1_Rising is high
			
			AERAck_SBO <= AERAck_SBO_Mid or Exp_W1_Rising;				--Chen-Han Chien modifies
			--from AERAck_SBO_Mid if Exp_W1_Rising is low
			
			AERExtraBit_S <= "101010";
			with (Exp_W1_Rising) select									--Chen-Han Chien modifies
			AERData_DI_Mid <= 	AERExtraBit_S & Exp_W1 & AERData_AI when '0',			--Chen-Han Chien modifies
								AERExtraBit_S & Exp_W1 & Addr_Exp_W1 when others;		--Chen-Han Chien modifies
			--add one extra bit Exp_W1
			--from AERData_AI if Exp_W1_Rising is low
			--from Addr_Exp_W1 if Exp_W1_Rising is high
			
	-- Reset is active-high in SampleProb chip.
	AERReset_SO <= not AERReset_SB;

	sampleProbAerSPIConfig : entity work.GenericAERSPIConfig
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
			DACSelect_SBO => DACSelectFromDACSM_SB,
			DACClock_CO   => DACClockFromDACSM_C,
			DACDataOut_DO => DACDataOutFromDACSM_D,
			DACSMInUse_SO => DACSMInUse_S,
			DACConfig_DI  => DACConfigReg2_D);

	-- Connect DAC select signals to outputs.
	DACSync1_SBO <= DACSelect_SB(0);
	DACSync2_SBO <= DACSelect_SB(1);
	DACSync3_SBO <= DACSelect_SB(2);

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

			MultiplexerConfigReg_D <= tMultiplexerConfigDefault;
			AERConfigReg_D         <= tGenericAERConfigDefault;
			FX3ConfigReg_D         <= tFX3ConfigDefault;
			DACConfigReg_D         <= tDACConfigDefault;
		elsif rising_edge(LogicClock_C) then
			MultiplexerConfigReg2_D <= MultiplexerConfigReg_D;
			AERConfigReg2_D         <= AERConfigReg_D;
			FX3ConfigReg2_D         <= FX3ConfigReg_D;
			DACConfigReg2_D         <= DACConfigReg_D;

			MultiplexerConfigReg_D <= MultiplexerConfig_D;
			AERConfigReg_D         <= AERConfig_D;
			FX3ConfigReg_D         <= FX3Config_D;
			DACConfigReg_D         <= DACConfig_D;
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

	spiConfigurationOutputSelect : process(ConfigModuleAddress_D, ConfigParamAddress_D, MultiplexerConfigParamOutput_D, AERConfigParamOutput_D, BiasConfigParamOutput_D, ChipConfigParamOutput_D, SystemInfoConfigParamOutput_D, FX3ConfigParamOutput_D, DACConfigParamOutput_D)
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
					ConfigParamOutput_D <= BiasConfigParamOutput_D;
				else
					ConfigParamOutput_D <= ChipConfigParamOutput_D;
				end if;

			when SYSTEMINFOCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= SystemInfoConfigParamOutput_D;

			when FX3CONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= FX3ConfigParamOutput_D;

			when DACCONFIG_MODULE_ADDRESS =>
				ConfigParamOutput_D <= DACConfigParamOutput_D;

			when others => null;
		end case;
	end process spiConfigurationOutputSelect;

	chipBiasSM : entity work.SampleProbStateMachine
		port map(Clock_CI             => LogicClock_C,
			     Reset_RI             => LogicReset_R,
			     ChipBiasSelect_SO    => ChipBiasSelectFromBiasSM_S,
			     ChipBiasClock_CBO    => ChipBiasClockFromBiasSM_CB,
			     ChipBiasBitIn_DO     => ChipBiasBitInFromBiasSM_D,
			     ChipBiasLatch_SBO    => ChipBiasLatchFromBiasSM_SB,
			     DistributionReset_SI => DistributionReset_S,
			     AERReset_SI          => AERReset_SO,
			     Timestep_SI          => ClockRNG_CO,
			     BiasSMInUse_SO       => BiasSMInUse_S,
			     BiasConfig_DI        => SampleProbBiasConfigReg_D,
			     ChipConfig_DI        => SampleProbChipConfigReg_D,
			     Timestep_SO          => Timestep_S);

	chipBiasConfigRegisters : process(LogicClock_C, LogicReset_R) is
	begin
		if LogicReset_R = '1' then
			SampleProbBiasConfigReg2_D <= tSampleProbBiasConfigDefault;
			SampleProbBiasConfigReg_D  <= tSampleProbBiasConfigDefault;

			SampleProbChipConfigReg_D <= tSampleProbChipConfigDefault;
		elsif rising_edge(LogicClock_C) then
			SampleProbBiasConfigReg2_D <= SampleProbBiasConfigReg_D;
			SampleProbBiasConfigReg_D  <= SampleProbBiasConfig_D;

			SampleProbChipConfigReg_D <= SampleProbChipConfig_D;
		end if;
	end process chipBiasConfigRegisters;

	chipBiasSPIConfig : entity work.SampleProbSPIConfig
		port map(Clock_CI                 => LogicClock_C,
			     Reset_RI                 => LogicReset_R,
			     BiasConfig_DO            => SampleProbBiasConfig_D,
			     ChipConfig_DO            => SampleProbChipConfig_D,
			     ConfigModuleAddress_DI   => ConfigModuleAddress_D,
			     ConfigParamAddress_DI    => ConfigParamAddress_D,
			     ConfigParamInput_DI      => ConfigParamInput_D,
			     ConfigLatchInput_SI      => ConfigLatchInput_S,
			     BiasConfigParamOutput_DO => BiasConfigParamOutput_D,
			     ChipConfigParamOutput_DO => ChipConfigParamOutput_D);

	-- Generate configurable pulse for clocking the random number generator (RNG).
	ClockPulseEnable_S <= SampleProbBiasConfigReg_D.ClockPulseEnable_S;
	ClockPulsePeriod_D <= SampleProbBiasConfigReg_D.ClockPulsePeriod_D;

	rngClockGenerator : entity work.PulseGenerator
		generic map(
			SIZE => CLOCK_PERIOD_LENGTH)
		port map(
			Clock_CI                                           => LogicClock_C,
			Reset_RI                                           => LogicReset_R,
			PulsePolarity_SI                                   => '1',
			PulseInterval_DI(CLOCK_PERIOD_LENGTH - 1 downto 0) => ClockPulsePeriod_D,
			PulseLength_DI(CLOCK_PERIOD_LENGTH - 1 downto 0)   => '0' & ClockPulsePeriod_D(CLOCK_PERIOD_LENGTH - 1 downto 1),
			Zero_SI                                            => not ClockPulseEnable_S or AERReset_SO,
			PulseOut_SO                                        => ClockRNGFromBiasSM_C);

	hazardClockGenerator : entity work.PulseGenerator
		generic map(
			SIZE => CLOCK_PERIOD_LENGTH + 5)
		port map(
			Clock_CI                                               => LogicClock_C,
			Reset_RI                                               => LogicReset_R,
			PulsePolarity_SI                                       => '1',
			PulseInterval_DI(CLOCK_PERIOD_LENGTH + 5 - 1 downto 0) => ClockPulsePeriod_D & "00000",
			PulseLength_DI(CLOCK_PERIOD_LENGTH + 5 - 1 downto 0)   => '0' & ClockPulsePeriod_D(CLOCK_PERIOD_LENGTH - 1 downto 1) & "00000",
			Zero_SI                                                => not ClockPulseEnable_S or AERReset_SO,
			PulseOut_SO                                            => ClockHazardExtFromBiasSM_C);

	landscapeSamplingVerilog : component Top
		port map(
			clk_main     => LogicClock_C,
			rst          => LogicReset_R,
			aer_in       => DistributionReset_S,
			clk_rng      => ClockRNGFromVerilogSM_C,
			clk_low      => ClockHazardExtFromVerilogSM_C,
			clk_data_de2 => ChipBiasClockFromVerilogSM_CB,
			latch        => ChipBiasLatchFromVerilogSM_SB,
			data_to_chip => ChipBiasBitInFromVerilogSM_D,
			exp_w1       => Exp_W1,
			exp_w1_rising=> Exp_W1_Rising,
			req_exp_w1_n => Req_Exp_W1_N,
			addr_exp_w1  => Addr_Exp_W1,
			cs           => Cs,
			bit_to_chip_a=> Bit_To_Chip_A,
			bit_to_chip_b=> Bit_To_Chip_B
			);

	-- When Verilog module active, we always send chip config, never biases, so this is always '1'.
	ChipBiasSelectFromVerilogSM_S <= '1';

	ChipBiasSelect_SO <= ChipBiasSelectFromVerilogSM_S when (SampleProbBiasConfigReg2_D.UseLandscapeSamplingVerilog_S = '1' and BiasSMInUse_S = '0') else ChipBiasSelectFromBiasSM_S;
	ChipBiasClock_CBO <= ChipBiasClockFromVerilogSM_CB when (SampleProbBiasConfigReg2_D.UseLandscapeSamplingVerilog_S = '1' and BiasSMInUse_S = '0') else ChipBiasClockFromBiasSM_CB;
	ChipBiasBitIn_DO  <= ChipBiasBitInFromVerilogSM_D when (SampleProbBiasConfigReg2_D.UseLandscapeSamplingVerilog_S = '1' and BiasSMInUse_S = '0') else ChipBiasBitInFromBiasSM_D;
	ChipBiasLatch_SBO <= ChipBiasLatchFromVerilogSM_SB when (SampleProbBiasConfigReg2_D.UseLandscapeSamplingVerilog_S = '1' and BiasSMInUse_S = '0') else ChipBiasLatchFromBiasSM_SB;

	ClockRNG_CO       <= ClockRNGFromVerilogSM_C when (SampleProbBiasConfigReg2_D.UseLandscapeSamplingVerilog_S = '1') else ClockRNGFromBiasSM_C;
	ClockHazardExt_CO <= ClockHazardExtFromVerilogSM_C when (SampleProbBiasConfigReg2_D.UseLandscapeSamplingVerilog_S = '1') else ClockHazardExtFromBiasSM_C;

	-- Support sending random values to DAC 3 (Noise). If enabled and not sending normal commands.
	DACClock_CO   <= DACClockFromRandomSM_C when (DACConfigReg2_D.RunRandomDAC_S = '1' and DACSMInUse_S = '0') else DACClockFromDACSM_C;
	DACDataOut_DO <= DACDataOutFromRandomSM_D when (DACConfigReg2_D.RunRandomDAC_S = '1' and DACSMInUse_S = '0') else DACDataOutFromDACSM_D;
	DACSelect_SB  <= DACSelectFromRandomSM_SB when (DACConfigReg2_D.RunRandomDAC_S = '1' and DACSMInUse_S = '0') else DACSelectFromDACSM_SB;

	randomDACFifo : entity work.FIFO
		generic map(
			DATA_WIDTH        => EVENT_WIDTH,
			DATA_DEPTH        => 512,
			ALMOST_EMPTY_FLAG => 2,
			ALMOST_FULL_FLAG  => 2)
		port map(
			Clock_CI       => LogicClock_C,
			Reset_RI       => LogicReset_R,
			FifoControl_SI => RandomDACFifoControlIn_S,
			FifoControl_SO => RandomDACFifoControlOut_S,
			FifoData_DI    => RandomDACFifoDataIn_D,
			FifoData_DO    => RandomDACFifoDataOut_D);

	randomNoiseDAC : entity work.RandomDACStateMachine
		port map(
			Clock_CI            => LogicClock_C,
			Reset_RI            => LogicReset_R,
			OutFifoControl_SI   => RandomDACFifoControlOut_S.WriteSide,
			OutFifoControl_SO   => RandomDACFifoControlIn_S.WriteSide,
			OutFifoData_DO      => RandomDACFifoDataIn_D,
			DACSelect_SBO       => DACSelectFromRandomSM_SB,
			DACClock_CO         => DACClockFromRandomSM_C,
			DACDataOut_DO       => DACDataOutFromRandomSM_D,
			TransactionClock_SI => ClockRNG_CO,
			DACConfig_DI        => DACConfigReg2_D);

	-- Debug
	timestepRegister : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Enable_SI    => '1',
			Input_SI(0)  => Timestep_S,
			Output_SO(0) => Timestep_SO);

	distribResetRegister : entity work.SimpleRegister
		generic map(
			SIZE => 16)
		port map(
			Clock_CI  => LogicClock_C,
			Reset_RI  => LogicReset_R,
			Enable_SI => AnyReset_S or SlowClock_S,
			Input_SI  => DistributionReset_S,
			Output_SO => DistribReset_SO);

	AnyReset_S <= or (DistributionReset_S);

	slowClock : entity work.ContinuousCounter
		generic map(
			SIZE              => 3,
			RESET_ON_OVERFLOW => true,
			GENERATE_OVERFLOW => true,
			SHORT_OVERFLOW    => true)
		port map(
			Clock_CI     => LogicClock_C,
			Reset_RI     => LogicReset_R,
			Clear_SI     => AnyReset_S,
			Enable_SI    => '1',
			DataLimit_DI => to_unsigned(5, 3),
			Overflow_SO  => SlowClock_S,
			Data_DO      => open);
end Structural;
