library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Chip to be used for this logic.
use work.CochleaLP.all;

package Settings is
	constant DEVICE_FAMILY : string := "ECP3";

	constant USB_CLOCK_FREQ         : integer := 80; -- 50, 80 or 100 are viable settings, depending on FX3 and routing.
	constant USB_FIFO_WIDTH         : integer := 16;
	constant USB_BURST_WRITE_LENGTH : integer := 8;

	constant LOGIC_CLOCK_FREQ : integer := 100; -- PLL can generate between 5 and 500 MHz here.

	constant ADC_CLOCK_FREQ  : integer := 25; -- ADC SPI clock frequency in MHz.
	constant MAX_ADC_CH_NUM  : integer := 4;
	constant ADC_CHAN_NUMBER : integer := 2;
	constant ADC_DATA_LENGTH : integer := 18;

	-- FX3 clock correction. Off by factor 1.008.
	constant CLOCK_CORRECTION_FACTOR : real := 1.008;
	constant USB_CLOCK_FREQ_REAL     : real := real(USB_CLOCK_FREQ) * CLOCK_CORRECTION_FACTOR;
	constant LOGIC_CLOCK_FREQ_REAL   : real := real(LOGIC_CLOCK_FREQ) * CLOCK_CORRECTION_FACTOR;
	constant ADC_CLOCK_FREQ_REAL     : real := real(ADC_CLOCK_FREQ) * CLOCK_CORRECTION_FACTOR;

	-- See Table 27 of AD5391 doc for explanation.
	constant DAC_DEFAULT_CONFIG_WORD : unsigned(23 downto 0) := b"0000_1100_0010_0101_0000_0000";

	constant USBLOGIC_FIFO_SIZE              : integer := 1024;
	constant USBLOGIC_FIFO_ALMOST_EMPTY_SIZE : integer := USB_BURST_WRITE_LENGTH;
	constant USBLOGIC_FIFO_ALMOST_FULL_SIZE  : integer := 2;
	constant DVSAER_FIFO_SIZE                : integer := 1024;
	constant DVSAER_FIFO_ALMOST_EMPTY_SIZE   : integer := 2;
	constant DVSAER_FIFO_ALMOST_FULL_SIZE    : integer := 2;

	constant LOGIC_VERSION : unsigned(3 downto 0) := to_unsigned(1, 4);

	-- The idea behing common-source/ is to have generic implementations of features, that can
	-- easily be adapted to a specific platform+chip combination. As such, only Settings.vhd and
	-- TopLevel.vhd are private to a specific system, while the rest of the code is shared.
	-- Some code (APSADC, SystemInfo for example) depends on information about the chip.
	-- This information is stored in the various chip definitions files under chipdefs/, but those
	-- files have to be included when they are needed. If this inclusion happened inside of the
	-- files inside common-source/, the whole purpose of it would be defeated: you'd have to edit
	-- several files in common-source/ each time you want to try another chip. We don't want that.
	-- As such, the chip def files are included here, only once, in Settings.vhd, so that code may
	-- refer to a common location, that is intended to be private to the particular system.
	-- VHDL use clauses are local to the file they are declared in, so anybody just including
	-- Settings.h wouldn't get the content of ChipDef.vhd automatically, which is why we re-define
	-- that common set of variables here and assign them their values from ChipDef.vhd.
	constant CHIP_IDENTIFIER : unsigned(3 downto 0) := CHIP_IDENTIFIER;

	constant AER_BUS_WIDTH     : integer := AER_BUS_WIDTH;
	constant AER_OUT_BUS_WIDTH : integer := 16;
end Settings;
