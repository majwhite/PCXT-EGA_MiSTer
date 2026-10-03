// Zero-FPGA-build contract test for the RTC backend used by the PC3086
// compatibility decode. The PC3086 BIOS treats 70h/71h as index/data ports;
// Peripherals supplies address[0], so this bench checks the actual RTC half
// of that contract without compiling the whole core.

`timescale 1ns / 1ps

module pc3086_rtc_index_data_tb;
    logic clock = 1'b0;
    logic reset_n = 1'b0;
    always #10 clock = ~clock;

    logic       io_address = 1'b0;
    logic       io_read = 1'b0;
    logic       io_write = 1'b0;
    logic [7:0] io_writedata = 8'h00;
    logic [7:0] mgmt_address = 8'h00;
    logic       mgmt_write = 1'b0;
    logic [7:0] mgmt_writedata = 8'h00;
    logic [7:0] io_readdata;
    logic       irq;
    integer     pass_count = 0;
    integer     fail_count = 0;

    rtc dut (
        .clk            (clock),
        .rst_n          (reset_n),
        .irq            (irq),
        .io_address     (io_address),
        .io_read        (io_read),
        .io_readdata    (io_readdata),
        .io_write       (io_write),
        .io_writedata   (io_writedata),
        .memcfg         (1'b0),
        .bootcfg        (6'd0),
        .mgmt_address   (mgmt_address),
        .mgmt_write     (mgmt_write),
        .mgmt_writedata (mgmt_writedata),
        .clock_rate     (28'd50_000_000)
    );

    task automatic check(input logic [7:0] actual, input logic [7:0] expected, input string label_text);
        begin
            if (actual !== expected) begin
                fail_count = fail_count + 1;
                $display("FAIL: %s actual=%02h expected=%02h", label_text, actual, expected);
            end else begin
                pass_count = pass_count + 1;
                $display("PASS: %s value=%02h", label_text, actual);
            end
        end
    endtask

    // Models an OUT to port 70h: select an RTC/CMOS register.
    task automatic select_index(input logic [6:0] index);
        begin
            @(negedge clock);
            io_address = 1'b0;
            io_writedata = {1'b0, index};
            io_write = 1'b1;
            @(negedge clock);
            io_write = 1'b0;
            // The RTC RAM has a registered read address and output.
            repeat (2) @(posedge clock);
        end
    endtask

    // Models an OUT to port 71h after an index selection.
    task automatic write_data(input logic [7:0] value);
        begin
            @(negedge clock);
            io_address = 1'b1;
            io_writedata = value;
            io_write = 1'b1;
            @(negedge clock);
            io_write = 1'b0;
            repeat (2) @(posedge clock);
        end
    endtask

    // Models a settled IN from port 71h after the index selection.
    task automatic read_data(output logic [7:0] value);
        begin
            @(negedge clock);
            io_address = 1'b1;
            io_read = 1'b1;
            @(posedge clock);
            #1 value = io_readdata;
            @(negedge clock);
            io_read = 1'b0;
        end
    endtask

    logic [7:0] read_value;
    integer cmos_index;
    logic [7:0] checksum;

    initial begin
        repeat (3) @(posedge clock);
        reset_n = 1'b1;

        // Port 70h itself is the index latch, never data.
        select_index(7'h0D);
        io_address = 1'b0;
        @(posedge clock);
        #1 check(io_readdata, 8'hFF, "index-port read is FF");

        // The MC146818 valid-RAM flag is a reset-independent RTC invariant.
        select_index(7'h0D);
        read_data(read_value);
        check(read_value, 8'h80, "register D valid-RAM flag");

        // Populate the exact PC3086 checksum span (0Eh..15h), then ensure
        // every indexed data read returns the byte written through port 71h.
        checksum = 8'h00;
        for (cmos_index = 7'h0E; cmos_index <= 7'h15; cmos_index = cmos_index + 1) begin
            select_index(cmos_index[6:0]);
            write_data(cmos_index[7:0] ^ 8'h5A);
            checksum = checksum + (cmos_index[7:0] ^ 8'h5A);
        end
        for (cmos_index = 7'h0E; cmos_index <= 7'h15; cmos_index = cmos_index + 1) begin
            select_index(cmos_index[6:0]);
            read_data(read_value);
            check(read_value, cmos_index[7:0] ^ 8'h5A, "CMOS checksum-span data read");
        end

        $display("PC3086 CMOS checksum-span sum=%02h", checksum);
        $display("RESULT: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count != 0) $fatal(1, "PC3086 RTC index/data regression failed");
        $finish;
    end
endmodule
