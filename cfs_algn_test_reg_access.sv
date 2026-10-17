///////////////////////////////////////////////////////////////////////////////
// File:        cfs_algn_test_reg_access.sv
// Author:      Cristian Florin Slav
// Date:        2023-06-27
// Description: Register access test. It targets APB accesses to the registers
//              of the Aligner module.
///////////////////////////////////////////////////////////////////////////////
`ifndef CFS_ALGN_TEST_REG_ACCESS_SV
  `define CFS_ALGN_TEST_REG_ACCESS_SV

  class cfs_algn_test_reg_access extends cfs_algn_test_base;

    `uvm_component_utils(cfs_algn_test_reg_access)
    
    function new(string name = "", uvm_component parent);
      super.new(name, parent);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this, "TEST_DONE");
      
      #(100ns);
      
      fork
        begin
          cfs_apb_vif vif = env.apb_agent.agent_config.get_vif();
          
          repeat(3) begin
            @(posedge vif.psel);
          end
          
          #(11ns);
          
          vif.preset_n <= 0;
          
          repeat(4) begin
            @(posedge vif.pclk);
          end
          
          vif.preset_n <= 1;
          
        end
        begin
          cfs_apb_sequence_simple seq_simple = cfs_apb_sequence_simple::type_id::create("seq_simple");

          void'(seq_simple.randomize() with {
            item.addr == 'h0;
            item.dir  == CFS_APB_WRITE;
            item.data == 'h0011;
          });

           seq_simple.start(env.apb_agent.sequencer);
        end

        begin
          cfs_apb_sequence_rw seq_rw = cfs_apb_sequence_rw::type_id::create("seq_rw");

          void'(seq_rw.randomize() with {
            addr == 'hC;
          });

           seq_rw.start(env.apb_agent.sequencer);
        end

        begin
          cfs_apb_sequence_random seq_random = cfs_apb_sequence_random::type_id::create("seq_random");

          void'(seq_random.randomize() with {
            num_items == 3;
          });

           seq_random.start(env.apb_agent.sequencer);
        end
      join
      
      begin
        cfs_apb_sequence_random seq_random = cfs_apb_sequence_random::type_id::create("seq_random");

        void'(seq_random.randomize() with {
          num_items == 3;
        });

        seq_random.start(env.apb_agent.sequencer);
      end
      
      #(100ns);
      
      `uvm_info("DEBUG", "this is the end of the test", UVM_LOW)
      
      phase.drop_objection(this, "TEST_DONE"); 
    endtask
    
  endclass

`endif