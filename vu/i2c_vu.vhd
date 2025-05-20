--! This VU treats read and write operations as seen from master, meaning a WRITE_OP expects the master to write data
--! and compares it against what it is provided

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.i2c_pkg.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;
  use osvvm.ScoreBoardPkg_slv.all;

entity i2c_vu is
  port (
    trans_io: inout AddressBusRecType;
    clk_i   : in    std_logic;
    pins_io : inout I2cPinoutT
  );
end entity;

architecture rtl of i2c_vu is

  signal read_queue, write_queue: osvvm.ScoreBoardPkg_slv.ScoreboardIdType;

  signal write_request_count, write_done_count: integer := 0;
  signal read_request_count, read_done_count: integer := 0;

begin

  initializer_p: process
  begin
    read_queue <= NewID("read_queue", DoNotReport => TRUE);
    write_queue <= NewID("write_queue", DoNotReport => TRUE);
    wait;
  end process;

  sequencer_p: process
    variable stimulus: I2cStim;
  begin
    wait for 0 ns;

    dispatcher_loop: loop
      WaitForTransaction(clk => clk_i, Rdy => trans_io.Rdy, Ack => trans_io.Ack);
      case trans_io.Operation is
        when READ_OP | ASYNC_READ =>
          stimulus.address := SafeResize(trans_io.Address, stimulus.address'length);
          stimulus.data := SafeResize(trans_io.DataFromModel, stimulus.data'length);
          Push(read_queue, stimulus.address & stimulus.data);
          Increment(read_request_count);
          wait for 0 ns;

          if trans_io.Operation = READ_OP then
            if read_done_count /= read_request_count then
              wait until read_done_count = read_request_count;
            end if;
          end if;

        when WRITE_OP | ASYNC_WRITE =>
          stimulus.address := SafeResize(trans_io.Address, stimulus.address'length);
          stimulus.data := SafeResize(trans_io.DataToModel, stimulus.data'length);
          Push(write_queue, stimulus.address & stimulus.data);
          Increment(write_request_count);
          wait for 0 ns;

          if trans_io.Operation = WRITE_OP then
            if write_done_count /= write_request_count then
              wait until write_done_count = write_request_count;
            end if;
          end if;

        when GET_WRITE_TRANSACTION_COUNT =>
          trans_io.IntFromModel <= write_done_count;

        when GET_READ_TRANSACTION_COUNT =>
          trans_io.IntFromModel <= read_done_count;

        when WAIT_FOR_TRANSACTION =>
          if write_done_count /= write_request_count or read_done_count /= read_request_count then
            wait until write_done_count = write_request_count and read_done_count = read_request_count;
          end if;

        when others =>
          Alert("Unsupported operation");

        end case;
    end loop;
  end process;

  i2c_p: process
    procedure transmit_bit(val: std_logic) is
    begin
      wait until falling_edge(pins_io.scl);
      pins_io.sda <= 'Z' when val else '0';
      wait until falling_edge(pins_io.scl);
      pins_io.sda <= 'Z';
    end procedure;

    procedure transmit_ack is
    begin
      transmit_bit('0');
    end procedure;

    procedure transmit_nack is
    begin
      transmit_bit('1');
    end procedure;

    procedure read_bit (variable val: out std_logic; variable is_stop: out boolean) is
    begin
      wait until falling_edge(pins_io.scl);

      if pins_io.sda = '0' then
        wait until rising_edge(pins_io.scl);
        val := '1' when pins_io.sda = 'Z' else pins_io.sda;

        wait until falling_edge(pins_io.scl) or rising_edge(pins_io.sda);
        if pins_io.scl = 'Z' and pins_io.sda = 'Z' then
          is_stop := TRUE;
        end if;
      else
        wait until rising_edge(pins_io.scl);
        val := '1' when pins_io.sda = 'Z' else pins_io.sda;
        is_stop := FALSE;
      end if;
    end procedure;

    variable stimulus: I2cStim;
    variable received: I2cStim;
    variable is_read: std_logic;
    variable master_ack: std_logic;
    variable is_stop: boolean;
  begin
    wait until falling_edge(pins_io.sda);
    Log("Start condition");

    for i in received.address'range loop
      wait until rising_edge(pins_io.scl);
      received.address(i) := pins_io.sda;
    end loop;
    read_bit(is_read, is_stop);

    if is_read then
      Log("Read request for " & to_hex_string(stimulus.address));
      if Empty(read_queue) then
        transmit_nack;
      else
        (stimulus.address, stimulus.data) := Peek(read_queue);
        if received.address /= stimulus.address then
          Log("Invalid address, expected " & to_hex_string(stimulus.address) & " got " & to_hex_string(received.address));
          transmit_nack;
        else
          transmit_ack;

          burst_read: loop
            if Empty(read_queue) then
              Alert("Read queue is empty");
            else
              (stimulus.address, stimulus.data) := Peek(read_queue);
              if received.address /= stimulus.address then
                Alert("Invalid address, expected " & to_hex_string(stimulus.address) & " got " & to_hex_string(received.address));
              else
                (stimulus.address, stimulus.data) := Pop(read_queue);

                for i in stimulus.data'range loop
                  transmit_bit(stimulus.data(i));
                end loop;

                read_bit(master_ack, is_stop);
                Increment(read_done_count);
                if master_ack /= '0' then
                  exit burst_read;
                end if;
              end if;
            end if;
          end loop;
        end if;
      end if;

      -- STOP condition
      wait until rising_edge(pins_io.scl);
      wait until rising_edge(pins_io.sda);

    else
      Log("Write request for " & to_hex_string(stimulus.address));
      if Empty(write_queue) then
        Log("No write enqueued");
        transmit_nack;
      else
        (stimulus.address, stimulus.data) := Peek(write_queue);
        if received.address /= stimulus.address then
          Log("Incorrect address");
          transmit_nack;
        else
          transmit_ack;

          burst_write: loop
            for i in received.data'range loop
              read_bit(received.data(i), is_stop);
              if is_stop then
                exit burst_write;
              end if;
            end loop;

            if Empty(write_queue) then
              Alert("Write queue empty");
              transmit_nack;
            else
              (stimulus.address, stimulus.data) := Peek(write_queue);
              if received.address /= stimulus.address then
                transmit_nack;
                Alert("Invalid address, expected " & to_hex_string(stimulus.address) & " got " & to_hex_string(received.address));
              else
                transmit_ack;

                (stimulus.address, stimulus.data) := Pop(write_queue);
                AlertIfNotEqual(received.data, stimulus.data, "Received data did not match stimulus");
                Increment(write_done_count);
              end if;
            end if;
          end loop;
        end if;
      end if;
    end if;

  end process;

end architecture;
