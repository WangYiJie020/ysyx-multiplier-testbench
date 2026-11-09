module HandshakeMultiplier #(parameter WIDTH = 8)(
    input wire clock, reset,
    input wire [WIDTH-1:0] a, b,
    input wire in_valid,
    output wire in_ready,
    output wire out_valid,
    input wire out_ready,
    output reg [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本阶段的时序、复位及握手约定。
    reg valid;
    assign in_ready = (!valid || out_ready) && !reset;
    assign out_valid = valid && !reset;
    always @(posedge clock) begin
        if (reset) valid <= 0;
        else if (in_ready) begin
            valid <= in_valid;
            if (in_valid) product <= a * b;
        end
    end
    // ==================== 缺省实现结束 ====================
endmodule
