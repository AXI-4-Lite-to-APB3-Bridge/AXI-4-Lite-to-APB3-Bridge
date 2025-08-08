
class axi_driver extends uvm_driver #(axi_transaction);
  
  `uvm_component_utils(axi_driver)
  
  virtual axi_interface vif;   
  
  function new(string name = "axi_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    uvm_config_db#(virtual axi_interface)::get(this, "", "axi_vif", vif);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(axi_transaction trans);
    if (trans.cmd) begin
      drive_write(trans);
    end else begin
      drive_read(trans);
    end
  endtask

  virtual task drive_write(axi_transaction trans);
    `uvm_info(get_type_name(), $sformatf("Driving AXI Write: addr=0x%0h data=0x%0h", trans.addr, trans.data), UVM_MEDIUM)
    
    // Write Address and Data Phase 
    fork
      begin
        repeat(50) @(vif.master_cb);
        vif.master_cb.awaddr  <= trans.addr;
        vif.master_cb.awvalid <= 1'b1;
        @(vif.master_cb iff vif.master_cb.awready); 
        @(vif.master_cb);
        vif.master_cb.awvalid <= 1'b0;
      end
      begin
        repeat(50) @(vif.master_cb); 
        vif.master_cb.wdata  <= trans.data;
        vif.master_cb.wstrb  <= trans.strb;
        vif.master_cb.wvalid <= 1'b1;
        @(vif.master_cb iff vif.master_cb.wready);  
        @(vif.master_cb);
        vif.master_cb.wvalid <= 1'b0;
      end
    join
    
    // Write Response Phase
    vif.master_cb.bready <= 1'b1;
    @(vif.master_cb iff vif.master_cb.bvalid);  
    trans.resp = vif.master_cb.bresp;
    @(vif.master_cb);
    vif.master_cb.bready <= 1'b0;
    
    `uvm_info(get_type_name(), $sformatf("AXI Write completed: resp=%0d", trans.resp), UVM_MEDIUM)
  endtask
  
  virtual task drive_read(axi_transaction trans);
  `uvm_info(get_type_name(), $sformatf("Driving AXI Read: addr=0x%0h", trans.addr), UVM_MEDIUM)
  
  // Read Address Phase
  repeat(10) @(vif.master_cb);
  vif.master_cb.araddr  <= trans.addr;
  vif.master_cb.arvalid <= 1'b1;
  @(vif.master_cb iff vif.master_cb.arready);
  @(vif.master_cb);
  vif.master_cb.arvalid <= 1'b0;
  
  `uvm_info(get_type_name(), $sformatf("AXI Address Phase completed: addr=0x%0h", trans.addr), UVM_MEDIUM)
  
  vif.master_cb.rready <= 1'b1;
  fork
    begin
      @(vif.master_cb iff vif.master_cb.rvalid);
      `uvm_info(get_type_name(), $sformatf("RVALID received for addr=0x%0h", trans.addr), UVM_HIGH)
    end
    begin
    
      repeat(1000) @(vif.master_cb);
      `uvm_fatal("DRIVER_TIMEOUT", $sformatf("Timeout waiting for RVALID on read addr=0x%0h. Check if DUT asserts rvalid correctly.", trans.addr))
    end
  join_any
  disable fork;
  
  // Sample read data and response
  trans.rdata = vif.master_cb.rdata;
  trans.resp  = vif.master_cb.rresp;
  
  
  @(vif.master_cb);
  vif.master_cb.rready <= 1'b0;
  
  `uvm_info(get_type_name(), $sformatf("AXI Read completed: addr=0x%0h data=0x%0h resp=%0d", trans.addr, trans.rdata, trans.resp), UVM_MEDIUM)
endtask

 

endclass
