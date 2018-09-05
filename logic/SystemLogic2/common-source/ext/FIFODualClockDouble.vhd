library ieee;
use ieee.std_logic_1164.all;
use work.Settings.DEVICE_FAMILY;
use work.FIFORecords.all;

entity FIFODualClockDouble is
	generic(
		DATA_WIDTH        : integer;    -- This is OUTPUT data width.
		DATA_DEPTH        : integer;    -- This is OUTPUT data depth.
		ALMOST_EMPTY_FLAG : integer;
		ALMOST_FULL_FLAG  : integer;
		MEMORY            : string := "EBR");
	port(
		WrClock_CI     : in  std_logic;
		WrReset_RI     : in  std_logic;
		RdClock_CI     : in  std_logic;
		RdReset_RI     : in  std_logic;
		FifoControl_SI : in  tToFifo;
		FifoControl_SO : out tFromFifo;
		FifoData_DI    : in  std_logic_vector((DATA_WIDTH / 2) - 1 downto 0);
		FifoData_DO    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity FIFODualClockDouble;

architecture Structural of FIFODualClockDouble is
	constant DATA_WIDTH_IN : integer := DATA_WIDTH / 2;
	constant DATA_DEPTH_IN : integer := DATA_DEPTH * 2;

	signal FIFOState_S : tFromFifoReadSide;
	signal FIFORead_S  : tToFifoReadSide;
	signal FIFOData_D  : std_logic_vector(DATA_WIDTH - 1 downto 0);

	component FIFODualClockDoubleECP3
		port(
			Data        : in  std_logic_vector(15 downto 0);
			WrClock     : in  std_logic;
			RdClock     : in  std_logic;
			WrEn        : in  std_logic;
			RdEn        : in  std_logic;
			Reset       : in  std_logic;
			RPReset     : in  std_logic;
			Q           : out std_logic_vector(31 downto 0);
			Empty       : out std_logic;
			Full        : out std_logic;
			AlmostEmpty : out std_logic;
			AlmostFull  : out std_logic);
	end component;
begin
	-- Use double-clock FIFO from the Lattice Portable Module Interfaces.
	-- This is a more portable variation than what you'd get with the other tools,
	-- but slightly less configurable. It has everything we need though, and allows
	-- for easy switching between underlying hardware implementations and tuning.
	pmiFifoDC : if DEVICE_FAMILY /= "ECP3" generate
		fifoDualClock : component work.pmi_components.pmi_fifo_dc
			generic map(
				pmi_data_width_w      => DATA_WIDTH_IN,
				pmi_data_width_r      => DATA_WIDTH,
				pmi_data_depth_w      => DATA_DEPTH_IN,
				pmi_data_depth_r      => DATA_DEPTH,
				pmi_full_flag         => DATA_DEPTH_IN,
				pmi_empty_flag        => 0,
				pmi_almost_full_flag  => DATA_DEPTH_IN - ALMOST_FULL_FLAG,
				pmi_almost_empty_flag => ALMOST_EMPTY_FLAG,
				pmi_regmode           => "noreg",
				pmi_resetmode         => "async",
				pmi_family            => DEVICE_FAMILY,
				pmi_implementation    => MEMORY)
			port map(
				Data        => FifoData_DI,
				WrClock     => WrClock_CI,
				RdClock     => RdClock_CI,
				WrEn        => FifoControl_SI.WriteSide.Write_S,
				RdEn        => FIFORead_S.Read_S,
				Reset       => WrReset_RI,
				RPReset     => WrReset_RI,
				Q           => FIFOData_D,
				Empty       => FIFOState_S.Empty_S,
				Full        => FifoControl_SO.WriteSide.Full_S,
				AlmostEmpty => FIFOState_S.AlmostEmpty_S,
				AlmostFull  => FifoControl_SO.WriteSide.AlmostFull_S);
	end generate pmiFifoDC;

	ipExpressFifoDC : if DEVICE_FAMILY = "ECP3" generate
		assert (DATA_WIDTH = 32) report "FIFODualClockDouble on ECP3 is hard-coded to 32bit data width." severity FAILURE;
		assert (DATA_DEPTH = 512) report "FIFODualClockDouble on ECP3 is hard-coded to 512 elements data depth." severity FAILURE;
		assert (ALMOST_EMPTY_FLAG = 8) report "FIFODualClockDouble on ECP3 is hard-coded to 8 elements for the almost empty flag." severity FAILURE;
		assert (ALMOST_FULL_FLAG = 2) report "FIFODualClockDouble on ECP3 is hard-coded to 2 elements for the almost full flag." severity FAILURE;

		fifoDualClock : component FIFODualClockDoubleECP3
			port map(
				Data        => FifoData_DI,
				WrClock     => WrClock_CI,
				RdClock     => RdClock_CI,
				WrEn        => FifoControl_SI.WriteSide.Write_S,
				RdEn        => FIFORead_S.Read_S,
				Reset       => WrReset_RI,
				RPReset     => WrReset_RI,
				Q           => FIFOData_D,
				Empty       => FIFOState_S.Empty_S,
				Full        => FifoControl_SO.WriteSide.Full_S,
				AlmostEmpty => FIFOState_S.AlmostEmpty_S,
				AlmostFull  => FifoControl_SO.WriteSide.AlmostFull_S);
	end generate ipExpressFifoDC;

	readSideOutputDelayReg : entity work.FIFOReadSideDelay
		generic map(
			DATA_WIDTH => DATA_WIDTH)
		port map(
			Clock_CI          => RdClock_CI,
			Reset_RI          => RdReset_RI,
			InFifoControl_SI  => FIFOState_S,
			InFifoControl_SO  => FIFORead_S,
			OutFifoControl_SI => FifoControl_SI.ReadSide,
			OutFifoControl_SO => FifoControl_SO.ReadSide,
			FifoData_DI       => FIFOData_D,
			FifoData_DO       => FifoData_DO);
end architecture Structural;
