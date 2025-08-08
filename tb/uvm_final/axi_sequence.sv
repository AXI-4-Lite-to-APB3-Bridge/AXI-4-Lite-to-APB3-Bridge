
class axi_base_sequence extends uvm_sequence #(axi_transaction);
  
  `uvm_object_utils(axi_base_sequence)

  function new(string name = "axi_base_sequence");
    super.new(name);
  endfunction

endclass

// 1. Basic read/write sequence
class basic_sequence extends axi_base_sequence;
  
  `uvm_object_utils(basic_sequence)

  function new(string name = "basic_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction trans;
    
    // Write operations: continuous write and continous read
    repeat(50) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      //assert(trans.randomize() with {cmd == 1; addr inside {[0:32'h3FF]};});
       assert(trans.randomize() with {cmd == 1; addr inside {32'h0, 32'h1, 32'h2, 32'h3, 32'h4};});
      finish_item(trans);
    /*  
    end
    
    // Read operations
    repeat(50) begin
   */ 
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
//       assert(trans.randomize() with {cmd == 0; addr inside {[0:32'h3FF]};});
      assert(trans.randomize() with {cmd == 0; addr inside {32'h0, 32'h1, 32'h2, 32'h3, 32'h4};});
      finish_item(trans);
    end
  endtask

endclass

//2. Error sequence
class error_injection_sequence extends axi_base_sequence;
  
  `uvm_object_utils(error_injection_sequence)

  function new(string name = "error_injection_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction trans;
  
    // write with Invalid address range to trigger PSLVERR
    repeat(5) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize() with {cmd == 1; addr > 32'h3FF;});
      finish_item(trans);
    end
   
  endtask

endclass


//3. Reset 
class reset_sequence extends axi_base_sequence;
  
  `uvm_object_utils(reset_sequence)

  function new(string name = "reset_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_transaction trans;
    
    // Start some transactions
    repeat(3) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize());
      finish_item(trans);
    end
    
    #100ns;
    
    // Continue after reset
    repeat(5) begin
      trans = axi_transaction::type_id::create("trans");
      start_item(trans);
      assert(trans.randomize());
      finish_item(trans);
    end
  endtask

endclass




