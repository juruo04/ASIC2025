`timescale 1ns/1ps

module button_debounce_pulse #(
    parameter integer STABLE_N = 20,
    parameter         ACTIVE_LEVEL = 1'b1
) (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_raw,

    output reg  btn_pressed,
    output reg  btn_press_pulse
);

    localparam integer COUNT_W = (STABLE_N <= 1) ? 1 : $clog2(STABLE_N);
    localparam [COUNT_W-1:0] STABLE_LAST = STABLE_N - 1;

    reg btn_sync_0;
    reg btn_sync_1;
    reg [COUNT_W-1:0] stable_count;

    wire sample_pressed;

    assign sample_pressed = (btn_sync_1 == ACTIVE_LEVEL);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0      <= ~ACTIVE_LEVEL;
            btn_sync_1      <= ~ACTIVE_LEVEL;
            btn_pressed     <= 1'b0;
            btn_press_pulse <= 1'b0;
            stable_count    <= {COUNT_W{1'b0}};
        end else begin
            btn_sync_0      <= btn_raw;
            btn_sync_1      <= btn_sync_0;
            btn_press_pulse <= 1'b0;

            if (sample_pressed == btn_pressed) begin
                stable_count <= {COUNT_W{1'b0}};
            end else if (stable_count == STABLE_LAST) begin
                btn_pressed     <= sample_pressed;
                btn_press_pulse <= sample_pressed;
                stable_count    <= {COUNT_W{1'b0}};
            end else begin
                stable_count <= stable_count + {{(COUNT_W-1){1'b0}}, 1'b1};
            end
        end
    end
endmodule