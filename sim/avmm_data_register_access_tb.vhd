library common_lib;
context common_lib.common_context;
use work.avmm_pkg.all;

architecture tb_avmm_data_access_arc of dut_test_ctrl is
  signal cov_cross : CoverageIDType;
begin

  CreateClock(clk_o, 10 ns);
  CreateReset(rst_o, '1', clk_o, 100 ns, 0 ns);

  
  stimuli_p: process is
    variable data_reg_addr : std_logic_vector(4 downto 0) := (others => '0');
    variable data_val : std_logic_vector(31 downto 0) := (others => '0');

    variable read_data : std_logic_vector(31 downto 0) := (others => '0');
    variable RV : RandomPType;
  begin
    Log("*** Start of AVMM Data Register Access Testbench ***");
    RV.InitSeed(RV'instance_name);
    cov_cross <= NewID("cov_cross");
    wait for 120 ns;
    AddCross(cov_cross, GenBin(16, 31), GenBin(integer'low, integer'high, 64)); 
    loop
      data_reg_addr := RV.RandSlv(16, 31, 5);
      data_val := RV.RandSlv(32);
      ICover(cov_cross, (to_integer(unsigned(data_reg_addr)), to_integer(signed(data_val))));
      AvmmWrite(avmm_trans_io, data_reg_addr, data_val, "1111");
      AvmmRead(avmm_trans_io, data_reg_addr, "1111", read_data);
      AffirmIfEqual(read_data, data_val);
      exit when IsCovered(cov_cross);
    end loop;

    std.env.stop;
  end process;
  
end architecture;

configuration AVMM_data_register_access_tb of dut_harness is
  for harness_arc
    for dut_test_ctrl_inst: dut_test_ctrl
      use entity work.dut_test_ctrl(tb_avmm_data_access_arc) ; 
    end for; 
  end for; 
end configuration;