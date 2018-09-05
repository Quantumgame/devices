library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package EventCodes is
	constant FULL_EVENT_WIDTH     : integer := 16;
	constant TIMESTAMP_WIDTH      : integer := 15;
	constant EVENT_WIDTH          : integer := 15;
	constant EVENT_DATA_WIDTH_MAX : integer := 12;
	constant OVERFLOW_WIDTH       : integer := EVENT_DATA_WIDTH_MAX;

	-- event codes
	constant EVENT_CODE_TIMESTAMP : std_logic := '1';
	constant EVENT_CODE_EVENT     : std_logic := '0';

	constant EVENT_CODE_SPECIAL                         : std_logic_vector(2 downto 0)                            := "000";
	constant EVENT_CODE_SPECIAL_TIMESTAMP_RESET         : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(1, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT_FALLING       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(2, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT_RISING        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(3, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT_PULSE         : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(4, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_IMU_START6              : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(5, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_IMU_START9              : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(6, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_IMU_END                 : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(7, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_STARTFRAME_GS       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(8, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_STARTFRAME_RS       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(9, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_ENDFRAME            : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(10, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_STARTRESETCOL       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(11, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_STARTSIGNALCOL      : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(12, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_ENDCOL              : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(13, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_STARTFRAME_GS_NORST : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(14, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_STARTFRAME_RS_NORST : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0)     := std_logic_vector(to_unsigned(15, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_IMU_SCALE_CONFIG        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 4 - 1 downto 0) := std_logic_vector(to_unsigned(1, EVENT_DATA_WIDTH_MAX - 4));
	-- IMU Scale Config uses addresses from 16 to 31, by adding four bits to the end of it.
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI0_ON        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(32, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI1_ON        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(33, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI2_ON        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(34, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI3_ON        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(35, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT1_FALLING      : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(36, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT1_RISING       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(37, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT1_PULSE        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(38, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT2_FALLING      : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(39, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT2_RISING       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(40, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUT2_PULSE        : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(41, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUTGEN_FALLING    : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(42, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_EXT_INPUTGEN_RISING     : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(43, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_ADC_START_CNV           : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(44, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_ADC_START_CNV_1US       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(45, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_ADC_RESERVED            : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(46, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_STEADICAM_RESERVED      : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(47, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_EXPOSURE       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(48, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI0_OFF       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(49, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI1_OFF       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(50, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI2_OFF       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(51, EVENT_DATA_WIDTH_MAX));
	constant EVENT_CODE_SPECIAL_APS_INFO_ROI3_OFF       : std_logic_vector(EVENT_DATA_WIDTH_MAX - 1 downto 0) := std_logic_vector(to_unsigned(52, EVENT_DATA_WIDTH_MAX));
	
	constant EVENT_CODE_Y_ADDR : std_logic_vector(2 downto 0) := "001";

	-- The fourth bit of an X address is the polarity. It usually gets encoded directly from the AER bus input.
	constant EVENT_CODE_X_ADDR         : std_logic_vector(1 downto 0) := "01";
	constant EVENT_CODE_X_ADDR_POL_OFF : std_logic_vector(2 downto 0) := "010";
	constant EVENT_CODE_X_ADDR_POL_ON  : std_logic_vector(2 downto 0) := "011";

	constant EVENT_CODE_ADC_SAMPLE : std_logic_vector(2 downto 0) := "100";

	constant EVENT_CODE_MISC_DATA8                 : std_logic_vector(2 downto 0) := "101";
	constant EVENT_CODE_MISC_DATA8_IMU             : std_logic_vector(3 downto 0) := "0000";
	constant EVENT_CODE_MISC_DATA8_APS_ROISIZE_0   : std_logic_vector(3 downto 0) := "0001";
	constant EVENT_CODE_MISC_DATA8_APS_ROISIZE_1   : std_logic_vector(3 downto 0) := "0010";
	constant EVENT_CODE_MISC_DATA8_APS_ADC_DEPTH   : std_logic_vector(3 downto 0) := "0011";
	constant EVENT_CODE_MISC_DATA8_MIC_FIRST_RIGHT : std_logic_vector(3 downto 0) := "0100";
	constant EVENT_CODE_MISC_DATA8_MIC_FIRST_LEFT  : std_logic_vector(3 downto 0) := "0101";
	constant EVENT_CODE_MISC_DATA8_MIC_SECOND      : std_logic_vector(3 downto 0) := "0110";
	constant EVENT_CODE_MISC_DATA8_MIC_THIRD       : std_logic_vector(3 downto 0) := "0111";

	constant EVENT_CODE_MISC_DATA10              : std_logic_vector(2 downto 0) := "110";
	constant EVENT_CODE_MISC_DATA10_APS_EXPOSURE : std_logic_vector(1 downto 0) := "00";

	constant EVENT_CODE_TIMESTAMP_WRAP : std_logic_vector(2 downto 0) := "111";
end package EventCodes;
