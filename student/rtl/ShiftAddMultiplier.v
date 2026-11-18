// 移位加乘法器
// 每周期根据乘数最低位决定是否累加，随后被乘数左移、乘数右移，乘数为 0 即可提前结束，因此延迟不固定，使用握手接口（讲义任务三）。
// 接口约定：握手接口：仅在 in_valid && in_ready 的上升沿接收请求，仅在 out_valid && out_ready 的上升沿取走结果；结果按请求顺序返回，复位取消在途请求。
module ShiftAddMultiplier #(parameter WIDTH = 8)(
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
    // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
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
