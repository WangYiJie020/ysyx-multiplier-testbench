// Testbench adapter: wraps the student module (selected by build/<config>/mul_config.svh, generated from
// impls/<id>.mk) behind one request/result stream interface, whatever the implementation's own
// interface is. The student only ever sees the ports of their own implementation.
//
// The parameters below mirror the flags of impls/<id>.mk.
//   handshake                 : student's valid/ready signals are forwarded directly
//   combinational             : result is available in the same cycle as the request
//   fixed-cycle, pipelined    : one request per cycle, result LATENCY edges later
//   fixed-cycle, multicycle   : one request every LATENCY cycles (sampled at phase 0), result LATENCY edges later
`include "mul_config.svh"

/* verilator lint_off DECLFILENAME */
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module Multiplier #(
    parameter WIDTH = `MUL_WIDTH,
    parameter LATENCY = `MUL_LATENCY,
    parameter CLOCKED = `MUL_CLOCKED,
    parameter FIXED_CYCLE = `MUL_FIXED_CYCLE,
    parameter PIPELINED = `MUL_PIPELINED,
    parameter HANDSHAKE = `MUL_HANDSHAKE,
    parameter SIGNED = `MUL_SIGNED
)(
    input  wire clock,
    input  wire reset,
    input  wire io_in_valid,
    output wire io_in_ready,
    input  wire [WIDTH-1:0] io_in_bits_a,
    input  wire [WIDTH-1:0] io_in_bits_b,
    input  wire io_in_bits_aSigned,
    input  wire io_in_bits_bSigned,
    output wire io_out_valid,
    input  wire io_out_ready,
    output wire [2*WIDTH-1:0] io_out_bits
);
    wire [2*WIDTH-1:0] product;

    // The DUT instantiation is chosen by the preprocessor (MUL_IF_*): the ports differ per interface,
    // so the instances of the other interfaces must not even be parsed against this module.
    generate
    if (HANDSHAKE) begin : g_handshake
        wire in_valid = io_in_valid && !reset;
        wire in_ready, out_valid;
        wire out_ready = io_out_ready && !reset;
        assign io_in_ready = in_ready && !reset;
        assign io_out_valid = out_valid && !reset;
        assign io_out_bits = product;
`ifdef MUL_IF_SIGNED
        begin : g_signed
            `MUL_MODULE `MUL_PARAMS dut (
                .clock(clock), .reset(reset), .a(io_in_bits_a), .b(io_in_bits_b),
                .a_signed(io_in_bits_aSigned), .b_signed(io_in_bits_bSigned),
                .in_valid(in_valid), .in_ready(in_ready), .out_valid(out_valid), .out_ready(out_ready),
                .product(product));
        end
`elsif MUL_IF_HANDSHAKE
        begin : g_unsigned
            `MUL_MODULE `MUL_PARAMS dut (
                .clock(clock), .reset(reset), .a(io_in_bits_a), .b(io_in_bits_b),
                .in_valid(in_valid), .in_ready(in_ready), .out_valid(out_valid), .out_ready(out_ready),
                .product(product));
        end
`endif
    end else begin : g_stream
`ifdef MUL_IF_TIMED
        begin : g_timed
            `MUL_MODULE `MUL_PARAMS dut (
                .clock(clock), .reset(reset), .a(io_in_bits_a), .b(io_in_bits_b), .product(product));
        end
`elsif MUL_IF_COMB
        begin : g_comb
            `MUL_MODULE `MUL_PARAMS dut (.a(io_in_bits_a), .b(io_in_bits_b), .product(product));
        end
`endif

        // Reserve space for every accepted request, including results still in flight.
        localparam CAPACITY = CLOCKED ? LATENCY + 2 : 2;
        localparam MULTICYCLE = FIXED_CYCLE && !PIPELINED;

        reg [$clog2(CAPACITY+1)-1:0] outstanding;
        reg [$clog2(LATENCY+1)-1:0] phase;
        reg [LATENCY-1:0] in_flight;       // accepted requests, LATENCY stages deep
        wire in_fire = io_in_valid && io_in_ready;
        wire out_fire = io_out_valid && io_out_ready;
        wire [LATENCY:0] in_flight_next = {in_flight, in_fire};

        wire schedule = MULTICYCLE ? phase == 0 : 1'b1;
        assign io_in_ready = outstanding < CAPACITY && schedule && !reset;

        always @(posedge clock) begin
            if (reset) begin
                outstanding <= 0;
                phase <= 0;
                in_flight <= 0;
            end else begin
                if (MULTICYCLE) phase <= (phase == LATENCY - 1) ? 0 : phase + 1'b1;
                in_flight <= in_flight_next[LATENCY-1:0];
                if (in_fire != out_fire) outstanding <= in_fire ? outstanding + 1'b1 : outstanding - 1'b1;
            end
        end

        wire result_valid = CLOCKED ? in_flight[LATENCY-1] : in_fire;
        wire enq_valid = result_valid && !reset;
        wire enq_ready, deq_valid;
        MulResultQueue #(.WIDTH(2*WIDTH), .DEPTH(CAPACITY)) results (
            .clock(clock), .reset(reset),
            .enq_valid(enq_valid), .enq_ready(enq_ready), .enq_bits(product),
            .deq_valid(deq_valid), .deq_ready(io_out_ready && !reset), .deq_bits(io_out_bits));
        assign io_out_valid = deq_valid && !reset;

        always @(posedge clock)
            assert (!enq_valid || enq_ready) else $fatal(1, "adapter result buffer overflow");
    end
    endgenerate
endmodule

// FIFO whose empty-state output is combinationally bypassed from the input (a "flow" queue).
module MulResultQueue #(parameter WIDTH = 16, DEPTH = 2)(
    input  wire clock,
    input  wire reset,
    input  wire enq_valid,
    output wire enq_ready,
    input  wire [WIDTH-1:0] enq_bits,
    output wire deq_valid,
    input  wire deq_ready,
    output wire [WIDTH-1:0] deq_bits
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    localparam [$clog2(DEPTH)-1:0] LAST = ($clog2(DEPTH))'(DEPTH - 1);
    reg [$clog2(DEPTH)-1:0] rd, wr;
    reg [$clog2(DEPTH+1)-1:0] count;

    wire empty = count == 0;
    assign enq_ready = count != DEPTH;
    assign deq_valid = !empty || enq_valid;
    assign deq_bits = empty ? enq_bits : mem[rd];

    wire do_enq = enq_valid && enq_ready && !(empty && deq_ready);
    wire do_deq = deq_ready && !empty;

    always @(posedge clock) begin
        if (reset) begin
            rd <= 0;
            wr <= 0;
            count <= 0;
        end else begin
            if (do_enq) begin
                mem[wr] <= enq_bits;
                wr <= (wr == LAST) ? '0 : wr + 1'b1;
            end
            if (do_deq) rd <= (rd == LAST) ? '0 : rd + 1'b1;
            if (do_enq != do_deq) count <= do_enq ? count + 1'b1 : count - 1'b1;
        end
    end
endmodule
