library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.i2c_pkg.all;
  use work.avmm_pkg.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

entity dut_test_ctrl is
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
end entity;
