library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Functions.BooleanToStdLogic;
use work.Settings.DEVICE_FAMILY;

-- Variable width counter that just cycles thorugh all binary values,
-- incrementing by one each time its enable signal is asserted,
-- until it hits a configurable limit. This limit is provided by the
-- DataLimit_DI input, if not needed, just keep it at all ones. The
-- limit can change during operation. When it is hit, the counter
-- emits a one-cycle pulse that signifies overflow on its Overflow_SO
-- signal, and then goes either back to zero or remains at its current
-- value until manually cleared (RESET_ON_OVERFLOW flag). While its
-- value is equal to the limit, it will continue to assert the overflow
-- flag. It is possible to force it to assert the flag for only one
-- cycle, by using the SHORT_OVERFLOW flag. Please note that this is
-- not supported in combination with the OVERFLOW_AT_ZERO flag.
-- It is further possible to specify that the overflow flag should not be
-- asserted when the limit value is reached, but instead when the counter
-- goes back to zero, thanks to the OVERFLOW_AT_ZERO flag.
-- Please be caerful about the counter size and its limit value.
-- If you need to count N times, you will need a counter of size
-- ceil(log2(N)) and a limit of N-1, since zero also counts!
-- If you need to count up to N, you will instead need a counter of
-- size ceil(log2(N+1)) and the limit will have to be N.
entity ContinuousCounter is
	generic(
		SIZE              : integer;
		RESET_ON_OVERFLOW : boolean := true;
		GENERATE_OVERFLOW : boolean := true;
		SHORT_OVERFLOW    : boolean := false;
		OVERFLOW_AT_ZERO  : boolean := false);
	port(
		Clock_CI     : in  std_logic;
		Reset_RI     : in  std_logic;
		Clear_SI     : in  std_logic;
		Enable_SI    : in  std_logic;
		DataLimit_DI : in  unsigned(SIZE - 1 downto 0);
		Overflow_SO  : out std_logic;
		Data_DO      : out unsigned(SIZE - 1 downto 0));
end ContinuousCounter;

architecture Behavioral of ContinuousCounter is
	signal Count_DP, Count_DN : unsigned(SIZE - 1 downto 0);
	signal Overflowing_S      : std_logic;
begin
	Data_DO <= Count_DP;

	Overflowing_S <= BooleanToStdLogic(Count_DP >= DataLimit_DI);

	counterLogic : process(Count_DP, Clear_SI, Enable_SI, Overflowing_S)
	begin
		Count_DN <= Count_DP;           -- Keep value by default.

		if Clear_SI = '1' then
			Count_DN <= (others => '0');
		elsif Enable_SI = '1' then
			Count_DN <= Count_DP + 1;

			if Overflowing_S = '1' then
				if RESET_ON_OVERFLOW then
					Count_DN <= (others => '0');
				else
					Count_DN <= Count_DP;
				end if;
			end if;
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

	overflowLogicEnabled : if GENERATE_OVERFLOW = true generate
	begin
		overflowUnbufferedOnLimit : if OVERFLOW_AT_ZERO = false generate
		begin
			overflowUnbufferedOnLimitLong : if SHORT_OVERFLOW = false generate
			begin
				-- Unbuffered, long overflow: depends only on CNT>=LIM. 
				Overflow_SO <= Overflowing_S;
			end generate overflowUnbufferedOnLimitLong;

			overflowUnbufferedOnLimitShort : if SHORT_OVERFLOW = true generate
				signal WasOverflowing_S : std_logic;
			begin
				assert (not SHORT_OVERFLOW) report
					"SHORT_OVERFLOW limits the overflow signal to just one cycle, and that limitation persists until the underlying counter is not in an overflow state anymore." severity WARNING;

				-- Unbuffered, short overflow: just limit the signal that can come
				-- from CNT>=LIM to one cycle.
				Overflow_SO <= Overflowing_S and not WasOverflowing_S;

				longOverflowSuppressor : entity work.SimpleRegister
					generic map(
						SIZE => 1)
					port map(
						Clock_CI     => Clock_CI,
						Reset_RI     => Reset_RI,
						Enable_SI    => '1',
						Input_SI(0)  => Overflowing_S,
						Output_SO(0) => WasOverflowing_S);
			end generate overflowUnbufferedOnLimitShort;
		end generate overflowUnbufferedOnLimit;

		overflowUnbufferedOnZero : if OVERFLOW_AT_ZERO = true generate
			signal Overflow_S : std_logic;
		begin
			-- This only ever makes sense if we also reset on overflow, since that's
			-- the only case where we overflow into zero automatically (with Enable_SI).
			assert (RESET_ON_OVERFLOW) report "OVERFLOW_AT_ZERO requires RESET_ON_OVERFLOW enabled." severity FAILURE;

			-- Disabling SHORT_OVERFLOW is not supported in OVERFLOW_AT_ZERO mode.
			-- It will always generate a short overflow signal.
			-- Doing so reliably would increase complexity and resource
			-- consumption to keep and check additional state, and no user of this
			-- module needs this functionality currently.
			assert (SHORT_OVERFLOW) report "OVERFLOW_AT_ZERO requires SHORT_OVERFLOW enabled." severity FAILURE;

			Overflow_S <= not Clear_SI and Enable_SI and Overflowing_S;

			zeroOverflowDelay : entity work.SimpleRegister
				generic map(
					SIZE => 1)
				port map(
					Clock_CI     => Clock_CI,
					Reset_RI     => Reset_RI,
					Enable_SI    => '1',
					Input_SI(0)  => Overflow_S,
					Output_SO(0) => Overflow_SO);
		end generate overflowUnbufferedOnZero;
	end generate overflowLogicEnabled;

	overflowLogicDisabled : if GENERATE_OVERFLOW = false generate
		-- Output overflow (constant zero).
		Overflow_SO <= '0';
	end generate overflowLogicDisabled;
end Behavioral;
