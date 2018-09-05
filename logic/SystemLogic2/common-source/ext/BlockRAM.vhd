library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Functions.BooleanToStdLogic;
use work.Settings.DEVICE_FAMILY;

entity BlockRAM is
	generic(
		ADDRESS_DEPTH : integer;
		ADDRESS_WIDTH : integer;
		DATA_WIDTH    : integer;
		-- Write mode for EBR memory, can be: "normal",  "writethrough", "readbeforewrite".
		WRITE_MODE    : string := "normal");
	port(
		Clock_CI       : in  std_logic;
		Reset_RI       : in  std_logic;

		Address_DI     : in  unsigned(ADDRESS_WIDTH - 1 downto 0);
		Enable_SI      : in  std_logic;
		WriteEnable_SI : in  std_logic;
		Data_DI        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		Data_DO        : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		DataValid_SO   : out std_logic);
end entity BlockRAM;

architecture Structural of BlockRAM is
	signal DataOutValid_S : std_logic;
begin
	-- Data output is valid only if the BlockRAM was enabled, and even then
	-- in normal mode only if this was a read. In writethrough and readbeforewrite
	-- modes the output is valid regardless of it being a read or write operation.
	DataOutValid_S <= Enable_SI and (not WriteEnable_SI or BooleanToStdLogic(WRITE_MODE /= "normal"));

	dataOutValidReg : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => DataOutValid_S,
			Output_SO(0) => DataValid_SO);

	blockRAM : component work.pmi_components.pmi_ram_dq
		generic map(
			pmi_addr_depth   => ADDRESS_DEPTH,
			pmi_addr_width   => ADDRESS_WIDTH,
			pmi_data_width   => DATA_WIDTH,
			pmi_regmode      => "noreg",
			pmi_gsr          => "disable",
			pmi_resetmode    => "async",
			pmi_optimization => "speed",
			pmi_write_mode   => WRITE_MODE,
			pmi_family       => DEVICE_FAMILY)
		port map(
			Data    => Data_DI,
			Address => std_logic_vector(Address_DI),
			Clock   => Clock_CI,
			ClockEn => Enable_SI,
			WE      => WriteEnable_SI,
			Reset   => Reset_RI,
			Q       => Data_DO);
end architecture Structural;
