// 累加乘法器
// 状态机每周期用同一个加法器累加一个部分积，共 WIDTH 个周期（讲义任务二）。LATENCY 固定为 WIDTH。
// 接口约定：固定多周期：复位后第 1, L+1, 2L+1... 个上升沿采样 a/b，第 L, 2L, 3L... 个上升沿之后 product 有效（L=LATENCY）；采样之间不会送入新输入。
module AccumMultiplier #(parameter WIDTH = 8, LATENCY = 8)(
    input wire clock, reset,
    input wire [WIDTH-1:0] a, b,
    output reg [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本实现的时序、复位及握手约定。
    reg [$clog2(LATENCY+1)-1:0] phase;
    reg [2*WIDTH-1:0] pending;
    always @(posedge clock) begin
        if (reset) phase <= 0;
        else begin
            if (phase == 0) pending <= a * b;
            if (phase == LATENCY-1) begin
                product <= (LATENCY == 1) ? a * b : pending;
                phase <= 0;
            end else phase <= phase + 1'b1;
        end
    end
    // ==================== 缺省实现结束 ====================
endmodule
