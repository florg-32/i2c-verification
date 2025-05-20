library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

package i2c_pkg is
  
  type I2cPinoutT is record
    scl: std_logic;
    sda: std_logic;
  end record;

  type I2cPinoutTArray is array(natural range<>) of I2cPinoutT;
  type AddressBusRecTypeArray is array(natural range<>) of AddressBusRecType(Address(5 downto 0), DataToModel(31 downto 0), DataFromModel(31 downto 0));

end package;

package body i2c_pkg is
end package body;