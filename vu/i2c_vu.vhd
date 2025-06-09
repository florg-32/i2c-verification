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

  signal busy: std_logic := '0';
  signal start_event, sr_event, stop_event, data_event: std_logic := '0';
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

  i2c_events: process
    variable setup_hold: time;
  begin
    wait until pins_io.sda = '0' and pins_io.scl = 'Z' and pins_io.sda'event;
    AffirmIf(now - pins_io.sda'last_event >= 1.3 us, "T-018 failed; tBuf too short");

    stop_event <= '0';
    start_event <= '1';
    setup_hold := now;

    wait until pins_io.sda = '0' and pins_io.scl = '0' and pins_io.scl'event;
    AffirmIf(now - setup_hold >= 0.6 us, "T-014 failed; start hold too short");

    loop
      wait until pins_io.scl'event and pins_io.scl = 'Z';
      AffirmIf(now - pins_io.sda'last_event >= 100 ns, "T-017 failed; SDA setup too short"); -- safe to assert always, as SR/STOP setup is way longer
      sr_event <= '0';
      data_event <= pins_io.sda;
      setup_hold := now;
      wait until (pins_io.scl'event and pins_io.scl = '0') or pins_io.sda'event;

      if pins_io.sda'event and pins_io.sda = '0' then
        -- repeated start
        AffirmIf(now - setup_hold >= 0.6 us, "T-015 failed; repeated start setup too short");
        sr_event <= '1';
        setup_hold := now;
        wait until pins_io.scl'event and pins_io.scl = '0';
        AffirmIf(now - setup_hold >= 0.6 us, "T-015 failed; repeated start hold too short");
      elsif pins_io.sda'event and pins_io.sda = 'Z' then
        -- stop
        AffirmIf(now - setup_hold >= 0.6 us, "T-014 failed; stop setup too short");
        stop_event <= '1';
        exit;
      end if;
    end loop;

    start_event <= '0';
  end process;

  i2c_scl_period: process
    variable event: time;
  begin
    wait until pins_io.scl'event;
    loop
      event := now;
      wait until pins_io.scl'event;
      if pins_io.scl = '0' then
        AffirmIf(now - event >= 0.6 us, "T-016 failed; SCL HIGH too short");
      else
        AffirmIf(now - event >= 1.3 us, "T-016 failed; SCL LOW too short");
      end if;
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

    procedure read_bit (variable val: out std_logic; variable is_stop, is_sr: out boolean) is
    begin
      wait until data_event'transaction'event or rising_edge(sr_event) or rising_edge(stop_event);
      val := data_event;
      is_stop := rising_edge(stop_event);
      is_sr := rising_edge(sr_event);
    end procedure;

    variable stimulus: I2cStim;
    variable received: I2cStim;
    variable is_read: std_logic;
    variable master_ack: std_logic;
    variable is_stop, is_sr: boolean;
  begin
    if pins_io.sda = 'Z' and pins_io.scl = 'Z' then
      wait until rising_edge(start_event);
    end if;

    for i in received.address'range loop
      read_bit(received.address(i), is_stop, is_sr);
    end loop;
    read_bit(is_read, is_stop, is_sr);

    if is_read = 'Z' then
      Log("Read request for " & to_hex_string(stimulus.address));
      if Empty(read_queue) then
        transmit_nack;
      else
        (stimulus.address, stimulus.data) := Peek(read_queue);
        if received.address /= stimulus.address then
          Alert("Invalid address, expected " & to_hex_string(stimulus.address) & " got " & to_hex_string(received.address));
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

                read_bit(master_ack, is_stop, is_sr);
                Increment(read_done_count);
                if master_ack /= '0' then
                  exit burst_read;
                end if;
              end if;
            end if;
          end loop;

        end if;
      end if;

      wait until rising_edge(stop_event);

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
              read_bit(received.data(i), is_stop, is_sr);
              if is_stop or is_sr then
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
