// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Hardened counter primitive:
//
// This internally uses a cross counter scheme with primary and a secondary counter, where the
// secondary counter counts in reverse direction. The sum of both counters must remain constant and
// equal to 2**Width-1 or otherwise an err_o will be asserted.
//
// This counter supports a generic clear / set / increment / decrement interface:
//
// clr_i: This clears the primary counter to ResetValue and adjusts the secondary counter to match
//        (i.e. 2**Width-1-ResetValue). Clear has priority over set, increment and decrement.
// set_i: This sets the primary counter to set_cnt_i and adjusts the secondary counter to match
//        (i.e. 2**Width-1-set_cnt_i). Set has priority over increment and decrement.
// incr_en_i: Increments the primary counter by step_i, and decrements the secondary by step_i.
// decr_en_i: Decrements the primary counter by step_i, and increments the secondary by step_i.
// commit_i: Counter changes only take effect when `commit_i` is set. This does not effect the
//           `cnt_after_commit_o` output which gives the next counter state if the change is
//           committed.
//
// Note that if both incr_en_i and decr_en_i are asserted at the same time, the counter remains
// unchanged. The counter is also protected against under- and overflows.


module prim_count
  import prim_count_pkg::*;
#(
  parameter int               Width = 2,
  // Can be used to reset the counter to a different value than 0, for example when
  // the counter is used as a down-counter.
  parameter logic [Width-1:0] ResetValue = '0,
  // This should only be disabled in special circumstances, for example
  // in non-comportable IPs where an error does not trigger an alert.
  parameter bit               EnableAlertTriggerSVA = 1,

  // We have some assertions below with preconditions that depend on particular input actions
  // (clear, set, incr, decr). If the design has instantiated prim_count with one of these actions
  // tied to zero, the preconditions for the associated assertions will not be satisfiable. The
  // result is an unreachable item, which we treat as a failed assertion in the report.
  //
  // To avoid this, we the instantiation to specify the actions which might happen. If this is not
  // '1, we will have an assertion which assert the corresponding action is never triggered. We can
  // then use this to avoid the unreachable assertions.
  parameter action_mask_t     PossibleActions = {$bits(action_mask_t){1'b1}}
) (
  input clk_i,
  input rst_ni,
  input clr_i,
  input set_i,
  input [Width-1:0] set_cnt_i,                 // Set value for the counter.
  input incr_en_i,
  input decr_en_i,
  input [Width-1:0] step_i,                    // Increment/decrement step when enabled.
  input commit_i,
  output logic [Width-1:0] cnt_o,              // Current counter state
  output logic [Width-1:0] cnt_after_commit_o, // Next counter state if committed
  output logic err_o
);

  ///////////////////
  // Counter logic //
  ///////////////////

  // Reset Values for primary and secondary counters.
  localparam int NumCnt = 2;
  localparam logic [NumCnt-1:0][Width-1:0] ResetValues = {{Width{1'b1}} - ResetValue, // secondary
                                                          ResetValue};                // primary

  logic [NumCnt-1:0][Width-1:0] cnt_d, cnt_d_committed, cnt_q;

  // The fpv_force signal can be used in FPV runs to make the internal counters (cnt_q) jump
  // unexpectedly. We only want to use this mechanism when we're doing FPV on prim_count itself. In
  // that situation, we will have the PrimCountFpv define and wish to leave fpv_force undriven so
  // that it becomes a free variable in FPV. In any other situation, we drive the signal with zero.
  logic [NumCnt-1:0][Width-1:0] fpv_force;
`ifndef PrimCountFpv
  assign fpv_force = '0;
`endif

  for (genvar k = 0; k < NumCnt; k++) begin : gen_cnts
    // Note that increments / decrements are reversed for the secondary counter.
    logic incr_en, decr_en;
    logic [Width-1:0] set_val;
    if (k == 0) begin : gen_up_cnt
      assign incr_en = incr_en_i;
      assign decr_en = decr_en_i;
      assign set_val = set_cnt_i;
    end else begin : gen_dn_cnt
      assign incr_en = decr_en_i;
      assign decr_en = incr_en_i;
      // The secondary value needs to be adjusted accordingly.
      assign set_val = {Width{1'b1}} - set_cnt_i;
    end

    // Main counter logic
    logic [Width:0] ext_cnt;
    assign ext_cnt = (decr_en) ? {1'b0, cnt_q[k]} - {1'b0, step_i} :
                     (incr_en) ? {1'b0, cnt_q[k]} + {1'b0, step_i} : {1'b0, cnt_q[k]};

    // Saturation logic
    logic uflow, oflow;
    assign oflow = incr_en && ext_cnt[Width];
    assign uflow = decr_en && ext_cnt[Width];
    logic [Width-1:0] cnt_sat;
    assign cnt_sat = (uflow) ? '0            :
                     (oflow) ? {Width{1'b1}} : ext_cnt[Width-1:0];

    // Clock gate flops when in saturation, and do not
    // count if both incr_en and decr_en are asserted.
    logic cnt_en;
    assign cnt_en = (incr_en ^ decr_en) &&
                    ((incr_en && !(&cnt_q[k])) ||
                    (decr_en && !(cnt_q[k] == '0)));

    // Counter muxes
    assign cnt_d[k] = (clr_i)  ? ResetValues[k] :
                      (set_i)  ? set_val        :
                      (cnt_en) ? cnt_sat        : cnt_q[k];

    assign cnt_d_committed[k] = commit_i ? cnt_d[k] : cnt_q[k];

    logic [Width-1:0] cnt_unforced_q;
    prim_flop #(
      .Width(Width),
      .ResetValue(ResetValues[k])
    ) u_cnt_flop (
      .clk_i,
      .rst_ni,
      .d_i(cnt_d_committed[k]),
      .q_o(cnt_unforced_q)
    );

    // fpv_force is only used during FPV.
    assign cnt_q[k] = fpv_force[k] + cnt_unforced_q;
  end

  // The sum of both counters must always equal the counter maximum.
  logic [Width:0] sum;
  assign sum = (cnt_q[0] + cnt_q[1]);

  // Register the error signal to avoid potential CDC issues downstream.
  logic err_d, err_q;
  assign err_d = (sum != {1'b0, {Width{1'b1}}});
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      err_q <= 1'b0;
    end else begin
      err_q <= err_d;
    end
  end
  assign err_o = err_q;

  // Output count values
  assign cnt_o              = cnt_q[0];
  assign cnt_after_commit_o = cnt_d[0];

endmodule // prim_count
