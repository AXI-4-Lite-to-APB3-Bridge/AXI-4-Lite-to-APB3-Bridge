
class axi_base_sequence extends uvm_sequence #(axi_transaction);
  
  `uvm_object_utils(axi_base_sequence)

  function new(string name = "axi_base_sequence");
    super.new(name);
  endfunction

endclass

// Basic read/write sequence
class basic_sequence extends axi_base_sequence;
  
  `uvm_object_utils(basic_sequence)

  function new(string name = "basic_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction trans;
    
    // Write operations
    repeat(5) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {cmd == 1; addr inside {[0:32'h3FF]};});
      finish_item(trans);
    end
    
    // Read operations
    repeat(5) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {cmd == 0; addr inside {[0:32'h3FF]};});
      finish_item(trans);
    end
  endtask

endclass



class reset_sequence extends axi_base_sequence;
  `uvm_object_utils(reset_sequence)
  
  function new(string name = "reset_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction trans;
    
    `uvm_info(get_type_name(), "=== RESET TEST STARTED ===", UVM_LOW)
    
    // Transactions BEFORE reset
    `uvm_info(get_type_name(), "Phase 1: Running transactions before reset", UVM_LOW)
    repeat(2) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {cmd == 1; addr inside {[0:32'h3FF]};});
      finish_item(trans);
      #100ns;
    end
    
   
   // `uvm_info(get_type_name(), "Waiting for reset to complete...", UVM_LOW)
    #600ns; // Wait for reset to occur and complete
    
    //  Transactions AFTER reset
    `uvm_info(get_type_name(), "Phase 3: Running transactions after reset", UVM_LOW)
    repeat(3) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {cmd == 1; addr inside {[0:32'h3FF]};});
      finish_item(trans);
      #100ns;
    end
    //cmd = 1
    
    `uvm_info(get_type_name(), "=== RESET TEST COMPLETED ===", UVM_LOW)
  endtask
endclass





//Invalid address error 
class error_injection_sequence extends axi_base_sequence;
  
  `uvm_object_utils(error_injection_sequence)

  function new(string name = "error_injection_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction trans;
    
    // Valid transactions
    repeat(3) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {addr inside {[0:32'h25]};});
      finish_item(trans);
    end
    
    // Invalid address range to trigger PSLVERR
    repeat(3) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {addr inside {[32'h1A:32'h30]};});
      finish_item(trans);
    end
  endtask

endclass


