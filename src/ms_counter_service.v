`timescale 1ns/1ps

module ms_counter_service #(
    parameter integer CLK_HZ = 50000000,
    parameter integer COUNTER_W = 16
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  counter_clr,
    input  wire                  counter_en,
    output reg  [COUNTER_W-1:0]  ms_counter
);

    localparam integer MS_TICK_CYCLES_RAW = CLK_HZ / 1000;
    localparam integer MS_TICK_CYCLES = (MS_TICK_CYCLES_RAW < 1) ? 1 : MS_TICK_CYCLES_RAW;
    localparam integer TICK_COUNTER_W = (MS_TICK_CYCLES <= 1) ? 1 : $clog2(MS_TICK_CYCLES);

    reg [TICK_COUNTER_W-1:0] tick_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_counter   <= {COUNTER_W{1'b0}};
            tick_counter <= {TICK_COUNTER_W{1'b0}};
        end else if (counter_clr) begin
            ms_counter   <= {COUNTER_W{1'b0}};
            tick_counter <= {TICK_COUNTER_W{1'b0}};
        end else if (counter_en) begin
            if (tick_counter == MS_TICK_CYCLES - 1) begin
                tick_counter <= {TICK_COUNTER_W{1'b0}};
                    ms_counter   <= ms_counter + 1'b1;
            end else begin
                    tick_counter <= tick_counter + 1'b1;
                ms_counter   <= ms_counter;
            end
        end else begin
            ms_counter   <= ms_counter;
            tick_counter <= {TICK_COUNTER_W{1'b0}};
        end
    end
endmodule
