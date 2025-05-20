library verification_project_lib

analyze ../vu/avmm_pkg.vhd
analyze ../vu/avmm_vu.vhd
analyze ../vu/i2c_pkg.vhd
analyze ../vu/i2c_vu.vhd

analyze ../dut/math_pkg.vhd
analyze ../dut/clock_crosser.vhd
analyze ../dut/i2c_multi_bus_controller_memory.vhd
analyze ../dut/i2c_multi_bus_controller.vhd

analyze dut_test_ctrl.vhd
analyze dut_harness.vhd
analyze tb_dut.vhd

simulate tb_dut