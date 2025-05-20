library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.avmm_pkg.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

entity avmm_vu is
  port (
    trans_io: inout AddressBusRecType;
    clk_i   : in    std_logic;
    pins_io : inout AvmmPinoutT
  );
end entity;

architecture rtl of avmm_vu is
begin
end architecture;
