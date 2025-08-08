class axi_transaction extends uvm_sequence_item;
  
  rand bit [31:0] addr;
  rand bit [31:0] data;
  bit [3:0]  strb = 4'b1111;   //  strobe constant 0xf
  rand bit        cmd;        // 0: read, 1: write
  bit [1:0]       resp = 2'b00;
  bit [31:0]      rdata;
  
  typedef enum bit {
  READ  = 1'b0,
  WRITE = 1'b1
} axi_cmd_e;

 
  /*constraint addr_range_c {
//     addr < 32'h1000;  
    addr inside {32'h0, 32'h1, 32'h2, 32'h3, 32'h4};
  }*/


  `uvm_object_utils_begin(axi_transaction)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(strb, UVM_ALL_ON)
    `uvm_field_int(cmd, UVM_ALL_ON)
    `uvm_field_int(resp, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "axi_transaction");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("AXI: cmd=%0s addr=0x%0h data=0x%0h strb=0x%0h resp=%0d", 
                     cmd ? "WRITE" : "READ", addr, data, strb, resp);
  endfunction

endclass
