library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.ChipBiasConfigRecords.CHIPBIASCONFIG_MODULE_ADDRESS;
use work.SampleProbChipBiasConfigRecords.all;

entity SampleProbSPIConfig is
	port(
		Clock_CI                 : in  std_logic;
		Reset_RI                 : in  std_logic;
		BiasConfig_DO            : out tSampleProbBiasConfig;
		ChipConfig_DO            : out tSampleProbChipConfig;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI   : in  unsigned(6 downto 0);
		ConfigParamAddress_DI    : in  unsigned(7 downto 0);
		ConfigParamInput_DI      : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI      : in  std_logic;
		BiasConfigParamOutput_DO : out std_logic_vector(31 downto 0);
		ChipConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity SampleProbSPIConfig;

architecture Behavioral of SampleProbSPIConfig is
	signal LatchBiasReg_S                     : std_logic;
	signal BiasInput_DP, BiasInput_DN         : std_logic_vector(31 downto 0);
	signal BiasOutput_DP, BiasOutput_DN       : std_logic_vector(31 downto 0);
	signal BiasConfigReg_DP, BiasConfigReg_DN : tSampleProbBiasConfig;

	signal LatchChipReg_S                     : std_logic;
	signal ChipInput_DP, ChipInput_DN         : std_logic_vector(31 downto 0);
	signal ChipOutput_DP, ChipOutput_DN       : std_logic_vector(31 downto 0);
	signal ChipConfigReg_DP, ChipConfigReg_DN : tSampleProbChipConfig;
begin
	BiasConfig_DO            <= BiasConfigReg_DP;
	BiasConfigParamOutput_DO <= BiasOutput_DP;

	ChipConfig_DO            <= ChipConfigReg_DP;
	ChipConfigParamOutput_DO <= ChipOutput_DP;

	LatchBiasReg_S <= '1' when (ConfigModuleAddress_DI = CHIPBIASCONFIG_MODULE_ADDRESS and ConfigParamAddress_DI(7) = '0') else '0';
	LatchChipReg_S <= '1' when (ConfigModuleAddress_DI = CHIPBIASCONFIG_MODULE_ADDRESS and ConfigParamAddress_DI(7) = '1') else '0';

	biasIO : process(ConfigParamAddress_DI, ConfigParamInput_DI, BiasInput_DP, BiasConfigReg_DP)
	begin
		BiasConfigReg_DN <= BiasConfigReg_DP;
		BiasInput_DN     <= ConfigParamInput_DI;
		BiasOutput_DN    <= (others => '0');

		case ConfigParamAddress_DI is
			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.MasterBias_D =>
				BiasConfigReg_DN.MasterBias_D                           <= BiasInput_DP(tSampleProbBiasConfig.MasterBias_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.MasterBias_D'range) <= BiasConfigReg_DP.MasterBias_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.SelSpikeExtend_D =>
				BiasConfigReg_DN.SelSpikeExtend_D                           <= BiasInput_DP(tSampleProbBiasConfig.SelSpikeExtend_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.SelSpikeExtend_D'range) <= BiasConfigReg_DP.SelSpikeExtend_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.SelHazardIV_D =>
				BiasConfigReg_DN.SelHazardIV_D                           <= BiasInput_DP(tSampleProbBiasConfig.SelHazardIV_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.SelHazardIV_D'range) <= BiasConfigReg_DP.SelHazardIV_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.SelCH_S =>
				BiasConfigReg_DN.SelCH_S <= BiasInput_DP(0);
				BiasOutput_DN(0)         <= BiasConfigReg_DP.SelCH_S;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.SelNS_S =>
				BiasConfigReg_DN.SelNS_S <= BiasInput_DP(0);
				BiasOutput_DN(0)         <= BiasConfigReg_DP.SelNS_S;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias0_D =>
				BiasConfigReg_DN.Bias0_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias0_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias0_D'range) <= BiasConfigReg_DP.Bias0_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias1_D =>
				BiasConfigReg_DN.Bias1_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias1_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias1_D'range) <= BiasConfigReg_DP.Bias1_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias2_D =>
				BiasConfigReg_DN.Bias2_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias2_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias2_D'range) <= BiasConfigReg_DP.Bias2_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias3_D =>
				BiasConfigReg_DN.Bias3_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias3_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias3_D'range) <= BiasConfigReg_DP.Bias3_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias4_D =>
				BiasConfigReg_DN.Bias4_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias4_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias4_D'range) <= BiasConfigReg_DP.Bias4_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias5_D =>
				BiasConfigReg_DN.Bias5_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias5_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias5_D'range) <= BiasConfigReg_DP.Bias5_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias6_D =>
				BiasConfigReg_DN.Bias6_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias6_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias6_D'range) <= BiasConfigReg_DP.Bias6_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias7_D =>
				BiasConfigReg_DN.Bias7_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias7_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias7_D'range) <= BiasConfigReg_DP.Bias7_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias8_D =>
				BiasConfigReg_DN.Bias8_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias8_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias8_D'range) <= BiasConfigReg_DP.Bias8_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias9_D =>
				BiasConfigReg_DN.Bias9_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias9_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias9_D'range) <= BiasConfigReg_DP.Bias9_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias10_D =>
				BiasConfigReg_DN.Bias10_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias10_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias10_D'range) <= BiasConfigReg_DP.Bias10_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias11_D =>
				BiasConfigReg_DN.Bias11_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias11_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias11_D'range) <= BiasConfigReg_DP.Bias11_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias12_D =>
				BiasConfigReg_DN.Bias12_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias12_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias12_D'range) <= BiasConfigReg_DP.Bias12_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias13_D =>
				BiasConfigReg_DN.Bias13_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias13_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias13_D'range) <= BiasConfigReg_DP.Bias13_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias14_D =>
				BiasConfigReg_DN.Bias14_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias14_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias14_D'range) <= BiasConfigReg_DP.Bias14_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias15_D =>
				BiasConfigReg_DN.Bias15_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias15_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias15_D'range) <= BiasConfigReg_DP.Bias15_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias16_D =>
				BiasConfigReg_DN.Bias16_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias16_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias16_D'range) <= BiasConfigReg_DP.Bias16_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias17_D =>
				BiasConfigReg_DN.Bias17_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias17_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias17_D'range) <= BiasConfigReg_DP.Bias17_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias18_D =>
				BiasConfigReg_DN.Bias18_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias18_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias18_D'range) <= BiasConfigReg_DP.Bias18_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias19_D =>
				BiasConfigReg_DN.Bias19_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias19_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias19_D'range) <= BiasConfigReg_DP.Bias19_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias20_D =>
				BiasConfigReg_DN.Bias20_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias20_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias20_D'range) <= BiasConfigReg_DP.Bias20_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias21_D =>
				BiasConfigReg_DN.Bias21_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias21_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias21_D'range) <= BiasConfigReg_DP.Bias21_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.Bias22_D =>
				BiasConfigReg_DN.Bias22_D                           <= BiasInput_DP(tSampleProbBiasConfig.Bias22_D'range);
				BiasOutput_DN(tSampleProbBiasConfig.Bias22_D'range) <= BiasConfigReg_DP.Bias22_D;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.ClockPulseEnable_S =>
				BiasConfigReg_DN.ClockPulseEnable_S <= BiasInput_DP(0);
				BiasOutput_DN(0)                    <= BiasConfigReg_DP.ClockPulseEnable_S;

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.ClockPulsePeriod_D =>
				BiasConfigReg_DN.ClockPulsePeriod_D                           <= unsigned(BiasInput_DP(tSampleProbBiasConfig.ClockPulsePeriod_D'range));
				BiasOutput_DN(tSampleProbBiasConfig.ClockPulsePeriod_D'range) <= std_logic_vector(BiasConfigReg_DP.ClockPulsePeriod_D);

			when SAMPLEPROB_BIASCONFIG_PARAM_ADDRESSES.UseLandscapeSamplingVerilog_S =>
				BiasConfigReg_DN.UseLandscapeSamplingVerilog_S <= BiasInput_DP(0);
				BiasOutput_DN(0)                               <= BiasConfigReg_DP.UseLandscapeSamplingVerilog_S;

			when others => null;
		end case;
	end process biasIO;

	biasUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			BiasInput_DP  <= (others => '0');
			BiasOutput_DP <= (others => '0');

			BiasConfigReg_DP <= tSampleProbBiasConfigDefault;
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
			when SAMPLEPROB_CHIPCONFIG_PARAM_ADDRESSES.Channel_D =>
				ChipConfigReg_DN.Channel_D                           <= ChipInput_DP(tSampleProbChipConfig.Channel_D'range);
				ChipOutput_DN(tSampleProbChipConfig.Channel_D'range) <= ChipConfigReg_DP.Channel_D;

			when SAMPLEPROB_CHIPCONFIG_PARAM_ADDRESSES.Address_D =>
				ChipConfigReg_DN.Address_D                           <= unsigned(ChipInput_DP(tSampleProbChipConfig.Address_D'range));
				ChipOutput_DN(tSampleProbChipConfig.Address_D'range) <= std_logic_vector(ChipConfigReg_DP.Address_D);

			when SAMPLEPROB_CHIPCONFIG_PARAM_ADDRESSES.Data_D =>
				ChipConfigReg_DN.Data_D                           <= ChipInput_DP(tSampleProbChipConfig.Data_D'range);
				ChipOutput_DN(tSampleProbChipConfig.Data_D'range) <= ChipConfigReg_DP.Data_D;

			when SAMPLEPROB_CHIPCONFIG_PARAM_ADDRESSES.Set_S =>
				ChipConfigReg_DN.Set_S <= ChipInput_DP(0);
				ChipOutput_DN(0)       <= ChipConfigReg_DP.Set_S;

			when SAMPLEPROB_CHIPCONFIG_PARAM_ADDRESSES.ClearAll_S =>
				ChipConfigReg_DN.ClearAll_S <= ChipInput_DP(0);
				ChipOutput_DN(0)            <= ChipConfigReg_DP.ClearAll_S;

			when others => null;
		end case;
	end process chipIO;

	chipUpdate : process(Clock_CI, Reset_RI) is
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active high)
			ChipInput_DP  <= (others => '0');
			ChipOutput_DP <= (others => '0');

			ChipConfigReg_DP <= tSampleProbChipConfigDefault;
		elsif rising_edge(Clock_CI) then -- rising clock edge
			ChipInput_DP  <= ChipInput_DN;
			ChipOutput_DP <= ChipOutput_DN;

			if LatchChipReg_S = '1' and ConfigLatchInput_SI = '1' then
				ChipConfigReg_DP <= ChipConfigReg_DN;
			end if;
		end if;
	end process chipUpdate;
end architecture Behavioral;
