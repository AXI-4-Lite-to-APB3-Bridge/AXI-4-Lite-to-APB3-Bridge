`timescale 1ns/1ps

`include "uvm_macros.svh"

`include "test_lib_pkg.sv"
import test_lib_pkg::*;

`timescale 1ns/1ps

module tb_top;
  
   
  bit aclk = 0;
  bit aresetn = 0;
  bit pclk = 0; 
  bit presetn = 0;
  
  always #5 aclk = ~aclk;    // 100MHz AXI clock
  always #10 pclk = ~pclk;   // 50MHz APB clock
  
  axi_interface axi_if (aclk, ~aresetn);
  apb_interface apb_if (pclk, ~presetn);
  
  // DUT instantiation 
  axi_to_apb_bridge #(
    .DATA_WIDTH(32),
    .ADDRESS(32),
    .FIFO_ASIZE(5)
  ) dut (
    .ACLK(aclk),
    .ARESETN(aresetn),
    .PCLK(pclk),
    .PRESETN(presetn),
    
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
    .presetn(presetn),
    .psel(apb_if.psel),
    .penable(apb_if.penable),
    .pwrite(apb_if.pwrite),
    .paddr(apb_if.paddr),
    .pwdata(apb_if.pwdata),
    .prdata(apb_if.prdata),
    .pready(apb_if.pready),
    .pslverr(apb_if.pslverr),
    .apb_memory_write(apb_memory_write),
    .apb_memory_read(apb_memory_read)
  );
  
  
  // Reset 
  initial begin
    aresetn = 0;
    presetn = 0;
    #50ns;
    aresetn = 1;
    presetn = 1;
    `uvm_info("TB_TOP", "Reset released - starting unidirectional bridge test", UVM_NONE)
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
    
    run_test("axi2apb_base_test");
    

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
  output logic pslverr,
  output logic apb_memory_write,
  output logic apb_memory_read  
);

  
  logic [31:0] memory [256];  // Support addresses 0x00 to 0xFF
  logic [7:0] word_addr;      
  
  
  initial begin
    for (int i = 0; i < 256; i++) begin
      memory[i] = 0;  
      if (i < 32) begin  
      end
    end
    apb_memory_write<=1'b0;
     apb_memory_read<=1'b0;
  end

  assign word_addr = paddr[9:2];  

  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      pready <= 1'b0;
      pslverr <= 1'b0;
      prdata <= 32'h0;
      apb_memory_write<=1'b0;
      apb_memory_read<=1'b0;
    end else begin
      apb_memory_write<=0;
      apb_memory_read<=0;
      if (psel && penable) begin //ACCESS phase
                pready <= 1'b1;

                if (paddr >= 32'h400 ) begin
                  pslverr <= 1'b1;


                end else begin
                  pslverr <= 1'b0;

                  if (pwrite && !pslverr) begin
                    // WRITE operation
                    memory[word_addr] <= pwdata;
                    apb_memory_write<=1;
                  end else if(!pwrite && !pslverr) begin
                    // READ operation 
                    prdata <= memory[word_addr];
                    apb_memory_read<=1;
                  end
        end
      end else if (psel && !penable) begin
        // SETUP phase 
        pready <= 1'b0;
        pslverr <= 1'b0;       
      end else begin
        // IDLE phase
        pready <= 1'b0;
        pslverr <= 1'b0;
      end
    end
  end

 

endmodule


  endmodule
