// Zero-FPGA-build contract test for the PC3086 system-port decode.  It checks
// both configurations: PC3086 gets a preprogrammed PPI at 60h..63h, write-only
// Status-1/Status-2 at 64h/65h and RTC at 70h/71h; a normal build keeps the
// historical 8255 60h..7Fh alias intact.

`timescale 1ns / 1ps

module pc3086_io_decode_tb;
    logic [19:0] address;
    logic        iorq;
    logic        address_enable_n;
    logic        ppi_60_7f_select;
    logic        pc3086_rtc_select;
    logic        pc3086_status1_write_select;
    logic        pc3086_status2_write_select;
    integer      failures = 0;

    PC3086_IO_DECODE dut (
        .address(address),
        .iorq(iorq),
        .address_enable_n(address_enable_n),
        .ppi_60_7f_select(ppi_60_7f_select),
        .pc3086_rtc_select(pc3086_rtc_select),
        .pc3086_status1_write_select(pc3086_status1_write_select),
        .pc3086_status2_write_select(pc3086_status2_write_select)
    );

    task automatic check_port(
        input logic [15:0] port,
        input logic expected_ppi,
        input logic expected_rtc,
        input logic expected_status1,
        input logic expected_status2,
        input string label_text
    );
        begin
            address = {4'h0, port};
            #1;
            if (ppi_60_7f_select !== expected_ppi ||
                pc3086_rtc_select !== expected_rtc ||
                pc3086_status1_write_select !== expected_status1 ||
                pc3086_status2_write_select !== expected_status2) begin
                failures = failures + 1;
                $display("FAIL: %s port=%04h ppi=%b rtc=%b s1=%b s2=%b expected=%b/%b/%b/%b",
                         label_text, port, ppi_60_7f_select, pc3086_rtc_select,
                         pc3086_status1_write_select, pc3086_status2_write_select,
                         expected_ppi, expected_rtc, expected_status1, expected_status2);
            end else begin
                $display("PASS: %s port=%04h ppi=%b rtc=%b s1=%b s2=%b",
                         label_text, port, ppi_60_7f_select, pc3086_rtc_select,
                         pc3086_status1_write_select, pc3086_status2_write_select);
            end
        end
    endtask

    initial begin
        iorq = 1'b1;
        address_enable_n = 1'b0;

`ifdef PC3086_LEGACY_PPI
        check_port(16'h0060, 1'b1, 1'b0, 1'b0, 1'b0, "PC3086 PPI port A");
        check_port(16'h0063, 1'b1, 1'b0, 1'b0, 1'b0, "PC3086 PPI control");
        check_port(16'h0064, 1'b0, 1'b0, 1'b1, 1'b0, "PC3086 Status-1 write");
        check_port(16'h0065, 1'b0, 1'b0, 1'b0, 1'b1, "PC3086 Status-2 write");
        check_port(16'h0066, 1'b0, 1'b0, 1'b0, 1'b0, "PC3086 reset port");
        check_port(16'h0072, 1'b0, 1'b0, 1'b0, 1'b0, "PC3086 no PPI alias");
        check_port(16'h0160, 1'b0, 1'b0, 1'b0, 1'b0, "PC3086 no high-byte PPI alias");
        check_port(16'h0070, 1'b0, 1'b1, 1'b0, 1'b0, "PC3086 RTC index");
        check_port(16'h0071, 1'b0, 1'b1, 1'b0, 1'b0, "PC3086 RTC data");
        check_port(16'h0170, 1'b0, 1'b0, 1'b0, 1'b0, "PC3086 no high-byte RTC alias");
`else
        check_port(16'h0060, 1'b1, 1'b0, 1'b0, 1'b0, "PPI keyboard data");
        check_port(16'h0061, 1'b1, 1'b0, 1'b0, 1'b0, "PPI keyboard control");
        check_port(16'h0064, 1'b1, 1'b0, 1'b0, 1'b0, "PPI legacy alias");
        check_port(16'h0072, 1'b1, 1'b0, 1'b0, 1'b0, "PPI window after RTC pair");
        check_port(16'h0160, 1'b1, 1'b0, 1'b0, 1'b0, "PPI high-byte alias");
        check_port(16'h0070, 1'b1, 1'b0, 1'b0, 1'b0, "normal-build RTC-index alias");
        check_port(16'h0071, 1'b1, 1'b0, 1'b0, 1'b0, "normal-build RTC-data alias");
`endif

        // I/O qualification and AEN are mandatory; neither may select a device.
        iorq = 1'b0;
        check_port(16'h0070, 1'b0, 1'b0, 1'b0, 1'b0, "memory access does not decode");
        iorq = 1'b1;
        address_enable_n = 1'b1;
        check_port(16'h0070, 1'b0, 1'b0, 1'b0, 1'b0, "AEN suppresses decode");

        if (failures != 0) $fatal(1, "PC3086 I/O decode regression failed");
        $display("RESULT: PC3086 I/O decode regression passed");
        $finish;
    end
endmodule
