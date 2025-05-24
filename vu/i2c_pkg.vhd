library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library osvvm;
  context osvvm.OsvvmContext;

package i2c_pkg is

  type I2cPinoutT is record
    scl: std_logic;
    sda: std_logic;
  end record;

  type I2cPinoutTArray is array(natural range<>) of I2cPinoutT;
  type AddressBusRecTypeArray is array(natural range<>) of AddressBusRecType(Address(6 downto 0), DataToModel(7 downto 0), DataFromModel(7 downto 0));

  type I2cStim is record
    data: std_logic_vector(7 downto 0);
    address: std_logic_vector(6 downto 0);
  end record;

  --! Enqueue an expected I2C write. When the write happens, it is checked against the given data.
  --! Consecutive writes to the same address can be burst written.
  procedure I2cWriteAsync(signal trans: inout AddressBusRecType; address, data: in std_logic_vector);

  --! Enqueue an expected I2C read. The VU will write back the provided data on reads to the provided address.
  --! Consecutive reads from the same address can be burst read.
  procedure I2cReadAsync(signal trans: inout AddressBusRecType; address, data: in std_logic_vector);

  --! Other supported operations:
  --!   - GetWriteTransactionCount
  --!   - GetReadTransactionCount
  --!   - WaitForTransanction (waits until all enqueued reads and writes are done)
end package;

package body i2c_pkg is

  procedure I2cWriteAsync(signal trans: inout AddressBusRecType; address, data: in std_logic_vector) is
  begin
    WriteAsync(trans, address, data);
  end procedure;

  procedure I2cReadAsync(signal trans: inout AddressBusRecType; address, data: in std_logic_vector) is
  begin
    trans.Operation     <= ASYNC_READ;
    trans.Address       <= SafeResize(address, trans.Address'length);
    trans.AddrWidth     <= address'length;
    trans.DataToModel   <= SafeResize(data, trans.DataToModel'length);
    trans.DataWidth     <= data'length;
    -- Start Transaction
    RequestTransaction(Rdy => trans.Rdy, Ack => trans.Ack);
  end procedure;

end package body;
