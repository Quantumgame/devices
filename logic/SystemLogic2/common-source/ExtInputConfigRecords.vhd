library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.Settings.LOGIC_CLOCK_FREQ;
use work.Settings.LOGIC_CLOCK_FREQ_REAL;

package ExtInputConfigRecords is
	constant EXTINPUTCONFIG_MODULE_ADDRESS : unsigned(6 downto 0) := to_unsigned(4, 7);

	-- Pulse lengths are in cycles at logic clock frequency. Since we want to support up to 1Hz signals,
	-- we need this value to go up to 10 million (20 bits) in microseconds.
	constant LOGIC_CLOCK_FREQ_SIZE : integer := integer(ceil(log2(real(LOGIC_CLOCK_FREQ_REAL + 1.0))));

	constant EXTINPUT_MAX_TIME_SIZE : integer := 20 + LOGIC_CLOCK_FREQ_SIZE;

	type tExtInputConfigParamAddresses is record
		RunDetector_S                 : unsigned(7 downto 0);
		DetectRisingEdges_S           : unsigned(7 downto 0);
		DetectFallingEdges_S          : unsigned(7 downto 0);
		DetectPulses_S                : unsigned(7 downto 0);
		DetectPulsePolarity_S         : unsigned(7 downto 0);
		DetectPulseLength_D           : unsigned(7 downto 0);
		HasGenerator_S                : unsigned(7 downto 0);
		RunGenerator_S                : unsigned(7 downto 0);
		GenerateUseCustomSignal_S     : unsigned(7 downto 0);
		GeneratePulsePolarity_S       : unsigned(7 downto 0);
		GeneratePulseInterval_D       : unsigned(7 downto 0);
		GeneratePulseLength_D         : unsigned(7 downto 0);
		GenerateInjectOnRisingEdge_S  : unsigned(7 downto 0);
		GenerateInjectOnFallingEdge_S : unsigned(7 downto 0);
		HasExtraDetectors_S           : unsigned(7 downto 0);
		RunDetector1_S                : unsigned(7 downto 0);
		DetectRisingEdges1_S          : unsigned(7 downto 0);
		DetectFallingEdges1_S         : unsigned(7 downto 0);
		DetectPulses1_S               : unsigned(7 downto 0);
		DetectPulsePolarity1_S        : unsigned(7 downto 0);
		DetectPulseLength1_D          : unsigned(7 downto 0);
		RunDetector2_S                : unsigned(7 downto 0);
		DetectRisingEdges2_S          : unsigned(7 downto 0);
		DetectFallingEdges2_S         : unsigned(7 downto 0);
		DetectPulses2_S               : unsigned(7 downto 0);
		DetectPulsePolarity2_S        : unsigned(7 downto 0);
		DetectPulseLength2_D          : unsigned(7 downto 0);
	end record tExtInputConfigParamAddresses;

	constant EXTINPUTCONFIG_PARAM_ADDRESSES : tExtInputConfigParamAddresses := (
		RunDetector_S                 => to_unsigned(0, 8),
		DetectRisingEdges_S           => to_unsigned(1, 8),
		DetectFallingEdges_S          => to_unsigned(2, 8),
		DetectPulses_S                => to_unsigned(3, 8),
		DetectPulsePolarity_S         => to_unsigned(4, 8),
		DetectPulseLength_D           => to_unsigned(5, 8),
		HasGenerator_S                => to_unsigned(6, 8),
		RunGenerator_S                => to_unsigned(7, 8),
		GenerateUseCustomSignal_S     => to_unsigned(8, 8),
		GeneratePulsePolarity_S       => to_unsigned(9, 8),
		GeneratePulseInterval_D       => to_unsigned(10, 8),
		GeneratePulseLength_D         => to_unsigned(11, 8),
		GenerateInjectOnRisingEdge_S  => to_unsigned(12, 8),
		GenerateInjectOnFallingEdge_S => to_unsigned(13, 8),
		HasExtraDetectors_S           => to_unsigned(14, 8),
		RunDetector1_S                => to_unsigned(15, 8),
		DetectRisingEdges1_S          => to_unsigned(16, 8),
		DetectFallingEdges1_S         => to_unsigned(17, 8),
		DetectPulses1_S               => to_unsigned(18, 8),
		DetectPulsePolarity1_S        => to_unsigned(19, 8),
		DetectPulseLength1_D          => to_unsigned(20, 8),
		RunDetector2_S                => to_unsigned(21, 8),
		DetectRisingEdges2_S          => to_unsigned(22, 8),
		DetectFallingEdges2_S         => to_unsigned(23, 8),
		DetectPulses2_S               => to_unsigned(24, 8),
		DetectPulsePolarity2_S        => to_unsigned(25, 8),
		DetectPulseLength2_D          => to_unsigned(26, 8));

	type tExtInputConfig is record
		RunDetector_S                 : std_logic;
		DetectRisingEdges_S           : std_logic;
		DetectFallingEdges_S          : std_logic;
		DetectPulses_S                : std_logic;
		DetectPulsePolarity_S         : std_logic;
		DetectPulseLength_D           : unsigned(EXTINPUT_MAX_TIME_SIZE - 1 downto 0);
		HasGenerator_S                : std_logic;
		RunGenerator_S                : std_logic;
		GenerateUseCustomSignal_S     : std_logic;
		GeneratePulsePolarity_S       : std_logic;
		GeneratePulseInterval_D       : unsigned(EXTINPUT_MAX_TIME_SIZE - 1 downto 0);
		GeneratePulseLength_D         : unsigned(EXTINPUT_MAX_TIME_SIZE - 1 downto 0);
		GenerateInjectOnRisingEdge_S  : std_logic;
		GenerateInjectOnFallingEdge_S : std_logic;
		HasExtraDetectors_S           : std_logic;
		RunDetector1_S                : std_logic;
		DetectRisingEdges1_S          : std_logic;
		DetectFallingEdges1_S         : std_logic;
		DetectPulses1_S               : std_logic;
		DetectPulsePolarity1_S        : std_logic;
		DetectPulseLength1_D          : unsigned(EXTINPUT_MAX_TIME_SIZE - 1 downto 0);
		RunDetector2_S                : std_logic;
		DetectRisingEdges2_S          : std_logic;
		DetectFallingEdges2_S         : std_logic;
		DetectPulses2_S               : std_logic;
		DetectPulsePolarity2_S        : std_logic;
		DetectPulseLength2_D          : unsigned(EXTINPUT_MAX_TIME_SIZE - 1 downto 0);
	end record tExtInputConfig;

	constant tExtInputConfigDefault : tExtInputConfig := (
		RunDetector_S                 => '0',
		DetectRisingEdges_S           => '0',
		DetectFallingEdges_S          => '0',
		DetectPulses_S                => '1',
		DetectPulsePolarity_S         => '1',
		DetectPulseLength_D           => to_unsigned(LOGIC_CLOCK_FREQ, EXTINPUT_MAX_TIME_SIZE),
		RunGenerator_S                => '0',
		HasGenerator_S                => '0',
		GenerateUseCustomSignal_S     => '0',
		GeneratePulsePolarity_S       => '1',
		GeneratePulseInterval_D       => to_unsigned(LOGIC_CLOCK_FREQ, EXTINPUT_MAX_TIME_SIZE),
		GeneratePulseLength_D         => to_unsigned(LOGIC_CLOCK_FREQ / 2, EXTINPUT_MAX_TIME_SIZE),
		GenerateInjectOnRisingEdge_S  => '0',
		GenerateInjectOnFallingEdge_S => '0',
		HasExtraDetectors_S           => '0',
		RunDetector1_S                => '0',
		DetectRisingEdges1_S          => '0',
		DetectFallingEdges1_S         => '0',
		DetectPulses1_S               => '1',
		DetectPulsePolarity1_S        => '1',
		DetectPulseLength1_D          => to_unsigned(LOGIC_CLOCK_FREQ, EXTINPUT_MAX_TIME_SIZE),
		RunDetector2_S                => '0',
		DetectRisingEdges2_S          => '0',
		DetectFallingEdges2_S         => '0',
		DetectPulses2_S               => '1',
		DetectPulsePolarity2_S        => '1',
		DetectPulseLength2_D          => to_unsigned(LOGIC_CLOCK_FREQ, EXTINPUT_MAX_TIME_SIZE));
end package ExtInputConfigRecords;
