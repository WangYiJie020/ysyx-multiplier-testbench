module MulticycleMultiplier #(parameter WIDTH = 8, LATENCY = 3)(
    input wire clock, reset,
    input wire [WIDTH-1:0] a, b,
    output reg [2*WIDTH-1:0] product
);

    // ==================== 缺省实现开始 ====================
    // 以下为直接使用 * 的缺省范例实现，可全部移除并重写。
    // 请保留上述接口，并遵守本阶段的时序、复位及握手约定。
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
