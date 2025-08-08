`include "uvm_macros.svh"
import uvm_pkg::*;

interface axi_interface (input bit clk, input bit reset);
  
  // Read Address Channel
  logic [31:0] araddr;
  logic        arvalid;
  logic        arready;
  
  // Read Data Channel  
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready;
  
  // Write Address Channel
  logic [31:0] awaddr;
  logic        awvalid;
  logic        awready;
  
  // Write Data Channel
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wvalid;
  logic        wready;
  
  // Write Response Channel
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;

  // Clocking blocks for AXI master (driver) operation only
  clocking master_cb @(posedge clk);
    output araddr, arvalid, rready;
    output awaddr, awvalid;
    output wdata, wstrb, wvalid;
    output bready;
    input  arready, rdata, rresp, rvalid;
    input  awready, wready;
    input  bresp, bvalid;
  endclocking

  // Monitor clocking block
  clocking monitor_cb @(posedge clk);
    input araddr, arvalid, rready, arready, rdata, rresp, rvalid;
    input awaddr, awvalid, awready;
    input wdata, wstrb, wvalid, wready;
    input bresp, bvalid, bready;
  endclocking

  modport master(clocking master_cb);
  modport monitor(clocking monitor_cb);

endinterface

    
`include "uvm_macros.svh"
import uvm_pkg::*;

interface apb_interface (input bit clk, input bit reset);
  
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  // Monitor clocking block only (no driver needed)
  clocking monitor_cb @(posedge clk);
    input psel, penable, pwrite, paddr, pwdata;
    input prdata, pready, pslverr;
  endclocking

  modport monitor(clocking monitor_cb);

endinterface

// ********* BRIDGE TOP MODULE DESIGN ************

`timescale 1ns / 1ps
`include "fifo.sv"
`include "axi_4_lite_slave.sv"
`include "APB_master_2.sv"

module axi_to_apb_bridge #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS = 32,
    parameter FIFO_ASIZE = 5
) (
    // AXI4-Lite Interface
    input ACLK, input ARESETN,
    input PCLK, input PRESETN,
    // Read Address Channel
    input [ADDRESS-1:0] S_ARADDR, input S_ARVALID, output logic S_ARREADY,
    // Read Data Channel
    input S_RREADY, output logic [DATA_WIDTH-1:0] S_RDATA, output logic [1:0] S_RRESP, output logic S_RVALID,
    // Write Address Channel
    input [ADDRESS-1:0] S_AWADDR, input S_AWVALID, output logic S_AWREADY,
    // Write Data Channel
    input [DATA_WIDTH-1:0] S_WDATA, input [3:0] S_WSTRB, input S_WVALID, output logic S_WREADY,
    // Write Response Channel
    input S_BREADY, output logic [1:0] S_BRESP, output logic S_BVALID,
    // APB3 Interface
    output logic PSEL, output logic PENABLE, output logic PWRITE, output logic [ADDRESS-1:0] PADDR,
    output logic [DATA_WIDTH-1:0] PWDATA, input [DATA_WIDTH-1:0] PRDATA, input PREADY, input PSLVERR
);

    // FIFO signals for clock domain crossing
    wire [ADDRESS-1:0] waddr_wdata, raddr_wdata, raddr_rdata;
    wire [DATA_WIDTH+3:0] wdata_wdata, wdata_rdata;
    wire [DATA_WIDTH-1:0] rdata_wdata, rdata_rdata;
    wire waddr_wfull, waddr_rempty, wdata_wfull, wdata_rempty;
    wire raddr_wfull, raddr_rempty, rdata_wfull, rdata_rempty;
    wire waddr_winc, waddr_rinc, wdata_winc, wdata_rinc;
    wire raddr_winc, raddr_rinc, rdata_winc, rdata_rinc;

    // Synchronized empty flags for cross-clock domain
    logic waddr_rempty_sync, wdata_rempty_sync, raddr_rempty_sync;

    // Request and write/read control signals
    wire req_bit;
    logic write_bit;

    // Instantiate AXI4-Lite Slave
    axi4_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS(ADDRESS)
    ) axi_slave (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID), .S_ARREADY(S_ARREADY),
        .S_RREADY(S_RREADY), .rdata_rempty(rdata_rempty), .PSLVERR(PSLVERR),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID), .S_AWREADY(S_AWREADY),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID), .S_WREADY(S_WREADY),
        .S_BREADY(S_BREADY), .S_BRESP(S_BRESP), .S_BVALID(S_BVALID),
        .rdata(rdata_rdata), .S_RDATA(S_RDATA), .S_RRESP(S_RRESP), .S_RVALID(S_RVALID)
    );

    // Write Address FIFO (AXI to APB)
    fifo #(
        .DSIZE(ADDRESS), .ASIZE(FIFO_ASIZE)
    ) waddr_fifo (
        .rdata(waddr_wdata), .wfull(waddr_wfull), .rempty(waddr_rempty),
        .wdata(S_AWADDR), .winc(waddr_winc), .wclk(ACLK), .wrst_n(ARESETN),
        .rinc(waddr_rinc), .rclk(PCLK), .rrst_n(PRESETN)
    );

    // Write Data FIFO (AXI to APB)
    fifo #(
        .DSIZE(DATA_WIDTH + 4), .ASIZE(FIFO_ASIZE)
    ) wdata_fifo (
        .rdata(wdata_rdata), .wfull(wdata_wfull), .rempty(wdata_rempty),
        .wdata({S_WDATA, S_WSTRB}), .winc(wdata_winc), .wclk(ACLK), .wrst_n(ARESETN),
        .rinc(wdata_rinc), .rclk(PCLK), .rrst_n(PRESETN)
    );

    // Read Address FIFO (AXI to APB)
    fifo #(
        .DSIZE(ADDRESS), .ASIZE(FIFO_ASIZE)
    ) raddr_fifo (
        .rdata(raddr_rdata), .wfull(raddr_wfull), .rempty(raddr_rempty),
        .wdata(S_ARADDR), .winc(raddr_winc), .wclk(ACLK), .wrst_n(ARESETN),
        .rinc(raddr_rinc), .rclk(PCLK), .rrst_n(PRESETN)
    );

    // Read Data FIFO (APB to AXI)
    fifo #(
        .DSIZE(DATA_WIDTH), .ASIZE(FIFO_ASIZE)
    ) rdata_fifo (
        .rdata(rdata_rdata), .wfull(rdata_wfull), .rempty(rdata_rempty),
        .wdata(PRDATA), .winc(rdata_winc), .wclk(PCLK), .wrst_n(PRESETN),
        .rinc(rdata_rinc), .rclk(ACLK), .rrst_n(ARESETN)
    );

    // Synchronization of empty flags across clock domains (simplified for clarity)
    always @(posedge PCLK or negedge PRESETN) begin
        if (!PRESETN) begin
            waddr_rempty_sync <= 1;
            wdata_rempty_sync <= 1;
            raddr_rempty_sync <= 1;
        end else begin
            waddr_rempty_sync <= waddr_rempty;
            wdata_rempty_sync <= wdata_rempty;
            raddr_rempty_sync <= raddr_rempty;
        end
    end

    // AXI side FIFO control signals
    assign waddr_winc = S_AWVALID && S_AWREADY && !waddr_wfull;
    assign wdata_winc = S_WVALID && S_WREADY && !wdata_wfull;
    assign raddr_winc = S_ARVALID && S_ARREADY && !raddr_wfull && !rdata_wfull;
    assign rdata_rinc = S_RVALID && S_RREADY && !rdata_rempty;

    // Request detection for APB transactions
    assign req_bit = !waddr_rempty_sync || !raddr_rempty_sync || !raddr_rempty_sync;

    // Write or read operation decision (prioritize write over read)
    always @(*) begin
        if (!waddr_rempty_sync && !wdata_rempty_sync)
            write_bit = 1;
        else if (!raddr_rempty_sync  )
            write_bit = 0;
        else
            write_bit = 0;
    end
//always @(*) begin
//    if (!waddr_rempty_sync && !wdata_rempty_sync)
//        write_bit = 1;         // PRIORITIZE writes if possible
//    else
//        write_bit = 0;         // Only do read if no write can be done
//end

    // APB Master instantiation with corrected signals
    logic [31:0] write_addr_pkt, write_data_pkt, read_addr_pkt;
    assign write_addr_pkt = waddr_wdata;
    assign write_data_pkt = wdata_rdata[DATA_WIDTH+3:4];
    assign read_addr_pkt = raddr_rdata;

    wire rd_flag, wr_flag;
    APB_master_2 #(
        .DSIZE(DATA_WIDTH), .ASIZE(ADDRESS)
    ) apb_master (
        .PCLK(PCLK), .PRESETn(PRESETN),
        .write_addr_pkt(write_addr_pkt), .write_data_pkt(write_data_pkt),
        .read_addr_pkt(read_addr_pkt), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
        .req_bit(req_bit), .write_bit(write_bit),
        .PADDR(PADDR), .PWDATA(PWDATA), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .wr_flag(wr_flag), .rd_flag(rd_flag)
    );

    // APB side FIFO control signals (corrected to prevent stalls)
    assign waddr_rinc = wr_flag && !waddr_rempty_sync;
    assign wdata_rinc = wr_flag && !wdata_rempty_sync;
    assign raddr_rinc = rd_flag && !raddr_rempty_sync;
    assign rdata_winc = rd_flag && !rdata_wfull;// && (PRDATA !== {DATA_WIDTH{1'bx}}) && PREADY;
  
  // Debug output
    always @(wdata_rinc, wr_flag) begin
        $display(" FIFO output wdata_rinc= %0h", wdata_rinc);
        $display(" FIFO output wr_flag= %0h", wr_flag);
    end

    // ADDED: Debug for read operations
    always @(posedge PCLK) begin
        if (rd_flag) begin
            $display("Time: %0t Bridge: rd_flag asserted, PADDR=0x%0h, PRDATA=0x%0h, rdata_winc=%b", 
                     $time, PADDR, PRDATA, rdata_winc);
        end
        if (raddr_rinc) begin
            $display("Time: %0t Bridge: Read address FIFO increment, raddr_rdata=0x%0h", 
                     $time, raddr_rdata);
        end
        if (rdata_winc) begin
            $display("Time: %0t Bridge: Read data FIFO write, PRDATA=0x%0h", $time, PRDATA);
        end
    end
endmodule

    