// 流水线化累加乘法器
// 将累加乘法器展开为 WIDTH 级流水线，每级只经过一个加法器（讲义任务四，二选一）。LATENCY 固定为 WIDTH。
// 接口约定：固定延迟流水线：每个上升沿都采样 a/b，经过 L 个上升沿后 product 有效（L=LATENCY），允许每拍一组输入。
module PipelinedAccumMultiplier #(parameter WIDTH = 8, LATENCY = 8)(
    input wire clock, reset,
    input wire [WIDTH-1:0] a, b,
    output wire [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
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
