library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.EventCodes.all;
use work.FIFORecords.all;
use work.ExtInputConfigRecords.all;

entity ExtInputStateMachine is
	generic(
		ENABLE_GENERATOR       : boolean := false;
		ENABLE_EXTRA_DETECTORS : boolean := false);
	port(
		Clock_CI              : in  std_logic;
		Reset_RI              : in  std_logic;

		-- Fifo output (to Multiplexer)
		OutFifoControl_SI     : in  tFromFifoWriteSide;
		OutFifoControl_SO     : out tToFifoWriteSide;
		OutFifoData_DO        : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		-- Input from jack
		ExtInputSignal_SI     : in  std_logic;

		-- Additional inputs from other pins
		ExtInputSignal1_SI    : in  std_logic;
		ExtInputSignal2_SI    : in  std_logic;

		-- Output to jack
		CustomOutputSignal_SI : in  std_logic;
		ExtInputSignal_SO     : out std_logic;

		-- Configuration input
		ExtInputConfig_DI     : in  tExtInputConfig);
end entity ExtInputStateMachine;

architecture Behavioral of ExtInputStateMachine is
	-- Detector signals.
	signal RisingEdgeDetected_S  : std_logic;
	signal FallingEdgeDetected_S : std_logic;
	signal PulseDetected_S       : std_logic;

	signal BufferRisingEdgeClear_S, BufferRisingEdgeOutput_S   : std_logic;
	signal BufferFallingEdgeClear_S, BufferFallingEdgeOutput_S : std_logic;
	signal BufferPulseClear_S, BufferPulseOutput_S             : std_logic;

	signal GeneratorBufferRisingEdgeClear_S, GeneratorBufferRisingEdgeOutput_S   : std_logic;
	signal GeneratorBufferFallingEdgeClear_S, GeneratorBufferFallingEdgeOutput_S : std_logic;

	signal Detector1BufferRisingEdgeClear_S, Detector1BufferRisingEdgeOutput_S   : std_logic;
	signal Detector1BufferFallingEdgeClear_S, Detector1BufferFallingEdgeOutput_S : std_logic;
	signal Detector1BufferPulseClear_S, Detector1BufferPulseOutput_S             : std_logic;
	signal Detector2BufferRisingEdgeClear_S, Detector2BufferRisingEdgeOutput_S   : std_logic;
	signal Detector2BufferFallingEdgeClear_S, Detector2BufferFallingEdgeOutput_S : std_logic;
	signal Detector2BufferPulseClear_S, Detector2BufferPulseOutput_S             : std_logic;

	-- Register outputs to FIFO.
	signal OutFifoWriteReg_S : std_logic;
	signal OutFifoDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	-- Register configuration inputs.
	signal ExtInputConfigReg_D : tExtInputConfig;
begin
	extInputDetectorLogic : process(OutFifoControl_SI, BufferRisingEdgeOutput_S, BufferFallingEdgeOutput_S, BufferPulseOutput_S, GeneratorBufferRisingEdgeOutput_S, GeneratorBufferFallingEdgeOutput_S, Detector1BufferFallingEdgeOutput_S, Detector1BufferPulseOutput_S, Detector1BufferRisingEdgeOutput_S, Detector2BufferFallingEdgeOutput_S, Detector2BufferPulseOutput_S, Detector2BufferRisingEdgeOutput_S)
	begin
		OutFifoWriteReg_S <= '0';
		OutFifoDataReg_D  <= (others => '0');

		BufferRisingEdgeClear_S  <= '0';
		BufferFallingEdgeClear_S <= '0';
		BufferPulseClear_S       <= '0';

		GeneratorBufferRisingEdgeClear_S  <= '0';
		GeneratorBufferFallingEdgeClear_S <= '0';

		Detector1BufferRisingEdgeClear_S  <= '0';
		Detector1BufferFallingEdgeClear_S <= '0';
		Detector1BufferPulseClear_S       <= '0';
		Detector2BufferRisingEdgeClear_S  <= '0';
		Detector2BufferFallingEdgeClear_S <= '0';
		Detector2BufferPulseClear_S       <= '0';

		-- Check that there is space for at least two elements (AlmostFull flag). This is needed because
		-- registering the FIFO outputs puts a 1 cycle delay on writing to the FIFO, which means the
		-- flags also get updated 1 cycle late. We work around that by checking for a flag that tells us
		-- if two elements would fit, instead of just one.
		if OutFifoControl_SI.AlmostFull_S = '0' then
			if BufferRisingEdgeOutput_S = '1' then
				BufferRisingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT_RISING;
			elsif BufferFallingEdgeOutput_S = '1' then
				BufferFallingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT_FALLING;
			elsif BufferPulseOutput_S = '1' then
				BufferPulseClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT_PULSE;
			elsif Detector1BufferRisingEdgeOutput_S = '1' then
				Detector1BufferRisingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT1_RISING;
			elsif Detector1BufferFallingEdgeOutput_S = '1' then
				Detector1BufferFallingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT1_FALLING;
			elsif Detector1BufferPulseOutput_S = '1' then
				Detector1BufferPulseClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT1_PULSE;
			elsif Detector2BufferRisingEdgeOutput_S = '1' then
				Detector2BufferRisingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT2_RISING;
			elsif Detector2BufferFallingEdgeOutput_S = '1' then
				Detector2BufferFallingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT2_FALLING;
			elsif Detector2BufferPulseOutput_S = '1' then
				Detector2BufferPulseClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUT2_PULSE;
			elsif GeneratorBufferRisingEdgeOutput_S = '1' then
				GeneratorBufferRisingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUTGEN_RISING;
			elsif GeneratorBufferFallingEdgeOutput_S = '1' then
				GeneratorBufferFallingEdgeClear_S <= '1';

				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_EXT_INPUTGEN_FALLING;
			end if;
		end if;
	end process extInputDetectorLogic;

	extInputBufferRisindEdge : entity work.BufferClear
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			Clear_SI        => BufferRisingEdgeClear_S,
			InputSignal_SI  => ExtInputConfigReg_D.RunDetector_S and ExtInputConfigReg_D.DetectRisingEdges_S and RisingEdgeDetected_S,
			OutputSignal_SO => BufferRisingEdgeOutput_S);

	extInputBufferFallingEdge : entity work.BufferClear
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			Clear_SI        => BufferFallingEdgeClear_S,
			InputSignal_SI  => ExtInputConfigReg_D.RunDetector_S and ExtInputConfigReg_D.DetectFallingEdges_S and FallingEdgeDetected_S,
			OutputSignal_SO => BufferFallingEdgeOutput_S);

	extInputBufferPulse : entity work.BufferClear
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			Clear_SI        => BufferPulseClear_S,
			InputSignal_SI  => ExtInputConfigReg_D.RunDetector_S and ExtInputConfigReg_D.DetectPulses_S and PulseDetected_S,
			OutputSignal_SO => BufferPulseOutput_S);

	extInputEdgeDetector : entity work.EdgeDetector
		generic map(
			SIGNAL_INITIAL_POLARITY => not tExtInputConfigDefault.DetectPulsePolarity_S)
		port map(
			Clock_CI               => Clock_CI,
			Reset_RI               => Reset_RI,
			InputSignal_SI         => ExtInputSignal_SI,
			RisingEdgeDetected_SO  => RisingEdgeDetected_S,
			FallingEdgeDetected_SO => FallingEdgeDetected_S);

	extInputPulseDetector : entity work.PulseDetector
		generic map(
			SIZE => EXTINPUT_MAX_TIME_SIZE)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			PulsePolarity_SI => ExtInputConfigReg_D.DetectPulsePolarity_S,
			PulseLength_DI   => ExtInputConfigReg_D.DetectPulseLength_D,
			InputSignal_SI   => ExtInputSignal_SI,
			PulseDetected_SO => PulseDetected_S);

	-- Change state on clock edge (synchronous).
	registerUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			OutFifoControl_SO.Write_S <= '0';
			OutFifoData_DO            <= (others => '0');

			ExtInputConfigReg_D <= tExtInputConfigDefault;
		elsif rising_edge(Clock_CI) then
			OutFifoControl_SO.Write_S <= OutFifoWriteReg_S;
			OutFifoData_DO            <= OutFifoDataReg_D;

			ExtInputConfigReg_D <= ExtInputConfig_DI;
		end if;
	end process registerUpdate;

	generator : if ENABLE_GENERATOR = true generate
		-- Generator signal.
		signal GeneratedPulse_S               : std_logic;
		signal GeneratorRisingEdgeDetected_S  : std_logic;
		signal GeneratorFallingEdgeDetected_S : std_logic;
		signal ExtInputOut_S                  : std_logic;
		signal ExtInputOutBuffer_S            : std_logic;
		signal ExtInputSignalOut_S            : std_logic;
	begin
		extInputPulseGenerator : entity work.PulseGenerator
			generic map(
				SIZE                    => EXTINPUT_MAX_TIME_SIZE,
				SIGNAL_INITIAL_POLARITY => not tExtInputConfigDefault.GeneratePulsePolarity_S)
			port map(
				Clock_CI         => Clock_CI,
				Reset_RI         => Reset_RI,
				PulsePolarity_SI => ExtInputConfigReg_D.GeneratePulsePolarity_S,
				PulseInterval_DI => ExtInputConfigReg_D.GeneratePulseInterval_D,
				PulseLength_DI   => ExtInputConfigReg_D.GeneratePulseLength_D,
				Zero_SI          => not ExtInputConfigReg_D.RunGenerator_S or ExtInputConfigReg_D.GenerateUseCustomSignal_S,
				PulseOut_SO      => GeneratedPulse_S);

		extInputGeneratorEdgeDetector : entity work.EdgeDetector
			generic map(
				SIGNAL_INITIAL_POLARITY => not tExtInputConfigDefault.GeneratePulsePolarity_S)
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				InputSignal_SI         => GeneratedPulse_S,
				RisingEdgeDetected_SO  => GeneratorRisingEdgeDetected_S,
				FallingEdgeDetected_SO => GeneratorFallingEdgeDetected_S);

		extInputGeneratorBufferRisindEdge : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => GeneratorBufferRisingEdgeClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunGenerator_S and ExtInputConfigReg_D.GenerateInjectOnRisingEdge_S and GeneratorRisingEdgeDetected_S,
				OutputSignal_SO => GeneratorBufferRisingEdgeOutput_S);

		extInputGeneratorBufferFallingEdge : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => GeneratorBufferFallingEdgeClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunGenerator_S and ExtInputConfigReg_D.GenerateInjectOnFallingEdge_S and GeneratorFallingEdgeDetected_S,
				OutputSignal_SO => GeneratorBufferFallingEdgeOutput_S);

		ExtInputOut_S <= CustomOutputSignal_SI when (ExtInputConfigReg_D.GenerateUseCustomSignal_S = '1') else GeneratedPulse_S;

		extInputOutBuffer : entity work.SimpleRegister
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => ExtInputOut_S,
				Output_SO(0) => ExtInputOutBuffer_S);

		ExtInputSignalOut_S <= ExtInputOutBuffer_S when (ExtInputConfigReg_D.RunGenerator_S = '1') else ExtInputSignal_SI;

		-- Register output to meet timing specifications.
		extInputSignalOutBuffer : entity work.SimpleRegister
			port map(
				Clock_CI     => Clock_CI,
				Reset_RI     => Reset_RI,
				Enable_SI    => '1',
				Input_SI(0)  => ExtInputSignalOut_S,
				Output_SO(0) => ExtInputSignal_SO);
	end generate generator;

	generatorDisabled : if ENABLE_GENERATOR = false generate
		-- If generator disabled, just redirect input to output.
		ExtInputSignal_SO <= ExtInputSignal_SI;

		GeneratorBufferRisingEdgeOutput_S  <= '0';
		GeneratorBufferFallingEdgeOutput_S <= '0';
	end generate generatorDisabled;

	extraDetectors : if ENABLE_EXTRA_DETECTORS = true generate
		signal Detector1RisingEdgeDetected_S  : std_logic;
		signal Detector1FallingEdgeDetected_S : std_logic;
		signal Detector1PulseDetected_S       : std_logic;
		signal Detector2RisingEdgeDetected_S  : std_logic;
		signal Detector2FallingEdgeDetected_S : std_logic;
		signal Detector2PulseDetected_S       : std_logic;
	begin
		extInputDetector1BufferRisindEdge : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => Detector1BufferRisingEdgeClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunDetector1_S and ExtInputConfigReg_D.DetectRisingEdges1_S and Detector1RisingEdgeDetected_S,
				OutputSignal_SO => Detector1BufferRisingEdgeOutput_S);

		extInputDetector1BufferFallingEdge : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => Detector1BufferFallingEdgeClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunDetector1_S and ExtInputConfigReg_D.DetectFallingEdges1_S and Detector1FallingEdgeDetected_S,
				OutputSignal_SO => Detector1BufferFallingEdgeOutput_S);

		extInputDetector1BufferPulse : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => Detector1BufferPulseClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunDetector1_S and ExtInputConfigReg_D.DetectPulses1_S and Detector1PulseDetected_S,
				OutputSignal_SO => Detector1BufferPulseOutput_S);

		extInputDetector1EdgeDetector : entity work.EdgeDetector
			generic map(
				SIGNAL_INITIAL_POLARITY => not tExtInputConfigDefault.DetectPulsePolarity1_S)
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				InputSignal_SI         => ExtInputSignal1_SI,
				RisingEdgeDetected_SO  => Detector1RisingEdgeDetected_S,
				FallingEdgeDetected_SO => Detector1FallingEdgeDetected_S);

		extInputDetector1PulseDetector : entity work.PulseDetector
			generic map(
				SIZE => EXTINPUT_MAX_TIME_SIZE)
			port map(
				Clock_CI         => Clock_CI,
				Reset_RI         => Reset_RI,
				PulsePolarity_SI => ExtInputConfigReg_D.DetectPulsePolarity1_S,
				PulseLength_DI   => ExtInputConfigReg_D.DetectPulseLength1_D,
				InputSignal_SI   => ExtInputSignal1_SI,
				PulseDetected_SO => Detector1PulseDetected_S);

		extInputDetector2BufferRisindEdge : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => Detector2BufferRisingEdgeClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunDetector2_S and ExtInputConfigReg_D.DetectRisingEdges2_S and Detector2RisingEdgeDetected_S,
				OutputSignal_SO => Detector2BufferRisingEdgeOutput_S);

		extInputDetector2BufferFallingEdge : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => Detector2BufferFallingEdgeClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunDetector2_S and ExtInputConfigReg_D.DetectFallingEdges2_S and Detector2FallingEdgeDetected_S,
				OutputSignal_SO => Detector2BufferFallingEdgeOutput_S);

		extInputDetector2BufferPulse : entity work.BufferClear
			port map(
				Clock_CI        => Clock_CI,
				Reset_RI        => Reset_RI,
				Clear_SI        => Detector2BufferPulseClear_S,
				InputSignal_SI  => ExtInputConfigReg_D.RunDetector2_S and ExtInputConfigReg_D.DetectPulses2_S and Detector2PulseDetected_S,
				OutputSignal_SO => Detector2BufferPulseOutput_S);

		extInputDetector2EdgeDetector : entity work.EdgeDetector
			generic map(
				SIGNAL_INITIAL_POLARITY => not tExtInputConfigDefault.DetectPulsePolarity2_S)
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				InputSignal_SI         => ExtInputSignal2_SI,
				RisingEdgeDetected_SO  => Detector2RisingEdgeDetected_S,
				FallingEdgeDetected_SO => Detector2FallingEdgeDetected_S);

		extInputDetector2PulseDetector : entity work.PulseDetector
			generic map(
				SIZE => EXTINPUT_MAX_TIME_SIZE)
			port map(
				Clock_CI         => Clock_CI,
				Reset_RI         => Reset_RI,
				PulsePolarity_SI => ExtInputConfigReg_D.DetectPulsePolarity2_S,
				PulseLength_DI   => ExtInputConfigReg_D.DetectPulseLength2_D,
				InputSignal_SI   => ExtInputSignal2_SI,
				PulseDetected_SO => Detector2PulseDetected_S);
	end generate extraDetectors;

	extraDetectorsDisabled : if ENABLE_EXTRA_DETECTORS = false generate
		Detector1BufferRisingEdgeOutput_S  <= '0';
		Detector1BufferFallingEdgeOutput_S <= '0';
		Detector1BufferPulseOutput_S       <= '0';
		Detector2BufferRisingEdgeOutput_S  <= '0';
		Detector2BufferFallingEdgeOutput_S <= '0';
		Detector2BufferPulseOutput_S       <= '0';
	end generate extraDetectorsDisabled;
end architecture Behavioral;
