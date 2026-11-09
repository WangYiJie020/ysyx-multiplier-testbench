module PipelineMultiplier #(parameter WIDTH = 8, LATENCY = 3)(
    input wire clock, reset,
    input wire [WIDTH-1:0] a, b,
    output wire [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本阶段的时序、复位及握手约定。
    reg [2*WIDTH-1:0] stages [0:LATENCY-1];
    integer i;
    always @(posedge clock) begin
        if (reset) begin
            for (i=0; i<LATENCY; i=i+1) stages[i] <= 0;
        end else begin
            stages[0] <= a * b;
            for (i=1; i<LATENCY; i=i+1) stages[i] <= stages[i-1];
        end
    end
    assign product = stages[LATENCY-1];
    // ==================== 缺省实现结束 ====================
endmodule
