module CombMultiplier #(parameter WIDTH = 8)(
    input wire [WIDTH-1:0] a, b,
    output wire [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本阶段的时序、复位及握手约定。
    assign product = a * b;
    // ==================== 缺省实现结束 ====================
endmodule
