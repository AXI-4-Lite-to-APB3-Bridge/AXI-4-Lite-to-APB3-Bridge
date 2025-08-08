
class axi_monitor extends uvm_monitor;
  
  `uvm_component_utils(axi_monitor)
  typedef enum bit {
  READ  = 1'b0,
  WRITE = 1'b1
} axi_cmd_e;
  virtual axi_interface vif;
  uvm_analysis_port #(axi_transaction) item_collected_port;
  
  axi_transaction trans_collected;

  function new(string name = "axi_monitor", uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(virtual axi_interface)::get(this, "", "axi_vif", vif);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      forever collect_write_transaction();
      forever collect_read_transaction();
    join
  endtask

  virtual task collect_write_transaction();
    axi_transaction trans;
    forever begin
      @(posedge vif.clk);
      
      // Capture on valid handshake completion
      if (vif.awvalid && vif.awready && vif.wvalid && vif.wready) begin
        trans = axi_transaction::type_id::create("trans");
        trans.cmd = WRITE;  
        trans.addr = vif.awaddr;
        trans.data = vif.wdata;
        trans.strb = vif.wstrb;
        
        // Wait for response
        @(posedge vif.bvalid && vif.bready);
        trans.resp = vif.bresp;
        
        `uvm_info("axi_monitor", $sformatf("AXI Write Monitor: %s", trans.convert2string()), UVM_MEDIUM)
        item_collected_port.write(trans);  
      end
    end
  endtask

  virtual task collect_read_transaction();
    //collect read address
    @(vif.monitor_cb iff (vif.monitor_cb.arvalid && vif.monitor_cb.arready));
    trans_collected = axi_transaction::type_id::create("trans_collected");
    
    trans_collected.addr = vif.monitor_cb.araddr;
    trans_collected.cmd = READ;  
    
    // Collect read data and resp
    @(vif.monitor_cb iff (vif.monitor_cb.rvalid && vif.monitor_cb.rready));
    trans_collected.rdata = vif.monitor_cb.rdata;
    trans_collected.resp = vif.monitor_cb.rresp;
    
    `uvm_info(get_type_name(), $sformatf("AXI Read Monitor: %s", trans_collected.convert2string()), UVM_MEDIUM)
    item_collected_port.write(trans_collected);
  endtask

endclass
