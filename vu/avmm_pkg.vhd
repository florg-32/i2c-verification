library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

package avmm_pkg is

  type AvmmPinoutT is record
    address            : std_logic_vector;
    writedata          : std_logic_vector;
    readdata           : std_logic_vector;
    byteenable         : std_logic_vector;
    read               : std_logic;
    write              : std_logic;
  end record;

  procedure AvmmWrite(signal trans: inout AddressBusRecType; addr, data, byte_enable: std_logic_vector);
  procedure AvmmRead(signal trans: inout AddressBusRecType; addr, byte_enable: std_logic_vector; variable read_data: out std_logic_vector);
  procedure AvmmReadModifyWrite(signal trans: inout AddressBusRecType; addr, data, write_mask: std_logic_vector);

end package;

package body avmm_pkg is

  procedure AvmmWrite(signal trans: inout AddressBusRecType; addr, data, byte_enable: std_logic_vector) is
  begin
    trans.IntToModel <= to_integer(unsigned(byte_enable));
    Write(trans, addr, data);
  end procedure;

  procedure AvmmRead(signal trans: inout AddressBusRecType; addr, byte_enable: std_logic_vector; variable read_data: out std_logic_vector) is
  begin
    trans.IntToModel <= to_integer(unsigned(byte_enable));
    Read(trans, addr, read_data);
  end procedure;

  procedure AvmmReadModifyWrite(signal trans: inout AddressBusRecType; addr, data, write_mask: std_logic_vector) is
    variable read_data: std_logic_vector;
  begin
    -- Using byteenable would mean we cannot support write_masks that are not byte aligned
    AvmmRead(trans, addr, (others => '1'), read_data);
    AvmmWrite(trans, addr, (data and write_mask) or (read_data and not write_mask), (others => '1'));
  end procedure;

end package body;
