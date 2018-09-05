library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ChipBiasConfigRecords.all;

package CochleaTow4EarChipBiasConfigRecords is
-- Bias Config for CochleaTowEar4
-- Bias Config is taken from DAVIS
-- Use https://docs.google.com/spreadsheets/d/1pGSDFvARpDgQ1maODE-3oa2F8cfzENx0hgGwzC-EMZU/edit#gid=9

	-- Total length of actual register to send out.
	constant NUMBER_OF_BIASES : integer := 37;

	type tCochleaTow4EarBiasConfigParamAddresses is record
		VrefpreampBp_D     : unsigned(7 downto 0);
		Vth1_D             : unsigned(7 downto 0);
		Vth2_D             : unsigned(7 downto 0);
		VbMicCasBpc_D      : unsigned(7 downto 0);
		VbiasHF2Bn_D       : unsigned(7 downto 0);
		Vbias2n_D          : unsigned(7 downto 0);
		Vrefdiff_D         : unsigned(7 downto 0);
		Vrefdiff2_D        : unsigned(7 downto 0);
		LocalBufBn_D       : unsigned(7 downto 0);
		VtauBn_D           : unsigned(7 downto 0);
		Vbias1Bn_D         : unsigned(7 downto 0);
		VrefractBnc4_D     : unsigned(7 downto 0);
		VrefractBnc1_D     : unsigned(7 downto 0);
		PixInvBn_D         : unsigned(7 downto 0);
		VBPScan_D          : unsigned(7 downto 0);
		VbBp1_D            : unsigned(7 downto 0);
		VbBp2_D            : unsigned(7 downto 0);
		VneuronLeakExtBp_D : unsigned(7 downto 0);
		VpulseAERExtdBn_D  : unsigned(7 downto 0);
		VwideampBp_D       : unsigned(7 downto 0);
		VQBn_D             : unsigned(7 downto 0);
		VcascodeBpc_D      : unsigned(7 downto 0);
		LcolTimeoutBn_D    : unsigned(7 downto 0);
		AEPdBn_D           : unsigned(7 downto 0);
		AEPuXBp_D          : unsigned(7 downto 0);
		AEPuYBp_D          : unsigned(7 downto 0);
		VbiasLF1Bn_D       : unsigned(7 downto 0);
		VclbtcasBnc_D      : unsigned(7 downto 0);
		Ibias20pOTA_D      : unsigned(7 downto 0);
		Ibias40pOTA_D      : unsigned(7 downto 0);
		Ibias1nOTA_D       : unsigned(7 downto 0);
		Blk2N_D            : unsigned(7 downto 0);
		Blk3N_D            : unsigned(7 downto 0);
		VthAGCBn_D         : unsigned(7 downto 0);
		BiasBuffer_D       : unsigned(7 downto 0);
		SSP_D              : unsigned(7 downto 0);
		SSN_D              : unsigned(7 downto 0);
	end record tCochleaTow4EarBiasConfigParamAddresses;

	constant COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES : tCochleaTow4EarBiasConfigParamAddresses := (
		VrefpreampBp_D     => to_unsigned(0, 8),
		Vth1_D             => to_unsigned(1, 8),
		Vth2_D             => to_unsigned(2, 8),
		VbMicCasBpc_D      => to_unsigned(3, 8),
		VbiasHF2Bn_D       => to_unsigned(4, 8),
		Vbias2n_D          => to_unsigned(5, 8),
		Vrefdiff_D         => to_unsigned(6, 8),
		Vrefdiff2_D        => to_unsigned(7, 8),
		LocalBufBn_D       => to_unsigned(8, 8),
		VtauBn_D           => to_unsigned(9, 8),
		Vbias1Bn_D         => to_unsigned(10, 8),
		VrefractBnc4_D     => to_unsigned(11, 8),
		VrefractBnc1_D     => to_unsigned(12, 8),
		PixInvBn_D         => to_unsigned(13, 8),
		VBPScan_D          => to_unsigned(14, 8),
		VbBp1_D            => to_unsigned(15, 8),
		VbBp2_D            => to_unsigned(16, 8),
		VneuronLeakExtBp_D => to_unsigned(17, 8),
		VpulseAERExtdBn_D  => to_unsigned(18, 8),
		VwideampBp_D       => to_unsigned(19, 8),
		VQBn_D             => to_unsigned(20, 8),
		VcascodeBpc_D      => to_unsigned(21, 8),
		LcolTimeoutBn_D    => to_unsigned(22, 8),
		AEPdBn_D           => to_unsigned(23, 8),
		AEPuXBp_D          => to_unsigned(24, 8),
		AEPuYBp_D          => to_unsigned(25, 8),
		VbiasLF1Bn_D       => to_unsigned(26, 8),
		VclbtcasBnc_D      => to_unsigned(27, 8),
		Ibias20pOTA_D      => to_unsigned(28, 8),
		Ibias40pOTA_D      => to_unsigned(29, 8),
		Ibias1nOTA_D       => to_unsigned(30, 8),
		Blk2N_D            => to_unsigned(31, 8),
		Blk3N_D            => to_unsigned(32, 8),
		VthAGCBn_D         => to_unsigned(33, 8),
		BiasBuffer_D       => to_unsigned(34, 8),
		SSP_D              => to_unsigned(35, 8),
		SSN_D              => to_unsigned(36, 8));

	type tCochleaTow4EarBiasConfig is record
		VrefpreampBp_D     : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		Vth1_D             : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		Vth2_D             : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		VbMicCasBpc_D      : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		VbiasHF2Bn_D       : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		Vbias2n_D          : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		Vrefdiff_D         : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		Vrefdiff2_D        : std_logic_vector(BIAS_VD_LENGTH - 1 downto 0);
		LocalBufBn_D       : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VtauBn_D           : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		Vbias1Bn_D         : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VrefractBnc4_D     : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VrefractBnc1_D     : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		PixInvBn_D         : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VBPScan_D          : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VbBp1_D            : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VbBp2_D            : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VneuronLeakExtBp_D : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VpulseAERExtdBn_D  : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VwideampBp_D       : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VQBn_D             : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VcascodeBpc_D      : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		LcolTimeoutBn_D    : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		AEPdBn_D           : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		AEPuXBp_D          : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		AEPuYBp_D          : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VbiasLF1Bn_D       : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VclbtcasBnc_D      : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		Ibias20pOTA_D      : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		Ibias40pOTA_D      : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		Ibias1nOTA_D       : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		Blk2N_D            : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		Blk3N_D            : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		VthAGCBn_D         : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		BiasBuffer_D       : std_logic_vector(BIAS_CF_LENGTH - 1 downto 0);
		SSP_D              : std_logic_vector(BIAS_SS_LENGTH - 1 downto 0);
		SSN_D              : std_logic_vector(BIAS_SS_LENGTH - 1 downto 0);
	end record tCochleaTow4EarBiasConfig;

	constant tCochleaTow4EarBiasConfigDefault : tCochleaTow4EarBiasConfig := (
		VrefpreampBp_D     => (others => '0'),
		Vth1_D             => (others => '0'),
		Vth2_D             => (others => '0'),
		VbMicCasBpc_D      => (others => '0'),
		VbiasHF2Bn_D       => (others => '0'),
		Vbias2n_D          => (others => '0'),
		Vrefdiff_D         => (others => '0'),
		Vrefdiff2_D        => (others => '0'),
		LocalBufBn_D       => (others => '0'),
		VtauBn_D           => (others => '0'),
		Vbias1Bn_D         => (others => '0'),
		VrefractBnc4_D     => (others => '0'),
		VrefractBnc1_D     => (others => '0'),
		PixInvBn_D         => (others => '0'),
		VBPScan_D          => (others => '0'),
		VbBp1_D            => (others => '0'),
		VbBp2_D            => (others => '0'),
		VneuronLeakExtBp_D => (others => '0'),
		VpulseAERExtdBn_D  => (others => '0'),
		VwideampBp_D       => (others => '0'),
		VQBn_D             => (others => '0'),
		VcascodeBpc_D      => (others => '0'),
		LcolTimeoutBn_D    => (others => '0'),
		AEPdBn_D           => (others => '0'),
		AEPuXBp_D          => (others => '0'),
		AEPuYBp_D          => (others => '0'),
		VbiasLF1Bn_D       => (others => '0'),
		VclbtcasBnc_D      => (others => '0'),
		Ibias20pOTA_D      => (others => '0'),
		Ibias40pOTA_D      => (others => '0'),
		Ibias1nOTA_D       => (others => '0'),
		Blk2N_D            => (others => '0'),
		Blk3N_D            => (others => '0'),
		VthAGCBn_D         => (others => '0'),
		BiasBuffer_D       => (others => '0'),
		SSP_D              => (others => '0'),
		SSN_D              => (others => '0'));

-- Chip Config for CochTow4Ear1
-- https://docs.google.com/spreadsheets/d/1bQuHMrMZlUMaP9yn8vyHrcpH_UG9bzZDWa8dEqHY7ic/edit#gid=12

	-- Total length of actual register to send out.
	constant CHIP_REG_LENGTH : integer := 44;

	-- Effectively used bits in chip register.
	constant CHIP_REG_USED_SIZE : integer := (5 * CHIP_MUX_LENGTH) + 24;

	type tCochleaTow4EarChipConfigParamAddresses is record
		AnalogMux0_D   : unsigned(7 downto 0);
		PreampGain_D   : unsigned(7 downto 0);
		Seln1_S        : unsigned(7 downto 0);
		Seln2_S        : unsigned(7 downto 0);
		SMconfigArow_S : unsigned(7 downto 0);
		DC5_S          : unsigned(7 downto 0);
		SelBot_S       : unsigned(7 downto 0);
		SelTop_S       : unsigned(7 downto 0);
		DC8_S          : unsigned(7 downto 0);
		DC9_S          : unsigned(7 downto 0);
		DC10_S         : unsigned(7 downto 0);
		DC11_S         : unsigned(7 downto 0);
		DC12_S         : unsigned(7 downto 0);
		DC13_S         : unsigned(7 downto 0);
		DC14_S         : unsigned(7 downto 0);
		DC15_S         : unsigned(7 downto 0);
		DC16_S         : unsigned(7 downto 0);
		DC17_S         : unsigned(7 downto 0);
		DC18_S         : unsigned(7 downto 0);
		BitTestLatch_S : unsigned(7 downto 0);
		DC20_S         : unsigned(7 downto 0);
		DC21_S         : unsigned(7 downto 0);
		DC22_S         : unsigned(7 downto 0);
		DC23_S         : unsigned(7 downto 0);
		DigitalMux0_D  : unsigned(7 downto 0);
		DigitalMux1_D  : unsigned(7 downto 0);
		DigitalMux2_D  : unsigned(7 downto 0);
		DigitalMux3_D  : unsigned(7 downto 0);
		SelResSw_S     : unsigned(7 downto 0);
		VresetBn_S     : unsigned(7 downto 0);
	end record tCochleaTow4EarChipConfigParamAddresses;

	-- Start with addresses 128 here, so that the MSB (bit 7) is always high. This heavily simplifies
	-- the SPI configuration module, and clearly separates biases from chip diagnostic.
	constant COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES : tCochleaTow4EarChipConfigParamAddresses := (
		AnalogMux0_D   => to_unsigned(128, 8),
		PreampGain_D   => to_unsigned(129, 8),
		Seln1_S        => to_unsigned(130, 8),
		Seln2_S        => to_unsigned(131, 8),
		SMconfigArow_S => to_unsigned(132, 8),
		DC5_S          => to_unsigned(133, 8),
		SelBot_S       => to_unsigned(134, 8),
		SelTop_S       => to_unsigned(135, 8),
		DC8_S          => to_unsigned(136, 8),
		DC9_S          => to_unsigned(137, 8),
		DC10_S         => to_unsigned(138, 8),
		DC11_S         => to_unsigned(139, 8),
		DC12_S         => to_unsigned(140, 8),
		DC13_S         => to_unsigned(141, 8),
		DC14_S         => to_unsigned(142, 8),
		DC15_S         => to_unsigned(143, 8),
		DC16_S         => to_unsigned(144, 8),
		DC17_S         => to_unsigned(145, 8),
		DC18_S         => to_unsigned(146, 8),
		BitTestLatch_S => to_unsigned(147, 8),
		DC20_S         => to_unsigned(148, 8),
		DC21_S         => to_unsigned(149, 8),
		DC22_S         => to_unsigned(150, 8),
		DC23_S         => to_unsigned(151, 8),
		DigitalMux0_D  => to_unsigned(152, 8),
		DigitalMux1_D  => to_unsigned(153, 8),
		DigitalMux2_D  => to_unsigned(154, 8),
		DigitalMux3_D  => to_unsigned(155, 8),
		SelResSw_S     => to_unsigned(156, 8),
		VresetBn_S     => to_unsigned(157, 8));

	type tCochleaTow4EarChipConfig is record
		AnalogMux0_D   : unsigned(CHIP_MUX_LENGTH - 1 downto 0);
		PreampGain_D   : unsigned(1 downto 0);
		Seln1_S        : std_logic;
		Seln2_S        : std_logic;
		SMconfigArow_S : std_logic;
		DC5_S          : std_logic;
		SelBot_S       : std_logic;
		SelTop_S       : std_logic;
		DC8_S          : std_logic;
		DC9_S          : std_logic;
		DC10_S         : std_logic;
		DC11_S         : std_logic;
		DC12_S         : std_logic;
		DC13_S         : std_logic;
		DC14_S         : std_logic;
		DC15_S         : std_logic;
		DC16_S         : std_logic;
		DC17_S         : std_logic;
		DC18_S         : std_logic;
		BitTestLatch_S : std_logic;
		DC20_S         : std_logic;
		DC21_S         : std_logic;
		DC22_S         : std_logic;
		DC23_S         : std_logic;
		DigitalMux0_D  : unsigned(CHIP_MUX_LENGTH - 1 downto 0);
		DigitalMux1_D  : unsigned(CHIP_MUX_LENGTH - 1 downto 0);
		DigitalMux2_D  : unsigned(CHIP_MUX_LENGTH - 1 downto 0);
		DigitalMux3_D  : unsigned(CHIP_MUX_LENGTH - 1 downto 0);
		-- The following 2 bits do not belong to the ChipConfig shift register. They have separate pins.
		SelResSw_S     : std_logic;
		VresetBn_S     : std_logic;
		
	end record tCochleaTow4EarChipConfig;

	constant tCochleaTow4EarChipConfigDefault : tCochleaTow4EarChipConfig := (
		AnalogMux0_D   => (others => '0'),
		PreampGain_D   => (others => '0'),
		Seln1_S        => '0',
		Seln2_S        => '0',
		SMconfigArow_S => '0',
		DC5_S          => '0',
		SelBot_S       => '0',
		SelTop_S       => '0',
		DC8_S          => '0',
		DC9_S          => '0',
		DC10_S         => '0',
		DC11_S         => '0',
		DC12_S         => '0',
		DC13_S         => '0',
		DC14_S         => '0',
		DC15_S         => '1',
		DC16_S         => '0',
		DC17_S         => '0',
		DC18_S         => '1',
		BitTestLatch_S => '0',
		DC20_S         => '0',
		DC21_S         => '0',
		DC22_S         => '0',
		DC23_S         => '0',
		DigitalMux0_D  => (others => '0'),
		DigitalMux1_D  => (others => '0'),
		DigitalMux2_D  => (others => '0'),
		DigitalMux3_D  => (others => '0'),
		SelResSw_S     => '0',   -- If SelResSW = 1, gate of resistor is tied to SSP, else it is tied to Vdd. SelResSW = 0 in normal operation
		VresetBn_S     => '0');  -- Global signal. If VresetBn_S = 1, all AER local request signals (from neurons) are reset

-- Channel Config
	-- There are 64 channels here.
	constant CHIP_CHAN_NUMBER : integer := 256;

	--  Total length of actual register to send out.
	constant CHIP_CHANADDR_REG_LENGTH : integer := 16;

	-- Effectively used bits in channel address config registers.
	constant CHIP_CHANADDR_REG_USED_SIZE : integer := 8;

	-- Total length of actual register to send out.
	constant CHIP_CHAN_REG_LENGTH : integer := 24;

	-- Effectively used bits in channel config registers.
	constant CHIP_CHAN_REG_USED_SIZE : integer := 20;

	-- Counter for delays between setting AerKillBit = 1, nSel<Top|Bot> = 0, nSel<Top|Bot> = 1 and AerKillBit = 0.
	constant AER_KILL_DELAY_COUNTER_WIDTH : integer := 11;

	type tCochleaTow4EarChannelConfigParamAddresses is record
		ChannelAddress_D   : unsigned(7 downto 0);
		ChannelDataRead_D  : unsigned(7 downto 0);
		ChannelDataWrite_D : unsigned(7 downto 0);
		ChannelSet_S       : unsigned(7 downto 0);
		PrePostKillDelay_D : unsigned(7 downto 0);
		ChannelKill02_S    : unsigned(7 downto 0);
		ChannelKill13_S    : unsigned(7 downto 0);
	end record tCochleaTow4EarChannelConfigParamAddresses;

	-- Start with addresses 160 here, so that the MSB (bit 7) is always high, plus 32 to
	-- distance from the above standard chip configuration.
	constant COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES : tCochleaTow4EarChannelConfigParamAddresses := (
		ChannelAddress_D   => to_unsigned(160, 8),
		ChannelDataRead_D  => to_unsigned(161, 8),
		ChannelDataWrite_D => to_unsigned(162, 8),
		ChannelSet_S       => to_unsigned(163, 8),
		PrePostKillDelay_D => to_unsigned(164, 8),
		ChannelKill02_S    => to_unsigned(165, 8),
		ChannelKill13_S    => to_unsigned(166, 8));

	type tCochleaTow4EarChannelConfig is record
		ChannelAddress_D   : unsigned(CHIP_CHANADDR_REG_USED_SIZE - 1 downto 0);
		ChannelDataWrite_D : std_logic_vector(CHIP_CHAN_REG_USED_SIZE - 1 downto 0);
		ChannelSet_S       : std_logic;
		PrePostKillDelay_D : unsigned(AER_KILL_DELAY_COUNTER_WIDTH - 1 downto 0);
		NeuronKill02_S     : std_logic;
		NeuronKill13_S     : std_logic;
	end record tCochleaTow4EarChannelConfig;

	constant tCochleaTow4EarChannelConfigDefault : tCochleaTow4EarChannelConfig := (
		ChannelAddress_D   => (others => '0'),
		ChannelDataWrite_D => (others => '0'),
		ChannelSet_S       => '0',
		PrePostKillDelay_D => to_unsigned(2000, tCochleaTow4EarChannelConfig.PrePostKillDelay_D'length),
		NeuronKill02_S     => '0',
		NeuronKill13_S     => '0');
		
end package CochleaTow4EarChipBiasConfigRecords;
