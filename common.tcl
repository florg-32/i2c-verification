vmap -c
source ../osvvm/Scripts/StartUp.tcl

set osvvm_libs $::osvvm::ToolNameVersion
if {[file exist "VHDL_LIBS/$osvvm_libs/osvvm.lib"] && [file exist "VHDL_LIBS/$osvvm_libs/OSVVM_Common.lib"]} {
  puts "OSVVM exists. Skipping."
} else {
  puts "Building OSVVM"
  build ../osvvm/OsvvmLibraries.pro
}

library common_lib
analyze ../common/common_pkg.vhd
puts ""
puts ""