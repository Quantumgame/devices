library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Settings.CHIP_IDENTIFIER;
use work.ChipBiasConfigRecords.all;
use work.DAVIS128ChipBiasConfigRecords.all;
use work.DAVIS208ChipBiasConfigRecords.all;
use work.DAVIS240ChipBiasConfigRecords.all;
use work.DAVIS346ChipBiasConfigRecords.all;
use work.DAVISrgbChipBiasConfigRecords.all;

entity ChipBiasSelector is
	generic(
		ADD_REGISTERS_FOR_TIMING : integer := 0);
	port(
		Clock_CI                 : in  std_logic;
		Reset_RI                 : in  std_logic;

		-- Bias configuration outputs (to chip)
		ChipBiasDiagSelect_SO    : out std_logic;
		ChipBiasAddrSelect_SBO   : out std_logic;
		ChipBiasClock_CBO        : out std_logic;
		ChipBiasBitIn_DO         : out std_logic;
		ChipBiasLatch_SBO        : out std_logic;

		-- SPI configuration inputs and outputs.
		ConfigModuleAddress_DI   : in  unsigned(6 downto 0);
		ConfigParamAddress_DI    : in  unsigned(7 downto 0);
		ConfigParamInput_DI      : in  std_logic_vector(31 downto 0);
		ConfigLatchInput_SI      : in  std_logic;
		BiasConfigParamOutput_DO : out std_logic_vector(31 downto 0);
		ChipConfigParamOutput_DO : out std_logic_vector(31 downto 0));
end entity ChipBiasSelector;

architecture Structural of ChipBiasSelector is
begin
	davis128ChipBias : if CHIP_IDENTIFIER = 3 generate
		signal DAVIS128BiasConfigOut_D, DAVIS128BiasConfigIn_D : tDAVIS128BiasConfig;
		signal DAVIS128ChipConfigOut_D, DAVIS128ChipConfigIn_D : tDAVIS128ChipConfig;
	begin
		davis128ChipBiasSM : entity work.DAVIS128StateMachine
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
				ChipBiasAddrSelect_SBO => ChipBiasAddrSelect_SBO,
				ChipBiasClock_CBO      => ChipBiasClock_CBO,
				ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
				ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
				BiasConfig_DI          => DAVIS128BiasConfigIn_D,
				ChipConfig_DI          => DAVIS128ChipConfigIn_D);
				
		timingReg0Support : if ADD_REGISTERS_FOR_TIMING = 0 generate
			DAVIS128BiasConfigIn_D <= DAVIS128BiasConfigOut_D;
			DAVIS128ChipConfigIn_D <= DAVIS128ChipConfigOut_D;
		end generate timingReg0Support;
		
		timingReg1Support : if ADD_REGISTERS_FOR_TIMING = 1 generate
			signal DAVIS128BiasConfigReg_D : tDAVIS128BiasConfig;
			signal DAVIS128ChipConfigReg_D : tDAVIS128ChipConfig;
		begin
			DAVIS128BiasConfigIn_D <= DAVIS128BiasConfigReg_D;
			DAVIS128ChipConfigIn_D <= DAVIS128ChipConfigReg_D;
			
			DAVIS128ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS128BiasConfigReg_D  <= tDAVIS128BiasConfigDefault;

					DAVIS128ChipConfigReg_D  <= tDAVIS128ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS128BiasConfigReg_D  <= DAVIS128BiasConfigOut_D;

					DAVIS128ChipConfigReg_D  <= DAVIS128ChipConfigOut_D;
				end if;
			end process DAVIS128ConfigRegisters;
		end generate timingReg1Support;
		
		timingReg2Support : if ADD_REGISTERS_FOR_TIMING = 2 generate
			signal DAVIS128BiasConfigReg_D, DAVIS128BiasConfigReg2_D : tDAVIS128BiasConfig;
			signal DAVIS128ChipConfigReg_D, DAVIS128ChipConfigReg2_D : tDAVIS128ChipConfig;
		begin
			DAVIS128BiasConfigIn_D <= DAVIS128BiasConfigReg2_D;
			DAVIS128ChipConfigIn_D <= DAVIS128ChipConfigReg2_D;
			
			DAVIS128ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS128BiasConfigReg2_D <= tDAVIS128BiasConfigDefault;
					DAVIS128BiasConfigReg_D  <= tDAVIS128BiasConfigDefault;

					DAVIS128ChipConfigReg2_D <= tDAVIS128ChipConfigDefault;
					DAVIS128ChipConfigReg_D  <= tDAVIS128ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS128BiasConfigReg2_D <= DAVIS128BiasConfigReg_D;
					DAVIS128BiasConfigReg_D  <= DAVIS128BiasConfigOut_D;

					DAVIS128ChipConfigReg2_D <= DAVIS128ChipConfigReg_D;
					DAVIS128ChipConfigReg_D  <= DAVIS128ChipConfigOut_D;
				end if;
			end process DAVIS128ConfigRegisters;
		end generate timingReg2Support;

		davis128ChipBiasSPIConfig : entity work.DAVIS128SPIConfig
			port map(
				Clock_CI                 => Clock_CI,
				Reset_RI                 => Reset_RI,
				BiasConfig_DO            => DAVIS128BiasConfigOut_D,
				ChipConfig_DO            => DAVIS128ChipConfigOut_D,
				ConfigModuleAddress_DI   => ConfigModuleAddress_DI,
				ConfigParamAddress_DI    => ConfigParamAddress_DI,
				ConfigParamInput_DI      => ConfigParamInput_DI,
				ConfigLatchInput_SI      => ConfigLatchInput_SI,
				BiasConfigParamOutput_DO => BiasConfigParamOutput_DO,
				ChipConfigParamOutput_DO => ChipConfigParamOutput_DO);
	end generate davis128ChipBias;

	davis208ChipBias : if CHIP_IDENTIFIER = 8 generate
		signal DAVIS208BiasConfigOut_D, DAVIS208BiasConfigIn_D : tDAVIS208BiasConfig;
		signal DAVIS208ChipConfigOut_D, DAVIS208ChipConfigIn_D : tDAVIS208ChipConfig;
	begin
		davis208ChipBiasSM : entity work.DAVIS208StateMachine
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
				ChipBiasAddrSelect_SBO => ChipBiasAddrSelect_SBO,
				ChipBiasClock_CBO      => ChipBiasClock_CBO,
				ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
				ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
				BiasConfig_DI          => DAVIS208BiasConfigIn_D,
				ChipConfig_DI          => DAVIS208ChipConfigIn_D);

		timingReg0Support : if ADD_REGISTERS_FOR_TIMING = 0 generate
			DAVIS208BiasConfigIn_D <= DAVIS208BiasConfigOut_D;
			DAVIS208ChipConfigIn_D <= DAVIS208ChipConfigOut_D;
		end generate timingReg0Support;
		
		timingReg1Support : if ADD_REGISTERS_FOR_TIMING = 1 generate
			signal DAVIS208BiasConfigReg_D : tDAVIS208BiasConfig;
			signal DAVIS208ChipConfigReg_D : tDAVIS208ChipConfig;
		begin
			DAVIS208BiasConfigIn_D <= DAVIS208BiasConfigReg_D;
			DAVIS208ChipConfigIn_D <= DAVIS208ChipConfigReg_D;
			
			DAVIS208ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS208BiasConfigReg_D  <= tDAVIS208BiasConfigDefault;

					DAVIS208ChipConfigReg_D  <= tDAVIS208ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS208BiasConfigReg_D  <= DAVIS208BiasConfigOut_D;

					DAVIS208ChipConfigReg_D  <= DAVIS208ChipConfigOut_D;
				end if;
			end process DAVIS208ConfigRegisters;
		end generate timingReg1Support;
		
		timingReg2Support : if ADD_REGISTERS_FOR_TIMING = 2 generate
			signal DAVIS208BiasConfigReg_D, DAVIS208BiasConfigReg2_D : tDAVIS208BiasConfig;
			signal DAVIS208ChipConfigReg_D, DAVIS208ChipConfigReg2_D : tDAVIS208ChipConfig;
		begin
			DAVIS208BiasConfigIn_D <= DAVIS208BiasConfigReg2_D;
			DAVIS208ChipConfigIn_D <= DAVIS208ChipConfigReg2_D;
			
			DAVIS208ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS208BiasConfigReg2_D <= tDAVIS208BiasConfigDefault;
					DAVIS208BiasConfigReg_D  <= tDAVIS208BiasConfigDefault;

					DAVIS208ChipConfigReg2_D <= tDAVIS208ChipConfigDefault;
					DAVIS208ChipConfigReg_D  <= tDAVIS208ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS208BiasConfigReg2_D <= DAVIS208BiasConfigReg_D;
					DAVIS208BiasConfigReg_D  <= DAVIS208BiasConfigOut_D;

					DAVIS208ChipConfigReg2_D <= DAVIS208ChipConfigReg_D;
					DAVIS208ChipConfigReg_D  <= DAVIS208ChipConfigOut_D;
				end if;
			end process DAVIS208ConfigRegisters;
		end generate timingReg2Support;

		davis208ChipBiasSPIConfig : entity work.DAVIS208SPIConfig
			port map(
				Clock_CI                 => Clock_CI,
				Reset_RI                 => Reset_RI,
				BiasConfig_DO            => DAVIS208BiasConfigOut_D,
				ChipConfig_DO            => DAVIS208ChipConfigOut_D,
				ConfigModuleAddress_DI   => ConfigModuleAddress_DI,
				ConfigParamAddress_DI    => ConfigParamAddress_DI,
				ConfigParamInput_DI      => ConfigParamInput_DI,
				ConfigLatchInput_SI      => ConfigLatchInput_SI,
				BiasConfigParamOutput_DO => BiasConfigParamOutput_DO,
				ChipConfigParamOutput_DO => ChipConfigParamOutput_DO);
	end generate davis208ChipBias;

	davis240ChipBias : if CHIP_IDENTIFIER = 0 or CHIP_IDENTIFIER = 1 or CHIP_IDENTIFIER = 2 generate
		signal DAVIS240BiasConfigOut_D, DAVIS240BiasConfigIn_D : tDAVIS240BiasConfig;
		signal DAVIS240ChipConfigOut_D, DAVIS240ChipConfigIn_D : tDAVIS240ChipConfig;
	begin
		davis240ChipBiasSM : entity work.DAVIS240StateMachine
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
				ChipBiasAddrSelect_SBO => ChipBiasAddrSelect_SBO,
				ChipBiasClock_CBO      => ChipBiasClock_CBO,
				ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
				ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
				BiasConfig_DI          => DAVIS240BiasConfigIn_D,
				ChipConfig_DI          => DAVIS240ChipConfigIn_D);

		timingReg0Support : if ADD_REGISTERS_FOR_TIMING = 0 generate
			DAVIS240BiasConfigIn_D <= DAVIS240BiasConfigOut_D;
			DAVIS240ChipConfigIn_D <= DAVIS240ChipConfigOut_D;
		end generate timingReg0Support;
		
		timingReg1Support : if ADD_REGISTERS_FOR_TIMING = 1 generate
			signal DAVIS240BiasConfigReg_D : tDAVIS240BiasConfig;
			signal DAVIS240ChipConfigReg_D : tDAVIS240ChipConfig;
		begin
			DAVIS240BiasConfigIn_D <= DAVIS240BiasConfigReg_D;
			DAVIS240ChipConfigIn_D <= DAVIS240ChipConfigReg_D;
			
			DAVIS240ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS240BiasConfigReg_D  <= tDAVIS240BiasConfigDefault;

					DAVIS240ChipConfigReg_D  <= tDAVIS240ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS240BiasConfigReg_D  <= DAVIS240BiasConfigOut_D;

					DAVIS240ChipConfigReg_D  <= DAVIS240ChipConfigOut_D;
				end if;
			end process DAVIS240ConfigRegisters;
		end generate timingReg1Support;
		
		timingReg2Support : if ADD_REGISTERS_FOR_TIMING = 2 generate
			signal DAVIS240BiasConfigReg_D, DAVIS240BiasConfigReg2_D : tDAVIS240BiasConfig;
			signal DAVIS240ChipConfigReg_D, DAVIS240ChipConfigReg2_D : tDAVIS240ChipConfig;
		begin
			DAVIS240BiasConfigIn_D <= DAVIS240BiasConfigReg2_D;
			DAVIS240ChipConfigIn_D <= DAVIS240ChipConfigReg2_D;
			
			DAVIS240ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS240BiasConfigReg2_D <= tDAVIS240BiasConfigDefault;
					DAVIS240BiasConfigReg_D  <= tDAVIS240BiasConfigDefault;

					DAVIS240ChipConfigReg2_D <= tDAVIS240ChipConfigDefault;
					DAVIS240ChipConfigReg_D  <= tDAVIS240ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS240BiasConfigReg2_D <= DAVIS240BiasConfigReg_D;
					DAVIS240BiasConfigReg_D  <= DAVIS240BiasConfigOut_D;

					DAVIS240ChipConfigReg2_D <= DAVIS240ChipConfigReg_D;
					DAVIS240ChipConfigReg_D  <= DAVIS240ChipConfigOut_D;
				end if;
			end process DAVIS240ConfigRegisters;
		end generate timingReg2Support;

		davis240ChipBiasSPIConfig : entity work.DAVIS240SPIConfig
			port map(
				Clock_CI                 => Clock_CI,
				Reset_RI                 => Reset_RI,
				BiasConfig_DO            => DAVIS240BiasConfigOut_D,
				ChipConfig_DO            => DAVIS240ChipConfigOut_D,
				ConfigModuleAddress_DI   => ConfigModuleAddress_DI,
				ConfigParamAddress_DI    => ConfigParamAddress_DI,
				ConfigParamInput_DI      => ConfigParamInput_DI,
				ConfigLatchInput_SI      => ConfigLatchInput_SI,
				BiasConfigParamOutput_DO => BiasConfigParamOutput_DO,
				ChipConfigParamOutput_DO => ChipConfigParamOutput_DO);
	end generate davis240ChipBias;

	-- DAVIS640 uses this too, since it has the same biases and chip config chain as DAVIS346.
	davis346ChipBias : if CHIP_IDENTIFIER = 4 or CHIP_IDENTIFIER = 5 or CHIP_IDENTIFIER = 6 or CHIP_IDENTIFIER = 9 generate
		signal DAVIS128BiasConfigOut_D, DAVIS128BiasConfigIn_D : tDAVIS128BiasConfig;
		signal DAVIS346ChipConfigOut_D, DAVIS346ChipConfigIn_D : tDAVIS346ChipConfig;
	begin
		davis346ChipBiasSM : entity work.DAVIS346StateMachine
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
				ChipBiasAddrSelect_SBO => ChipBiasAddrSelect_SBO,
				ChipBiasClock_CBO      => ChipBiasClock_CBO,
				ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
				ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
				BiasConfig_DI          => DAVIS128BiasConfigIn_D,
				ChipConfig_DI          => DAVIS346ChipConfigIn_D);

		timingReg0Support : if ADD_REGISTERS_FOR_TIMING = 0 generate
			DAVIS128BiasConfigIn_D <= DAVIS128BiasConfigOut_D;
			DAVIS346ChipConfigIn_D <= DAVIS346ChipConfigOut_D;
		end generate timingReg0Support;
		
		timingReg1Support : if ADD_REGISTERS_FOR_TIMING = 1 generate
			signal DAVIS128BiasConfigReg_D : tDAVIS128BiasConfig;
			signal DAVIS346ChipConfigReg_D : tDAVIS346ChipConfig;
		begin
			DAVIS128BiasConfigIn_D <= DAVIS128BiasConfigReg_D;
			DAVIS346ChipConfigIn_D <= DAVIS346ChipConfigReg_D;
			
			DAVIS346ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS128BiasConfigReg_D  <= tDAVIS128BiasConfigDefault;

					DAVIS346ChipConfigReg_D  <= tDAVIS346ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS128BiasConfigReg_D  <= DAVIS128BiasConfigOut_D;

					DAVIS346ChipConfigReg_D  <= DAVIS346ChipConfigOut_D;
				end if;
			end process DAVIS346ConfigRegisters;
		end generate timingReg1Support;
		
		timingReg2Support : if ADD_REGISTERS_FOR_TIMING = 2 generate
			signal DAVIS128BiasConfigReg_D, DAVIS128BiasConfigReg2_D : tDAVIS128BiasConfig;
			signal DAVIS346ChipConfigReg_D, DAVIS346ChipConfigReg2_D : tDAVIS346ChipConfig;
		begin
			DAVIS128BiasConfigIn_D <= DAVIS128BiasConfigReg2_D;
			DAVIS346ChipConfigIn_D <= DAVIS346ChipConfigReg2_D;
			
			DAVIS346ConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVIS128BiasConfigReg2_D <= tDAVIS128BiasConfigDefault;
					DAVIS128BiasConfigReg_D  <= tDAVIS128BiasConfigDefault;

					DAVIS346ChipConfigReg2_D <= tDAVIS346ChipConfigDefault;
					DAVIS346ChipConfigReg_D  <= tDAVIS346ChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVIS128BiasConfigReg2_D <= DAVIS128BiasConfigReg_D;
					DAVIS128BiasConfigReg_D  <= DAVIS128BiasConfigOut_D;

					DAVIS346ChipConfigReg2_D <= DAVIS346ChipConfigReg_D;
					DAVIS346ChipConfigReg_D  <= DAVIS346ChipConfigOut_D;
				end if;
			end process DAVIS346ConfigRegisters;
		end generate timingReg2Support;

		davis346ChipBiasSPIConfig : entity work.DAVIS346SPIConfig
			port map(
				Clock_CI                 => Clock_CI,
				Reset_RI                 => Reset_RI,
				BiasConfig_DO            => DAVIS128BiasConfigOut_D,
				ChipConfig_DO            => DAVIS346ChipConfigOut_D,
				ConfigModuleAddress_DI   => ConfigModuleAddress_DI,
				ConfigParamAddress_DI    => ConfigParamAddress_DI,
				ConfigParamInput_DI      => ConfigParamInput_DI,
				ConfigLatchInput_SI      => ConfigLatchInput_SI,
				BiasConfigParamOutput_DO => BiasConfigParamOutput_DO,
				ChipConfigParamOutput_DO => ChipConfigParamOutput_DO);
	end generate davis346ChipBias;

	davisRGBChipBias : if CHIP_IDENTIFIER = 7 generate
		signal DAVISrgbBiasConfigOut_D, DAVISrgbBiasConfigIn_D : tDAVISrgbBiasConfig;
		signal DAVISrgbChipConfigOut_D, DAVISrgbChipConfigIn_D : tDAVISrgbChipConfig;
	begin
		davisRGBChipBiasSM : entity work.DAVISrgbStateMachine
			port map(
				Clock_CI               => Clock_CI,
				Reset_RI               => Reset_RI,
				ChipBiasDiagSelect_SO  => ChipBiasDiagSelect_SO,
				ChipBiasAddrSelect_SBO => ChipBiasAddrSelect_SBO,
				ChipBiasClock_CBO      => ChipBiasClock_CBO,
				ChipBiasBitIn_DO       => ChipBiasBitIn_DO,
				ChipBiasLatch_SBO      => ChipBiasLatch_SBO,
				BiasConfig_DI          => DAVISrgbBiasConfigIn_D,
				ChipConfig_DI          => DAVISrgbChipConfigIn_D);

		timingReg0Support : if ADD_REGISTERS_FOR_TIMING = 0 generate
			DAVISrgbBiasConfigIn_D <= DAVISrgbBiasConfigOut_D;
			DAVISrgbChipConfigIn_D <= DAVISrgbChipConfigOut_D;
		end generate timingReg0Support;
		
		timingReg1Support : if ADD_REGISTERS_FOR_TIMING = 1 generate
			signal DAVISrgbBiasConfigReg_D : tDAVISrgbBiasConfig;
			signal DAVISrgbChipConfigReg_D : tDAVISrgbChipConfig;
		begin
			DAVISrgbBiasConfigIn_D <= DAVISrgbBiasConfigReg_D;
			DAVISrgbChipConfigIn_D <= DAVISrgbChipConfigReg_D;
			
			DAVISrgbConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVISrgbBiasConfigReg_D  <= tDAVISrgbBiasConfigDefault;

					DAVISrgbChipConfigReg_D  <= tDAVISrgbChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVISrgbBiasConfigReg_D  <= DAVISrgbBiasConfigOut_D;

					DAVISrgbChipConfigReg_D  <= DAVISrgbChipConfigOut_D;
				end if;
			end process DAVISrgbConfigRegisters;
		end generate timingReg1Support;
		
		timingReg2Support : if ADD_REGISTERS_FOR_TIMING = 2 generate
			signal DAVISrgbBiasConfigReg_D, DAVISrgbBiasConfigReg2_D : tDAVISrgbBiasConfig;
			signal DAVISrgbChipConfigReg_D, DAVISrgbChipConfigReg2_D : tDAVISrgbChipConfig;
		begin
			DAVISrgbBiasConfigIn_D <= DAVISrgbBiasConfigReg2_D;
			DAVISrgbChipConfigIn_D <= DAVISrgbChipConfigReg2_D;
			
			DAVISrgbConfigRegisters : process(Clock_CI, Reset_RI) is
			begin
				if Reset_RI = '1' then
					DAVISrgbBiasConfigReg2_D <= tDAVISrgbBiasConfigDefault;
					DAVISrgbBiasConfigReg_D  <= tDAVISrgbBiasConfigDefault;

					DAVISrgbChipConfigReg2_D <= tDAVISrgbChipConfigDefault;
					DAVISrgbChipConfigReg_D  <= tDAVISrgbChipConfigDefault;
				elsif rising_edge(Clock_CI) then
					DAVISrgbBiasConfigReg2_D <= DAVISrgbBiasConfigReg_D;
					DAVISrgbBiasConfigReg_D  <= DAVISrgbBiasConfigOut_D;

					DAVISrgbChipConfigReg2_D <= DAVISrgbChipConfigReg_D;
					DAVISrgbChipConfigReg_D  <= DAVISrgbChipConfigOut_D;
				end if;
			end process DAVISrgbConfigRegisters;
		end generate timingReg2Support;

		davisRGBChipBiasSPIConfig : entity work.DAVISrgbSPIConfig
			port map(
				Clock_CI                 => Clock_CI,
				Reset_RI                 => Reset_RI,
				BiasConfig_DO            => DAVISrgbBiasConfigOut_D,
				ChipConfig_DO            => DAVISrgbChipConfigOut_D,
				ConfigModuleAddress_DI   => ConfigModuleAddress_DI,
				ConfigParamAddress_DI    => ConfigParamAddress_DI,
				ConfigParamInput_DI      => ConfigParamInput_DI,
				ConfigLatchInput_SI      => ConfigLatchInput_SI,
				BiasConfigParamOutput_DO => BiasConfigParamOutput_DO,
				ChipConfigParamOutput_DO => ChipConfigParamOutput_DO);
	end generate davisRGBChipBias;
end architecture Structural;
