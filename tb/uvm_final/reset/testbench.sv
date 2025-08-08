`timescale 1ns/1ps

`include "uvm_macros.svh"

`include "test_lib_pkg.sv"
import test_lib_pkg::*;

`timescale 1ns/1ps

module tb_top;
  
   
  bit aclk = 0;
  bit aresetn = 0;
  bit pclk = 0; 
  bit presetn_tb = 0;
  
  always #5 aclk = ~aclk;    // 100MHz AXI clock
  always #10 pclk = ~pclk;   // 50MHz APB clock
  
  axi_interface axi_if (aclk, ~aresetn);
  apb_interface apb_if (pclk, ~presetn_tb);
  
  // DUT instantiation 
  axi_to_apb_bridge #(
    .DATA_WIDTH(32),
    .ADDRESS(32),
    .FIFO_ASIZE(5)
  ) dut (
    .ACLK(aclk),
    .ARESETN(aresetn),
    .PCLK(pclk),
    .PRESETN(presetn_tb),
    
    // AXI4-Lite Interface 
    .S_ARADDR(axi_if.araddr),
    .S_ARVALID(axi_if.arvalid),
    .S_ARREADY(axi_if.arready),
    .S_RDATA(axi_if.rdata),
    .S_RRESP(axi_if.rresp),
    .S_RVALID(axi_if.rvalid),
    .S_RREADY(axi_if.rready),
    .S_AWADDR(axi_if.awaddr),
    .S_AWVALID(axi_if.awvalid),
    .S_AWREADY(axi_if.awready),
    .S_WDATA(axi_if.wdata),
    .S_WSTRB(axi_if.wstrb),
    .S_WVALID(axi_if.wvalid),
    .S_WREADY(axi_if.wready),
    .S_BRESP(axi_if.bresp),
    .S_BVALID(axi_if.bvalid),
    .S_BREADY(axi_if.bready),
    
    // APB3 Interface 
    .PSEL(apb_if.psel),
    .PENABLE(apb_if.penable),
    .PWRITE(apb_if.pwrite),
    .PADDR(apb_if.paddr),
    .PWDATA(apb_if.pwdata),
    .PRDATA(apb_if.prdata),
    .PREADY(apb_if.pready),
    .PSLVERR(apb_if.pslverr)
  );
  
  
  // Standalone APB Slave Memory Model
  apb_slave_memory apb_slave (
    .pclk(pclk),
    .presetn(presetn_tb),
    .psel(apb_if.psel),
    .penable(apb_if.penable),
    .pwrite(apb_if.pwrite),
    .paddr(apb_if.paddr),
    .pwdata(apb_if.pwdata),
    .prdata(apb_if.prdata),
    .pready(apb_if.pready),
    .pslverr(apb_if.pslverr)
  );
  
  
  // Reset 
  initial begin
    aresetn = 0;
    presetn_tb = 0;
    #50ns;
    aresetn = 1;
    presetn_tb = 1;
    `uvm_info("TB_TOP", "Reset released - starting  bridge test", UVM_NONE)
  end
  
  initial begin
    $dumpfile("axi2apb_bridge.vcd");
    $dumpvars(0, tb_top);
  end  
  
  initial begin
    
    uvm_config_db#(virtual axi_interface)::set(null,"*","axi_vif", axi_if);
    uvm_config_db#(virtual apb_interface)::set(null,"*","apb_vif", apb_if);

    uvm_config_db#(int)::set(null, "*", "recording_detail", UVM_FULL);
    
    `uvm_info("TB_TOP", "Starting UVM test AXI4-Lite to APB3 bridge", UVM_NONE)
    
//     run_test("axi2apb_base_test");
    run_test("axi2apb_reset_test");
    

  end

 //APB_slave memory model
  module apb_slave_memory(
  input logic pclk,
  input logic presetn,
  input logic psel,
  input logic penable,
  input logic pwrite,
  input logic [31:0] paddr,
  input logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic pready,
  output logic pslverr
);


  logic [31:0] memory [256];  // Support addresses 0x00 to 0xFF
  logic [7:0] word_addr;      // Word address (byte_addr / 4)
  

  initial begin
    for (int i = 0; i < 256; i++) begin
      memory[i] = 0;  // Distinctive pattern
      if (i < 32) begin  // Only print first 32 for clarity
        $display("memory[%0h] = 0x%0h", i, memory[i]);
      end
    end
    $display("APB Slave: Memory initialized with 256 locations");
  end


  assign word_addr = paddr[9:2];  // Extract word address (divide by 4)


  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      pready <= 1'b0;
      pslverr <= 1'b0;
      prdata <= 32'h0;
    end else begin
      if (psel && penable) begin
        pready <= 1'b1;
      
        if (paddr >= 32'h400 ) begin
          // Error if byte address >= 1024 (0x400) or not word-aligned
          pslverr <= 1'b1;
          $display("Time: %0t APB Slave ERROR: paddr=0x%0h out of bounds (>=0x400) or misaligned", 
                   $time, paddr);
        end else begin
          pslverr <= 1'b0;
          
          if (pwrite) begin
            // WRITE operation
            memory[word_addr] <= pwdata;
            $display("Time: %0t APB Slave WRITE: paddr=0x%0h (word_addr=%0d) data=0x%0h", 
                     $time, paddr, word_addr, pwdata);
          end else begin
            // READ operation 
            prdata <= memory[word_addr];
            $display("Time: %0t APB Slave READ: paddr=0x%0h (word_addr=%0d) data=0x%0h", 
                     $time, paddr, word_addr, memory[word_addr]);
          end
        end
      end else if (psel && !penable) begin
        // SETUP phase 
        pready <= 1'b0;
        pslverr <= 1'b0;
        if (!pwrite && paddr < 32'h400 && paddr[1:0] == 2'b00) begin
          prdata <= memory[word_addr];
        end
      end else begin
        // IDLE phase
        pready <= 1'b0;
        pslverr <= 1'b0;
       
      end
    end
  end


    task apply_reset_during_test();
  #800ns;
  `uvm_info("TB_TOP", "=== APPLYING RESET DURING TEST ===", UVM_MEDIUM)
  aresetn = 0;
  presetn_tb = 0;  
  `uvm_info("TB_TOP", "Reset asserted", UVM_MEDIUM)
  #100ns;
  aresetn = 1;
  presetn_tb = 1;  
    `uvm_info("TB_TOP", "Reset released", UVM_MEDIUM)
    
    #50ns;
    `uvm_info("TB_TOP", "Reset sequence completed", UVM_MEDIUM)
  endtask
  

  initial begin
    fork
      apply_reset_during_test();  // Reset
    join_none
  end

    
    
  //Debug monitoring
  always @(posedge pclk) begin
    if (psel && penable && !pwrite) begin
      $display("DEBUG: APB READ ACCESS - paddr=0x%0h word_addr=%0d prdata=0x%0h memory[%0d]=0x%0h", 
               paddr, word_addr, prdata, word_addr, memory[word_addr]);
    end
  end

endmodule


  endmodule
