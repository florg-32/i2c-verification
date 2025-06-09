library common_lib;
context common_lib.common_context;
use work.avmm_pkg.all;

architecture tb_reset_register_arc of dut_test_ctrl is
  shared variable ControlReg : std_logic_vector(3 downto 0) := "0000" ;
  shared variable StatusReg : std_logic_vector(3 downto 0) := "0001" ;
  shared variable ByteEnReg : std_logic_vector(3 downto 0) := "0010" ;
  shared variable DataReg0 : std_logic_vector(3 downto 0) := "1000" ;
  shared variable DataReg15 : std_logic_vector(3 downto 0) := "1111" ;
  shared variable ByteEnable : std_logic_vector(3 downto 0) := "1111" ;
begin

  CreateClock(clk_o, 10 ns);
  --CreateReset(rst_o, '1', clk_o, 100 ns, 0 ns);
  
  stimuli_p: process is
  variable read_control: std_logic_vector(31 downto 0);
  variable read_status: std_logic_vector(31 downto 0);
  variable read_byteen: std_logic_vector(31 downto 0);
  variable read_data0: std_logic_vector(31 downto 0);
  variable read_data15: std_logic_vector(31 downto 0);

  constant reset_value : std_logic_vector(31 downto 0) := X"00000000";
  constant reset_value_be : std_logic_vector(31 downto 0) := X"00000001";
  constant reset_value_data : std_logic_vector(31 downto 0) := X"DEADBEEF";
  
  begin
    Log("*** Start of Testbench ***");
    wait for 10 ns;
    AvmmRead(avmm_trans_io, ControlReg, ByteEnable, read_control);
    AvmmRead(avmm_trans_io, StatusReg, ByteEnable, read_status);
    AvmmRead(avmm_trans_io, ByteEnReg, ByteEnable, read_byteen);
    AvmmRead(avmm_trans_io, DataReg0, ByteEnable, read_data0);
    AvmmRead(avmm_trans_io, DataReg0, ByteEnable, read_data15);
    
    WaitForClock(clk_o, 2);
    Log("Read control register: " & to_hstring(unsigned(read_control)));
    Log("Read status register: " & to_hstring(unsigned(read_status)));
    Log("Read byte enable register: " & to_hstring(unsigned(read_byteen)));
    Log("Read data 0 register: " & to_hstring(unsigned(read_data0)));
    Log("Read data 15 register: " & to_hstring(unsigned(read_data15)));

    AvmmWrite(avmm_trans_io, ControlReg, X"7FFFFFE", "1111");
    AvmmWrite(avmm_trans_io, StatusReg, X"00000003", "1111");
    AvmmWrite(avmm_trans_io, ByteEnable, X"0000000F", "1111");
    AvmmWrite(avmm_trans_io, DataReg0, X"FFFFFFFF", "1111");
    AvmmWrite(avmm_trans_io, DataReg15, X"AAAAAAAA", "1111");

  -- Hard reset
    WaitForClock(clk_o, 2);
    rst_o <= '1';
    WaitForClock(clk_o, 2);
    rst_o <= '0';
    WaitForClock(clk_o, 2);

    AvmmRead(avmm_trans_io, ControlReg, ByteEnable, read_control);
    AvmmRead(avmm_trans_io, StatusReg, ByteEnable, read_status);
    AvmmRead(avmm_trans_io, ByteEnReg, ByteEnable, read_byteen);
    AvmmRead(avmm_trans_io, DataReg0, ByteEnable, read_data0);
    AvmmRead(avmm_trans_io, DataReg15, ByteEnable, read_data15);
    
    WaitForClock(clk_o, 2);

    Log("Read control register: " & to_hstring(unsigned(read_control)));
    Log("Read status register: " & to_hstring(unsigned(read_status)));
    Log("Read byte enable register: " & to_hstring(unsigned(read_byteen)));
    Log("Read data 0 register: " & to_hstring(unsigned(read_data0)));
    Log("Read data 0 register: " & to_hstring(unsigned(read_data15)));

    AffirmIf(read_control=reset_value, "T-001: I2C-003/005 Violated, Controller register does not reset");
    AffirmIf(read_status=reset_value, "T-001: I2C-003/005 Violated, Status register does not reset");
    AffirmIf(read_byteen=reset_value_be, "T-001: I2C-003/005 Violated, Byte Enable register does not reset");
    AffirmIf(read_data0=reset_value_data, "T-001: I2C-003/005 Violated, Data 0 register does not reset");
    AffirmIf(read_data15=reset_value_data, "T-001: I2C-003/005 Violated, Data 15 register does not reset");

    WaitForClock(clk_o, 2);

    AvmmWrite(avmm_trans_io, ControlReg, X"7FFFFFE", "1111");
    AvmmWrite(avmm_trans_io, StatusReg, X"00000003", "1111");
    AvmmWrite(avmm_trans_io, ByteEnable, X"0000000F", "1111");
    AvmmWrite(avmm_trans_io, DataReg0, X"FFFFFFFF", "1111");
    AvmmWrite(avmm_trans_io, DataReg15, X"AAAAAAAA", "1111");

    WaitForClock(clk_o, 2);

    -- soft reset
    Log("---Soft Reset---");
    AvmmWrite(avmm_trans_io, ControlReg, X"7FFFFFF", "1111");

    WaitForClock(clk_o, 2);

    AvmmRead(avmm_trans_io, ControlReg, ByteEnable, read_control);
    AvmmRead(avmm_trans_io, StatusReg, ByteEnable, read_status);
    AvmmRead(avmm_trans_io, ByteEnReg, ByteEnable, read_byteen);
    AvmmRead(avmm_trans_io, DataReg0, ByteEnable, read_data0);
    AvmmRead(avmm_trans_io, DataReg15, ByteEnable, read_data15);
    
    WaitForClock(clk_o, 2);

    Log("Read control register: " & to_hstring(unsigned(read_control)));
    Log("Read status register: " & to_hstring(unsigned(read_status)));
    Log("Read byte enable register: " & to_hstring(unsigned(read_byteen)));
    Log("Read data 0 register: " & to_hstring(unsigned(read_data0)));
    Log("Read data 0 register: " & to_hstring(unsigned(read_data15)));

    AffirmIf(read_control=reset_value, "T-001: I2C-053 Violated, Controller register does not soft-reset");
    AffirmIf(read_status=reset_value, "T-001: I2C-053 Violated, Status register does not soft-reset");
    AffirmIf(read_byteen=reset_value_be, "T-001: I2C-053 Violated, Byte Enable register does not soft-reset");
    AffirmIf(read_data0=reset_value_data, "T-001: I2C-053 Violated, Data 0 register does not soft-reset");
    AffirmIf(read_data15=reset_value_data, "T-001: I2C-053 Violated, Data 15 register does not soft-reset");


    WaitForClock(clk_o, 2);
    -- soft reset deassertion check
    AvmmRead(avmm_trans_io, ControlReg, ByteEnable, read_control);
    WaitForClock(clk_o, 2);
    
    AffirmIf(read_control(0)='0',"T-001: I2C-054 Violated, Control.RST is not deasserted");



    std.env.stop;
  end process;
  
end architecture;

configuration tb_reset_register of dut_harness is
  for harness_arc
    for dut_test_ctrl_inst: dut_test_ctrl
      use entity work.dut_test_ctrl(tb_reset_register_arc) ; 
    end for; 
  end for; 
end configuration;