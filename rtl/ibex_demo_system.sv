// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The Ibex demo system, which instantiates and connects the following blocks:
// - Memory bus.
// - Ibex top module.
// - RAM memory to contain code and data.
// - GPIO driving logic.
// - UART for serial communication.
// - Timer.
// - Debug module.
// - SPI for driving LCD screen.
module ibex_demo_system #(
  parameter int                 GpiWidth       = 8,
  parameter int                 GpoWidth       = 16,
  parameter int                 PwmWidth       = 12,
  parameter int unsigned        ClockFrequency = 50_000_000,
  parameter int unsigned        BaudRate       = 115_200,
  parameter ibex_pkg::regfile_e RegFile        = ibex_pkg::RegFileFPGA,
  parameter                     SRAMInitFile   = ""
) (
  input  logic clk_sys_i,
  input  logic rst_sys_ni,

  input  logic [GpiWidth-1:0] gp_i,
  output logic [GpoWidth-1:0] gp_o,
  output logic [PwmWidth-1:0] pwm_o,
  input  logic                uart_rx_i,
  output logic                uart_tx_o,
);
  localparam logic [31:0] MEM_SIZE      = 128 * 1024; // 128 KiB
  localparam logic [31:0] MEM_START     = 32'h00100000;
  localparam logic [31:0] MEM_MASK      = ~(MEM_SIZE-1);


  localparam logic [31:0] UART_SIZE     =  4 * 1024; //  4 KiB
  localparam logic [31:0] UART_START    = 32'h80001000;
  localparam logic [31:0] UART_MASK     = ~(UART_SIZE-1);

  typedef enum int {
    Ram,
    Uart,
  } bus_device_e;

  localparam int NrDevices = 2;
  localparam int NrHosts = 1;

  // Interrupts.
  logic timer_irq;
  logic uart_irq;

  // Host signals.
  logic        host_req      [NrHosts];
  logic        host_gnt      [NrHosts];
  logic [31:0] host_addr     [NrHosts];
  logic        host_we       [NrHosts];
  logic [ 3:0] host_be       [NrHosts];
  logic [31:0] host_wdata    [NrHosts];
  logic        host_rvalid   [NrHosts];
  logic [31:0] host_rdata    [NrHosts];
  logic        host_err      [NrHosts];

  // Device signals.
  logic        device_req    [NrDevices];
  logic [31:0] device_addr   [NrDevices];
  logic        device_we     [NrDevices];
  logic [ 3:0] device_be     [NrDevices];
  logic [31:0] device_wdata  [NrDevices];
  logic        device_rvalid [NrDevices];
  logic [31:0] device_rdata  [NrDevices];
  logic        device_err    [NrDevices];

  // Instruction fetch signals.
  logic        core_instr_req;
  logic        core_instr_gnt;
  logic        core_instr_rvalid;
  logic [31:0] core_instr_addr;
  logic [31:0] core_instr_rdata;

  logic        mem_instr_req;
  logic [31:0] mem_instr_rdata;

  // Device address mapping.
  logic [31:0] cfg_device_addr_base [NrDevices];
  logic [31:0] cfg_device_addr_mask [NrDevices];

  assign cfg_device_addr_base[Ram]     = MEM_START;
  assign cfg_device_addr_mask[Ram]     = MEM_MASK;
  assign cfg_device_addr_base[Uart]    = UART_START;
  assign cfg_device_addr_mask[Uart]    = UART_MASK;

  // Tie-off unused error signals.
  assign device_err[Ram]     = 1'b0;
//  assign device_err[Gpio]    = 1'b0;
 // assign device_err[Pwm]     = 1'b0;
  assign device_err[Uart]    = 1'b0;
  //assign device_err[Spi]     = 1'b0;
  //assign device_err[SimCtrl] = 1'b0;

  bus #(
    .NrDevices    ( NrDevices ),
    .NrHosts      ( NrHosts   ),
    .DataWidth    ( 32        ),
    .AddressWidth ( 32        )
  ) u_bus (
    .clk_i (clk_sys_i),
    .rst_ni(rst_sys_ni),

    .host_req_i   (host_req     ),
    .host_gnt_o   (host_gnt     ),
    .host_addr_i  (host_addr    ),
    .host_we_i    (host_we      ),
    .host_be_i    (host_be      ),
    .host_wdata_i (host_wdata   ),
    .host_rvalid_o(host_rvalid  ),
    .host_rdata_o (host_rdata   ),
    .host_err_o   (host_err     ),

    .device_req_o   (device_req   ),
    .device_addr_o  (device_addr  ),
    .device_we_o    (device_we    ),
    .device_be_o    (device_be    ),
    .device_wdata_o (device_wdata ),
    .device_rvalid_i(device_rvalid),
    .device_rdata_i (device_rdata ),
    .device_err_i   (device_err   ),

    .cfg_device_addr_base,
    .cfg_device_addr_mask
  );

  assign mem_instr_req =
      core_instr_req & ((core_instr_addr & cfg_device_addr_mask[Ram]) == cfg_device_addr_base[Ram]);

  assign core_instr_gnt = mem_instr_req;
  always @(posedge clk_sys_i or negedge rst_sys_ni) begin
    if (!rst_sys_ni) begin
      core_instr_rvalid  <= 1'b0;
    end else begin
      core_instr_rvalid  <= core_instr_gnt;
    end
  end

  assign core_instr_rdata = mem_instr_rdata;

  ibex_top #(

  ) u_top (
    .clk_i (clk_sys_i),
    .rst_ni(rst_sys_ni),

    .test_en_i  ('b0),
    .scan_rst_ni(1'b1),
    .ram_cfg_i  ('b0),

    .hart_id_i  (32'b0),
    // First instruction executed is at 0x0 + 0x80.
    .boot_addr_i(32'h00100000),

    .instr_req_o       (core_instr_req),
    .instr_gnt_i       (core_instr_gnt),
    .instr_rvalid_i    (core_instr_rvalid),
    .instr_addr_o      (core_instr_addr),
    .instr_rdata_i     (core_instr_rdata),
    .instr_rdata_intg_i('0),
    .instr_err_i       ('0),

    .data_req_o       (host_req[CoreD]),
    .data_gnt_i       (host_gnt[CoreD]),
    .data_rvalid_i    (host_rvalid[CoreD]),
    .data_we_o        (host_we[CoreD]),
    .data_be_o        (host_be[CoreD]),
    .data_addr_o      (host_addr[CoreD]),
    .data_wdata_o     (host_wdata[CoreD]),
    .data_wdata_intg_o(),
    .data_rdata_i     (host_rdata[CoreD]),
    .data_rdata_intg_i('0),
    .data_err_i       (host_err[CoreD]),

    .irq_software_i(1'b0),
    .irq_timer_i   (timer_irq),
    .irq_external_i(1'b0),
    .irq_fast_i    ({14'b0, uart_irq}),
    .irq_nm_i      (1'b0),

    .scramble_key_valid_i('0),
    .scramble_key_i      ('0),
    .scramble_nonce_i    ('0),
    .scramble_req_o      (),

    .debug_req_i        (dm_debug_req),
    .crash_dump_o       (),
    .double_fault_seen_o(),

    .fetch_enable_i        ('1),
    .alert_minor_o         (),
    .alert_major_internal_o(),
    .alert_major_bus_o     (),
    .core_sleep_o          ()
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


  uart #(
    .ClockFrequency ( ClockFrequency ),
    .BaudRate       ( BaudRate       )
  ) u_uart (
    .clk_i (clk_sys_i),
    .rst_ni(rst_sys_ni),

    .device_req_i   (device_req[Uart]),
    .device_addr_i  (device_addr[Uart]),
    .device_we_i    (device_we[Uart]),
    .device_be_i    (device_be[Uart]),
    .device_wdata_i (device_wdata[Uart]),
    .device_rvalid_o(device_rvalid[Uart]),
    .device_rdata_o (device_rdata[Uart]),

    .uart_rx_i,
    .uart_irq_o     (uart_irq),
    .uart_tx_o
  );
endmodule
