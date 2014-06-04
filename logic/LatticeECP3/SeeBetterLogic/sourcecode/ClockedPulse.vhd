library IEEE;
use IEEE.MATH_REAL."ceil";
use IEEE.MATH_REAL."log2";
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity ClockedPulse is
	generic (
		PULSE_EVERY_CYCLES : integer := 100);
	port (
		Clock_CI : in std_logic;
		Reset_RI : in std_logic;
		PulseOut_SO : out std_logic);
end ClockedPulse;

architecture Behavioral of ClockedPulse is
	constant COUNTER_WIDTH : integer := integer(ceil(log2(real(PULSE_EVERY_CYCLES))));
	
	-- present and next state
	signal Count_DP, Count_DN : unsigned(COUNTER_WIDTH-1 downto 0);
begin
	-- Variable width counter, calculation of next state
	p_memoryless : process (Count_DP)
	begin -- process p_memoryless
		if Count_DP = PULSE_EVERY_CYCLES then
			Count_DN <= (others => '0');
			PulseOut_SO <= '1';
		else
			Count_DN <= Count_DP + 1;
			PulseOut_SO <= '0';
		end if;
	end process p_memoryless;

	-- Change state on clock edge (synchronous).
	p_memoryzing : process (Clock_CI, Reset_RI)
	begin  -- process p_memoryzing
		if Reset_RI = '1' then -- asynchronous reset (active-high for FPGAs)
			Count_DP <= (others => '0');
		elsif rising_edge(Clock_CI) then
			Count_DP <= Count_DN;
		end if;
	end process p_memoryzing;
end Behavioral;
