library common_lib;
context common_lib.common_context;
use work.avmm_pkg.all;

architecture tb_control_interface_arc of dut_test_ctrl is

begin

  CreateClock(clk_o, 10 ns);
  --CreateReset(rst_o, '1', clk_o, 100 ns, 0 ns);
  
  stimuli_p: process is
    constant ControlReg : std_logic_vector(3 downto 0) := "0000" ;
    constant StatusReg : std_logic_vector(3 downto 0) := "0001" ;
    constant ByteEnReg : std_logic_vector(3 downto 0) := "0010" ;
    constant DataReg0 : std_logic_vector(3 downto 0) := "1000" ;
    variable ByteEnable : std_logic_vector(3 downto 0) := "1111" ;

    variable read_control: std_logic_vector(31 downto 0);
    variable read_status: std_logic_vector(31 downto 0);
    variable read_byteen: std_logic_vector(31 downto 0);
    variable read_data0: std_logic_vector(31 downto 0);
    variable read_data15: std_logic_vector(31 downto 0);
  begin
    Log("*** Start of Testbench ***");
    wait for 10 ns;
    rst_o <= '0';
    WaitForClock(clk_o, 2);
    rst_o <= '1';
    WaitForClock(clk_o, 2);
    rst_o <= '0';
    WaitForClock(clk_o, 2);

    AvmmWrite(avmm_trans_io, ControlReg, X"7ABCDEFE", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, ControlReg, ByteEnable, read_control);
    WaitForClock(clk_o, 2);


    AvmmWrite(avmm_trans_io, StatusReg, X"000000000", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, StatusReg, ByteEnable, read_status);
    WaitForClock(clk_o, 2);


    AvmmWrite(avmm_trans_io, ByteEnReg, X"0000000F", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, ByteEnReg, ByteEnable, read_byteen);
    WaitForClock(clk_o, 2);

    AvmmWrite(avmm_trans_io, DataReg0, X"FFFFFFFF", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, DataReg0, ByteEnable, read_data0);

    WaitForClock(clk_o, 2);
    AffirmIf(read_control = X"7ABCDEFE", "T-004: I2C-006/0013 Violated, Controller register does not read back same value");
    AffirmIf(read_status = X"000000000", "T-005: I2C-006/0013 Violated, Status register does not read back same value");
    AffirmIf(read_byteen = X"00000000F", "T-006: I2C-006/0013 Violated, Byte Enable register does not read back same value");
    AffirmIf(read_data0 = X"FFFFFFFF", "T-007: I2C-006/0013 Violated, Data 0 register does not read back same value");

---------
    WaitForClock(clk_o, 2);

    AvmmWrite(avmm_trans_io, ControlReg, X"7000000E", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, ControlReg, ByteEnable, read_control);
    WaitForClock(clk_o, 2);


    AvmmWrite(avmm_trans_io, StatusReg, X"000000001", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, StatusReg, ByteEnable, read_status);
    WaitForClock(clk_o, 2);


    AvmmWrite(avmm_trans_io, ByteEnReg, X"0000000A", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, ByteEnReg, ByteEnable, read_byteen);
    WaitForClock(clk_o, 2);

    AvmmWrite(avmm_trans_io, DataReg0, X"AAAAAAAA", "1111");
    WaitForClock(clk_o, 2);
    AvmmRead(avmm_trans_io, DataReg0, ByteEnable, read_data0);

    WaitForClock(clk_o, 2);
    AffirmIf(read_control = X"7000000E", "T-004: I2C-006/0013 Violated, Controller register does not read back same value");
    AffirmIf(read_status = X"000000001", "T-005: I2C-006/0013 Violated, Status register does not read back same value");
    AffirmIf(read_byteen = X"0000000A", "T-006: I2C-006/0013 Violated, Byte Enable register does not read back same value");
    AffirmIf(read_data0 = X"AAAAAAAA", "T-007: I2C-006/0013 Violated, Data 0 register does not read back same value");

    std.env.stop;
  end process;
  
end architecture;

configuration tb_control_interface of dut_harness is
  for harness_arc
    for dut_test_ctrl_inst: dut_test_ctrl
      use entity work.dut_test_ctrl(tb_control_interface_arc) ; 
    end for; 
  end for; 
end configuration;