// A*B 直接乘法
// 直接使用 Verilog/Chisel 的 `*` 运算符，作为功能与综合结果的参照。
// 接口约定：组合逻辑：无 clock/reset，product 须随 a/b 在同一周期给出。
module DirectMultiplier #(parameter WIDTH = 8)(
    input wire [WIDTH-1:0] a, b,
    output wire [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
    assign product = a * b;
    // ==================== 缺省实现结束 ====================
endmodule
