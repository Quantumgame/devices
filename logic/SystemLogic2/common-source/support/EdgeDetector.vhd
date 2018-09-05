library ieee;
use ieee.std_logic_1164.all;

-- Detect rising and falling edges on a signal.
-- Please note that if SIGNAL_INITIAL_POLARITY and the actual
-- InputSignal_SI are different at reset, there will be a
-- one cycle glitch (false edge detection).
entity EdgeDetector is
	generic(
		SIGNAL_INITIAL_POLARITY : std_logic := '0');
	port(
		Clock_CI               : in  std_logic;
		Reset_RI               : in  std_logic;
		InputSignal_SI         : in  std_logic;
		-- Pulse will follow one cycle after the edge has been detected.
		RisingEdgeDetected_SO  : out std_logic;
		FallingEdgeDetected_SO : out std_logic);
end EdgeDetector;

architecture Behavioral of EdgeDetector is
	signal RisingEdgeDetectedReg_S  : std_logic;
	signal FallingEdgeDetectedReg_S : std_logic;

	signal InputSignalPrevReg_S : std_logic;
begin
	RisingEdgeDetectedReg_S <= '1' when (InputSignal_SI = '1' and InputSignalPrevReg_S = '0') else '0';

	FallingEdgeDetectedReg_S <= '1' when (InputSignal_SI = '0' and InputSignalPrevReg_S = '1') else '0';

	-- Change state on clock edge (synchronous).
	registerUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			InputSignalPrevReg_S <= SIGNAL_INITIAL_POLARITY;

			RisingEdgeDetected_SO  <= '0';
			FallingEdgeDetected_SO <= '0';
		elsif rising_edge(Clock_CI) then
			InputSignalPrevReg_S <= InputSignal_SI;

			RisingEdgeDetected_SO  <= RisingEdgeDetectedReg_S;
			FallingEdgeDetected_SO <= FallingEdgeDetectedReg_S;
		end if;
	end process registerUpdate;
end Behavioral;
