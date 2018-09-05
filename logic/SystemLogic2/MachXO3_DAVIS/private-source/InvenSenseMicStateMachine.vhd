library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.EventCodes.all;
use work.FIFORecords.all;
use work.ShiftRegisterModes.all;
use work.InvenSenseMicConfigRecords.all;

entity InvenSenseMicStateMachine is
	port(
		Clock_CI                 : in  std_logic;
		Reset_RI                 : in  std_logic;

		-- Fifo output (to Multiplexer)
		-- Almost full must be set to 3, size should be multiple of 3 or close.
		OutFifoControl_SI        : in  tFromFifoWriteSide;
		OutFifoControl_SO        : out tToFifoWriteSide;
		OutFifoData_DO           : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		-- Microphone controls
		MicrophoneClock_CO       : out std_logic;
		MicrophoneData_DI        : in  std_logic;
		MicrophoneSelectRight_SO : out std_logic;
		MicrophoneSelectLeft_SO  : out std_logic;

		-- Configuration input
		MicConfig_DI             : in  tInvenSenseMicConfig);
end InvenSenseMicStateMachine;

architecture Behavioral of InvenSenseMicStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stSend1, stSend2, stSend3);
	attribute syn_enum_encoding of tState : type is "onehot";

	-- present and next state
	signal State_DP, State_DN : tState;

	-- Microphone data width.
	constant MIC_DATA_WIDTH : integer := 24;

	-- Register outputs to microphones.
	signal MicrophoneClockReg_C      : std_logic;
	signal MicrophoneWordSelectReg_S : std_logic;

	-- Input shift register control for microphone data.
	signal MicrophoneSRMode_S : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal MicrophoneSRData_D : std_logic_vector(MIC_DATA_WIDTH - 1 downto 0);

	signal MicrophoneCaptureLeft_S  : std_logic;
	signal MicrophoneCaptureRight_S : std_logic;
	signal MicrophoneCaptureBit_S   : std_logic;

	-- SCK counter.
	signal SckCounter_D : unsigned(tInvenSenseMicConfig.SampleCycles_D'range);

	-- WordSelect counter.
	signal WsCount_S   : std_logic;
	signal WsCounter_D : unsigned(5 downto 0);

	-- Register output to FIFO.
	signal OutFifoWriteReg_S : std_logic;
	signal OutFifoDataReg_D  : std_logic_vector(EVENT_WIDTH - 1 downto 0);

	-- Register configuration input.
	signal MicConfigReg_D : tInvenSenseMicConfig;
begin
	micShiftRegister : entity work.ShiftRegister
		generic map(
			SIZE => MIC_DATA_WIDTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => MicrophoneSRMode_S,
			DataIn_DI        => MicrophoneData_DI,
			ParallelWrite_DI => (others => '0'),
			ParallelRead_DO  => MicrophoneSRData_D);

	-- The microphone's WordSelect, which corresponds ultimately to the desired sampling
	-- frequency, can be toggled from 7.19 KHz to 52.8 KHz. Each period is made up of 64
	-- SCK transitions, 32 during the low period (Left channel) and 32 during the high
	-- period (Right channel). So SCK has to be 64 times as fast. And ultimately SCK has
	-- to boil down to a certain number of cycles running at the LogicClock_C speed, which
	-- is 100.8 MHz for the standard MachXO3 logic. This means one SCK clock cycle should take
	-- between 30 and 219 LogicClock_C cycles ( (LOGIC_FREQ * 1000) / (SAMPLE_FREQ * 64) ),
	-- and one WordSelect clock cycles 64 times that number.
	-- The default sampling frequency is set to 48KHz, which results in 32 cycles.
	-- For simplicity, we take the user-supplied number of LogicClock_C cycles to one
	-- SCK clock cycle, and derive the right frequencies from there, as this is easy
	-- with them all being results of multiplications and divisions by powers of two.
	-- So we then have the user-supplied SampleCycles_D: 30-219 LogicClock_C cycles
	-- SCK is then SampleCycles_D directly (with LOW period being SampleCycles_D >> 1)
	-- WordSelect is SampleCycles_D << 6 (with LOW period being SampleCycles_D << 5)
	sckCounter : entity work.ContinuousCounter
		generic map(
			SIZE => tInvenSenseMicConfig.SampleCycles_D'length)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not MicConfigReg_D.Run_S,
			Enable_SI    => '1',
			DataLimit_DI => MicConfigReg_D.SampleCycles_D - 1,
			Overflow_SO  => WsCount_S,
			Data_DO      => SckCounter_D);

	-- When not running (SckCounter_D = 0), keep at ground. First half of period is LOW, then HIGH.
	MicrophoneClockReg_C <= '1' when (SckCounter_D >= MicConfigReg_D.SampleCycles_D(tInvenSenseMicConfig.SampleCycles_D'length - 1 downto 1)) else '0';

	wsCounter : entity work.Counter
		generic map(
			SIZE => 6)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not MicConfigReg_D.Run_S,
			Enable_SI    => WsCount_S,
			Data_DO      => WsCounter_D);

	-- When not running (WsCounter_D = 0), keep at ground. First half of period is LOW, then HIGH.
	-- So first part is LEFT (low) when 0-31, then RIGHT (high) when 32-63.
	MicrophoneWordSelectReg_S <= '1' when (WsCounter_D >= 32) else '0';

	-- We capture a new bit of data on the SCK rising edge. There are 24 bits, starting with
	-- one cycle of delay, so we don't capture on SCK cycle 0. Then we capture 1 to 24 inclusive.
	-- And then again we don't capture 32, but 33 to 56 inclusive for the other stereo channel.
	MicrophoneCaptureLeft_S  <= '1' when (WsCounter_D >= 1 and WsCounter_D <= MIC_DATA_WIDTH) else '0';
	MicrophoneCaptureRight_S <= '1' when (WsCounter_D >= (32 + 1) and WsCounter_D <= (32 + MIC_DATA_WIDTH)) else '0';

	MicrophoneCaptureBit_S <= '1' when (SckCounter_D = MicConfigReg_D.SampleCycles_D(tInvenSenseMicConfig.SampleCycles_D'length - 1 downto 1) and (MicrophoneCaptureLeft_S = '1' or MicrophoneCaptureRight_S = '1')) else '0';

	MicrophoneSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT when (MicrophoneCaptureBit_S = '1') else SHIFTREGISTER_MODE_DO_NOTHING;

	-- After we have shifted in 24 new bits of data, on SCK cycle 25, we send the data to the FIFO.
	-- We split the 24 bits up into 3x8 bits, the first event will also differentiate between Right
	-- or Left channel. If the three events can be sent to FIFO, it will start a cascade that will
	-- see them committed in just three cycles one after another.
	invenSenseMicLogic : process(State_DP, OutFifoControl_SI, SckCounter_D, WsCounter_D, MicrophoneSRData_D)
	begin
		State_DN <= State_DP;           -- Keep current state by default.

		OutFifoWriteReg_S <= '0';
		OutFifoDataReg_D  <= (others => '0');

		case State_DP is
			when stIdle =>
				-- We just captured the last bit 24 for sure above, so if there is space, we can send it out.
				if OutFifoControl_SI.AlmostFull_S = '0' and SckCounter_D = 0 and (WsCounter_D = 25 or WsCounter_D = (32 + 25)) then
					State_DN <= stSend1;
				end if;

			when stSend1 =>
				OutFifoWriteReg_S <= '1';
				if WsCounter_D = 25 then
					-- Left channel.
					OutFifoDataReg_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_MIC_FIRST_LEFT & MicrophoneSRData_D(MIC_DATA_WIDTH - 1 downto MIC_DATA_WIDTH - 8);
				else
					-- Right channel.
					OutFifoDataReg_D <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_MIC_FIRST_RIGHT & MicrophoneSRData_D(MIC_DATA_WIDTH - 1 downto MIC_DATA_WIDTH - 8);
				end if;

				State_DN <= stSend2;

			when stSend2 =>
				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_MIC_SECOND & MicrophoneSRData_D(MIC_DATA_WIDTH - 9 downto MIC_DATA_WIDTH - 16);

				State_DN <= stSend3;

			when stSend3 =>
				OutFifoWriteReg_S <= '1';
				OutFifoDataReg_D  <= EVENT_CODE_MISC_DATA8 & EVENT_CODE_MISC_DATA8_MIC_THIRD & MicrophoneSRData_D(MIC_DATA_WIDTH - 17 downto MIC_DATA_WIDTH - 24);

				State_DN <= stIdle;

			when others => null;
		end case;
	end process invenSenseMicLogic;

	invenSenseMicRegisterUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			State_DP <= stIdle;

			MicrophoneClock_CO       <= '0';
			MicrophoneSelectLeft_SO  <= '0';
			MicrophoneSelectRight_SO <= '0';

			OutFifoControl_SO.Write_S <= '0';
			OutFifoData_DO            <= (others => '0');

			MicConfigReg_D <= tInvenSenseMicConfigDefault;
		elsif rising_edge(Clock_CI) then
			State_DP <= State_DN;

			MicrophoneClock_CO       <= MicrophoneClockReg_C;
			MicrophoneSelectLeft_SO  <= MicrophoneWordSelectReg_S;
			MicrophoneSelectRight_SO <= MicrophoneWordSelectReg_S;

			OutFifoControl_SO.Write_S <= OutFifoWriteReg_S;
			OutFifoData_DO            <= OutFifoDataReg_D;

			MicConfigReg_D <= MicConfig_DI;
		end if;
	end process invenSenseMicRegisterUpdate;
end Behavioral;
