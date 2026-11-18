// 有符号 A*B（握手接口）
// 在握手接口上额外支持有符号/混合符号操作数，缺省直接使用 `*`。启用 menuconfig 中的 TEST_SIGNED 才会测试符号组合。
// 接口约定：握手接口 + 符号控制：a_signed/b_signed 为 1 时对应操作数按有符号数解释（符号扩展后相乘），product 取 2*WIDTH 位完整乘积；握手约定同上。
module SignedDirectMultiplier #(parameter WIDTH = 8)(
    input wire clock, reset,
    input wire [WIDTH-1:0] a, b,
    input wire a_signed, b_signed,
    input wire in_valid,
    output wire in_ready,
    output wire out_valid,
    input wire out_ready,
    output reg [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
    wire signed [WIDTH:0] sa = {a_signed & a[WIDTH-1], a};
    wire signed [WIDTH:0] sb = {b_signed & b[WIDTH-1], b};
    wire signed [2*WIDTH+1:0] full_product = sa * sb;
    reg valid;
    assign in_ready = (!valid || out_ready) && !reset;
    assign out_valid = valid && !reset;
    always @(posedge clock) begin
        if (reset) valid <= 0;
        else if (in_ready) begin
            valid <= in_valid;
            if (in_valid) product <= full_product[2*WIDTH-1:0];
        end
    end
    // ==================== 缺省实现结束 ====================
endmodule
