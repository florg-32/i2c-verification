library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.i2c_pkg.all;
  use work.avmm_pkg.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

entity dut_harness is
  generic (
    CLK_DIVIDE_G: integer := 10000;
    NUM_BUSSES_G: integer := 4
  );
end entity;

architecture harness_arc of dut_harness is

  component dut_test_ctrl is
    generic (
      CLK_DIVIDE_G: integer := 10000;
      NUM_BUSSES_G: integer := 4
    );
    port (
      clk_o: out std_logic;
      rst_o: out std_logic;
      irq_i: in std_logic;
      i2c_trans_io: inout AddressBusRecTypeArray(0 to NUM_BUSSES_G - 1);
      avmm_trans_io: inout AddressBusRecType
    );
  end component;

  signal clk_s, rst_s, irq_s: std_logic;
  signal avmm_trans_s: AddressBusRecType(Address(5 downto 0), DataToModel(31 downto 0), DataFromModel(31 downto 0));
  signal avmm_pins_s: AvmmPinoutT(address(5 downto 0), readdata(31 downto 0), writedata(31 downto 0), byteenable(3 downto 0));
  signal i2c_trans_s: AddressBusRecTypeArray(0 to NUM_BUSSES_G - 1);
  signal i2c_pins_s: I2cPinoutTArray(0 to NUM_BUSSES_G - 1);
  signal scl_s, sda_s: std_logic_vector(0 to NUM_BUSSES_G - 1);
  
begin

  dut_test_ctrl_inst: dut_test_ctrl
    generic map (
      CLK_DIVIDE_G => CLK_DIVIDE_G,
      NUM_BUSSES_G => NUM_BUSSES_G
    )
    port map (
      clk_o         => clk_s,
      rst_o         => rst_s,
      irq_i         => irq_s,
      i2c_trans_io  => i2c_trans_s,
      avmm_trans_io => avmm_trans_s
    );

  i2c_multi_bus_controller_inst: entity work.i2c_multi_bus_controller
    generic map (
      CLK_DIVIDE_G => CLK_DIVIDE_G,
      NUM_BUSSES_G => NUM_BUSSES_G
    )
    port map (
      clk_i                   => clk_s,
      rst_i                   => rst_s,
      avalon_mms_address_i    => avmm_pins_s.address,
      avalon_mms_readdata_o   => avmm_pins_s.readdata,
      avalon_mms_writedata_i  => avmm_pins_s.writedata,
      avalon_mms_read_i       => avmm_pins_s.read,
      avalon_mms_write_i      => avmm_pins_s.write,
      avalon_mms_byteenable_i => avmm_pins_s.byteenable,
      irq_o                   => irq_s,
      scl_io                  => scl_s,
      sda_io                  => sda_s
    );

  avmm_vu_inst: entity work.avmm_vu
    port map (
      trans_io => avmm_trans_s,
      clk_i    => clk_s,
      pins_io  => avmm_pins_s
    );

  i2c_vu_gen: for i in 0 to NUM_BUSSES_G - 1 generate
  
    i2c_vu_inst: entity work.i2c_vu
      port map (
        trans_io    => i2c_trans_s(i),
        clk_i       => clk_s,
        pins_io.scl => scl_s(i),
        pins_io.sda => sda_s(i)
      );
      
  end generate;
  
  
end architecture;
