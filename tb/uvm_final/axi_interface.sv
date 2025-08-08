// `include "uvm_macros.svh"
// import uvm_pkg::*;

// interface axi_interface (input bit clk, input bit reset);
  
//   // Read Address Channel
//   logic [31:0] araddr;
//   logic        arvalid;
//   logic        arready;
  
//   // Read Data Channel  
//   logic [31:0] rdata;
//   logic [1:0]  rresp;
//   logic        rvalid;
//   logic        rready;
  
//   // Write Address Channel
//   logic [31:0] awaddr;
//   logic        awvalid;
//   logic        awready;
  
//   // Write Data Channel
//   logic [31:0] wdata;
//   logic [3:0]  wstrb;
//   logic        wvalid;
//   logic        wready;
  
//   // Write Response Channel
//   logic [1:0]  bresp;
//   logic        bvalid;
//   logic        bready;

//   // Clocking blocks for master (driver) operation only
//   clocking master_cb @(posedge clk);
//     output araddr, arvalid, rready;
//     output awaddr, awvalid;
//     output wdata, wstrb, wvalid;
//     output bready;
//     input  arready, rdata, rresp, rvalid;
//     input  awready, wready;
//     input  bresp, bvalid;
//   endclocking

//   // Monitor clocking block
//   clocking monitor_cb @(posedge clk);
//     input araddr, arvalid, rready, arready, rdata, rresp, rvalid;
//     input awaddr, awvalid, awready;
//     input wdata, wstrb, wvalid, wready;
//     input bresp, bvalid, bready;
//   endclocking

//   modport master(clocking master_cb);
//   modport monitor(clocking monitor_cb);

// endinterface
