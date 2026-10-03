// Controller-level regression for the command sequence used by the native
// Amstrad PC3086 boot ROM.  This is deliberately independent of the 8088,
// DMA and video paths: it lets us prove (or disprove) the 765 protocol before
// paying for a Quartus build.
`timescale 1ns/1ps

module pc3086_floppy_command_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg        io_read = 1'b0;
    reg        io_write = 1'b0;
    reg [2:0]  io_address = 3'd0;
    reg [7:0]  io_writedata = 8'd0;
    wire [7:0] io_readdata;
    wire       irq;
    wire       fdd0_inserted;

    reg [3:0]  mgmt_address = 4'd0;
    reg        mgmt_fddn = 1'b0;
    reg        mgmt_write = 1'b0;
    reg [15:0] mgmt_writedata = 16'd0;

    floppy dut (
        .clk(clk), .rst_n(rst_n),
        .dma_req(), .dma_ack(1'b0), .dma_tc(1'b0), .dma_readdata(8'd0), .dma_writedata(),
        .irq(irq),
        .io_address(io_address), .io_read(io_read), .io_readdata(io_readdata),
        .io_write(io_write), .io_writedata(io_writedata),
        .fdd0_inserted(fdd0_inserted),
        .mgmt_address(mgmt_address), .mgmt_fddn(mgmt_fddn), .mgmt_write(mgmt_write),
        .mgmt_writedata(mgmt_writedata), .mgmt_read(1'b0), .mgmt_readdata(),
        // A compact, non-zero timing scale: small enough for a fast
        // regression while retaining the controller's rate-counter phases.
        .wp(2'b00), .clock_rate(28'd1000), .request()
    );

    task automatic write_io(input [2:0] address, input [7:0] data);
        begin
            @(negedge clk);
            io_address = address;
            io_writedata = data;
            io_write = 1'b1;
            @(negedge clk);
            io_write = 1'b0;
        end
    endtask

    task automatic read_io(input [2:0] address, output [7:0] data);
        begin
            @(negedge clk);
            io_address = address;
            io_read = 1'b1;
            @(negedge clk);
            data = io_readdata;
            io_read = 1'b0;
        end
    endtask

    task automatic write_media(input [3:0] address, input [15:0] data);
        begin
            @(negedge clk);
            mgmt_address = address;
            mgmt_writedata = data;
            mgmt_write = 1'b1;
            @(negedge clk);
            mgmt_write = 1'b0;
        end
    endtask

    task automatic wait_for_irq;
        integer ticks;
        begin
            ticks = 0;
            while (!irq && ticks < 50000) begin
                @(posedge clk);
                ticks = ticks + 1;
            end
            if (!irq)
                $fatal(1, "FDC IRQ did not arrive after %0d clocks", ticks);
        end
    endtask

    task automatic sense_interrupt(output [7:0] st0, output [7:0] pcn);
        begin
            write_io(3'd5, 8'h08);
            read_io(3'd5, st0);
            read_io(3'd5, pcn);
        end
    endtask

    task automatic expect_equal(input [7:0] actual, input [7:0] expected, input [255:0] what);
        begin
            if (actual !== expected)
                $fatal(1, "%0s: expected %02x, got %02x", what, expected, actual);
        end
    endtask

    reg [7:0] st0;
    reg [7:0] pcn;
    reg [7:0] msr;
    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        // Same geometry advertised by the mounted 720 KiB image path.
        write_media(4'd0, 16'd1);
        write_media(4'd1, 16'd0);
        write_media(4'd2, 16'd80);
        write_media(4'd3, 16'd9);
        write_media(4'd4, 16'd1440);
        write_media(4'd5, 16'd2);
        if (!fdd0_inserted) $fatal(1, "drive 0 did not become present");

        // PC3086 initialises the controller by toggling DOR reset, then
        // drains reset completion with SENSE INTERRUPT STATUS.
        // Establish the disabled state first.  The platform reset normally
        // leaves DOR disabled; modelling it explicitly avoids treating the
        // controller's internal power-on enable value as a BIOS action.
        write_io(3'd2, 8'h00);
        write_io(3'd2, 8'h08);
        write_io(3'd2, 8'h0C);
        wait_for_irq();
        sense_interrupt(st0, pcn);
        expect_equal(st0, 8'hC0, "reset SENSE ST0");
        expect_equal(pcn, 8'h00, "reset SENSE PCN");

        // SPECIFY, motor-on, recalibrate and sense completion.
        write_io(3'd5, 8'h03);
        write_io(3'd5, 8'hDF);
        write_io(3'd5, 8'h02);
        write_io(3'd2, 8'h1C);
        write_io(3'd5, 8'h07);
        write_io(3'd5, 8'h00);
        wait_for_irq();
        sense_interrupt(st0, pcn);
        expect_equal(st0, 8'h20, "recalibrate SENSE ST0");
        expect_equal(pcn, 8'h00, "recalibrate SENSE PCN");

        // The native ROM then seeks and senses; verify both cylinder zero
        // and a non-zero target so parameter ordering is covered too.
        write_io(3'd5, 8'h0F);
        write_io(3'd5, 8'h00);
        write_io(3'd5, 8'h00);
        wait_for_irq();
        sense_interrupt(st0, pcn);
        expect_equal(st0, 8'h20, "seek-0 SENSE ST0");
        expect_equal(pcn, 8'h00, "seek-0 SENSE PCN");

        write_io(3'd5, 8'h0F);
        write_io(3'd5, 8'h00);
        write_io(3'd5, 8'h01);
        wait_for_irq();
        sense_interrupt(st0, pcn);
        expect_equal(st0, 8'h20, "seek-1 SENSE ST0");
        expect_equal(pcn, 8'h01, "seek-1 SENSE PCN");

        read_io(3'd4, msr);
        if (msr !== 8'h80) $fatal(1, "FDC did not return to command phase: MSR=%02x", msr);
        $display("PASS: PC3086 FDC reset/recalibrate/seek/SENSE sequence");
        $finish;
    end
endmodule
