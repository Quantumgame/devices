library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ChipBiasConfigRecords is
	constant CHIPBIASCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(5, 7);

	constant BIASADDR_REG_LENGTH : integer := 8;
	constant BIAS_REG_LENGTH     : integer := 16;

	constant BIAS_VD_LENGTH : integer := 9;
	constant BIAS_CF_LENGTH : integer := 15;
	constant BIAS_SS_LENGTH : integer := 16;

	-- Valid for all DAVIS chips. Not for Cochlea or SampleProb.
	constant CHIP_REG_LENGTH_DEFAULT : integer := 56;

	constant CHIP_MUX_LENGTH : integer := 4;

	type tChipBiasGenericConfigParamAddresses is record
		Bias_D      : unsigned(7 downto 0);
		ChipLower_D : unsigned(7 downto 0);
		ChipUpper_D : unsigned(7 downto 0);
	end record tChipBiasGenericConfigParamAddresses;

	constant CHIPBIAS_GENERIC_CONFIG_PARAM_ADDRESSES : tChipBiasGenericConfigParamAddresses := (
		Bias_D      => to_unsigned(0, 8),
		ChipLower_D => to_unsigned(1, 8),
		ChipUpper_D => to_unsigned(2, 8));

	type tChipBiasGenericConfig is record
		Bias_D      : std_logic_vector(BIASADDR_REG_LENGTH + BIAS_REG_LENGTH - 1 downto 0);
		ChipLower_D : std_logic_vector(32 - 1 downto 0);
		ChipUpper_D : std_logic_vector(CHIP_REG_LENGTH_DEFAULT - 32 - 1 downto 0);
	end record tChipBiasGenericConfig;

	constant tChipBiasGenericConfigDefault : tChipBiasGenericConfig := (
		Bias_D      => (others => '0'),
		ChipLower_D => (others => '0'),
		ChipUpper_D => (others => '0'));

	function BiasGenerateCoarseFine(CFBIAS : in std_logic_vector(BIAS_CF_LENGTH - 1 downto 0)) return std_logic_vector;

	function BiasGenerateVDAC(VDBIAS : in std_logic_vector(BIAS_VD_LENGTH - 1 downto 0)) return std_logic_vector;
end package ChipBiasConfigRecords;

package body ChipBiasConfigRecords is
	function BiasGenerateCoarseFine(CFBIAS : in std_logic_vector(BIAS_CF_LENGTH - 1 downto 0)) return std_logic_vector is
	begin
		return '0' & not CFBIAS(12) & not CFBIAS(13) & not CFBIAS(14) & CFBIAS(11 downto 0);
	end function BiasGenerateCoarseFine;

	function BiasGenerateVDAC(VDBIAS : in std_logic_vector(BIAS_VD_LENGTH - 1 downto 0)) return std_logic_vector is
	begin
		return '0' & not VDBIAS(6) & not VDBIAS(7) & not VDBIAS(8) & "000000" & VDBIAS(5 downto 0);
	end function BiasGenerateVDAC;
end package body ChipBiasConfigRecords;
