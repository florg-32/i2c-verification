library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library osvvm;
  context osvvm.OsvvmContext;

package avmm_pkg is
  
  type AvmmPinoutT is record
    address            : std_logic_vector;
    writedata          : std_logic_vector;
    readdata           : std_logic_vector;
    byteenable         : std_logic_vector;
    read               : std_logic;
    write              : std_logic;
  end record;

end package;

package body avmm_pkg is
end package body;