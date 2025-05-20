library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package math_pkg is

  function log2_f(n : integer) return integer;
  function log2_f(n : unsigned) return integer;
  function test_underflow_f(n : unsigned ; dec : integer := 1) return boolean;

end package math_pkg;

package body math_pkg is

  function log2_f(n : integer) return integer is
    variable i : integer := 0;
  begin
    while (2**i < n) loop  -- n: 0 1 2 3 4 5
      i := i + 1;
    end loop;              -- i: 0 0 1 2 2 3
    return i;
  end log2_f;

  function log2_f(n : unsigned) return integer is
    variable i       : integer  := n'left;
    variable sub_1_v : unsigned(n'range) := n - 1;
  begin
    if n = 0 or n = 1 then         -- n: 0 1
      return 0;                    --    0 0
    end if;
    
    while (sub_1_v(i) = '0') loop  -- n:     2 3 4 5
      i := i - 1;
    end loop;                      -- i:     0 1 1 2
    return i + 1;                  --        1 2 2 3
  end log2_f;
  
  function test_underflow_f(n : unsigned; dec : integer := 1) return boolean is
    variable minus : unsigned(n'range);
  begin
    if n'length = 0 then
      return true;
    else
      minus := n-dec;
      return minus(n'left)='1' and n(n'left)='0';
    end if;
  end function test_underflow_f;

end package body math_pkg;

