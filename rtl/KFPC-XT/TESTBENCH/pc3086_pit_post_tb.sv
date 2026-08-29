// PC3086 interval-timer POST regression.
//
// The PC3086 ROS tests the 8253 at F000:C204.  Its first phase writes and
// reads 0000h and FFFFh through counter 2 (ports 42h/43h), then programs
// counter 1 through 41h/43h and repeatedly uses the 8253 read-latch command
// while the counter is running.  This fixture keeps that bus sequence in a
// fast, self-checking simulation.  It also checks counter 0's periodic output
// because that output is wired to the 8259 IRQ0 request by PERIPHERALS.
//
// This deliberately instantiates the production KF8253 RTL rather than a
// behavioural timer model.  It is not a full ROS emulator; it pins down the
// timer contracts that the PC3086 POST depends on before an FPGA rebuild.
module pc3086_pit_post_tb;
    timeunit 1ns;
    timeprecision 1ns;

    logic clock = 1'b0;
    always #5 clock = ~clock;

    logic reset = 1'b1;
    initial begin
        repeat (4) @(posedge clock);
        reset = 1'b0;
    end

    logic chip_select_n = 1'b1;
    logic read_enable_n = 1'b1;
    logic write_enable_n = 1'b1;
    logic [1:0] address = 2'b00;
    logic [7:0] data_bus_in = 8'h00;
    logic [7:0] data_bus_out;

    logic counter_0_clock = 1'b1;
    logic counter_0_gate = 1'b1;
    logic counter_0_out;
    logic counter_1_clock = 1'b1;
    logic counter_1_gate = 1'b1;
    logic counter_1_out;
    logic counter_2_clock = 1'b1;
    logic counter_2_gate = 1'b1;
    logic counter_2_out;

    KF8253 dut (.*);

    task automatic pit_write(input logic [1:0] port, input logic [7:0] value);
    begin
        @(negedge clock);
        chip_select_n = 1'b0;
        write_enable_n = 1'b0;
        address = port;
        data_bus_in = value;
        @(negedge clock);
        chip_select_n = 1'b1;
        write_enable_n = 1'b1;
        @(posedge clock);
    end
    endtask

    task automatic pit_read(input logic [1:0] port, output logic [7:0] value);
    begin
        @(negedge clock);
        chip_select_n = 1'b0;
        read_enable_n = 1'b0;
        address = port;
        #1 value = data_bus_out;
        @(negedge clock);
        chip_select_n = 1'b1;
        read_enable_n = 1'b1;
        @(posedge clock);
    end
    endtask

    task automatic expect8(
        input logic [7:0] actual,
        input logic [7:0] expected,
        input string label
    );
    begin
        if (actual !== expected)
            $fatal(1, "%s: got %02x, expected %02x", label, actual, expected);
    end
    endtask

    task automatic tick_counter_0;
    begin
        // The production counter advances on the falling edge of its input.
        @(negedge clock);
        counter_0_clock = 1'b0;
        @(negedge clock);
        counter_0_clock = 1'b1;
    end
    endtask

    task automatic tick_counter_1;
    begin
        @(negedge clock);
        counter_1_clock = 1'b0;
        @(negedge clock);
        counter_1_clock = 1'b1;
    end
    endtask

    task automatic tick_counter_2;
    begin
        @(negedge clock);
        counter_2_clock = 1'b0;
        @(negedge clock);
        counter_2_clock = 1'b1;
    end
    endtask

    logic [7:0] byte0;
    logic [7:0] byte1;
    logic [15:0] first_latched_count;
    logic [15:0] second_latched_count;
    integer out0_low_pulses;
    logic previous_out0;

    always @(posedge clock) begin
        if (!reset) begin
            if (previous_out0 && !counter_0_out)
                out0_low_pulses <= out0_low_pulses + 1;
            previous_out0 <= counter_0_out;
        end
    end

    initial begin
        out0_low_pulses = 0;
        previous_out0 = 1'b0;
        wait (!reset);

        // ROS F000:C20C: counter 2, LSB/MSB, mode 0, binary.
        pit_write(2'b11, 8'hB0);

        // ROS F000:C215: verify 0000h and FFFFh byte-for-byte through 42h.
        // The ROS's intervening I/O instructions allow the 1.19 MHz timer
        // input to see its load edge before the immediate reads.
        pit_write(2'b10, 8'h00);
        pit_write(2'b10, 8'h00);
        tick_counter_2();
        pit_read(2'b10, byte0);
        pit_read(2'b10, byte1);
        expect8(byte0, 8'h00, "counter 2 0000h LSB");
        expect8(byte1, 8'h00, "counter 2 0000h MSB");

        pit_write(2'b10, 8'hFF);
        pit_write(2'b10, 8'hFF);
        tick_counter_2();
        pit_read(2'b10, byte0);
        pit_read(2'b10, byte1);
        expect8(byte0, 8'hFF, "counter 2 FFFFh LSB");
        expect8(byte1, 8'hFF, "counter 2 FFFFh MSB");

        // ROS F000:C233: counter 1, LSB/MSB, mode 4, binary; count 2e7ch.
        pit_write(2'b11, 8'h78);
        pit_write(2'b01, 8'h7C);
        pit_write(2'b01, 8'h2E);
        tick_counter_1();

        // ROS F000:C248: latch, then read a coherent LSB/MSB pair.
        pit_write(2'b11, 8'h48);
        pit_read(2'b01, byte0);
        pit_read(2'b01, byte1);
        first_latched_count = {byte1, byte0};
        if (first_latched_count !== 16'h2E7C)
            $fatal(1, "counter 1 initial latch: got %04x, expected 2e7c",
                   first_latched_count);

        // Let the same counter run, latch again, and require a coherent,
        // decreasing value.  This detects a dead clock path separately from
        // the counter-2 register/readback portion of the POST.
        repeat (8) tick_counter_1();
        pit_write(2'b11, 8'h48);
        pit_read(2'b01, byte0);
        pit_read(2'b01, byte1);
        second_latched_count = {byte1, byte0};
        if (second_latched_count >= first_latched_count)
            $fatal(1, "counter 1 did not decrement: %04x -> %04x",
                   first_latched_count, second_latched_count);

        // This is the critical part of the real ROS test at F000:C248.  In
        // mode 4 the visible count keeps rolling after the terminal-count
        // strobe: 0000h is followed by ffffh.  The ROS waits until C1's
        // latched MSB is greater than 2eh, which only happens after that
        // rollover.  A counter that saturates at 0000h therefore reports
        // "Faulty interval timer" even though its input clock is alive.
        repeat (16'h2E7C + 16) tick_counter_1();
        pit_write(2'b11, 8'h48);
        pit_read(2'b01, byte0);
        pit_read(2'b01, byte1);
        if (byte1 <= 8'h2E)
            $fatal(1, "counter 1 mode-4 count did not roll over: %02x%02x",
                   byte1, byte0);

        // Counter 0 is the PC timer source.  Check that a normal mode-2
        // programming sequence produces recurring low pulses; PERIPHERALS
        // forwards this signal to the 8259 as IRQ0.
        pit_write(2'b11, 8'h34);
        pit_write(2'b00, 8'h04);
        pit_write(2'b00, 8'h00);
        repeat (20) tick_counter_0();
        if (out0_low_pulses < 3)
            $fatal(1, "counter 0 periodic output missing: observed %0d low pulses",
                   out0_low_pulses);

        $display("PC3086 PIT POST regression passed: c1 %04x -> %04x, IRQ0 pulses=%0d",
                 first_latched_count, second_latched_count, out0_low_pulses);
        $finish;
    end
endmodule
