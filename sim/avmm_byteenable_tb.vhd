library common_lib;
context common_lib.common_context;
use work.avmm_pkg.all;

architecture tb_avmm_byteenable_arc of dut_test_ctrl is
 signal cov_byteenable : CoverageIDType;
begin

  CreateClock(clk_o, 10 ns);
  CreateReset(rst_o, '1', clk_o, 100 ns, 0 ns);
  
  stimuli_p: process is
    type byte_array is array (0 to 3) of std_logic_vector(7 downto 0);
    variable write_data : byte_array;
    variable data_reg_addr : std_logic_vector(4 downto 0) := (others => '0');
    variable byteenable : std_logic_vector(3 downto 0) := (others => '0');
    variable read_data : std_logic_vector(31 downto 0) := (others => '0');
    variable read_data_check : byte_array;
    variable RV : RandomPType;
  begin
    Log("*** Start of AVMM byteenable Testbench ***");
    RV.InitSeed(RV'instance_name);
    cov_byteenable <= NewID("cov_byteenable");
    wait for 120 ns;
    AddCross(cov_byteenable, GenBin(16, 31), GenBin(0, 15));
    loop
      -- initialize random data
      data_reg_addr := RV.RandSlv(16, 31, 5);
      byteenable := RV.RandSlv(0, 15, 4);
      ICover(cov_byteenable, (to_integer(unsigned(data_reg_addr)), to_integer(unsigned(byteenable))));
      for i in 0 to 3 loop
        write_data(i) := RV.RandSlv(1, 255, 8);
      end loop;
            -- reset register content
      AvmmWrite(avmm_trans_io, data_reg_addr, x"00000000", "1111");

      AvmmWrite(avmm_trans_io, data_reg_addr, write_data(3) & write_data(2) & write_data(1) & write_data(0), byteenable);
      AvmmRead(avmm_trans_io, data_reg_addr, "1111", read_data);
      for i in 3 downto 0 loop
        if byteenable(i) = '1' then
          read_data_check(i) := write_data(i);
        else
          read_data_check(i) := (others => '0');
        end if;
      end loop;
      AffirmIfEqual(read_data, read_data_check(3) & read_data_check(2) & read_data_check(1) & read_data_check(0));
      exit when IsCovered(cov_byteenable);
    end loop;
    std.env.stop;
  end process;
  
end architecture;

configuration AVMM_byteenable_tb of dut_harness is
  for harness_arc
    for dut_test_ctrl_inst: dut_test_ctrl
      use entity work.dut_test_ctrl(tb_avmm_byteenable_arc) ; 
    end for; 
  end for; 
end configuration;