library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.round;
use ieee.math_real.log2;
use work.ShiftRegisterModes.all;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;
use work.Settings.ADC_CLOCK_FREQ_REAL;
use work.Settings.ADC_DATA_LENGTH;
use work.Settings.MAX_ADC_CH_NUM;
use work.Settings.ADC_CHAN_NUMBER;
use work.EventCodes.all;
use work.ADCConfigRecords.all;
use work.ADCStatusRecords.all;
use work.FIFORecords.all;

-- Handles up to 4 AD7691 ADCs connected in nCS mode with common SDO
entity ADCStateMachine is
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;

		-- ADC control I/O
		ADC_SCK_CO      : out std_logic;
		ADC_CNV_SO      : out std_logic;
		ADC_SDI_SBO     : out std_logic_vector(ADC_CHAN_NUMBER - 1 downto 0); -- Support up to 4 ADCs., SDI used as nCS
		ADC_SDO_DI      : in  std_logic;

		ADCDataRead_SI  : in  tToFifoReadSide;
		ADCDataEmpty_SO : out tFromFifoReadSide;
		ADCEventData_DO : out std_logic_vector(EVENT_WIDTH - 1 downto 0);

		-- Configuration input
		ADCConfig_DI    : in  tADCConfig;
		ADCStatus_DO    : out tADCStatus);
end entity ADCStateMachine;

architecture Behavioral of ADCStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stStartup, stIdle, stWaitCycleStart, stWaitConversionDone, stInitAcquisition, stWaitPostCS, stAcquisition, stSendLSB,
	                stPowerUp, stPowerDown, stDelay1Cycle);
	attribute syn_enum_encoding of tState : type is "onehot";

	type tStateOfFifo is (stIdle, stWaitConvStartSent, stSendMSB, stSendLSB, stDelay1Cycle);
	attribute syn_enum_encoding of tStateOfFifo : type is "onehot";

	type t4wordRAM is array (0 to MAX_ADC_CH_NUM - 1) of std_logic_vector(ADC_DATA_LENGTH - 1 downto 0);

	-- Calculated values in cycles.
	constant CLK_CYCLES_FOR_44100HZ    : integer := integer(round((LOGIC_CLOCK_FREQ_REAL * 1000.0) / 44.1));
	constant CLK_CYCLES_FOR_16000HZ    : integer := integer(round((LOGIC_CLOCK_FREQ_REAL * 1000.0) / 16.0));
	constant CLK_CYCLES_FOR_CONVERSION : integer := integer(round((LOGIC_CLOCK_FREQ_REAL * 1000.0) / 270.0)); -- Max conv time for VDD < 4.5V = 3.7 us or 270 ksps.
	constant ADC_SCK_TOGGLE_CYCLES     : integer := integer(round(LOGIC_CLOCK_FREQ_REAL / (ADC_CLOCK_FREQ_REAL * 2.0)));

	constant ADC_POST_CS_DELAY : integer := 3;

	-- Calcualted length of cycles counter.
	constant SCK_TOGGLE_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(ADC_SCK_TOGGLE_CYCLES))));

	constant SAMPLING16_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(CLK_CYCLES_FOR_16000HZ))));
	constant SAMPLING44_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(CLK_CYCLES_FOR_44100HZ))));
	constant CONVERSION_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(CLK_CYCLES_FOR_CONVERSION))));
	constant ADC_POST_CS_DELAY_COUNTER_SIZE : integer := integer(ceil(log2(real(ADC_POST_CS_DELAY))));

	-- Counts number of sent bits.
	constant SENT_BITS_COUNTER_SIZE : integer := integer(ceil(log2(real(ADC_DATA_LENGTH))));

	signal State_DP, State_DN             : tState;
	signal StateOfFifo_DP, StateOfFifo_DN : tStateOfFifo;

	-- ADC interface clock
	signal ADCSpiSck_S          : std_logic;
	signal ADCSpiSckToggle_S    : std_logic;
	signal ADCSpiSckEn_S        : std_logic;
	signal ADCSamplingStrobe_S  : std_logic;
	signal SendStartConvEvent_S : std_logic;
	signal StoreADCSample_S     : std_logic;
	signal ADCConversionDone_S  : std_logic;

	signal ADCDataRAM_D : t4wordRAM;

	signal ADCEventData_DP, ADCEventData_DN         : std_logic_vector(EVENT_WIDTH - 1  downto 0);
	signal WaitAckCounter_DP, WaitAckCounter_DN     : unsigned(10 downto 0);
	signal ADCEventReq_SP, ADCEventReq_SN           : std_logic;
	signal LostSamplesCount_DP, LostSamplesCount_DN : unsigned(19 downto 0);

	signal ADCRunConversionTimer_SP, ADCRunConversionTimer_SN : std_logic;

	signal ADCStartConversion_SP, ADCStartConversion_SN : std_logic;
	signal ADCCNVLowCounter_DP, ADCCNVLowCounter_DN     : unsigned(1 downto 0);

	signal ADCPostCSDelay_DP, ADCPostCSDelay_DN : unsigned(ADC_POST_CS_DELAY_COUNTER_SIZE - 1 downto 0);

	-- In the beginning of the acquisition cycle ADCConfig_DI.ADCChanEn_S is copied to this register.
	-- When data is read from a channel, the corresponding bit is cleard in this register.
	signal ChannelsToRead_SP, ChannelsToRead_SN : std_logic_vector(ADC_CHAN_NUMBER - 1  downto 0); -- Support up to 4 ADCs.

	-- When channel readout is finished, the corresponding bit is set in this register.
	-- This register is cleared in adcControl process at the beginning of the acquisition cycle when ADCStartConversion_SP goes low.
	signal ChannelsReady_SP, ChannelsReady_SN : std_logic_vector(ADC_CHAN_NUMBER - 1  downto 0);

	-- When data from a channel is sent to the host, the corresponding bit is set in this register.
	-- This register is cleared in sortOfFifo process at the beginning of the acquisition cycle when ADCSamplingStrobe_S goes low.
	signal ChannelsSent_SP, ChannelsSent_SN : std_logic_vector(ADC_CHAN_NUMBER - 1  downto 0);

	-- Inactivate CS for all channels to prevent data collision at SDO during switching of channels
	signal DeselectAllChannels_SP, DeselectAllChannels_SN : std_logic;

	-- One-hot register, showing which channel should be read next or is being read currently
	-- Output of ADCChannelSelector. Is registered already.
	signal ADCChanSelect_S : std_logic_vector(MAX_ADC_CH_NUM - 1 downto 0); -- Support up to 4 ADCs.
	signal AllChanOff_S    : std_logic;

	-- One-hot register, showing which channel should be sent or is being sent to the host currently
	signal SendingChannelMask_S : std_logic_vector(MAX_ADC_CH_NUM - 1  downto 0);
	signal NoDataToSend_S       : std_logic;

	-- 0-based nubmer of a channel which should be read next or is being read currently
	signal FirstActiveChannel_S : unsigned(1 downto 0);

	-- 0-based nubmer of a channel which should be sent or is being sent to the host currently
	signal FirstChannelToSend_S : unsigned(1 downto 0);

	-- Enable signal for the counter keeping track of read bits.
	signal ADCReadBit_S         : std_logic;
	signal ADCChanReadoutDone_S : std_logic;

	-- Input data register (from ADC).
	signal ADCDataInSRMode_S : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal ADCDataInSRRead_D : std_logic_vector(ADC_DATA_LENGTH - 1 downto 0);

	signal AlmostEmpty_SN : std_logic;
-- Register configuration input to improve timing.
-- signal ADCConfigReg_D : tADCConfig;
begin
	-- ADC_SCK_CO <= ADCSpiSck_S when Reset_RI = '0' else 'Z';
	ADC_SCK_CO  <= ADCSpiSck_S;
	ADC_CNV_SO  <= ADCStartConversion_SP; -- Conversion starts at the rising edge of ADC_CNV_SO
	ADC_SDI_SBO <= not ADCChanSelect_S(ADC_CHAN_NUMBER - 1 downto 0);

	ADCDataEmpty_SO.AlmostEmpty_S <= not ADCEventReq_SP;
	ADCDataEmpty_SO.Empty_S       <= not ADCEventReq_SP;
	ADCEventData_DO               <= ADCEventData_DP;

	ADCStatus_DO.NSamplesDropped_D(19 downto 0)  <= LostSamplesCount_DP;
	ADCStatus_DO.NSamplesDropped_D(31 downto 20) <= (others => '0');

	adcDataInShiftRegister : entity work.ShiftRegister
		generic map(
			SIZE => ADC_DATA_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => ADCDataInSRMode_S,
			DataIn_DI        => ADC_SDO_DI,
			ParallelWrite_DI => (others => '1'),
			ParallelRead_DO  => ADCDataInSRRead_D);

	-- Counter to introduce delays between operations, and generate the SCK clock.
	sckWaitCyclesCounter : entity work.ContinuousCounter
		generic map(
			SIZE => SCK_TOGGLE_CYCLES_COUNTER_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not ADCSpiSckEn_S,
			Enable_SI    => '1',        -- ADCEnable_S,
			DataLimit_DI => to_unsigned(ADC_SCK_TOGGLE_CYCLES - 1, SCK_TOGGLE_CYCLES_COUNTER_SIZE),
			Overflow_SO  => ADCSpiSckToggle_S,
			Data_DO      => open);

	adcConversionTimer : entity work.ContinuousCounter
		generic map(
			SIZE => CONVERSION_CYCLES_COUNTER_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => not ADCRunConversionTimer_SP,
			Enable_SI    => '1',
			DataLimit_DI => to_unsigned(CLK_CYCLES_FOR_CONVERSION - 1, CONVERSION_CYCLES_COUNTER_SIZE),
			Overflow_SO  => ADCConversionDone_S,
			Data_DO      => open);

	adcSampleFreqCounter : entity work.ContinuousCounter
		generic map(
			SIZE => SAMPLING16_CYCLES_COUNTER_SIZE)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => '1',        -- ADCEnable_S,
			DataLimit_DI => to_unsigned(CLK_CYCLES_FOR_16000HZ - 1, SAMPLING16_CYCLES_COUNTER_SIZE),
			Overflow_SO  => ADCSamplingStrobe_S,
			Data_DO      => open);

	-- Counter for keeping track of output bits.
	sentBitsCounter : entity work.ContinuousCounter
		generic map(
			SIZE             => SENT_BITS_COUNTER_SIZE,
			SHORT_OVERFLOW   => true,
			OVERFLOW_AT_ZERO => true)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => ADCReadBit_S,
			DataLimit_DI => to_unsigned(ADC_DATA_LENGTH - 1, SENT_BITS_COUNTER_SIZE),
			Overflow_SO  => ADCChanReadoutDone_S,
			Data_DO      => open);

	channelSelector : entity work.ADCChannelSelector
		generic map(
			CHAN_NUMBER => ADC_CHAN_NUMBER)
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			ChanEnabled_DI  => ChannelsToRead_SP,
			DeselectAll_SI  => DeselectAllChannels_SP,
			ChanSelected_DO => FirstActiveChannel_S,
			ChanBitMask_SO  => ADCChanSelect_S,
			AllChanOff_SO   => AllChanOff_S);

	sendChanSelector : entity work.ADCChannelSelector
		generic map(
			CHAN_NUMBER => ADC_CHAN_NUMBER)
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			ChanEnabled_DI  => ChannelsReady_SP and not ChannelsSent_SP,
			DeselectAll_SI  => '0',
			ChanSelected_DO => FirstChannelToSend_S,
			ChanBitMask_SO  => SendingChannelMask_S,
			AllChanOff_SO   => NoDataToSend_S);

	-- Extend low state of the ADC start conversion signal to 4 Clock_CI cycles
	-- ADCSamplingStrobe_S   : __/`\________
	-- ADCStartConversion_SP : ````\____/```
	cnvControl : process(ADCSamplingStrobe_S, ADCCNVLowCounter_DP, ADCStartConversion_SP)
	begin
		ADCStartConversion_SN <= ADCStartConversion_SP;
		ADCCNVLowCounter_DN   <= "00";
		if ADCSamplingStrobe_S = '1' then
			ADCStartConversion_SN <= '0';
			ADCCNVLowCounter_DN   <= "11";
		elsif ADCCNVLowCounter_DP = "00" then
			ADCStartConversion_SN <= '1'; -- Conversion starts here
		else
			ADCCNVLowCounter_DN <= ADCCNVLowCounter_DP - '1';
		end if;
	end process cnvControl;

	cnvRegUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			ADCStartConversion_SP <= '1';
			ADCCNVLowCounter_DP   <= "00";
		elsif rising_edge(Clock_CI) then
			ADCStartConversion_SP <= ADCStartConversion_SN;
			ADCCNVLowCounter_DP   <= ADCCNVLowCounter_DN;
		end if;
	end process cnvRegUpdate;

	-- 4 words of 18 bits RAM to keep ADC samples for 4 channels
	ramProc : process(Clock_CI) is
	begin
		if rising_edge(Clock_CI) then
			if StoreADCSample_S = '1' then
				ADCDataRAM_D(to_integer(FirstActiveChannel_S)) <= ADCDataInSRRead_D;
			end if;
		end if;
	end process ramProc;

	-- Substitution for FIFO interface for sending data to the Multiplexer state machine
	-- ADCSamplingStrobe_S is used to reset the FIFO state if transaction was not completed by the start of the next cycle
	sortOfFifo : process(StateOfFifo_DP, ADCSamplingStrobe_S, SendStartConvEvent_S, LostSamplesCount_DP, ADCEventReq_SP,
		 WaitAckCounter_DP, ADCDataRead_SI.Read_S, ADCEventData_DP, ADCConfig_DI.ADCChanEn_S, ADCDataRAM_D,
		 ChannelsSent_SP, FirstChannelToSend_S, NoDataToSend_S, WaitAckCounter_DN, SendingChannelMask_S)
	begin
		StateOfFifo_DN      <= StateOfFifo_DP;
		ADCEventData_DN     <= ADCEventData_DP;
		WaitAckCounter_DN   <= WaitAckCounter_DP;
		ADCEventReq_SN      <= ADCEventReq_SP;
		LostSamplesCount_DN <= LostSamplesCount_DP;
		ChannelsSent_SN     <= ChannelsSent_SP;
		-- AlmostEmpty_SN		<= ADCDataEmpty_SO.AlmostEmpty_S;

		if ADCSamplingStrobe_S = '1' then
			ADCEventReq_SN      <= '0';
			AlmostEmpty_SN      <= '1';
			WaitAckCounter_DN   <= to_unsigned(0, WaitAckCounter_DN'length);
			LostSamplesCount_DN <= LostSamplesCount_DP + 1;
			ChannelsSent_SN     <= (others => '0');
			StateOfFifo_DN      <= stIdle;
		else
			if ADCEventReq_SP = '1' then
				WaitAckCounter_DN <= WaitAckCounter_DP + 1;
			end if;

			case StateOfFifo_DP is
				when stIdle =>
					if SendStartConvEvent_S = '1' then
						ADCEventReq_SN <= '1'; -- Connected to both ADCDataEmpty_SO.AlmostEmpty_S and ADCDataEmpty_SO.Empty_S flags
						if WaitAckCounter_DN < integer(round(LOGIC_CLOCK_FREQ_REAL)) then
							ADCEventData_DN <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_ADC_START_CNV;
						else
							ADCEventData_DN <= EVENT_CODE_SPECIAL & EVENT_CODE_SPECIAL_ADC_START_CNV_1US;
						end if;
						StateOfFifo_DN <= stWaitConvStartSent;
					end if;

				when stWaitConvStartSent =>
					if ADCDataRead_SI.Read_S = '1' then
						ADCEventReq_SN    <= '0';
						WaitAckCounter_DN <= to_unsigned(0, WaitAckCounter_DN'length);
						StateOfFifo_DN    <= stSendMSB;
					end if;

				when stSendMSB =>
					if ChannelsSent_SP = ADCConfig_DI.ADCChanEn_S then
						ADCEventReq_SN <= '0';
						AlmostEmpty_SN <= '0';
						StateOfFifo_DN <= stIdle;
					else
						if NoDataToSend_S = '0' then
							-- [EC_3 & CH_2 & MSB_1 & 9 data bits ]
							ADCEventData_DN <= EVENT_CODE_ADC_SAMPLE & std_logic_vector(FirstChannelToSend_S) & '1' &
							 ADCDataRAM_D(to_integer(FirstChannelToSend_S))(17 downto 9);
							ADCEventReq_SN  <= '1';
							if ADCDataRead_SI.Read_S = '1' then
								ADCEventData_DN <= EVENT_CODE_ADC_SAMPLE & std_logic_vector(FirstChannelToSend_S) & '0' &
								 ADCDataRAM_D(to_integer(FirstChannelToSend_S))(8 downto 0);
								StateOfFifo_DN  <= stSendLSB;
							end if;
						end if;
					end if;

				when stSendLSB =>
					if ADCDataRead_SI.Read_S = '1' then
						ChannelsSent_SN <= ChannelsSent_SP or SendingChannelMask_S(ADC_CHAN_NUMBER - 1 downto 0);
						ADCEventReq_SN  <= '0';
						StateOfFifo_DN  <= stDelay1Cycle;
					end if;

				when stDelay1Cycle =>   -- Delay Sending MSB for 1 cycle to let the NoDataToSend_S output register to be latched
					StateOfFifo_DN <= stSendMSB;

				when others =>
					StateOfFifo_DN <= stIdle;
			end case;
		end if;
	end process sortOfFifo;

	fifoRegUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			StateOfFifo_DP      <= stIdle;
			ADCEventReq_SP      <= '0';
			WaitAckCounter_DP   <= (others => '0');
			ADCEventData_DP     <= (others => '0');
			LostSamplesCount_DP <= (others => '0');
			ChannelsSent_SP     <= (others => '0');
			-- ADCDataEmpty_SO.AlmostEmpty_S <= '1';
		elsif rising_edge(Clock_CI) then
			StateOfFifo_DP      <= StateOfFifo_DN;
			ADCEventReq_SP      <= ADCEventReq_SN;
			WaitAckCounter_DP   <= WaitAckCounter_DN;
			LostSamplesCount_DP <= LostSamplesCount_DN;
			ADCEventData_DP     <= ADCEventData_DN;
			ChannelsSent_SP     <= ChannelsSent_SN;
			-- ADCDataEmpty_SO.AlmostEmpty_S <= AlmostEmpty_SN;
		end if;
	end process fifoRegUpdate;

	-- ADC control combinational process
	adcControl : process(State_DP, ADCConfig_DI.Run_S, ADCConfig_DI.ADCChanEn_S, ADCConversionDone_S,
		 ADCPostCSDelay_DP, ADCStartConversion_SP, AllChanOff_S, ADCChanReadoutDone_S, ADCRunConversionTimer_SP,
		 ChannelsToRead_SP, DeselectAllChannels_SP, ADCSpiSck_S, ADCSpiSckToggle_S, ADCChanSelect_S, ChannelsReady_SP)
	begin
		-- Keep state by default.
		State_DN                 <= State_DP;
		ADCPostCSDelay_DN        <= ADCPostCSDelay_DP;
		ADCRunConversionTimer_SN <= ADCRunConversionTimer_SP;
		ChannelsToRead_SN        <= ChannelsToRead_SP;
		DeselectAllChannels_SN   <= DeselectAllChannels_SP;
		ChannelsReady_SN         <= ChannelsReady_SP;

		ADCSpiSckEn_S <= '0';
		ADCReadBit_S  <= '0';

		SendStartConvEvent_S <= '0';

		ADCDataInSRMode_S <= SHIFTREGISTER_MODE_DO_NOTHING;

		case State_DP is
			when stIdle =>
				DeselectAllChannels_SN <= '1';
				if ADCConfig_DI.Run_S = '1' and unsigned(ADCConfig_DI.ADCChanEn_S) /= 0 then
					if ADCStartConversion_SP = '0' then
						ChannelsReady_SN         <= (others => '0');
						SendStartConvEvent_S     <= '1';
						ADCRunConversionTimer_SN <= '1';
						ChannelsToRead_SN        <= ADCConfig_DI.ADCChanEn_S;
						State_DN                 <= stWaitConversionDone;
					end if;
				end if;

			when stWaitConversionDone =>
				if ADCConversionDone_S = '1' then
					ADCRunConversionTimer_SN <= '0';
					State_DN                 <= stInitAcquisition;
				end if;

			when stInitAcquisition =>
				if AllChanOff_S = '0' then
					ADCPostCSDelay_DN      <= to_unsigned(ADC_POST_CS_DELAY, ADC_POST_CS_DELAY_COUNTER_SIZE);
					DeselectAllChannels_SN <= '0'; -- Select one of the ADCs and wait for ADCPostCSDelay_DN clock cycles
					State_DN               <= stWaitPostCS;
				else                    -- No channels are selected
					State_DN <= stIdle;
				end if;

			when stWaitPostCS =>
				if ADCPostCSDelay_DP = to_unsigned(0, ADC_POST_CS_DELAY_COUNTER_SIZE) then
					ADCSpiSckEn_S <= '1';
					State_DN      <= stAcquisition;
				else
					ADCPostCSDelay_DN <= ADCPostCSDelay_DP - '1';
				end if;

			when stAcquisition =>
				ADCSpiSckEn_S <= '1';
				if ADCSpiSckToggle_S = '1' and ADCSpiSck_S = '1' then -- right before the falling edge of the SPI_SCK
					ADCReadBit_S      <= '1';
					ADCDataInSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;
				end if;
				if ADCChanReadoutDone_S = '1' then
					DeselectAllChannels_SN <= '1';
					ChannelsToRead_SN      <= ChannelsToRead_SP and not ADCChanSelect_S(ADC_CHAN_NUMBER - 1 downto 0);
					ChannelsReady_SN       <= ChannelsReady_SP or ADCChanSelect_S(ADC_CHAN_NUMBER - 1 downto 0);
					StoreADCSample_S       <= '1';
					State_DN               <= stDelay1Cycle;
				end if;

			when stDelay1Cycle =>       -- Delay acquisition for 1 cycle to let the AllChanOff_S output register to be latched
				State_DN <= stInitAcquisition;

			when others =>
				State_DN <= stIdle;
		end case;
	end process adcControl;

	spiSCK : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			ADCSpiSck_S <= '1';
		elsif rising_edge(Clock_CI) then
			if ADCSpiSckEn_S = '1' then
				if ADCSpiSckToggle_S = '1' then
					ADCSpiSck_S <= not ADCSpiSck_S;
				end if;
			else
				ADCSpiSck_S <= '1';
			end if;
		end if;
	end process spiSCK;

	registerUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			State_DP                 <= stIdle;
			ADCPostCSDelay_DP        <= (others => '0');
			ADCRunConversionTimer_SP <= '0';
			ChannelsToRead_SP        <= (others => '0');
			DeselectAllChannels_SP   <= '1';
			-- ADCConfigReg_D         <= tADCConfigDefault;
		elsif rising_edge(Clock_CI) then
			State_DP                 <= State_DN;
			ADCPostCSDelay_DP        <= ADCPostCSDelay_DN;
			ADCRunConversionTimer_SP <= ADCRunConversionTimer_SN;
			ChannelsToRead_SP        <= ChannelsToRead_SN;
			DeselectAllChannels_SP   <= DeselectAllChannels_SN;
			ChannelsReady_SP         <= ChannelsReady_SN;
			-- ADCConfigReg_D           <= ADCConfig_DI;
		end if;
	end process registerUpdate;
end architecture Behavioral;
