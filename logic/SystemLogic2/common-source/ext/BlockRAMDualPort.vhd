library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Functions.BooleanToStdLogic;
use work.Settings.DEVICE_FAMILY;

entity BlockRAMDualPort is
	generic(
		ADDRESS_DEPTH : integer;
		ADDRESS_WIDTH : integer;
		DATA_WIDTH    : integer;
		-- Write mode for EBR memory, can be: "normal",  "writethrough", "readbeforewrite".
		WRITE_MODE_A  : string := "normal";
		WRITE_MODE_B  : string := "normal");
	port(
		Clock_CI        : in  std_logic;
		Reset_RI        : in  std_logic;

		-- Port A.
		AddressA_DI     : in  unsigned(ADDRESS_WIDTH - 1 downto 0);
		EnableA_SI      : in  std_logic;
		WriteEnableA_SI : in  std_logic;
		DataA_DI        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		DataA_DO        : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		DataValidA_SO   : out std_logic;

		-- Port B.
		AddressB_DI     : in  unsigned(ADDRESS_WIDTH - 1 downto 0);
		EnableB_SI      : in  std_logic;
		WriteEnableB_SI : in  std_logic;
		DataB_DI        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		DataB_DO        : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		DataValidB_SO   : out std_logic);
end entity BlockRAMDualPort;

architecture Structural of BlockRAMDualPort is
	signal DataOutValidA_S, DataOutValidB_S : std_logic;
begin
	-- Data output is valid only if the BlockRAM was enabled, and even then
	-- in normal mode only if this was a read. In writethrough and readbeforewrite
	-- modes the output is valid regardless of it being a read or write operation.
	DataOutValidA_S <= EnableA_SI and (not WriteEnableA_SI or BooleanToStdLogic(WRITE_MODE_A /= "normal"));
	DataOutValidB_S <= EnableB_SI and (not WriteEnableB_SI or BooleanToStdLogic(WRITE_MODE_B /= "normal"));

	dataOutValidAReg : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => DataOutValidA_S,
			Output_SO(0) => DataValidA_SO);

	dataOutValidBReg : entity work.SimpleRegister
		generic map(
			SIZE => 1)
		port map(
			Clock_CI     => Clock_CI,
			Reset_RI     => Reset_RI,
			Enable_SI    => '1',
			Input_SI(0)  => DataOutValidB_S,
			Output_SO(0) => DataValidB_SO);

	blockRAMDualPort : component work.pmi_components.pmi_ram_dp_true
		generic map(
			pmi_addr_depth_a => ADDRESS_DEPTH,
			pmi_addr_width_a => ADDRESS_WIDTH,
			pmi_data_width_a => DATA_WIDTH,
			pmi_addr_depth_b => ADDRESS_DEPTH,
			pmi_addr_width_b => ADDRESS_WIDTH,
			pmi_data_width_b => DATA_WIDTH,
			pmi_regmode_a    => "noreg",
			pmi_regmode_b    => "noreg",
			pmi_gsr          => "disable",
			pmi_resetmode    => "async",
			pmi_optimization => "speed",
			pmi_write_mode_a => WRITE_MODE_A,
			pmi_write_mode_b => WRITE_MODE_B,
			pmi_family       => DEVICE_FAMILY)
		port map(
			DataInA  => DataA_DI,
			DataInB  => DataB_DI,
			AddressA => std_logic_vector(AddressA_DI),
			AddressB => std_logic_vector(AddressB_DI),
			ClockA   => Clock_CI,
			ClockB   => Clock_CI,
			ClockEnA => EnableA_SI,
			ClockEnB => EnableB_SI,
			WrA      => WriteEnableA_SI,
			WrB      => WriteEnableB_SI,
			ResetA   => Reset_RI,
			ResetB   => Reset_RI,
			QA       => DataA_DO,
			QB       => DataB_DO);
end architecture Structural;
