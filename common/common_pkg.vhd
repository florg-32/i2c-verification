package common_pkg is
end package;

package body common_pkg is
end package body;

context common_context is

  library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
  
  library common_lib;
    use common_lib.common_pkg.all;
  
  library osvvm;
    context osvvm.OsvvmContext;
  library osvvm_common;
    context osvvm_common.OsvvmCommonContext;
  
end context;
