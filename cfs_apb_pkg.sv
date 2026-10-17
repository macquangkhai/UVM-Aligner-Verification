///////////////////////////////////////////////////////////////////////////////
// File:        cfs_apb_pkg.sv
// Author:      Cristian Florin Slav
// Date:        2023-07-05
// Description: APB Agent package.
///////////////////////////////////////////////////////////////////////////////
`ifndef CFS_APB_PKG_SV
  `define CFS_APB_PKG_SV

  `include "uvm_macros.svh"

  `include "cfs_apb_if.sv"

  package cfs_apb_pkg;
    import uvm_pkg::*;

    //Virtual interface type
    typedef virtual cfs_apb_if cfs_apb_vif;

    //APB direction
    typedef enum bit {CFS_APB_READ = 0, CFS_APB_WRITE = 1} cfs_apb_dir;

    //APB address
    typedef bit[`CFS_APB_MAX_ADDR_WIDTH-1:0] cfs_apb_addr;

    //APB data
    typedef bit[`CFS_APB_MAX_DATA_WIDTH-1:0] cfs_apb_data;

    //APB response
    typedef enum bit {CFS_APB_OKAY = 0, CFS_APB_ERR = 1} cfs_apb_response;

    interface class cfs_apb_reset_handler;

      //Function to handle the reset
      pure virtual function void handle_reset(uvm_phase phase);

    endclass

    class cfs_apb_item_base extends uvm_sequence_item;

      //Direction
      rand cfs_apb_dir dir;

      //Address
      rand cfs_apb_addr addr;

      //Data
      rand cfs_apb_data data;

      `uvm_object_utils(cfs_apb_item_base)

      function new(string name = "");
        super.new(name);
      endfunction

      virtual function string convert2string();
        string result = $sformatf("dir: %0s, addr: %0x", dir.name(), addr);

        return result;
      endfunction

    endclass

    class cfs_apb_item_drv extends cfs_apb_item_base;

      //Pre drive delay
      rand int unsigned pre_drive_delay;

      //Post drive delay
      rand int unsigned post_drive_delay;

      constraint pre_drive_delay_default {
        soft pre_drive_delay <= 5;
      }

      constraint post_drive_delay_default {
        soft post_drive_delay <= 5;
      }

      `uvm_object_utils(cfs_apb_item_drv)

      function new(string name = "");
        super.new(name);
      endfunction

      virtual function string convert2string();
        string result = super.convert2string();

        if(dir == CFS_APB_WRITE) begin
          result = $sformatf("%s, data: %0x", result, data);
        end

        result = $sformatf("%s, pre_drive_delay: %0d, post_drive_delay: %0d", 
                           result, pre_drive_delay, post_drive_delay);

        return result;
      endfunction

    endclass

    class cfs_apb_item_mon extends cfs_apb_item_base;

      //Response
      cfs_apb_response response;

      //Lenght, in clock cycles, of the APB transfer
      int unsigned length;

      //Number of clock cycles from the previous item
      int unsigned prev_item_delay;

      `uvm_object_utils(cfs_apb_item_mon)

      function new(string name = "");
        super.new(name);
      endfunction

      virtual function string convert2string();
        string result = super.convert2string();

        result = $sformatf("%s, data: %0x, response: %0s, length: %0d, prev_item_delay: %0d",
                           result, data, response.name(), length, prev_item_delay);

        return result;
      endfunction

    endclass

    class cfs_apb_agent_config extends uvm_component;

      //Virtual interface
      local cfs_apb_vif vif;

      //Active/Passive control
      local uvm_active_passive_enum active_passive;

      //Switch to enable coverage
      local bit has_coverage;

      //Switch to enable checks
      local bit has_checks;

      //Number of clock cycles after which an APB transfer is considered
      //stuck and an error is triggered
      local int unsigned stuck_threshold;

      `uvm_component_utils(cfs_apb_agent_config)

      function new(string name = "", uvm_component parent);
        super.new(name, parent);

        active_passive  = UVM_ACTIVE;
        has_coverage    = 1;
        has_checks      = 1;
        stuck_threshold = 1000;
      endfunction

      //Getter for the APB virtual interface
      virtual function cfs_apb_vif get_vif();
        return vif;
      endfunction

      //Setter for the APB virtual interface
      virtual function void set_vif(cfs_apb_vif value);
        if(vif == null) begin
          vif = value;

          set_has_checks(get_has_checks());
        end
        else begin
          `uvm_fatal("ALGORITHM_ISSUE", "Trying to set the APB virtual interface more than once")
        end
      endfunction

      //Getter for the APB Active/Passive control
      virtual function uvm_active_passive_enum get_active_passive();
        return active_passive;
      endfunction

      //Setter for the APB Active/Passive control
      virtual function void set_active_passive(uvm_active_passive_enum value);
        active_passive = value;
      endfunction

      //Getter for the has_coverage control field
      virtual function bit get_has_coverage();
        return has_coverage;
      endfunction

      //Setter for the has_coverage control field
      virtual function void set_has_coverage(bit value);
        has_coverage = value;
      endfunction

      //Getter for the has_checks control field
      virtual function bit get_has_checks();
        return has_checks;
      endfunction

      //Setter for the has_checks control field
      virtual function void set_has_checks(bit value);
        has_checks = value;

        if(vif != null) begin
          vif.has_checks = has_checks;
        end
      endfunction

      //Getter for the stuck threshold
      virtual function int unsigned get_stuck_threshold();
        return stuck_threshold;
      endfunction

      //Setter for stuck threshold
      virtual function void set_stuck_threshold(int unsigned value);
        if(value <= 2) begin
          `uvm_error("ALGORITHM_ISSUE", $sformatf("Tried to set stuck_threshold to value %d but the minimum length of an APB transfer is 2", value))
        end

        stuck_threshold = value;
      endfunction

      virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);

        if(get_vif() == null) begin
          `uvm_fatal("ALGORITHM_ISSUE", "The APB virtual interface is not configured at \"Start of simulation\" phase")
        end
        else begin
          `uvm_info("APB_CONFIG", "The APB virtual interface is configured at \"Start of simulation\" phase", UVM_DEBUG)
        end
      endfunction

      virtual task run_phase(uvm_phase phase);
        forever begin
          @(vif.has_checks);

          if(vif.has_checks != get_has_checks()) begin
            `uvm_error("ALGORITHM_ISSUE", $sformatf("Can not change \"has_checks\" from APB interface directly - use %0s.set_has_checks()", get_full_name()))
          end
        end
      endtask

      //Task for waiting the reset to start
      virtual task wait_reset_start();
        if(vif.preset_n !== 0) begin
          @(negedge vif.preset_n);
        end
      endtask

      //Task for waiting the reset to be finished
      virtual task wait_reset_end();
        while(vif.preset_n == 0) begin
          @(posedge vif.pclk);
        end
      endtask

    endclass

    class cfs_apb_monitor extends uvm_monitor implements cfs_apb_reset_handler;

      //Pointer to agent configuration
      cfs_apb_agent_config agent_config;

      //Port for sending the collected item
      uvm_analysis_port#(cfs_apb_item_mon) output_port;

      //Process for collect_transactions() task
      protected process process_collect_transactions;

      `uvm_component_utils(cfs_apb_monitor)

      function new(string name = "", uvm_component parent);
        super.new(name, parent);

        output_port = new("output_port", this);
      endfunction

      virtual task run_phase(uvm_phase phase);
        forever begin
          fork
            begin
              wait_reset_end();
              collect_transactions();

              disable fork;
            end 
          join
        end
      endtask

      //Task which drives one single item on the bus
      protected virtual task collect_transaction();
        cfs_apb_vif vif = agent_config.get_vif();
        cfs_apb_item_mon item = cfs_apb_item_mon::type_id::create("item");

        while(vif.psel !== 1) begin
          @(posedge vif.pclk);
          item.prev_item_delay++;
        end

        item.addr   = vif.paddr;
        item.dir    = cfs_apb_dir'(vif.pwrite);
        item.length = 1;

        if(item.dir == CFS_APB_WRITE) begin
          item.data = vif.pwdata;
        end

        @(posedge vif.pclk);
        item.length++;

        while(vif.pready !== 1) begin
          @(posedge vif.pclk);
          item.length++;

          if(agent_config.get_has_checks()) begin
            if(item.length >= agent_config.get_stuck_threshold()) begin
              `uvm_error("PROTOCOL_ERROR", $sformatf("The APB transfer reached the stuck threshold value of %0d", item.length))
            end
          end
        end

        item.response = cfs_apb_response'(vif.pslverr);

        if(item.dir == CFS_APB_READ) begin
          item.data = vif.prdata;
        end

        output_port.write(item);

        `uvm_info("DEBUG", $sformatf("Monitored item:: %0s", item.convert2string()), UVM_NONE)

        @(posedge vif.pclk);
      endtask

      //Task for collecting all transactions
      protected virtual task collect_transactions();
        fork
          begin
            process_collect_transactions = process::self();

            forever begin
              collect_transaction();
            end

          end
        join
      endtask

      //Task for waiting the reset to be finished
      protected virtual task wait_reset_end();
        agent_config.wait_reset_end();
      endtask

      //Function to handle the reset
      virtual function void handle_reset(uvm_phase phase);
        if(process_collect_transactions != null) begin
          process_collect_transactions.kill();

          process_collect_transactions = null;
        end
      endfunction

    endclass

    `uvm_analysis_imp_decl(_item)

    virtual class cfs_apb_cover_index_wrapper_base extends uvm_component;

      function new(string name = "", uvm_component parent);
        super.new(name, parent);
      endfunction

      //Function used to sample the information
      pure virtual function void sample(int unsigned value);

      //Function to print the coverage information.
      //This is only to be able to visualize some basic coverage information
      //in EDA Playground.
      //DON'T DO THIS IN A REAL PROJECT!!!
      pure virtual function string coverage2string();   
    endclass

    //Wrapper over the covergroup which covers indices.
    //The MAX_VALUE parameter is used to determine the maximum value to sample
    class cfs_apb_cover_index_wrapper#(int unsigned MAX_VALUE_PLUS_1 = 16) extends cfs_apb_cover_index_wrapper_base;

      `uvm_component_param_utils(cfs_apb_cover_index_wrapper#(MAX_VALUE_PLUS_1))

      covergroup cover_index with function sample(int unsigned value);
        option.per_instance = 1;

        index : coverpoint value {
          option.comment = "Index";
          bins values[MAX_VALUE_PLUS_1] = {[0:MAX_VALUE_PLUS_1-1]};
        }

      endgroup

      function new(string name = "", uvm_component parent);
        super.new(name, parent);

        cover_index = new();
        cover_index.set_inst_name($sformatf("%s_%s", get_full_name(), "cover_index"));
      endfunction

      //Function to print the coverage information.
      //This is only to be able to visualize some basic coverage information
      //in EDA Playground.
      //DON'T DO THIS IN A REAL PROJECT!!!
      virtual function string coverage2string();
        return {
          $sformatf("\n   cover_index:              %03.2f%%", cover_index.get_inst_coverage()),
          $sformatf("\n      index:                 %03.2f%%", cover_index.index.get_inst_coverage())
        };
      endfunction

      //Function used to sample the information
      virtual function void sample(int unsigned value);
        cover_index.sample(value);
      endfunction

    endclass

    class cfs_apb_coverage extends uvm_component implements cfs_apb_reset_handler;

      //Pointer to agent configuration
      cfs_apb_agent_config agent_config;

      //Port for sending the collected item
      uvm_analysis_imp_item#(cfs_apb_item_mon, cfs_apb_coverage) port_item;

      //Wrapper over the coverage group covering the indices in the PADDR signal
      //at which the bit of the PADDR was 0
      cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_ADDR_WIDTH) wrap_cover_addr_0;

      //Wrapper over the coverage group covering the indices in the PADDR signal
      //at which the bit of the PADDR was 1
      cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_ADDR_WIDTH) wrap_cover_addr_1;

      //Wrapper over the coverage group covering the indices in the PWDATA signal
      //at which the bit of the PWDATA was 0
      cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH) wrap_cover_wr_data_0;

      //Wrapper over the coverage group covering the indices in the PWDATA signal
      //at which the bit of the PWDATA was 1
      cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH) wrap_cover_wr_data_1;

      //Wrapper over the coverage group covering the indices in the PRDATA signal
      //at which the bit of the PRDATA was 0
      cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH) wrap_cover_rd_data_0;

      //Wrapper over the coverage group covering the indices in the PRDATA signal
      //at which the bit of the PRDATA was 1
      cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH) wrap_cover_rd_data_1;

      `uvm_component_utils(cfs_apb_coverage)

      covergroup cover_item with function sample(cfs_apb_item_mon item);
        option.per_instance = 1;

        direction : coverpoint item.dir {
          option.comment = "Direction of the APB access";
        }

        response : coverpoint item.response {
          option.comment = "Response of the APB access";
        }

        length : coverpoint item.length {
          option.comment = "Length of the APB access";
          bins length_eq_2     = {2};
          bins length_le_10[8] = {[3:10]};
          bins length_gt_10    = {[11:$]};

          illegal_bins length_lt_2 = {[$:1]};
        }

        prev_item_delay : coverpoint item.prev_item_delay {
          option.comment = "Delay, in clock cycles, between two consecutive APB accesses";
          bins back2back       = {0};
          bins delay_le_5[5]   = {[1:5]};
          bins delay_gt_5      = {[6:$]};
        }

        response_x_direction : cross response, direction;

        trans_direction : coverpoint item.dir {
          option.comment = "Transitions of APB direction";
          bins direction_trans[] = (CFS_APB_READ, CFS_APB_WRITE => CFS_APB_READ, CFS_APB_WRITE);
        }

      endgroup

      covergroup cover_reset with function sample(bit psel);
        option.per_instance = 1;

        access_ongoing : coverpoint psel {
          option.comment = "An APB access was ongoing at reset";
        }
      endgroup

      function new(string name = "", uvm_component parent);
        super.new(name, parent);

        port_item = new("port_item", this);

        cover_item = new();
        cover_item.set_inst_name($sformatf("%s_%s", get_full_name(), "cover_item"));

        cover_reset = new();
        cover_reset.set_inst_name($sformatf("%s_%s", get_full_name(), "cover_reset"));
      endfunction

      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        wrap_cover_addr_0    = cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_ADDR_WIDTH)::type_id::create("wrap_cover_addr_0",    this);
        wrap_cover_addr_1    = cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_ADDR_WIDTH)::type_id::create("wrap_cover_addr_1",    this);
        wrap_cover_wr_data_0 = cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH)::type_id::create("wrap_cover_wr_data_0", this);
        wrap_cover_wr_data_1 = cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH)::type_id::create("wrap_cover_wr_data_1", this);
        wrap_cover_rd_data_0 = cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH)::type_id::create("wrap_cover_rd_data_0", this);
        wrap_cover_rd_data_1 = cfs_apb_cover_index_wrapper#(`CFS_APB_MAX_DATA_WIDTH)::type_id::create("wrap_cover_rd_data_1", this);
      endfunction

      //Port associated with port_item port
      virtual function void write_item(cfs_apb_item_mon item);
        cover_item.sample(item);

        for(int i = 0; i < `CFS_APB_MAX_ADDR_WIDTH; i++) begin
          if(item.addr[i]) begin
            wrap_cover_addr_1.sample(i);
          end
          else begin
            wrap_cover_addr_0.sample(i);
          end
        end

        for(int i = 0; i < `CFS_APB_MAX_DATA_WIDTH; i++) begin
          case(item.dir)
            CFS_APB_WRITE : begin
              if(item.data[i]) begin
                wrap_cover_wr_data_1.sample(i);
              end
              else begin
                wrap_cover_wr_data_0.sample(i);
              end
            end
            CFS_APB_READ : begin
              if(item.data[i]) begin
                wrap_cover_rd_data_1.sample(i);
              end
              else begin
                wrap_cover_rd_data_0.sample(i);
              end
            end
            default : begin
              `uvm_error("ALGORITHM_ISSUE", $sformatf("Current version of the code does not support item.dir: %0s", item.dir.name()))
            end
          endcase
        end

        //IMPORTANT: DON'T DO THIS IN A REAL PROJECT!!!
        //`uvm_info("DEBUG", $sformatf("Coverage: %0s", coverage2string()), UVM_NONE)
      endfunction

      //Function to handle the reset
      virtual function void handle_reset(uvm_phase phase);
        cfs_apb_vif vif = agent_config.get_vif();

        cover_reset.sample(vif.psel);
      endfunction

      //Function to print the coverage information.
      //This is only to be able to visualize some basic coverage information
      //in EDA Playground.
      //DON'T DO THIS IN A REAL PROJECT!!!
      virtual function string coverage2string();
        string result = {
          $sformatf("\n   cover_item:              %03.2f%%", cover_item.get_inst_coverage()),
          $sformatf("\n      direction:            %03.2f%%", cover_item.direction.get_inst_coverage()),
          $sformatf("\n      trans_direction:      %03.2f%%", cover_item.trans_direction.get_inst_coverage()),
          $sformatf("\n      response:             %03.2f%%", cover_item.response.get_inst_coverage()),
          $sformatf("\n      response_x_direction: %03.2f%%", cover_item.response_x_direction.get_inst_coverage()),
          $sformatf("\n      length:               %03.2f%%", cover_item.length.get_inst_coverage()),
          $sformatf("\n      prev_item_delay:      %03.2f%%", cover_item.prev_item_delay.get_inst_coverage()),
          $sformatf("\n                                    "),
          $sformatf("\n   cover_reset:             %03.2f%%", cover_reset.get_inst_coverage()),
          $sformatf("\n      access_ongoing:       %03.2f%%", cover_reset.access_ongoing.get_inst_coverage())
        };

        uvm_component children[$];

        get_children(children);

        foreach(children[idx]) begin
          cfs_apb_cover_index_wrapper_base wrapper;

          if($cast(wrapper, children[idx])) begin
            result = $sformatf("%s\n\nChild component: %0s%0s", result, wrapper.get_name(), wrapper.coverage2string());
          end
        end

        return result;
      endfunction

    endclass

    class cfs_apb_driver extends uvm_driver#(.REQ(cfs_apb_item_drv)) implements cfs_apb_reset_handler;

      //Pointer to agent configuration
      cfs_apb_agent_config agent_config;

      //process for drive_transactions() task
      protected process process_drive_transactions;

      `uvm_component_utils(cfs_apb_driver)

      function new(string name = "", uvm_component parent);
        super.new(name, parent);
      endfunction

      virtual task run_phase(uvm_phase phase);
        forever begin
          fork
            begin
              wait_reset_end();
              drive_transactions();

              disable fork;
            end
          join
        end
      endtask

      //Task which drives one single item on the bus
      protected virtual task drive_transaction(cfs_apb_item_drv item);
        cfs_apb_vif vif = agent_config.get_vif();

        `uvm_info("DEBUG", $sformatf("Driving \"%0s\": %0s", item.get_full_name(), item.convert2string()), UVM_NONE)

        for(int i = 0; i < item.pre_drive_delay; i++) begin
          @(posedge vif.pclk);
        end

        vif.psel   <= 1;
        vif.pwrite <= bit'(item.dir);
        vif.paddr  <= item.addr;

        if(item.dir == CFS_APB_WRITE) begin
          vif.pwdata <= item.data;
        end

        @(posedge vif.pclk);

        vif.penable <= 1;

        @(posedge vif.pclk);

        while(vif.pready !== 1) begin
          @(posedge vif.pclk);
        end

        vif.psel    <= 0;
        vif.penable <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;

        for(int i = 0; i < item.post_drive_delay; i++) begin
          @(posedge vif.pclk);
        end
      endtask

      //Task for driving all transactions
      protected virtual task drive_transactions();

        fork
          begin
            process_drive_transactions = process::self();

            forever begin
              cfs_apb_item_drv item;

              seq_item_port.get_next_item(item);

              drive_transaction(item);

              seq_item_port.item_done();
            end
          end
        join
      endtask

      //Task for waiting the reset to be finished
      protected virtual task wait_reset_end();
        agent_config.wait_reset_end();
      endtask

      //Function to handle the reset
      virtual function void handle_reset(uvm_phase phase);
        cfs_apb_vif vif = agent_config.get_vif();

        if(process_drive_transactions != null) begin
          process_drive_transactions.kill();

          process_drive_transactions = null;
        end

        //Initialize the signals
        vif.psel    <= 0;
        vif.penable <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;
      endfunction


    endclass

    class cfs_apb_sequencer extends uvm_sequencer#(.REQ(cfs_apb_item_drv)) implements cfs_apb_reset_handler;

      `uvm_component_utils(cfs_apb_sequencer)

      function new(string name = "", uvm_component parent);
        super.new(name, parent);
      endfunction

      virtual function void handle_reset(uvm_phase phase);
        int objections_count;
        stop_sequences();

        objections_count = uvm_test_done.get_objection_count(this);

        if(objections_count > 0) begin
          uvm_test_done.drop_objection(this, $sformatf("Dropping %0d objections at reset", objections_count), objections_count);
        end

        start_phase_sequence(phase);
      endfunction

    endclass

    class cfs_apb_agent extends uvm_agent implements cfs_apb_reset_handler;

      //Agent configuration handler
      cfs_apb_agent_config agent_config;

      //Driver handler
      cfs_apb_driver driver;

      //Sequencer handler
      cfs_apb_sequencer sequencer;

      //Monitor handler
      cfs_apb_monitor monitor;

      //Coverage handler
      cfs_apb_coverage coverage;

      `uvm_component_utils(cfs_apb_agent)

      function new(string name = "", uvm_component parent);
        super.new(name, parent);
      endfunction

      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent_config = cfs_apb_agent_config::type_id::create("agent_config", this);

        monitor = cfs_apb_monitor::type_id::create("monitor", this);

        if(agent_config.get_has_coverage()) begin
          coverage = cfs_apb_coverage::type_id::create("coverage", this);
        end

        if(agent_config.get_active_passive() == UVM_ACTIVE) begin
          driver    = cfs_apb_driver::type_id::create("driver", this);
          sequencer = cfs_apb_sequencer::type_id::create("sequencer", this);
        end
      endfunction

      virtual function void connect_phase(uvm_phase phase);
        cfs_apb_vif vif;
        string      vif_name = "vif";

        super.connect_phase(phase);

        if(!uvm_config_db#(virtual cfs_apb_if)::get(this, "", vif_name, vif)) begin
          `uvm_fatal("APB_NO_VIF", $sformatf("Could not get from the database the APB virtual interface using name \"%0s\"", vif_name))
        end
        else begin
          agent_config.set_vif(vif);
        end

        monitor.agent_config = agent_config;

        if(agent_config.get_has_coverage()) begin
          coverage.agent_config = agent_config;

          monitor.output_port.connect(coverage.port_item);
        end

        if(agent_config.get_active_passive() == UVM_ACTIVE) begin
          driver.seq_item_port.connect(sequencer.seq_item_export);

          driver.agent_config = agent_config;
        end
      endfunction

      //Task for waiting the reset to start
      protected virtual task wait_reset_start();
        agent_config.wait_reset_start();
      endtask

      //Task for waiting the reset to be finished
      protected virtual task wait_reset_end();
        agent_config.wait_reset_end();
      endtask

      //Function to handle the reset
      virtual function void handle_reset(uvm_phase phase);
        uvm_component children[$];

        get_children(children);

        foreach(children[idx]) begin
          cfs_apb_reset_handler reset_handler;

          if($cast(reset_handler, children[idx])) begin
            reset_handler.handle_reset(phase);
          end
        end
      endfunction

      virtual task run_phase(uvm_phase phase);
        forever begin
          wait_reset_start();
          handle_reset(phase);
          wait_reset_end();
        end
      endtask

    endclass

    class cfs_apb_sequence_base extends uvm_sequence#(.REQ(cfs_apb_item_drv));

      `uvm_declare_p_sequencer(cfs_apb_sequencer)

      `uvm_object_utils(cfs_apb_sequence_base)

      function new(string name = "");
        super.new(name);
      endfunction

    endclass

    class cfs_apb_sequence_simple extends cfs_apb_sequence_base;

      //Item to drive
      rand cfs_apb_item_drv item;

      `uvm_object_utils(cfs_apb_sequence_simple)

      function new(string name = "");
        super.new(name);

        item = cfs_apb_item_drv::type_id::create("item");
      endfunction

      virtual task body();
        `uvm_send(item)
      endtask

    endclass

    class cfs_apb_sequence_rw extends cfs_apb_sequence_base;

      //Address
      rand cfs_apb_addr addr;

      //Write data
      rand cfs_apb_data wr_data;

      `uvm_object_utils(cfs_apb_sequence_rw)

      function new(string name = "");
        super.new(name);
      endfunction

      virtual task body();

        //The above code can be replaced with `uvm_do macros
        cfs_apb_item_drv item;

        `uvm_do_with(item, {
          dir  == CFS_APB_READ;
          addr == local::addr;
        });

        `uvm_do_with(item, {
          dir  == CFS_APB_WRITE;
          addr == local::addr;
          data == wr_data;
        });

      endtask

    endclass

    class cfs_apb_sequence_random extends cfs_apb_sequence_base;

      //NUmber of items to drive
      rand int unsigned num_items;

      constraint num_items_default {
        soft num_items inside {[1:10]}; 
      }

      `uvm_object_utils(cfs_apb_sequence_random)

      function new(string name = "");
        super.new(name);
      endfunction

      virtual task body();
        for(int i = 0; i < num_items; i++) begin
          cfs_apb_sequence_simple seq = cfs_apb_sequence_simple::type_id::create("seq");
          
          `uvm_do(seq)
        end
      endtask

    endclass

  endpackage

`endif