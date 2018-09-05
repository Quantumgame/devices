library ieee;
use ieee.std_logic_1164.all;
use work.Settings.DEVICE_FAMILY;
use work.FIFORecords.all;

entity FIFODualClock is
	generic(
		DATA_WIDTH        : integer;
		DATA_DEPTH        : integer;
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
		FifoData_DI    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		FifoData_DO    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity FIFODualClock;

architecture Structural of FIFODualClock is
	signal FIFOState_S : tFromFifoReadSide;
	signal FIFORead_S  : tToFifoReadSide;
	signal FIFOData_D  : std_logic_vector(DATA_WIDTH - 1 downto 0);
begin
	-- Use double-clock FIFO from the Lattice Portable Module Interfaces.
	-- This is a more portable variation than what you'd get with the other tools,
	-- but slightly less configurable. It has everything we need though, and allows
	-- for easy switching between underlying hardware implementations and tuning.
	fifoDualClock : component work.pmi_components.pmi_fifo_dc
		generic map(
			pmi_data_width_w      => DATA_WIDTH,
			pmi_data_width_r      => DATA_WIDTH,
			pmi_data_depth_w      => DATA_DEPTH,
			pmi_data_depth_r      => DATA_DEPTH,
			pmi_full_flag         => DATA_DEPTH,
			pmi_empty_flag        => 0,
			pmi_almost_full_flag  => DATA_DEPTH - ALMOST_FULL_FLAG,
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
