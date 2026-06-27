`timescale 1ns/1ps

module buzzer_driver #(
    parameter integer CLK_HZ = 50000000,
    parameter         BUZZER_ON_LEVEL = 1'b0
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] state,
    input  wire [1:0] fail_code,
    output reg        buzzer
);

    localparam integer BEEP_MS = 200;
    localparam integer BEEP_CYCLES_RAW = (CLK_HZ * BEEP_MS) / 1000;
    localparam integer BEEP_CYCLES = (BEEP_CYCLES_RAW < 2) ? 2 : BEEP_CYCLES_RAW;

    reg [2:0]  state_d;
    reg [31:0] beep_cnt;
    reg        beep_active;
    reg        boot_beep_done;

    wire state_changed;

    assign state_changed = (state != state_d);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_d      <= 3'd0;
            beep_cnt     <= 32'd0;
            beep_active  <= 1'b0;
            boot_beep_done <= 1'b0;
            buzzer       <= ~BUZZER_ON_LEVEL;
        end else begin
            state_d <= state;

            if (!boot_beep_done) begin
                boot_beep_done <= 1'b1;
                beep_active    <= 1'b1;
                beep_cnt       <= 32'd0;
                buzzer         <= BUZZER_ON_LEVEL;
            end else if (state_changed) begin
                beep_active <= 1'b1;
                beep_cnt    <= 32'd0;
                buzzer      <= BUZZER_ON_LEVEL;
            end else if (beep_active) begin
                if (beep_cnt >= BEEP_CYCLES - 1) begin
                    beep_active <= 1'b0;
                    beep_cnt    <= 32'd0;
                    buzzer      <= ~BUZZER_ON_LEVEL;
                end else begin
                    beep_cnt <= beep_cnt + 32'd1;
                    buzzer   <= BUZZER_ON_LEVEL;
                end
            end else begin
                beep_cnt    <= 32'd0;
                buzzer      <= ~BUZZER_ON_LEVEL;
            end
        end
    end

endmodule