library common_lib;
context common_lib.common_context;
use work.avmm_pkg.all;

architecture tb_dut_arc of dut_test_ctrl is
begin

  CreateClock(clk_o, 10 ns);
  CreateReset(rst_o, '1', clk_o, 100 ns, 0 ns);
  
  stimuli_p: process is
  begin
    Log("*** Start of Testbench ***");
    wait for 10 ns;
    std.env.stop;
  end process;
  
end architecture;

configuration tb_dut of dut_harness is
  for harness_arc
    for dut_test_ctrl_inst: dut_test_ctrl
      use entity work.dut_test_ctrl(tb_dut_arc) ; 
    end for; 
  end for; 
end configuration;