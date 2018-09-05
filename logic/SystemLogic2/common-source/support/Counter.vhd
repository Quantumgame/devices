library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Counter is
	generic(
		SIZE : integer);
	port(
		Clock_CI  : in  std_logic;
		Reset_RI  : in  std_logic;
		Clear_SI  : in  std_logic;
		Enable_SI : in  std_logic;
		Data_DO   : out unsigned(SIZE - 1 downto 0));
end entity Counter;

architecture Structural of Counter is
	signal Count_DP, Count_DN : unsigned(SIZE - 1 downto 0);
begin
	Data_DO <= Count_DP;

	-- Variable width counter, calculation of next value.
	counterLogic : process(Count_DP, Clear_SI, Enable_SI)
	begin
		Count_DN <= Count_DP;           -- Keep value by default.

		if Clear_SI = '1' then
			Count_DN <= (others => '0');
		elsif Enable_SI = '1' then
			Count_DN <= Count_DP + 1;
		end if;
	end process counterLogic;

	-- Change state on clock edge (synchronous).
	counterRegisterUpdate : process(Clock_CI, Reset_RI)
	begin
		if Reset_RI = '1' then          -- asynchronous reset (active-high for FPGAs)
			Count_DP <= (others => '0');
		elsif rising_edge(Clock_CI) then
			Count_DP <= Count_DN;
		end if;
	end process counterRegisterUpdate;
end architecture Structural;
