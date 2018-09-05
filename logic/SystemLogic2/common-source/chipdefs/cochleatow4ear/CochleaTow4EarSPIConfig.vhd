library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.ChipBiasConfigRecords.all;
use work.CochleaTow4EarChipBiasConfigRecords.all;

entity CochleaTow4EarSPIConfig is
	port(
		Clock_CI                    : in  std_logic;
		Reset_RI                    : in  std_logic;
		BiasConfig_DO               : out tCochleaTow4EarBiasConfig;
		ChipConfig_DO               : out tCochleaTow4EarChipConfig;
		ChannelConfig_DO            : out tCochleaTow4EarChannelConfig;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI      : in  unsigned(6 downto 0);
		ConfigParamAddress_DI       : in  unsigned(7 downto 0);
		ConfigParamInput_DI         : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI         : in  std_logic;
		BiasConfigParamOutput_DO    : out std_logic_vector(31 downto 0);
		ChipConfigParamOutput_DO    : out std_logic_vector(31 downto 0);
		ChannelConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity CochleaTow4EarSPIConfig;

architecture Behavioral of CochleaTow4EarSPIConfig is
	signal ChannelConfigStorage_DP, ChannelConfigStorage_DN : std_logic_vector(CHIP_CHAN_REG_USED_SIZE - 1 downto 0);

	signal ChannelConfigStorageAddress_D     : unsigned(CHIP_CHANADDR_REG_USED_SIZE - 1 downto 0);
	signal ChannelConfigStorageWriteEnable_S : std_logic;

	signal LatchBiasReg_S                     : std_logic;
	signal BiasInput_DP, BiasInput_DN         : std_logic_vector(31 downto 0);
	signal BiasOutput_DP, BiasOutput_DN       : std_logic_vector(31 downto 0);
	signal BiasConfigReg_DP, BiasConfigReg_DN : tCochleaTow4EarBiasConfig;

	signal LatchChipReg_S                     : std_logic;
	signal ChipInput_DP, ChipInput_DN         : std_logic_vector(31 downto 0);
	signal ChipOutput_DP, ChipOutput_DN       : std_logic_vector(31 downto 0);
	signal ChipConfigReg_DP, ChipConfigReg_DN : tCochleaTow4EarChipConfig;

	signal LatchChannelReg_S                        : std_logic;
	signal ChannelInput_DP, ChannelInput_DN         : std_logic_vector(31 downto 0);
	signal ChannelOutput_DP, ChannelOutput_DN       : std_logic_vector(31 downto 0);
	signal ChannelConfigReg_DP, ChannelConfigReg_DN : tCochleaTow4EarChannelConfig;

begin
	BiasConfig_DO            <= BiasConfigReg_DP;
	BiasConfigParamOutput_DO <= BiasOutput_DP;

	ChipConfig_DO            <= ChipConfigReg_DP;
	ChipConfigParamOutput_DO <= ChipOutput_DP;

	ChannelConfig_DO            <= ChannelConfigReg_DP;
	ChannelConfigParamOutput_DO <= ChannelOutput_DP;

	LatchBiasReg_S    <= '1' when (ConfigModuleAddress_DI = CHIPBIASCONFIG_MODULE_ADDRESS and ConfigParamAddress_DI(7) = '0') else '0';
	-- Cochlea Chip Config starts from addresses 128
	LatchChipReg_S    <= '1' when (ConfigModuleAddress_DI = CHIPBIASCONFIG_MODULE_ADDRESS and ConfigParamAddress_DI(7 downto 5) = "100") else '0';
	-- Cochlea Channel Config starts from addresses 160
	LatchChannelReg_S <= '1' when (ConfigModuleAddress_DI = CHIPBIASCONFIG_MODULE_ADDRESS and ConfigParamAddress_DI(7 downto 5) = "101") else '0';

	channelConfigStorage : entity work.BlockRAM
		generic map(
			ADDRESS_DEPTH => CHIP_CHAN_NUMBER,
			ADDRESS_WIDTH => CHIP_CHANADDR_REG_USED_SIZE,
			DATA_WIDTH    => CHIP_CHAN_REG_USED_SIZE)
		port map(
			Clock_CI       => Clock_CI,
			Reset_RI       => Reset_RI,
			Address_DI     => ChannelConfigStorageAddress_D,
			Enable_SI      => '1',
			WriteEnable_SI => ChannelConfigStorageWriteEnable_S,
			Data_DI        => ChannelConfigStorage_DN,
			Data_DO        => ChannelConfigStorage_DP);

	ChannelConfigStorageAddress_D     <= ChannelConfigReg_DP.ChannelAddress_D;
	ChannelConfigStorageWriteEnable_S <= '1' when (LatchChannelReg_S = '1' and ConfigLatchInput_SI = '1' and ConfigParamAddress_DI = COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelSet_S) else '0';
	ChannelConfigStorage_DN           <= ChannelConfigReg_DP.ChannelDataWrite_D;

	biasIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, BiasInput_DP, BiasConfigReg_DP)
	begin
		BiasConfigReg_DN <= BiasConfigReg_DP;
		BiasInput_DN     <= ConfigParamInput_DI;
		BiasOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VrefpreampBp_D =>
				BiasConfigReg_DN.VrefpreampBp_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VrefpreampBp_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VrefpreampBp_D'range) <= BiasConfigReg_DP.VrefpreampBp_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Vth1_D =>
				BiasConfigReg_DN.Vth1_D                              <= BiasInput_DP(tCochleaTow4EarBiasConfig.Vth1_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Vth1_D'range) <= BiasConfigReg_DP.Vth1_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Vth2_D =>
				BiasConfigReg_DN.Vth2_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Vth2_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Vth2_D'range) <= BiasConfigReg_DP.Vth2_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VbMicCasBpc_D =>
				BiasConfigReg_DN.VbMicCasBpc_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VbMicCasBpc_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VbMicCasBpc_D'range) <= BiasConfigReg_DP.VbMicCasBpc_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VbiasHF2Bn_D =>
				BiasConfigReg_DN.VbiasHF2Bn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VbiasHF2Bn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VbiasHF2Bn_D'range) <= BiasConfigReg_DP.VbiasHF2Bn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Vbias2n_D =>
				BiasConfigReg_DN.Vbias2n_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Vbias2n_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Vbias2n_D'range) <= BiasConfigReg_DP.Vbias2n_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Vrefdiff_D =>
				BiasConfigReg_DN.Vrefdiff_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Vrefdiff_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Vrefdiff_D'range) <= BiasConfigReg_DP.Vrefdiff_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Vrefdiff2_D =>
				BiasConfigReg_DN.Vrefdiff2_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Vrefdiff2_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Vrefdiff2_D'range) <= BiasConfigReg_DP.Vrefdiff2_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.LocalBufBn_D =>
				BiasConfigReg_DN.LocalBufBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.LocalBufBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.LocalBufBn_D'range) <= BiasConfigReg_DP.LocalBufBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VtauBn_D =>
				BiasConfigReg_DN.VtauBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VtauBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VtauBn_D'range) <= BiasConfigReg_DP.VtauBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Vbias1Bn_D =>
				BiasConfigReg_DN.Vbias1Bn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Vbias1Bn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Vbias1Bn_D'range) <= BiasConfigReg_DP.Vbias1Bn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VrefractBnc4_D =>
				BiasConfigReg_DN.VrefractBnc4_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VrefractBnc4_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VrefractBnc4_D'range) <= BiasConfigReg_DP.VrefractBnc4_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VrefractBnc1_D =>
				BiasConfigReg_DN.VrefractBnc1_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VrefractBnc1_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VrefractBnc1_D'range) <= BiasConfigReg_DP.VrefractBnc1_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.PixInvBn_D =>
				BiasConfigReg_DN.PixInvBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.PixInvBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.PixInvBn_D'range) <= BiasConfigReg_DP.PixInvBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VBPScan_D =>
				BiasConfigReg_DN.VBPScan_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VBPScan_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VBPScan_D'range) <= BiasConfigReg_DP.VBPScan_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VbBp1_D =>
				BiasConfigReg_DN.VbBp1_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VbBp1_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VbBp1_D'range) <= BiasConfigReg_DP.VbBp1_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VbBp2_D =>
				BiasConfigReg_DN.VbBp2_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VbBp2_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VbBp2_D'range) <= BiasConfigReg_DP.VbBp2_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VneuronLeakExtBp_D =>
				BiasConfigReg_DN.VneuronLeakExtBp_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VneuronLeakExtBp_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VneuronLeakExtBp_D'range) <= BiasConfigReg_DP.VneuronLeakExtBp_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VpulseAERExtdBn_D =>
				BiasConfigReg_DN.VpulseAERExtdBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VpulseAERExtdBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VpulseAERExtdBn_D'range) <= BiasConfigReg_DP.VpulseAERExtdBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VwideampBp_D =>
				BiasConfigReg_DN.VwideampBp_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VwideampBp_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VwideampBp_D'range) <= BiasConfigReg_DP.VwideampBp_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VQBn_D =>
				BiasConfigReg_DN.VQBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VQBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VQBn_D'range) <= BiasConfigReg_DP.VQBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VcascodeBpc_D =>
				BiasConfigReg_DN.VcascodeBpc_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VcascodeBpc_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VcascodeBpc_D'range) <= BiasConfigReg_DP.VcascodeBpc_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.LcolTimeoutBn_D =>
				BiasConfigReg_DN.LcolTimeoutBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.LcolTimeoutBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.LcolTimeoutBn_D'range) <= BiasConfigReg_DP.LcolTimeoutBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.AEPdBn_D =>
				BiasConfigReg_DN.AEPdBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.AEPdBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.AEPdBn_D'range) <= BiasConfigReg_DP.AEPdBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.AEPuXBp_D =>
				BiasConfigReg_DN.AEPuXBp_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.AEPuXBp_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.AEPuXBp_D'range) <= BiasConfigReg_DP.AEPuXBp_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.AEPuYBp_D =>
				BiasConfigReg_DN.AEPuYBp_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.AEPuYBp_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.AEPuYBp_D'range) <= BiasConfigReg_DP.AEPuYBp_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VbiasLF1Bn_D =>
				BiasConfigReg_DN.VbiasLF1Bn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VbiasLF1Bn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VbiasLF1Bn_D'range) <= BiasConfigReg_DP.VbiasLF1Bn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VclbtcasBnc_D =>
				BiasConfigReg_DN.VclbtcasBnc_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VclbtcasBnc_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VclbtcasBnc_D'range) <= BiasConfigReg_DP.VclbtcasBnc_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Ibias20pOTA_D =>
				BiasConfigReg_DN.Ibias20pOTA_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Ibias20pOTA_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Ibias20pOTA_D'range) <= BiasConfigReg_DP.Ibias20pOTA_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Ibias40pOTA_D =>
				BiasConfigReg_DN.Ibias40pOTA_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Ibias40pOTA_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Ibias40pOTA_D'range) <= BiasConfigReg_DP.Ibias40pOTA_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Ibias1nOTA_D =>
				BiasConfigReg_DN.Ibias1nOTA_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Ibias1nOTA_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Ibias1nOTA_D'range) <= BiasConfigReg_DP.Ibias1nOTA_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Blk2N_D =>
				BiasConfigReg_DN.Blk2N_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Blk2N_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Blk2N_D'range) <= BiasConfigReg_DP.Blk2N_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.Blk3N_D =>
				BiasConfigReg_DN.Blk3N_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.Blk3N_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.Blk3N_D'range) <= BiasConfigReg_DP.Blk3N_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.VthAGCBn_D =>
				BiasConfigReg_DN.VthAGCBn_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.VthAGCBn_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.VthAGCBn_D'range) <= BiasConfigReg_DP.VthAGCBn_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.BiasBuffer_D =>
				BiasConfigReg_DN.BiasBuffer_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.BiasBuffer_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.BiasBuffer_D'range) <= BiasConfigReg_DP.BiasBuffer_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.SSP_D =>
				BiasConfigReg_DN.SSP_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.SSP_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.SSP_D'range) <= BiasConfigReg_DP.SSP_D;

			when COCHLEATOW4EAR_BIASCONFIG_PARAM_ADDRESSES.SSN_D =>
				BiasConfigReg_DN.SSN_D                               <= BiasInput_DP(tCochleaTow4EarBiasConfig.SSN_D'range);
				BiasOutput_DN(tCochleaTow4EarBiasConfig.SSN_D'range) <= BiasConfigReg_DP.SSN_D;

			when others => null;
		end case;
	end process biasIO;

	biasUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			BiasInput_DP  <= (others => '0');
			BiasOutput_DP <= (others => '0');

			BiasConfigReg_DP <= tCochleaTow4EarBiasConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			BiasInput_DP  <= BiasInput_DN;
			BiasOutput_DP <= BiasOutput_DN;

			if LatchBiasReg_S = '1' and ConfigLatchInput_SI = '1' then
				BiasConfigReg_DP <= BiasConfigReg_DN;
			end if;
		end if;
	end process biasUpdate;

	chipIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, ChipInput_DP, ChipConfigReg_DP)
	begin
		ChipConfigReg_DN <= ChipConfigReg_DP;
		ChipInput_DN     <= ConfigParamInput_DI;
		ChipOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.AnalogMux0_D =>
				ChipConfigReg_DN.AnalogMux0_D                               <= unsigned(ChipInput_DP(tCochleaTow4EarChipConfig.AnalogMux0_D'range));
				ChipOutput_DN(tCochleaTow4EarChipConfig.AnalogMux0_D'range) <= std_logic_vector(ChipConfigReg_DP.AnalogMux0_D);

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.PreampGain_D =>
				ChipConfigReg_DN.PreampGain_D                               <= unsigned(ChipInput_DP(tCochleaTow4EarChipConfig.PreampGain_D'range));
				ChipOutput_DN(tCochleaTow4EarChipConfig.PreampGain_D'range) <= std_logic_vector(ChipConfigReg_DP.PreampGain_D);

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.Seln1_S =>
				ChipConfigReg_DN.Seln1_S <= ChipInput_DP(0);
				ChipOutput_DN(0)         <= ChipConfigReg_DP.Seln1_S;

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.Seln2_S =>
				ChipConfigReg_DN.Seln2_S <= ChipInput_DP(0);
				ChipOutput_DN(0)         <= ChipConfigReg_DP.Seln2_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.SMconfigArow_S =>
				ChipConfigReg_DN.SMconfigArow_S <= ChipInput_DP(0);
				ChipOutput_DN(0)                <= ChipConfigReg_DP.SMconfigArow_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC5_S =>
				ChipConfigReg_DN.DC5_S <= ChipInput_DP(0);
				ChipOutput_DN(0)       <= ChipConfigReg_DP.DC5_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.SelBot_S =>
				ChipConfigReg_DN.SelBot_S <= ChipInput_DP(0);
				ChipOutput_DN(0)       <= ChipConfigReg_DP.SelBot_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.SelTop_S =>
				ChipConfigReg_DN.SelTop_S <= ChipInput_DP(0);
				ChipOutput_DN(0)       <= ChipConfigReg_DP.SelTop_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC8_S =>
				ChipConfigReg_DN.DC8_S <= ChipInput_DP(0);
				ChipOutput_DN(0)       <= ChipConfigReg_DP.DC8_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC9_S =>
				ChipConfigReg_DN.DC9_S <= ChipInput_DP(0);
				ChipOutput_DN(0)       <= ChipConfigReg_DP.DC9_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC10_S =>
				ChipConfigReg_DN.DC10_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC10_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC11_S =>
				ChipConfigReg_DN.DC11_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC11_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC12_S =>
				ChipConfigReg_DN.DC12_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC12_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC13_S =>
				ChipConfigReg_DN.DC13_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC13_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC14_S =>
				ChipConfigReg_DN.DC14_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC14_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC15_S =>
				ChipConfigReg_DN.DC15_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC15_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC16_S =>
				ChipConfigReg_DN.DC16_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC16_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC17_S =>
				ChipConfigReg_DN.DC17_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC17_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC18_S =>
				ChipConfigReg_DN.DC18_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC18_S;
								
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.BitTestLatch_S =>
				ChipConfigReg_DN.BitTestLatch_S <= ChipInput_DP(0);
				ChipOutput_DN(0)                <= ChipConfigReg_DP.BitTestLatch_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC20_S =>
				ChipConfigReg_DN.DC20_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC20_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC21_S =>
				ChipConfigReg_DN.DC21_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC21_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC22_S =>
				ChipConfigReg_DN.DC22_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC22_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DC23_S =>
				ChipConfigReg_DN.DC23_S <= ChipInput_DP(0);
				ChipOutput_DN(0)        <= ChipConfigReg_DP.DC23_S;
				
			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DigitalMux0_D =>
				ChipConfigReg_DN.DigitalMux0_D                         <= unsigned(ChipInput_DP(tCochleaTow4EarChipConfig.DigitalMux0_D'range));
				ChipOutput_DN(tCochleaTow4EarChipConfig.DigitalMux0_D'range) <= std_logic_vector(ChipConfigReg_DP.DigitalMux0_D);

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DigitalMux1_D =>
				ChipConfigReg_DN.DigitalMux1_D                         <= unsigned(ChipInput_DP(tCochleaTow4EarChipConfig.DigitalMux1_D'range));
				ChipOutput_DN(tCochleaTow4EarChipConfig.DigitalMux1_D'range) <= std_logic_vector(ChipConfigReg_DP.DigitalMux1_D);

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DigitalMux2_D =>
				ChipConfigReg_DN.DigitalMux2_D                         <= unsigned(ChipInput_DP(tCochleaTow4EarChipConfig.DigitalMux2_D'range));
				ChipOutput_DN(tCochleaTow4EarChipConfig.DigitalMux2_D'range) <= std_logic_vector(ChipConfigReg_DP.DigitalMux2_D);

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.DigitalMux3_D =>
				ChipConfigReg_DN.DigitalMux3_D                         <= unsigned(ChipInput_DP(tCochleaTow4EarChipConfig.DigitalMux3_D'range));
				ChipOutput_DN(tCochleaTow4EarChipConfig.DigitalMux3_D'range) <= std_logic_vector(ChipConfigReg_DP.DigitalMux3_D);

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.SelResSw_S =>
				ChipConfigReg_DN.SelResSw_S <= ChipInput_DP(0);
				ChipOutput_DN(0)            <= ChipConfigReg_DP.SelResSw_S;

			when COCHLEATOW4EAR_CHIPCONFIG_PARAM_ADDRESSES.VresetBn_S =>
				ChipConfigReg_DN.VresetBn_S <= ChipInput_DP(0);
				ChipOutput_DN(0)            <= ChipConfigReg_DP.VresetBn_S;

			when others => null;
		end case;
	end process chipIO;

	chipUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			ChipInput_DP  <= (others => '0');
			ChipOutput_DP <= (others => '0');

			ChipConfigReg_DP <= tCochleaTow4EarChipConfigDefault;

		elsif rising_edge(Clock_CI) then -- rising clock edge
			ChipInput_DP  <= ChipInput_DN;
			ChipOutput_DP <= ChipOutput_DN;

			if LatchChipReg_S = '1' and ConfigLatchInput_SI = '1' then
				ChipConfigReg_DP <= ChipConfigReg_DN;
			end if;
		end if;
	end process chipUpdate;

	channelIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, ChannelInput_DP, ChannelConfigReg_DP, ChannelConfigStorage_DP)
	begin
		ChannelConfigReg_DN <= ChannelConfigReg_DP;
		ChannelInput_DN     <= ConfigParamInput_DI;
		ChannelOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelAddress_D =>
				ChannelConfigReg_DN.ChannelAddress_D                                  <= unsigned(ChannelInput_DP(tCochleaTow4EarChannelConfig.ChannelAddress_D'range));
				ChannelOutput_DN(tCochleaTow4EarChannelConfig.ChannelAddress_D'range) <= std_logic_vector(ChannelConfigReg_DP.ChannelAddress_D);

			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelDataRead_D =>
				ChannelOutput_DN(CHIP_CHAN_REG_USED_SIZE - 1 downto 0) <= ChannelConfigStorage_DP;

			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelDataWrite_D =>
				ChannelConfigReg_DN.ChannelDataWrite_D                                  <= ChannelInput_DP(tCochleaTow4EarChannelConfig.ChannelDataWrite_D'range);
				ChannelOutput_DN(tCochleaTow4EarChannelConfig.ChannelDataWrite_D'range) <= ChannelConfigReg_DP.ChannelDataWrite_D;

			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelSet_S =>
				ChannelConfigReg_DN.ChannelSet_S <= ChannelInput_DP(0);
				ChannelOutput_DN(0)              <= ChannelConfigReg_DP.ChannelSet_S;

			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.PrePostKillDelay_D =>
				ChannelConfigReg_DN.PrePostKillDelay_D                                  <= unsigned(ChannelInput_DP(tCochleaTow4EarChannelConfig.PrePostKillDelay_D'range));
				ChannelOutput_DN(tCochleaTow4EarChannelConfig.PrePostKillDelay_D'range) <= std_logic_vector(ChannelConfigReg_DP.PrePostKillDelay_D);

			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelKill02_S =>
				ChannelConfigReg_DN.NeuronKill02_S <= ChannelInput_DP(0);
				ChannelOutput_DN(0)                 <= ChannelConfigReg_DP.NeuronKill02_S;
			
			when COCHLEATOW4EAR_CHANNELCONFIG_PARAM_ADDRESSES.ChannelKill13_S =>
				ChannelConfigReg_DN.NeuronKill13_S <= ChannelInput_DP(0);
				ChannelOutput_DN(0)                 <= ChannelConfigReg_DP.NeuronKill13_S;

			when others => null;
		end case;
	end process channelIO;

	channelUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			ChannelInput_DP  <= (others => '0');
			ChannelOutput_DP <= (others => '0');

			ChannelConfigReg_DP <= tCochleaTow4EarChannelConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			ChannelInput_DP  <= ChannelInput_DN;
			ChannelOutput_DP <= ChannelOutput_DN;

			if LatchChannelReg_S = '1' and ConfigLatchInput_SI = '1' then
				ChannelConfigReg_DP <= ChannelConfigReg_DN;
			end if;
		end if;
	end process channelUpdate;
end architecture Behavioral;
