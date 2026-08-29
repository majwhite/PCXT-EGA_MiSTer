// PC3086 system-status-register POST regression.
//
// The PC3086 ROS enters this check at F000:C277 after the interval-timer
// check.  It writes 31h to PPI port B, programs PIT counter 2 with B0h
// (mode 0, LSB/MSB), and reads PPI port C bit 5.  Bit 5 must initially be low
// and then become high after a counter-2 count of 0001h expires.  On a PC/XT
// that bit is the physical PIT channel-2 OUT pin.
//
// This fixture combines the production KF8255 and KF8253 RTL, and models the
// top-level PC/XT status wiring.  It is deliberately self-checking so the
// error cannot regress to a build-only discovery.
module pc3086_system_status_tb;
    timeunit 1ns;
    timeprecision 1ns;

    logic clock = 1'b0;
    always #5 clock = ~clock;

    logic reset = 1'b1;
    initial begin
        repeat (4) @(posedge clock);
        reset = 1'b0;
    end

    logic pit_chip_select_n = 1'b1;
    logic pit_read_enable_n = 1'b1;
    logic pit_write_enable_n = 1'b1;
    logic [1:0] pit_address = 2'b00;
    logic [7:0] pit_data_bus_in = 8'h00;
    logic [7:0] pit_data_bus_out;
    logic timer_clock = 1'b1;
    logic timer2_out;
    logic [7:0] port_b_out;

    KF8253 pit (
        .clock,
        .reset,
        .chip_select_n(pit_chip_select_n),
        .read_enable_n(pit_read_enable_n),
        .write_enable_n(pit_write_enable_n),
        .address(pit_address),
        .data_bus_in(pit_data_bus_in),
        .data_bus_out(pit_data_bus_out),
        .counter_0_clock(timer_clock),
        .counter_0_gate(1'b1),
        .counter_0_out(),
        .counter_1_clock(timer_clock),
        .counter_1_gate(1'b1),
        .counter_1_out(),
        .counter_2_clock(timer_clock),
        .counter_2_gate(port_b_out[0]),
        .counter_2_out(timer2_out)
    );

    logic ppi_chip_select_n = 1'b1;
    logic ppi_read_enable_n = 1'b1;
    logic ppi_write_enable_n = 1'b1;
    logic [1:0] ppi_address = 2'b00;
    logic [7:0] ppi_data_bus_in = 8'h00;
    logic [7:0] ppi_data_bus_out;
    logic [7:0] port_c_in;

    // Exact relevant PC/XT status contract: PC5 is PIT channel-2 OUT.
    assign port_c_in = {2'b00, timer2_out, 1'b0, 4'b0000};

    // The PC3086 board straps its 8255-compatible block to A=input,
    // B=output and C=input before the BIOS starts.
    KF8255 #(.PC3086_RESET_COMPAT(1'b1)) ppi (
        .clock,
        .reset,
        .chip_select_n(ppi_chip_select_n),
        .read_enable_n(ppi_read_enable_n),
        .write_enable_n(ppi_write_enable_n),
        .address(ppi_address),
        .data_bus_in(ppi_data_bus_in),
        .data_bus_out(ppi_data_bus_out),
        .port_a_in(8'h00),
        .port_a_out(),
        .port_a_io(),
        .port_b_in(port_b_out),
        .port_b_out,
        .port_b_io(),
        .port_c_in,
        .port_c_out(),
        .port_c_io()
    );

    task automatic ppi_write(input logic [1:0] port, input logic [7:0] value);
    begin
        @(negedge clock);
        ppi_chip_select_n = 1'b0;
        ppi_write_enable_n = 1'b0;
        ppi_address = port;
        ppi_data_bus_in = value;
        @(negedge clock);
        ppi_chip_select_n = 1'b1;
        ppi_write_enable_n = 1'b1;
        repeat (2) @(posedge clock);
    end
    endtask

    task automatic ppi_read(input logic [1:0] port, output logic [7:0] value);
    begin
        @(negedge clock);
        ppi_chip_select_n = 1'b0;
        ppi_read_enable_n = 1'b0;
        ppi_address = port;
        #1 value = ppi_data_bus_out;
        @(negedge clock);
        ppi_chip_select_n = 1'b1;
        ppi_read_enable_n = 1'b1;
        @(posedge clock);
    end
    endtask

    task automatic pit_write(input logic [1:0] port, input logic [7:0] value);
    begin
        @(negedge clock);
        pit_chip_select_n = 1'b0;
        pit_write_enable_n = 1'b0;
        pit_address = port;
        pit_data_bus_in = value;
        @(negedge clock);
        pit_chip_select_n = 1'b1;
        pit_write_enable_n = 1'b1;
        @(posedge clock);
    end
    endtask

    task automatic tick_timer;
    begin
        @(negedge clock);
        timer_clock = 1'b0;
        @(negedge clock);
        timer_clock = 1'b1;
    end
    endtask

    logic [7:0] status;

    initial begin
        wait (!reset);

        // ROS F000:C277: gate timer 2 on via PPI port 61h (PPI port B).
        ppi_write(2'b01, 8'h31);
        if (port_b_out !== 8'h31)
            $fatal(1, "PPI port B did not retain 31h: %02x", port_b_out);

        // ROS F000:C2D4: counter 2, LSB/MSB, mode 0, binary.
        pit_write(2'b11, 8'hB0);
        ppi_read(2'b10, status);
        if (status[5] !== 1'b0)
            $fatal(1, "POST initial port 62h bit 5: got %02x, expected bit 5 low", status);

        // ROS F000:C2E3..C2EA: write a count of 0001h to port 42h.
        pit_write(2'b10, 8'h01);
        pit_write(2'b10, 8'h00);

        // The ROS spends a short instruction loop between loading 0001h and
        // sampling 62h.  Keep the same margin: the production counter sees
        // the load on one timer edge and reaches terminal count on the next.
        repeat (6) tick_timer;

        // PC5 must now mirror OUT2 high.
        ppi_read(2'b10, status);
        if (status[5] !== 1'b1)
            $fatal(1, "POST terminal port 62h bit 5: got %02x, expected bit 5 high", status);

        $display("PC3086 system-status POST regression passed: 62h bit 5 followed PIT OUT2");
        $finish;
    end
endmodule
