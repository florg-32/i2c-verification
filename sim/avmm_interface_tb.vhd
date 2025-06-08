library common_lib;
context common_lib.common_context;
use work.avmm_pkg.all;

architecture tb_avmm_interface_arc of dut_test_ctrl is
    signal cov_length : CoverageIDType;
    signal cov_reg_addr : CoverageIDType;
    signal cov_targ_addr : CoverageIDType;
    signal cov_bus_en : CoverageIDType;
begin

    CreateClock(clk_o, 10 ns);
    CreateReset(rst_o, '1', clk_o, 100 ns, 0 ns);
    
    stimuli_p: process is
        variable write_data : std_logic_vector (31 downto 0) := (others => '0');
        variable read_data : std_logic_vector (31 downto 0) := (others => '0');
        
        variable ctrl_length : std_logic_vector(5 downto 0) := (others => '0');
        variable ctrl_reg_addr : std_logic_vector(7 downto 0) := (others => '0');
        variable ctrl_targ_addr : std_logic_vector(6 downto 0) := (others => '0');
        variable ctrl_go_rwn : std_logic_vector(1 downto 0) := (others => '0'); -- for go and rwn flag
        variable bus_en : std_logic_vector(3 downto 0) := (others => '0');

        variable RV : RandomPType; --random variable
    begin
        Log("*** Start of AVMM Interface Testbench ***");
        RV.InitSeed(RV'instance_name);
        cov_length <= NewID("cov_length");
        cov_reg_addr <= NewID("cov_reg_addr");
        cov_targ_addr <= NewID("cov_targ_addr");
        cov_bus_en <= NewID("cov_bus_en");
        wait for 120 ns;
        AddBins(cov_length, GenBin(0, 63));
        AddBins(cov_reg_addr, GenBin(0, 255));
        AddBins(cov_targ_addr, GenBin(0, 127));
        Log("*** Testing ControlReg ***");
        loop
            ctrl_length := RV.RandSlv(0, 63, 6);
            ICover(cov_length, to_integer(unsigned(ctrl_length)));
            ctrl_reg_addr := RV.RandSlv(0, 255, 8);
            ICover(cov_reg_addr, to_integer(unsigned(ctrl_reg_addr)));
            ctrl_targ_addr := RV.RandSlv(0, 127, 7);
            ICover(cov_targ_addr, to_integer(unsigned(ctrl_targ_addr)));
            ctrl_go_rwn := RV.RandSlv(0, 3, 2);

            write_data(31) := ctrl_go_rwn(0);
            write_data(29 downto 24) := ctrl_length;
            write_data(23 downto 16) := ctrl_reg_addr;
            write_data(11 downto 5) := ctrl_targ_addr;
            write_data(4) := ctrl_go_rwn(1);

            AvmmWrite(avmm_trans_io, "00000", write_data, "1111");
            AvmmRead(avmm_trans_io, "00000", "1111", read_data);
            AffirmIfEqual(read_data, write_data);

            exit when IsCovered(cov_length) and IsCovered(cov_reg_addr) and IsCovered(cov_targ_addr);
        end loop;
        --soft reset
        AvmmWrite(avmm_trans_io, "00000", x"00000001", "1111");
        wait for 20 ns;

        Log("*** Testing StatusReg ***");  
        wait until rising_edge(clk_o); 
        for i in 3 downto 0 loop
            AvmmWrite(avmm_trans_io, "00001", std_logic_vector(to_unsigned(i, 32)), "0001");
            AvmmRead(avmm_trans_io, "00001", "1111", read_data);
            AffirmIfEqual(read_data, std_logic_vector(to_unsigned(i, 32)));
        end loop;

        -- soft reset
        AvmmWrite(avmm_trans_io, "00000", x"00000001", "1111");
        write_data := (others => '0');
        wait for 20 ns;
        log("*** Testing BusEnReg ***");
        AddBins(cov_bus_en, GenBin(0, 15));
        wait until rising_edge(clk_o);
        loop
            bus_en := RV.RandSlv(0, 15, 4);
            ICover(cov_bus_en, to_integer(unsigned(bus_en)));
            write_data(3 downto 0) := bus_en;
            AvmmWrite(avmm_trans_io, "00010", write_data, "1111");
            AvmmRead(avmm_trans_io, "00010", "1111", read_data);
            AffirmIfEqual(read_data, write_data);
            exit when IsCovered(cov_bus_en);
        end loop;
        std.env.stop;
    end process;
end architecture;

configuration AVMM_interface_tb of dut_harness is
  for harness_arc
    for dut_test_ctrl_inst: dut_test_ctrl
      use entity work.dut_test_ctrl(tb_avmm_interface_arc) ; 
    end for; 
  end for;
end configuration;