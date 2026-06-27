`timescale 1ns/1ps

module button_debounce_pulse_tb;
    reg clk;
    reg rst_n;
    reg btn_raw;

    wire btn_pressed;
    wire btn_press_pulse;

    integer pulse_count;

    button_debounce_pulse #(
        .STABLE_N(3),
        .ACTIVE_LEVEL(1'b1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_raw(btn_raw),
        .btn_pressed(btn_pressed),
        .btn_press_pulse(btn_press_pulse)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (btn_press_pulse) begin
            pulse_count <= pulse_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        btn_raw = 1'b0;
        pulse_count = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Bouncing before stable press
        @(negedge clk); btn_raw <= 1'b1;
        @(negedge clk); btn_raw <= 1'b0;
        @(negedge clk); btn_raw <= 1'b1;
        @(negedge clk); btn_raw <= 1'b0;

        // Stable high
        @(negedge clk); btn_raw <= 1'b1;
        repeat (5) @(posedge clk);

        if (btn_pressed !== 1'b1) begin
            $fatal(1, "Expected btn_pressed=1 after stable press");
        end
        if (pulse_count != 1) begin
            $fatal(1, "Expected one pulse after press, got=%0d", pulse_count);
        end

        // Stable release should not generate press pulse
        @(negedge clk); btn_raw <= 1'b0;
        repeat (5) @(posedge clk);

        if (btn_pressed !== 1'b0) begin
            $fatal(1, "Expected btn_pressed=0 after stable release");
        end
        if (pulse_count != 1) begin
            $fatal(1, "Release should not increase pulse count, got=%0d", pulse_count);
        end

        $display("button_debounce_pulse TB passed");
        #20;
        $finish;
    end
endmodule
