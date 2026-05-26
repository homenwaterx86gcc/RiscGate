/*
module ram_2p #(
    parameter int Depth       = 128,
    parameter     MemInitFile = ""
) (
    input               clk_i,
    input               rst_ni,

    input               a_req_i,
    input               a_we_i,
    input        [ 3:0] a_be_i,
    input        [31:0] a_addr_i,
    input        [31:0] a_wdata_i,
    output logic        a_rvalid_o,
    output logic [31:0] a_rdata_o,

    input               b_req_i,
    input               b_we_i,
    input        [ 3:0] b_be_i,
    input        [31:0] b_addr_i,
    input        [31:0] b_wdata_i,
    output logic        b_rvalid_o,
    output logic [31:0] b_rdata_o
);
ram_2p #(
      .Depth       ( MEM_SIZE / 4 ),
      .MemInitFile ( SRAMInitFile )
  ) u_ram (
    .clk_i (clk_sys_i),
    .rst_ni(rst_sys_ni),

    .a_req_i   (device_req[Ram]),
    .a_we_i    (device_we[Ram]),
    .a_be_i    (device_be[Ram]),
    .a_addr_i  (device_addr[Ram]),
    .a_wdata_i (device_wdata[Ram]),
    .a_rvalid_o(device_rvalid[Ram]),
    .a_rdata_o (device_rdata[Ram]),

    .b_req_i   (mem_instr_req),
    .b_we_i    (1'b0),
    .b_be_i    (4'b0),
    .b_addr_i  (core_instr_addr),
    .b_wdata_i (32'b0),
    .b_rvalid_o(),
    .b_rdata_o (mem_instr_rdata)
  );

*/
// Dual Port RAM (NO_CHANGE)
module gatemate_ram2p #(
 parameter int Depth       = 128,
 parameter     MemInitFile = ""
) (
    input               clk_a_i,
    input               clk_b_i,
    input               rst_ni,

    input               a_req_i,
    input               a_we_i,
    input        [ 3:0] a_be_i,
    input        [31:0] a_addr_i,
    input        [31:0] a_wdata_i,
    output logic        a_rvalid_o,
    output logic [31:0] a_rdata_o,

    input               b_req_i,
    input               b_we_i,
    input        [ 3:0] b_be_i,
    input        [31:0] b_addr_i,
    input        [31:0] b_wdata_i,
    output logic        b_rvalid_o,
    output logic [31:0] b_rdata_o
);
  localparam WORD = (32 - 1);
  localparam DEPTH_MEM = (Depth);
  reg [WORD:0] memory [0:DEPTH_MEM];
  //initial $readmemb("mem/mem_a9d18.hex", memory); // optional
  assign a_rvalid_o = 1'b1;
  assign b_rvalid_o = 1'b1;
  
  always @(posedge clk_a_i) begin
    if (a_req_i) begin
      if (a_we_i) begin
        memory[a_addr_i] <= a_wdata_i;
      end else
        a_rdata_o <= memory[a_addr_i];
      end
  end
  always @(posedge clk_b_i) begin
    if (b_req_i) begin
      if (b_we_i) begin
        memory[b_addr_i] <= b_wdata_i;
      end else
        b_rdata_o <= memory[b_addr_i];
      end
  end
endmodule