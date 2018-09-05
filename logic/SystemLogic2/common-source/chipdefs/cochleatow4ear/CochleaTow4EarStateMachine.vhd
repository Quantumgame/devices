library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.ShiftRegisterModes.all;
use work.Functions.BiasGenerateCoarseFine;
use work.Functions.BiasGenerateVDAC;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;
use work.ChipBiasConfigRecords.all;
use work.CochleaTow4EarChipBiasConfigRecords.all;

entity CochleaTow4EarStateMachine is
	port(
		Clock_CI              : in  std_logic;
		Reset_RI              : in  std_logic;

		-- Bias configuration outputs (to chip)
		ChipBiasDiagSelect_SO : out std_logic;
		ChipBiasAddrSelect_SO : out std_logic;
		ChipBiasClock_CBO     : out std_logic;
		ChipBiasBitIn_DO      : out std_logic;
		ChipBiasLatch_SBO     : out std_logic;
		SelResSw_SO           : out std_logic;

		-- Configuration inputs
		BiasConfig_DI         : in  tCochleaTow4EarBiasConfig;
		ChipConfig_DI         : in  tCochleaTow4EarChipConfig;
		ChannelConfig_DI      : in  tCochleaTow4EarChannelConfig;

		-- Output for the neuron kill signal
		AERKillBit_SO         : out std_logic;

		-- Reset all local AER requests (from neurons) 
		VresetBn_SO           : out std_logic
	);
end entity CochleaTow4EarStateMachine;

architecture Behavioral of CochleaTow4EarStateMachine is
	attribute syn_enum_encoding : string;

	type tState is (stIdle, stPrepareSendBiasAddress, stSendBiasAddress, stPrepareSendBias, stSendBias, stDelayBias, stPrepareSendChip, stSendChip, stLatchBiasAddress, stLatchBias, stLatchChip, stEndChip, stDelay,
	                stPrepareSendChannel, stSendChannel, stLatchChannel, stPrepareSendChannelAddress, stSendChannelAddress, stLatchChannelAddress);
	attribute syn_enum_encoding of tState : type is "onehot";

	type tKillState is (stIdle, stSendChannelAddress, stSendingChannelAddress, stSetKill, stSetSelTopBot, stWaitSelTopBotIsSet, stClearSelTopBot, stWaitSelTopBotIsCleared, stClearKill);
	attribute syn_enum_encoding of tKillState : type is "onehot";

	signal State_DP, State_DN         : tState;
	signal KillState_DP, KillState_DN : tKillState;

	-- Bias clock frequency in KHz.
	constant BIAS_CLOCK_FREQ : real := 100.0;

	-- How long the latch should be asserted, based on bias clock frequency.
	constant LATCH_LENGTH : integer := 10;

	constant CHANNEL_CONFIG_SELECT : std_logic := '1'; -- Value from documentation
	constant CHIP_CONFIG_SELECT    : std_logic := '0'; -- Value from documentation

	-- Hold time for the ChipBiasDiagSelect_SO and ChipBiasAddrSelect_SO signals after ChipBiasLatch_SBO goes high. Based on bias clock frequency.
	constant POST_LATCH_HOLD : integer := 1;

	-- Calculated values in cycles.
	constant BIAS_CLOCK_CYCLES : integer := integer((LOGIC_CLOCK_FREQ_REAL * 1000.0) / BIAS_CLOCK_FREQ);
	constant LATCH_CYCLES      : integer := BIAS_CLOCK_CYCLES * LATCH_LENGTH;
	constant LATCH_PLUS_HOLD   : integer := BIAS_CLOCK_CYCLES *(LATCH_LENGTH + POST_LATCH_HOLD);

	-- Calcualted length of cycles counter. Based on latch cycles, since biggest value.
	constant WAIT_CYCLES_COUNTER_SIZE : integer := integer(ceil(log2(real(LATCH_PLUS_HOLD))));

	-- Counts number of sent bits. Biggest value is 56 bits of chip SR, so 6 bits are enough.
	constant SENT_BITS_COUNTER_SIZE : integer := 6;

	-- Chip changes and acknowledges.
	signal ChipChangedInput_D        : std_logic_vector(CHIP_REG_USED_SIZE - 1 downto 0);
	signal ChipChanged_S, ChipSent_S : std_logic;

	-- Bias changes and acknowledges.
	signal BiasChanged_S, BiasSent_S : std_logic_vector(NUMBER_OF_BIASES - 1 downto 0);

	-- Data shift registers for output.
	signal BiasAddrSRMode_S                      : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal BiasAddrSRInput_D, BiasAddrSROutput_D : std_logic_vector(BIASADDR_REG_LENGTH - 1 downto 0);

	signal BiasSRMode_S                  : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal BiasSRInput_D, BiasSROutput_D : std_logic_vector(BIAS_REG_LENGTH - 1 downto 0);

	signal ChipSRMode_S                  : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal ChipSRInput_D, ChipSROutput_D : std_logic_vector(CHIP_REG_LENGTH - 1 downto 0);

	signal ChannelAddressSRMode_S                            : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal ChannelAddressSRInput_D, ChannelAddressSROutput_D : std_logic_vector(CHIP_CHANADDR_REG_LENGTH - 1 downto 0);

	signal ChannelSRMode_S                     : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal ChannelSRInput_D, ChannelSROutput_D : std_logic_vector(CHIP_CHAN_REG_LENGTH - 1 downto 0);

	-- Counter for keeping track of output bits.
	signal SentBitsCounterClear_S, SentBitsCounterEnable_S : std_logic;
	signal SentBitsCounterData_D                           : unsigned(SENT_BITS_COUNTER_SIZE - 1 downto 0);

	-- Counter to introduce delays between operations, and generate the clock.
	signal WaitCyclesCounterClear_S, WaitCyclesCounterEnable_S : std_logic;
	signal WaitCyclesCounterData_D                             : unsigned(WAIT_CYCLES_COUNTER_SIZE - 1 downto 0);

	-- Signal when to latch the channel registers and start a transaction.
	signal ChannelSetPulse_S : std_logic;
	signal ChannelSetAck_S   : std_logic;
	signal ChannelSet_S      : std_logic;

	-- Signal when to kill neurons 0 and 2 of the channel.
	signal NeuronKill02Pulse_S        : std_logic;
	signal NeuronKill02Ack_S          : std_logic;
	signal NeuronKill02_S             : std_logic;
	signal Sel02Kill_SP, Sel02Kill_SN : std_logic;

	-- Signal when to kill neurons 1 and 3 of the channel.
	signal NeuronKill13Pulse_S        : std_logic;
	signal NeuronKill13Ack_S          : std_logic;
	signal NeuronKill13_S             : std_logic;
	signal Sel13Kill_SP, Sel13Kill_SN : std_logic;

	signal KillNeurons02_SP, KillNeurons02_SN  : std_logic;
	signal KillDelayCount_S, KillDelayPassed_S : std_logic;

	-- Keep track if what we send after the channel address is channel data or diag chain data.
	signal IsChannelConfigData_SP, IsChannelConfigData_SN : std_logic;

	-- Register configuration inputs.
	signal BiasConfigReg_DP, BiasConfigReg_DN       : tCochleaTow4EarBiasConfig;
	signal ChipConfigReg_DP, ChipConfigReg_DN       : tCochleaTow4EarChipConfig;
	signal ChannelConfigReg_DP, ChannelConfigReg_DN : tCochleaTow4EarChannelConfig;

	-- Register all outputs.
	signal ChipBiasDiagSelectReg_S : std_logic;
	signal ChipBiasAddrSelectReg_S : std_logic;
	signal ChipBiasClockReg_CB     : std_logic;
	signal ChipBiasBitInReg_D      : std_logic;
	signal ChipBiasLatchReg_SB     : std_logic;
	signal AERKillBitReg_S         : std_logic;

	function ChannelGenerateConfig(CHAN : in std_logic_vector(CHIP_CHAN_REG_USED_SIZE - 1 downto 0)) return std_logic_vector is
	begin
		return "0000" & CHAN(19 downto 0);
	end function ChannelGenerateConfig;

	-- Note: Bits SelResSw_S and VresetBn_S are not included since they do not belong to the shift register but have separate pins.
	function FlattenChipConfig(ChipConfig_D : in tCochleaTow4EarChipConfig; SelTopKill_S : in std_logic; SelBotKill_S : in std_logic) return std_logic_vector is
		variable FlatChipConfig_D : std_logic_vector(CHIP_REG_USED_SIZE - 1 downto 0);
	begin
		FlatChipConfig_D(43 downto 40) := std_logic_vector(ChipConfig_D.DigitalMux3_D);
		FlatChipConfig_D(39 downto 36) := std_logic_vector(ChipConfig_D.DigitalMux2_D);
		FlatChipConfig_D(35 downto 32) := std_logic_vector(ChipConfig_D.DigitalMux1_D);
		FlatChipConfig_D(31 downto 28) := std_logic_vector(ChipConfig_D.DigitalMux0_D);
		FlatChipConfig_D(27)           := ChipConfig_D.DC23_S;
		FlatChipConfig_D(26)           := ChipConfig_D.DC22_S;
		FlatChipConfig_D(25)           := ChipConfig_D.DC21_S;
		FlatChipConfig_D(24)           := ChipConfig_D.DC20_S;
		FlatChipConfig_D(23)           := ChipConfig_D.BitTestLatch_S;
		FlatChipConfig_D(22)           := ChipConfig_D.DC18_S;
		FlatChipConfig_D(21)           := ChipConfig_D.DC17_S;
		FlatChipConfig_D(20)           := ChipConfig_D.DC16_S;
		FlatChipConfig_D(19)           := ChipConfig_D.DC15_S;
		FlatChipConfig_D(18)           := ChipConfig_D.DC14_S;
		FlatChipConfig_D(17)           := ChipConfig_D.DC13_S;
		FlatChipConfig_D(16)           := ChipConfig_D.DC12_S;
		FlatChipConfig_D(15)           := ChipConfig_D.DC11_S;
		FlatChipConfig_D(14)           := ChipConfig_D.DC10_S;
		FlatChipConfig_D(13)           := ChipConfig_D.DC9_S;
		FlatChipConfig_D(12)           := ChipConfig_D.DC8_S;
		FlatChipConfig_D(11)           := ChipConfig_D.SelTop_S or SelTopKill_S;
		FlatChipConfig_D(10)           := ChipConfig_D.SelBot_S or SelBotKill_S;
		FlatChipConfig_D(9)            := ChipConfig_D.DC5_S;
		FlatChipConfig_D(8)            := ChipConfig_D.SMconfigArow_S;
		FlatChipConfig_D(7)            := ChipConfig_D.Seln2_S;
		FlatChipConfig_D(6)            := ChipConfig_D.Seln1_S;
		FlatChipConfig_D(5 downto 4)   := std_logic_vector(ChipConfig_D.PreampGain_D);
		FlatChipConfig_D(3 downto 0)   := std_logic_vector(ChipConfig_D.AnalogMux0_D);
		return FlatChipConfig_D;
	end function FlattenChipConfig;

begin
	SelResSw_SO <= ChipConfigReg_DP.SelResSw_S;
	VresetBn_SO <= ChipConfigReg_DP.VresetBn_S;

	sendConfig : process(State_DP, BiasConfigReg_DP, BiasAddrSROutput_D, BiasSROutput_D, ChipConfigReg_DP, ChipSROutput_D, ChipChanged_S, SentBitsCounterData_D, WaitCyclesCounterData_D, ChipBiasDiagSelect_SO, ChipBiasAddrSelect_SO,
		 BiasChanged_S, ChannelConfigReg_DP, ChannelAddressSROutput_D, ChannelSROutput_D, ChannelSet_S, IsChannelConfigData_SP, Sel02Kill_SP, Sel13Kill_SP, BiasConfig_DI, ChannelConfig_DI, ChipConfig_DI, KillState_DP, ChipBiasLatch_SBO
		)
	begin
		-- Keep state by default.
		State_DN <= State_DP;

		BiasConfigReg_DN    <= BiasConfigReg_DP;
		ChipConfigReg_DN    <= ChipConfigReg_DP;
		ChannelConfigReg_DN <= ChannelConfigReg_DP;

		-- Default state for bias config outputs.
		ChipBiasDiagSelectReg_S <= ChipBiasDiagSelect_SO;
		ChipBiasAddrSelectReg_S <= ChipBiasAddrSelect_SO;
		ChipBiasLatchReg_SB     <= ChipBiasLatch_SBO;
		ChipBiasClockReg_CB     <= '1';
		ChipBiasBitInReg_D      <= '0';

		BiasSent_S <= (others => '0');
		ChipSent_S <= '0';

		ChannelSetAck_S <= '0';

		IsChannelConfigData_SN <= IsChannelConfigData_SP;

		BiasAddrSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		BiasAddrSRInput_D <= (others => '0');

		BiasSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		BiasSRInput_D <= (others => '0');

		ChipSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		ChipSRInput_D <= (others => '0');

		ChannelAddressSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		ChannelAddressSRInput_D <= (others => '0');

		ChannelSRMode_S  <= SHIFTREGISTER_MODE_DO_NOTHING;
		ChannelSRInput_D <= (others => '0');

		WaitCyclesCounterClear_S  <= '0';
		WaitCyclesCounterEnable_S <= '0';

		SentBitsCounterClear_S  <= '0';
		SentBitsCounterEnable_S <= '0';

		case State_DP is
			when stIdle =>

				-- Do not accept any changes if we are in the middle of the neuron killing process, 
				-- except the ChipConfig change due to the SelTopKill_SB and SelBotKill_SB bits  
				if ChipChanged_S = '1' then
					-- Acknowledge all chip config changes, since we're getting the up-to-date
					-- content of all of them anyway, so we can just ACk them all.
					ChipSent_S <= '1';

					-- Load shiftreg with current chip config content.
					-- The shiftreg will be shifted out to the left, so we need to write MSB of ChipConfigReg to MSB of the SR, since MSB should be shifted out first.
					ChipSRInput_D(CHIP_REG_LENGTH - 1 downto CHIP_REG_LENGTH - CHIP_REG_USED_SIZE) <= FlattenChipConfig(ChipConfigReg_DP, Sel13Kill_SP, Sel02Kill_SP);
					ChipSRMode_S                                                                   <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

					-- Load channel address with special chip diag register MSB.
					-- MSB is CHIP_CONFIG_SELECT (0), and the rest is don't care (set to 0 above).
					ChannelAddressSRInput_D(CHIP_CHANADDR_REG_LENGTH - 1) <= CHIP_CONFIG_SELECT;
					ChannelAddressSRMode_S                                <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

					-- Sending diag chain data, not channel config data.
					IsChannelConfigData_SN <= '0';

					State_DN <= stPrepareSendChannelAddress;

				elsif KillState_DP = stSendChannelAddress then
					-- Load channel address with current channel address. MSB must be 1.
					ChannelAddressSRInput_D(CHIP_CHANADDR_REG_LENGTH - 1)             <= CHANNEL_CONFIG_SELECT;
					ChannelAddressSRInput_D(CHIP_CHANADDR_REG_USED_SIZE - 1 downto 0) <= std_logic_vector(ChannelConfigReg_DP.ChannelAddress_D);
					ChannelAddressSRMode_S                                            <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

					-- Sending channel config data (actually only the address), not chip diag data.
					IsChannelConfigData_SN <= '1';

					State_DN <= stPrepareSendChannelAddress;

				elsif KillState_DP = stIdle then

					BiasConfigReg_DN    <= BiasConfig_DI;
					ChipConfigReg_DN    <= ChipConfig_DI;
					ChannelConfigReg_DN <= ChannelConfig_DI;

					if BiasChanged_S /= std_logic_vector(to_unsigned(0, NUMBER_OF_BIASES)) then
						BiasAddrSRMode_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD;
						BiasSRMode_S     <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

						State_DN <= stPrepareSendBiasAddress;
					end if;

					if ChannelSet_S = '1' then
						-- Load shiftreg with current channel config content.
						ChannelSRInput_D <= ChannelGenerateConfig(ChannelConfigReg_DP.ChannelDataWrite_D);
						ChannelSRMode_S  <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

						-- Load channel address with current channel address. MSB must be 1.
						ChannelAddressSRInput_D(CHIP_CHANADDR_REG_LENGTH - 1)             <= CHANNEL_CONFIG_SELECT;
						ChannelAddressSRInput_D(CHIP_CHANADDR_REG_USED_SIZE - 1 downto 0) <= std_logic_vector(ChannelConfigReg_DP.ChannelAddress_D);
						ChannelAddressSRMode_S                                            <= SHIFTREGISTER_MODE_PARALLEL_LOAD;

						-- Sending channel config data, not chip diag data.
						IsChannelConfigData_SN <= '1';

						State_DN <= stPrepareSendChannelAddress;

					elsif BiasChanged_S(0) = '1' then
						-- Acknowledge this particular bias.
						BiasSent_S(0) <= '1';
						-- Load shiftreg with current bias address.
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(0, BIASADDR_REG_LENGTH));
						-- Load shiftreg with current bias config content.
						BiasSRInput_D <= BiasGenerateVDAC(BiasConfigReg_DP.VrefpreampBp_D);
					elsif BiasChanged_S(1) = '1' then
						BiasSent_S(1)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(1, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.Vth1_D);
					elsif BiasChanged_S(2) = '1' then
						BiasSent_S(2)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(2, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.Vth2_D);
					elsif BiasChanged_S(3) = '1' then
						BiasSent_S(3)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(3, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.VbMicCasBpc_D);
					elsif BiasChanged_S(4) = '1' then
						BiasSent_S(4)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(4, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.VbiasHF2Bn_D);
					elsif BiasChanged_S(5) = '1' then
						BiasSent_S(5)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(5, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.Vbias2n_D);
					elsif BiasChanged_S(6) = '1' then
						BiasSent_S(6)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(6, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.Vrefdiff_D);
					elsif BiasChanged_S(7) = '1' then
						BiasSent_S(7)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(7, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateVDAC(BiasConfigReg_DP.Vrefdiff2_D);
					elsif BiasChanged_S(8) = '1' then
						BiasSent_S(8)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(8, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.LocalBufBn_D);
					elsif BiasChanged_S(9) = '1' then
						BiasSent_S(9)     <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(9, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VtauBn_D);
					elsif BiasChanged_S(10) = '1' then
						BiasSent_S(10)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(10, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.Vbias1Bn_D);
					elsif BiasChanged_S(11) = '1' then
						BiasSent_S(11)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(11, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VrefractBnc4_D);
					elsif BiasChanged_S(12) = '1' then
						BiasSent_S(12)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(12, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VrefractBnc1_D);
					elsif BiasChanged_S(13) = '1' then
						BiasSent_S(13)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(13, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.PixInvBn_D);
					elsif BiasChanged_S(14) = '1' then
						BiasSent_S(14)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(14, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VBPScan_D);
					elsif BiasChanged_S(15) = '1' then
						BiasSent_S(15)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(15, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VbBp1_D);
					elsif BiasChanged_S(16) = '1' then
						BiasSent_S(16)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(16, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VbBp2_D);
					elsif BiasChanged_S(17) = '1' then
						BiasSent_S(17)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(17, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VneuronLeakExtBp_D);
					elsif BiasChanged_S(18) = '1' then
						BiasSent_S(18)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(18, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VpulseAERExtdBn_D);
					elsif BiasChanged_S(19) = '1' then
						BiasSent_S(19)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(19, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VwideampBp_D);
					elsif BiasChanged_S(20) = '1' then
						BiasSent_S(20)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(20, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VQBn_D);
					elsif BiasChanged_S(21) = '1' then
						BiasSent_S(21)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(21, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VcascodeBpc_D);
					elsif BiasChanged_S(22) = '1' then
						BiasSent_S(22)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(22, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.LcolTimeoutBn_D);
					elsif BiasChanged_S(23) = '1' then
						BiasSent_S(23)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(23, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.AEPdBn_D);
					elsif BiasChanged_S(24) = '1' then
						BiasSent_S(24)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(24, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.AEPuXBp_D);
					elsif BiasChanged_S(25) = '1' then
						BiasSent_S(25)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(25, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.AEPuYBp_D);
					elsif BiasChanged_S(26) = '1' then
						BiasSent_S(26)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(26, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VbiasLF1Bn_D);
					elsif BiasChanged_S(27) = '1' then
						BiasSent_S(27)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(27, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VclbtcasBnc_D);
					elsif BiasChanged_S(28) = '1' then
						BiasSent_S(28)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(28, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.Ibias20pOTA_D);
					elsif BiasChanged_S(29) = '1' then
						BiasSent_S(29)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(29, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.Ibias40pOTA_D);
					elsif BiasChanged_S(30) = '1' then
						BiasSent_S(30)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(30, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.Ibias1nOTA_D);
					elsif BiasChanged_S(31) = '1' then
						BiasSent_S(31)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(31, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.Blk2N_D);
					elsif BiasChanged_S(32) = '1' then
						BiasSent_S(32)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(32, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.Blk3N_D);
					elsif BiasChanged_S(33) = '1' then
						BiasSent_S(33)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(33, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.VthAGCBn_D);
					elsif BiasChanged_S(34) = '1' then
						BiasSent_S(34)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(34, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasGenerateCoarseFine(BiasConfigReg_DP.BiasBuffer_D);
					elsif BiasChanged_S(35) = '1' then
						BiasSent_S(35)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(35, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasConfigReg_DP.SSP_D;
					elsif BiasChanged_S(36) = '1' then
						BiasSent_S(36)    <= '1';
						BiasAddrSRInput_D <= std_logic_vector(to_unsigned(36, BIASADDR_REG_LENGTH));
						BiasSRInput_D     <= BiasConfigReg_DP.SSN_D;
					end if;
				end if;

			-- Sending Biases
			-- First send Bias Address
			when stPrepareSendBiasAddress =>
				-- Set flags as needed for bias address SR.
				ChipBiasDiagSelectReg_S <= '0';
				ChipBiasAddrSelectReg_S <= '0';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendBiasAddress;
				end if;

			when stSendBiasAddress =>
				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= BiasAddrSROutput_D(BIASADDR_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					BiasAddrSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(BIASADDR_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Make Latch transparent.
						ChipBiasLatchReg_SB <= '0';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchBiasAddress;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchBiasAddress =>
				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					-- Latch new config.
					ChipBiasLatchReg_SB <= '1';
				end if;

				-- Wait for Bias Address to be latched before changing AddrSel and DiagSel signals
				if WaitCyclesCounterData_D = to_unsigned(LATCH_PLUS_HOLD - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stPrepareSendBias;
				end if;

			-- Now send Bias itself
			when stPrepareSendBias =>
				-- Set flags as needed for bias SR.
				ChipBiasDiagSelectReg_S <= '0';
				ChipBiasAddrSelectReg_S <= '1';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendBias;
				end if;

			when stSendBias =>
				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= BiasSROutput_D(BIAS_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					BiasSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(BIAS_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Make Latch transparent.
						ChipBiasLatchReg_SB <= '0';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchBias;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchBias =>
				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					-- Latch new config.
					ChipBiasLatchReg_SB <= '1';
				end if;

				-- Wait for data to be latched before changing AddrSel and DiagSel signals
				if WaitCyclesCounterData_D = to_unsigned(LATCH_PLUS_HOLD - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelay;
				end if;

			-- Sending Channel or Chip Config, ChipBiasDiagSelectReg_S = '1'
			-- First send Channel/Chip Address (same for both)
			when stPrepareSendChannelAddress =>
				-- Set flags as needed for channel address SR.
				ChipBiasDiagSelectReg_S <= '1';
				ChipBiasAddrSelectReg_S <= '1';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendChannelAddress;
				end if;

			when stSendChannelAddress =>
				-- Shift it out, slowly, over the bias ports.
				-- NOTE: this is reversed, first to be shifted out is LSB!
				ChipBiasBitInReg_D <= ChannelAddressSROutput_D(0);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					-- NOTE: this is reversed, first to be shifted out is LSB!
					ChannelAddressSRMode_S <= SHIFTREGISTER_MODE_SHIFT_RIGHT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(CHIP_CHANADDR_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Make Latch transparent.
						ChipBiasLatchReg_SB <= '0';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchChannelAddress;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchChannelAddress =>
				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					-- Latch new config.
					ChipBiasLatchReg_SB <= '1';
				end if;

				-- Wait for Channel Address to be latched before changing AddrSel and DiagSel signals
				if WaitCyclesCounterData_D = to_unsigned(LATCH_PLUS_HOLD - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					if IsChannelConfigData_SP = '1' then
						-- Acknowledge current channel config changes.

						if KillState_DP /= stIdle then
							State_DN <= stDelay; -- In case of Neuron Killing
						else
							ChannelSetAck_S <= '1';

							State_DN <= stPrepareSendChannel;
						end if;

					else
						State_DN <= stPrepareSendChip;
					end if;
				end if;

			-- Send Chip Config
			when stPrepareSendChip =>
				-- Set flags as needed for chip diag SR.
				ChipBiasDiagSelectReg_S <= '1';
				ChipBiasAddrSelectReg_S <= '0';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendChip;
				end if;

			when stSendChip =>
				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= ChipSROutput_D(CHIP_REG_LENGTH - 1);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					ChipSRMode_S <= SHIFTREGISTER_MODE_SHIFT_LEFT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(CHIP_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Make Latch transparent.
						ChipBiasLatchReg_SB <= '0';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchChip;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchChip =>
				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					-- Latch new config.
					ChipBiasLatchReg_SB <= '1';
				end if;

				-- Wait for data to be latched before changing AddrSel and DiagSel signals
				if WaitCyclesCounterData_D = to_unsigned(LATCH_PLUS_HOLD - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelay;
				end if;

			when stPrepareSendChannel =>
				-- Set flags as needed for channel SR.
				ChipBiasDiagSelectReg_S <= '1';
				ChipBiasAddrSelectReg_S <= '0';

				-- Wait for one bias clock cycle, to ensure the chip has had time to switch to the right SR.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stSendChannel;
				end if;

			when stSendChannel =>
				-- Shift it out, slowly, over the bias ports.
				ChipBiasBitInReg_D <= ChannelSROutput_D(0);

				-- Wait for one full clock cycle, then switch to the next bit.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					-- Move to next bit.
					ChannelSRMode_S <= SHIFTREGISTER_MODE_SHIFT_RIGHT;

					-- Count up one, this bit is done!
					SentBitsCounterEnable_S <= '1';

					if SentBitsCounterData_D = to_unsigned(CHIP_CHAN_REG_LENGTH - 1, SENT_BITS_COUNTER_SIZE) then
						SentBitsCounterEnable_S <= '0';
						SentBitsCounterClear_S  <= '1';

						-- Make Latch transparent.
						ChipBiasLatchReg_SB <= '0';

						-- Move to next state, this SR is fully shifted out now.
						State_DN <= stLatchChannel;
					end if;
				end if;

				-- Clock data. Default clock is HIGH, so we pull it LOW during the middle half of its period.
				-- This way both clock edges happen when the data is stable.
				if WaitCyclesCounterData_D >= to_unsigned(BIAS_CLOCK_CYCLES / 4, WAIT_CYCLES_COUNTER_SIZE) and WaitCyclesCounterData_D <= to_unsigned(BIAS_CLOCK_CYCLES / 4 * 3, WAIT_CYCLES_COUNTER_SIZE) then
					ChipBiasClockReg_CB <= '0';
				end if;

			when stLatchChannel =>
				-- Keep latch active for a few cycles.
				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(LATCH_CYCLES - 1, WAIT_CYCLES_COUNTER_SIZE) then
					-- Latch new config.
					ChipBiasLatchReg_SB <= '1';
				end if;

				-- Wait for data to be latched before changing AddrSel and DiagSel signals
				if WaitCyclesCounterData_D = to_unsigned(LATCH_PLUS_HOLD - 1, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stDelay;
				end if;

			-- Delay by one cycle to ensure no back-to-back updates can happen.
			when stDelay =>
				-- Keep all flags in the previous state.

				WaitCyclesCounterEnable_S <= '1';

				if WaitCyclesCounterData_D = to_unsigned(BIAS_CLOCK_CYCLES, WAIT_CYCLES_COUNTER_SIZE) then
					WaitCyclesCounterEnable_S <= '0';
					WaitCyclesCounterClear_S  <= '1';

					State_DN <= stIdle;
				end if;

			when others => null;
		end case;
	end process sendConfig;

	KillNeuronSM : process(KillState_DP, AERKillBit_SO, KillDelayPassed_S, KillNeurons02_SP, NeuronKill02_S, NeuronKill13_S, Sel02Kill_SP, Sel13Kill_SP, State_DP)
	begin
		KillState_DN <= KillState_DP;

		Sel02Kill_SN     <= Sel02Kill_SP;
		Sel13Kill_SN     <= Sel13Kill_SP;
		KillNeurons02_SN <= KillNeurons02_SP;
		AERKillBitReg_S  <= AERKillBit_SO;

		NeuronKill02Ack_S <= '0';
		NeuronKill13Ack_S <= '0';
		KillDelayCount_S  <= '0';

		case KillState_DP is
			when stIdle =>
				-- Accept Kill signal only when the main state machine is in the Idle state
				if State_DP = stIdle then
					if (NeuronKill02_S or NeuronKill13_S) = '1' then
						-- Remember which neurons we are killing now - 0,2 or 1,3 
						KillNeurons02_SN <= NeuronKill02_S;
						-- This should trigger ChipConfig update process in the main state machine
						Sel02Kill_SN <= NeuronKill02_S;
						Sel13Kill_SN <= NeuronKill13_S;

						KillState_DN <= stSetSelTopBot;
					end if;
				end if;

			when stSetSelTopBot =>
				-- Wait a little bit to make sure that the changes were detected
				KillDelayCount_S <= '1';

				if KillDelayPassed_S = '1' then
					KillState_DN <= stWaitSelTopBotIsSet;
				end if;

			when stWaitSelTopBotIsSet =>
				-- Wait until the shift register is shifted out
				if State_DP = stIdle then
					-- Wait a little bit more after setting SelTopBot
					KillDelayCount_S <= '1';

					if KillDelayPassed_S = '1' then
						KillState_DN <= stSendChannelAddress;
					end if;
				end if;

			when stSendChannelAddress =>
				KillState_DN <= stSendingChannelAddress;

			when stSendingChannelAddress =>
				-- Proceed with killing when the address for the selected channel is sent
				if State_DP = stIdle then
					AERKillBitReg_S <= '1';

					KillState_DN <= stSetKill;
				end if;

			when stSetKill =>
				KillDelayCount_S <= '1';

				if KillDelayPassed_S = '1' then
					-- This should trigger ChipConfig update process in the main state machine
					Sel02Kill_SN <= '0';
					Sel13Kill_SN <= '0';

					KillState_DN <= stClearSelTopBot;
				end if;

			when stClearSelTopBot =>
				-- Wait a little bit to make sure that the changes were detected
				KillDelayCount_S <= '1';

				if KillDelayPassed_S = '1' then
					KillState_DN <= stWaitSelTopBotIsCleared;
				end if;

			when stWaitSelTopBotIsCleared =>
				-- Wait until the shift register is shifted out
				if State_DP = stIdle then
					KillState_DN <= stClearKill;
				end if;

			when stClearKill =>
				AERKillBitReg_S  <= '0';
				KillDelayCount_S <= '1';

				if KillDelayPassed_S = '1' then
					if KillNeurons02_SP = '1' then
						NeuronKill02Ack_S <= '1';
					else
						NeuronKill13Ack_S <= '1';
					end if;

					KillState_DN <= stIdle;
				end if;

			when others => null;
		end case;
	end process KillNeuronSM;

	regUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then
			State_DP     <= stIdle;
			KillState_DP <= stIdle;

			BiasConfigReg_DP    <= tCochleaTow4EarBiasConfigDefault;
			ChipConfigReg_DP    <= tCochleaTow4EarChipConfigDefault;
			ChannelConfigReg_DP <= tCochleaTow4EarChannelConfigDefault;

			IsChannelConfigData_SP <= '0';
			KillNeurons02_SP       <= '0';
			Sel02Kill_SP           <= '0';
			Sel13Kill_SP           <= '0';

			ChipBiasDiagSelect_SO <= '0';
			ChipBiasAddrSelect_SO <= '1';
			ChipBiasClock_CBO     <= '1';
			ChipBiasBitIn_DO      <= '0';
			ChipBiasLatch_SBO     <= '1';
			AERKillBit_SO         <= '0';
		elsif rising_edge(Clock_CI) then
			State_DP     <= State_DN;
			KillState_DP <= KillState_DN;

			BiasConfigReg_DP    <= BiasConfigReg_DN;
			ChipConfigReg_DP    <= ChipConfigReg_DN;
			ChannelConfigReg_DP <= ChannelConfigReg_DN;

			IsChannelConfigData_SP <= IsChannelConfigData_SN;
			KillNeurons02_SP       <= KillNeurons02_SN;
			Sel02Kill_SP           <= Sel02Kill_SN;
			Sel13Kill_SP           <= Sel13Kill_SN;

			ChipBiasDiagSelect_SO <= ChipBiasDiagSelectReg_S;
			ChipBiasAddrSelect_SO <= ChipBiasAddrSelectReg_S;
			ChipBiasClock_CBO     <= ChipBiasClockReg_CB;
			ChipBiasBitIn_DO      <= ChipBiasBitInReg_D;
			ChipBiasLatch_SBO     <= ChipBiasLatchReg_SB;
			AERKillBit_SO         <= AERKillBitReg_S;
		end if;
	end process regUpdate;

	waitCyclesCounter : entity work.Counter
		generic map(
			SIZE => WAIT_CYCLES_COUNTER_SIZE)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Clear_SI  => WaitCyclesCounterClear_S,
			Enable_SI => WaitCyclesCounterEnable_S,
			Data_DO   => WaitCyclesCounterData_D);

	sentBitsCounter : entity work.Counter
		generic map(
			SIZE => SENT_BITS_COUNTER_SIZE)
		port map(
			Clock_CI  => Clock_CI,
			Reset_RI  => Reset_RI,
			Clear_SI  => SentBitsCounterClear_S,
			Enable_SI => SentBitsCounterEnable_S,
			Data_DO   => SentBitsCounterData_D);

	killDelayCounter : entity work.ContinuousCounter
		generic map(
			SIZE => AER_KILL_DELAY_COUNTER_WIDTH)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Clear_SI     => '0',
			Enable_SI    => KillDelayCount_S,
			DataLimit_DI => ChannelConfigReg_DP.PrePostKillDelay_D,
			Overflow_SO  => KillDelayPassed_S,
			Data_DO      => open);

	biasAddrSR : entity work.ShiftRegister
		generic map(
			SIZE => BIASADDR_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => BiasAddrSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => BiasAddrSRInput_D,
			ParallelRead_DO  => BiasAddrSROutput_D);

	biasSR : entity work.ShiftRegister
		generic map(
			SIZE => BIAS_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => BiasSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => BiasSRInput_D,
			ParallelRead_DO  => BiasSROutput_D);

	chipSR : entity work.ShiftRegister
		generic map(
			SIZE => CHIP_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => ChipSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChipSRInput_D,
			ParallelRead_DO  => ChipSROutput_D);

	channelAddressSR : entity work.ShiftRegister
		generic map(
			SIZE => CHIP_CHANADDR_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => ChannelAddressSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChannelAddressSRInput_D,
			ParallelRead_DO  => ChannelAddressSROutput_D);

	channelSR : entity work.ShiftRegister
		generic map(
			SIZE => CHIP_CHAN_REG_LENGTH)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => ChannelSRMode_S,
			DataIn_DI        => '0',
			ParallelWrite_DI => ChannelSRInput_D,
			ParallelRead_DO  => ChannelSROutput_D);

	detectChannelSetPulse : entity work.PulseDetector
		generic map(
			SIZE => 2)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			PulsePolarity_SI => '1',
			PulseLength_DI   => to_unsigned(2, 2),
			InputSignal_SI   => ChannelConfigReg_DP.ChannelSet_S,
			PulseDetected_SO => ChannelSetPulse_S);

	bufferChannelSet : entity work.BufferClear
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			Clear_SI        => ChannelSetAck_S,
			InputSignal_SI  => ChannelSetPulse_S,
			OutputSignal_SO => ChannelSet_S);

	detectChannelKill02Pulse : entity work.PulseDetector
		generic map(
			SIZE => 2)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			PulsePolarity_SI => '1',
			PulseLength_DI   => to_unsigned(2, 2),
			InputSignal_SI   => ChannelConfigReg_DP.NeuronKill02_S,
			PulseDetected_SO => NeuronKill02Pulse_S);

	bufferChannelKill02 : entity work.BufferClear
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			Clear_SI        => NeuronKill02Ack_S,
			InputSignal_SI  => NeuronKill02Pulse_S,
			OutputSignal_SO => NeuronKill02_S);

	detectChannelKill13Pulse : entity work.PulseDetector
		generic map(
			SIZE => 2)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			PulsePolarity_SI => '1',
			PulseLength_DI   => to_unsigned(2, 2),
			InputSignal_SI   => ChannelConfigReg_DP.NeuronKill13_S,
			PulseDetected_SO => NeuronKill13Pulse_S);

	bufferChannelKill13 : entity work.BufferClear
		port map(
			Clock_CI        => Clock_CI,
			Reset_RI        => Reset_RI,
			Clear_SI        => NeuronKill13Ack_S,
			InputSignal_SI  => NeuronKill13Pulse_S,
			OutputSignal_SO => NeuronKill13_S);

	detectBias0Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VrefpreampBp_D,
			ChangeDetected_SO     => BiasChanged_S(0),
			ChangeAcknowledged_SI => BiasSent_S(0));

	detectBias1Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Vth1_D,
			ChangeDetected_SO     => BiasChanged_S(1),
			ChangeAcknowledged_SI => BiasSent_S(1));

	detectBias2Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Vth2_D,
			ChangeDetected_SO     => BiasChanged_S(2),
			ChangeAcknowledged_SI => BiasSent_S(2));

	detectBias3Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VbMicCasBpc_D,
			ChangeDetected_SO     => BiasChanged_S(3),
			ChangeAcknowledged_SI => BiasSent_S(3));

	detectBias4Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VbiasHF2Bn_D,
			ChangeDetected_SO     => BiasChanged_S(4),
			ChangeAcknowledged_SI => BiasSent_S(4));

	detectBias5Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Vbias2n_D,
			ChangeDetected_SO     => BiasChanged_S(5),
			ChangeAcknowledged_SI => BiasSent_S(5));

	detectBias6Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Vrefdiff_D,
			ChangeDetected_SO     => BiasChanged_S(6),
			ChangeAcknowledged_SI => BiasSent_S(6));

	detectBias7Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_VD_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Vrefdiff2_D,
			ChangeDetected_SO     => BiasChanged_S(7),
			ChangeAcknowledged_SI => BiasSent_S(7));

	detectBias8Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.LocalBufBn_D,
			ChangeDetected_SO     => BiasChanged_S(8),
			ChangeAcknowledged_SI => BiasSent_S(8));

	detectBias9Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VtauBn_D,
			ChangeDetected_SO     => BiasChanged_S(9),
			ChangeAcknowledged_SI => BiasSent_S(9));

	detectBias10Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Vbias1Bn_D,
			ChangeDetected_SO     => BiasChanged_S(10),
			ChangeAcknowledged_SI => BiasSent_S(10));

	detectBias11Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VrefractBnc4_D,
			ChangeDetected_SO     => BiasChanged_S(11),
			ChangeAcknowledged_SI => BiasSent_S(11));

	detectBias12Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VrefractBnc1_D,
			ChangeDetected_SO     => BiasChanged_S(12),
			ChangeAcknowledged_SI => BiasSent_S(12));

	detectBias13Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.PixInvBn_D,
			ChangeDetected_SO     => BiasChanged_S(13),
			ChangeAcknowledged_SI => BiasSent_S(13));

	detectBias14Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VBPScan_D,
			ChangeDetected_SO     => BiasChanged_S(14),
			ChangeAcknowledged_SI => BiasSent_S(14));

	detectBias15Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VbBp1_D,
			ChangeDetected_SO     => BiasChanged_S(15),
			ChangeAcknowledged_SI => BiasSent_S(15));

	detectBias16Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VbBp2_D,
			ChangeDetected_SO     => BiasChanged_S(16),
			ChangeAcknowledged_SI => BiasSent_S(16));

	detectBias17Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VneuronLeakExtBp_D,
			ChangeDetected_SO     => BiasChanged_S(17),
			ChangeAcknowledged_SI => BiasSent_S(17));

	detectBias18Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VpulseAERExtdBn_D,
			ChangeDetected_SO     => BiasChanged_S(18),
			ChangeAcknowledged_SI => BiasSent_S(18));

	detectBias19Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VwideampBp_D,
			ChangeDetected_SO     => BiasChanged_S(19),
			ChangeAcknowledged_SI => BiasSent_S(19));

	detectBias20Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VQBn_D,
			ChangeDetected_SO     => BiasChanged_S(20),
			ChangeAcknowledged_SI => BiasSent_S(20));

	detectBias21Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VcascodeBpc_D,
			ChangeDetected_SO     => BiasChanged_S(21),
			ChangeAcknowledged_SI => BiasSent_S(21));

	detectBias22Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.LcolTimeoutBn_D,
			ChangeDetected_SO     => BiasChanged_S(22),
			ChangeAcknowledged_SI => BiasSent_S(22));

	detectBias23Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.AEPdBn_D,
			ChangeDetected_SO     => BiasChanged_S(23),
			ChangeAcknowledged_SI => BiasSent_S(23));

	detectBias24Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.AEPuXBp_D,
			ChangeDetected_SO     => BiasChanged_S(24),
			ChangeAcknowledged_SI => BiasSent_S(24));

	detectBias25Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.AEPuYBp_D,
			ChangeDetected_SO     => BiasChanged_S(25),
			ChangeAcknowledged_SI => BiasSent_S(25));

	detectBias26Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VbiasLF1Bn_D,
			ChangeDetected_SO     => BiasChanged_S(26),
			ChangeAcknowledged_SI => BiasSent_S(26));

	detectBias27Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VclbtcasBnc_D,
			ChangeDetected_SO     => BiasChanged_S(27),
			ChangeAcknowledged_SI => BiasSent_S(27));

	detectBias28Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Ibias20pOTA_D,
			ChangeDetected_SO     => BiasChanged_S(28),
			ChangeAcknowledged_SI => BiasSent_S(28));

	detectBias29Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Ibias40pOTA_D,
			ChangeDetected_SO     => BiasChanged_S(29),
			ChangeAcknowledged_SI => BiasSent_S(29));

	detectBias30Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Ibias1nOTA_D,
			ChangeDetected_SO     => BiasChanged_S(30),
			ChangeAcknowledged_SI => BiasSent_S(30));

	detectBias31Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Blk2N_D,
			ChangeDetected_SO     => BiasChanged_S(31),
			ChangeAcknowledged_SI => BiasSent_S(31));

	detectBias32Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.Blk3N_D,
			ChangeDetected_SO     => BiasChanged_S(32),
			ChangeAcknowledged_SI => BiasSent_S(32));

	detectBias33Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.VthAGCBn_D,
			ChangeDetected_SO     => BiasChanged_S(33),
			ChangeAcknowledged_SI => BiasSent_S(33));

	detectBias34Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_CF_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.BiasBuffer_D,
			ChangeDetected_SO     => BiasChanged_S(34),
			ChangeAcknowledged_SI => BiasSent_S(34));

	detectBias35Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_SS_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.SSP_D,
			ChangeDetected_SO     => BiasChanged_S(35),
			ChangeAcknowledged_SI => BiasSent_S(35));

	detectBias36Change : entity work.ChangeDetector
		generic map(
			SIZE => BIAS_SS_LENGTH)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => BiasConfigReg_DP.SSN_D,
			ChangeDetected_SO     => BiasChanged_S(36),
			ChangeAcknowledged_SI => BiasSent_S(36));

	-- Put all chip register configuration parameters together, and then detect changes
	-- on the whole lot of them. This is easier to handle and slightly more efficient.
	ChipChangedInput_D <= FlattenChipConfig(ChipConfigReg_DP, Sel13Kill_SP, Sel02Kill_SP);

	detectChipChange : entity work.ChangeDetector
		generic map(
			SIZE => CHIP_REG_USED_SIZE)
		port map(
			Clock_CI              => Clock_CI,
			Reset_RI              => Reset_RI,
			InputData_DI          => ChipChangedInput_D,
			ChangeDetected_SO     => ChipChanged_S,
			ChangeAcknowledged_SI => ChipSent_S);
end architecture Behavioral;
