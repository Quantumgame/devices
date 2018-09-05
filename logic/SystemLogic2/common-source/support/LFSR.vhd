library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ShiftRegisterModes.all;

-- Fibonacci XOR-based LFSR with maximum period, for sizes from 3 to 32 bits.
entity LFSR is
	generic(
		SIZE         : integer;
		INITIAL_SEED : integer := 1);
	port(
		Clock_CI       : in  std_logic;
		Reset_RI       : in  std_logic;

		-- Control inputs.
		NextValue_SI   : in  std_logic;
		ReloadSeed_SI  : in  std_logic;
		SeedValue_DI   : in  std_logic_vector(SIZE - 1 downto 0);

		-- Data outputs.
		RandomValue_DO : out std_logic_vector(SIZE - 1 downto 0));
end entity LFSR;

architecture Behavioral of LFSR is
	signal LFSRControl_S : std_logic_vector(SHIFTREGISTER_MODE_SIZE - 1 downto 0);
	signal LFSRInput_D   : std_logic;
begin
	-- We want the LFSR to switch to a new value only when NextValue_SI is asserted,
	-- and to switch to a new seed value (initial value) if ReloadSeed_SI is toggled.
	LFSRControl_S <= SHIFTREGISTER_MODE_PARALLEL_LOAD when (ReloadSeed_SI = '1') else SHIFTREGISTER_MODE_SHIFT_LEFT when (NextValue_SI = '1') else SHIFTREGISTER_MODE_DO_NOTHING;

	-- The LFSR is a simple shift register. It's input depends on current value.
	lfShiftRegister : entity work.ShiftRegister
		generic map(
			SIZE          => SIZE,
			INITIAL_VALUE => INITIAL_SEED)
		port map(
			Clock_CI         => Clock_CI,
			Reset_RI         => Reset_RI,
			Mode_SI          => LFSRControl_S,
			DataIn_DI        => LFSRInput_D,
			ParallelWrite_DI => SeedValue_DI,
			ParallelRead_DO  => RandomValue_DO);

	-- Depending on size, we select the right bits to be fed back into the
	-- LFSR, to achieve the largest possible period.
	lfsr3 : if SIZE = 3 generate
		LFSRInput_D <= RandomValue_DO(2) xor RandomValue_DO(1);
	end generate lfsr3;

	lfsr4 : if SIZE = 4 generate
		LFSRInput_D <= RandomValue_DO(3) xor RandomValue_DO(2);
	end generate lfsr4;

	lfsr5 : if SIZE = 5 generate
		LFSRInput_D <= RandomValue_DO(4) xor RandomValue_DO(2);
	end generate lfsr5;

	lfsr6 : if SIZE = 6 generate
		LFSRInput_D <= RandomValue_DO(5) xor RandomValue_DO(4);
	end generate lfsr6;

	lfsr7 : if SIZE = 7 generate
		LFSRInput_D <= RandomValue_DO(6) xor RandomValue_DO(5);
	end generate lfsr7;

	lfsr8 : if SIZE = 8 generate
		LFSRInput_D <= RandomValue_DO(7) xor RandomValue_DO(5) xor RandomValue_DO(4) xor RandomValue_DO(3);
	end generate lfsr8;

	lfsr9 : if SIZE = 9 generate
		LFSRInput_D <= RandomValue_DO(8) xor RandomValue_DO(4);
	end generate lfsr9;

	lfsr10 : if SIZE = 10 generate
		LFSRInput_D <= RandomValue_DO(9) xor RandomValue_DO(6);
	end generate lfsr10;

	lfsr11 : if SIZE = 11 generate
		LFSRInput_D <= RandomValue_DO(10) xor RandomValue_DO(8);
	end generate lfsr11;

	lfsr12 : if SIZE = 12 generate
		LFSRInput_D <= RandomValue_DO(11) xor RandomValue_DO(10) xor RandomValue_DO(9) xor RandomValue_DO(3);
	end generate lfsr12;

	lfsr13 : if SIZE = 13 generate
		LFSRInput_D <= RandomValue_DO(12) xor RandomValue_DO(11) xor RandomValue_DO(10) xor RandomValue_DO(7);
	end generate lfsr13;

	lfsr14 : if SIZE = 14 generate
		LFSRInput_D <= RandomValue_DO(13) xor RandomValue_DO(12) xor RandomValue_DO(11) xor RandomValue_DO(1);
	end generate lfsr14;

	lfsr15 : if SIZE = 15 generate
		LFSRInput_D <= RandomValue_DO(14) xor RandomValue_DO(13);
	end generate lfsr15;

	lfsr16 : if SIZE = 16 generate
		LFSRInput_D <= RandomValue_DO(15) xor RandomValue_DO(14) xor RandomValue_DO(12) xor RandomValue_DO(3);
	end generate lfsr16;

	lfsr17 : if SIZE = 17 generate
		LFSRInput_D <= RandomValue_DO(16) xor RandomValue_DO(13);
	end generate lfsr17;

	lfsr18 : if SIZE = 18 generate
		LFSRInput_D <= RandomValue_DO(17) xor RandomValue_DO(10);
	end generate lfsr18;

	lfsr19 : if SIZE = 19 generate
		LFSRInput_D <= RandomValue_DO(18) xor RandomValue_DO(17) xor RandomValue_DO(16) xor RandomValue_DO(13);
	end generate lfsr19;

	lfsr20 : if SIZE = 20 generate
		LFSRInput_D <= RandomValue_DO(19) xor RandomValue_DO(16);
	end generate lfsr20;

	lfsr21 : if SIZE = 21 generate
		LFSRInput_D <= RandomValue_DO(20) xor RandomValue_DO(18);
	end generate lfsr21;

	lfsr22 : if SIZE = 22 generate
		LFSRInput_D <= RandomValue_DO(21) xor RandomValue_DO(20);
	end generate lfsr22;

	lfsr23 : if SIZE = 23 generate
		LFSRInput_D <= RandomValue_DO(22) xor RandomValue_DO(17);
	end generate lfsr23;

	lfsr24 : if SIZE = 24 generate
		LFSRInput_D <= RandomValue_DO(23) xor RandomValue_DO(22) xor RandomValue_DO(21) xor RandomValue_DO(16);
	end generate lfsr24;

	lfsr25 : if SIZE = 25 generate
		LFSRInput_D <= RandomValue_DO(24) xor RandomValue_DO(21);
	end generate lfsr25;

	lfsr26 : if SIZE = 26 generate
		LFSRInput_D <= RandomValue_DO(25) xor RandomValue_DO(24) xor RandomValue_DO(23) xor RandomValue_DO(19);
	end generate lfsr26;

	lfsr27 : if SIZE = 27 generate
		LFSRInput_D <= RandomValue_DO(26) xor RandomValue_DO(25) xor RandomValue_DO(24) xor RandomValue_DO(21);
	end generate lfsr27;

	lfsr28 : if SIZE = 28 generate
		LFSRInput_D <= RandomValue_DO(27) xor RandomValue_DO(24);
	end generate lfsr28;

	lfsr29 : if SIZE = 29 generate
		LFSRInput_D <= RandomValue_DO(28) xor RandomValue_DO(26);
	end generate lfsr29;

	lfsr30 : if SIZE = 30 generate
		LFSRInput_D <= RandomValue_DO(29) xor RandomValue_DO(28) xor RandomValue_DO(27) xor RandomValue_DO(6);
	end generate lfsr30;

	lfsr31 : if SIZE = 31 generate
		LFSRInput_D <= RandomValue_DO(30) xor RandomValue_DO(27);
	end generate lfsr31;

	lfsr32 : if SIZE = 32 generate
		LFSRInput_D <= RandomValue_DO(31) xor RandomValue_DO(30) xor RandomValue_DO(29) xor RandomValue_DO(9);
	end generate lfsr32;

	lfsrError : if SIZE < 3 or SIZE > 32 generate
		assert (false) report "LFSR has invalid SIZE. Only sizes between 3 and 32 are supported." severity FAILURE;
	end generate lfsrError;
end architecture Behavioral;
