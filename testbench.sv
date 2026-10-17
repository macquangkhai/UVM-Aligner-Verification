///////////////////////////////////////////////////////////////////////////////
// File:        testbench.sv
// Author:      Cristian Florin Slav
// Date:        2023-06-27
// Description: Testbench module. It contains the instance of the DUT and the 
//              logic to start the UVM test and UVM phases.
///////////////////////////////////////////////////////////////////////////////
`include "cfs_algn_test_pkg.sv"

module testbench();
  
  import uvm_pkg::*;
  import cfs_algn_test_pkg::*;
  
  //CLock signal
  reg clk;
  
  //Clock generator
  initial begin
    clk = 0;
    
    forever begin
      //Generate an 100MHz clock
      clk = #5ns ~clk;
    end
  end
  
  //Instance of the APB interface
  cfs_apb_if apb_if(.pclk(clk));
  
  //Initial reset generator
  initial begin
    apb_if.preset_n = 1;
    
    #3ns;
    
    apb_if.preset_n = 0;
    
    #30ns;
    apb_if.preset_n = 1;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    
    uvm_config_db#(virtual cfs_apb_if)::set(null, "uvm_test_top.env.apb_agent", "vif", apb_if);
    
    //Start UVM test and phases
    run_test("");
  end
  
  //Instantiate the DUT
  cfs_aligner dut(
    .clk(    clk),
    .reset_n(apb_if.preset_n),
    
    .paddr(  apb_if.paddr),
    .pwrite( apb_if.pwrite),
    .psel(   apb_if.psel),
    .penable(apb_if.penable),
    .pwdata( apb_if.pwdata),
    .pready( apb_if.pready),
    .prdata( apb_if.prdata),
    .pslverr(apb_if.pslverr)
  );
  
  
endmodule
