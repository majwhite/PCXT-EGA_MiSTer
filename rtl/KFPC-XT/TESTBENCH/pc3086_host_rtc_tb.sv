`timescale 1ns / 1ps
module pc3086_host_rtc_tb;
    reg clk = 0;
    always #10 clk = ~clk;
    reg [64:0] host_rtc = 0;
    reg [15:0] hps_address = 16'h1234, hps_writedata = 16'hABCD;
    reg hps_write = 0, hps_read = 0;
    wire [15:0] mgmt_address, mgmt_writedata;
    wire mgmt_write, mgmt_read, done;
    reg system_reset = 0;
    wire reset_n = done && !system_reset;
    reg io_address = 0, io_read = 0, io_write = 0;
    reg [7:0] io_writedata = 0;
    wire [7:0] io_readdata;
    pc3086_host_rtc loader (.*);
    rtc clock_device (
        .clk(clk), .rst_n(reset_n), .irq(),
        .io_address(io_address), .io_read(io_read), .io_write(io_write),
        .io_writedata(io_writedata), .io_readdata(io_readdata),
        .memcfg(1'b0), .bootcfg(6'd0), .clock_rate(28'd50_000_000),
        .mgmt_address(mgmt_address[7:0]),
        .mgmt_write(mgmt_write && mgmt_address[15:8] == 8'hF4),
        .mgmt_writedata(mgmt_writedata[7:0])
    );
    reg [7:0] expected_address [0:17];
    reg [7:0] expected_data [0:17];
    integer writes = 0;
    always @(posedge clk) begin
        if (!done && mgmt_write && mgmt_address[15:8] == 8'hF4) begin
            if (writes >= 18) $fatal(1, "unexpected extra startup write");
            if (mgmt_address !== {8'hF4, expected_address[writes]} ||
                mgmt_writedata !== {8'h00, expected_data[writes]})
                $fatal(1, "write %0d: address=%h data=%h", writes, mgmt_address, mgmt_writedata);
            if (done || reset_n || mgmt_read) $fatal(1, "CPU/read enabled during initialization");
            writes = writes + 1;
        end
    end

    task automatic check_register(input [7:0] index, input [7:0] expected);
        begin
            @(negedge clk);
            io_address = 0; io_writedata = index; io_write = 1;
            @(negedge clk);
            io_write = 0; io_address = 1; io_read = 1;
            repeat (2) @(negedge clk);
            // Status A bit 7 is the dynamic update-in-progress indication.
            if ((index == 8'h0A ? (io_readdata & 8'h7F) : io_readdata) !== expected)
                $fatal(1, "RTC %h: got %h expected %h", index, io_readdata, expected);
            io_read = 0;
        end
    endtask

    task automatic check_passthrough;
        begin
            #1;
            if (mgmt_address !== hps_address || mgmt_writedata !== hps_writedata ||
                mgmt_write !== hps_write || mgmt_read !== hps_read)
                $fatal(1, "HPS management passthrough failed");
        end
    endtask

    initial begin
        expected_address[0]='h0B; expected_data[0]='h02;
        expected_address[1]='h0A; expected_data[1]='h26;
        expected_address[2]='h00; expected_data[2]='h58;
        expected_address[3]='h02; expected_data[3]='h59;
        expected_address[4]='h04; expected_data[4]='h23;
        expected_address[5]='h06; expected_data[5]='h07;
        expected_address[6]='h07; expected_data[6]='h31;
        expected_address[7]='h08; expected_data[7]='h12;
        expected_address[8]='h09; expected_data[8]='h99;
        expected_address[9]='h0E; expected_data[9]='h59;
        expected_address[10]='h0F; expected_data[10]='h23;
        expected_address[11]='h10; expected_data[11]='h07;
        expected_address[12]='h11; expected_data[12]='h31;
        expected_address[13]='h12; expected_data[13]='h12;
        expected_address[14]='h13; expected_data[14]='h99;
        expected_address[15]='h14; expected_data[15]='h20;
        expected_address[16]='h32; expected_data[16]='h20;
        expected_address[17]='h15; expected_data[17]='h7F;
        repeat (3) @(negedge clk);
        hps_write = 1; hps_read = 1;
        check_passthrough();
        // An invalid packet must not release reset; both toggle directions
        // work, and changing calendar data alone must not trigger loading.
        host_rtc[64] = 1;
        repeat (3) @(negedge clk);
        if (done || writes != 0) $fatal(1, "invalid packet accepted");
        host_rtc[63:0] = 64'h4006991231235958;
        repeat (3) @(negedge clk);
        if (done || writes != 0) $fatal(1, "uncommitted packet accepted");
        host_rtc[64] = 0;
        @(negedge clk);
        // Startup must own the bus even if HPS is also driving writes/reads.
        if (mgmt_read || mgmt_address != 16'hF40B) $fatal(1, "arbitration failed");
        // New HPS data during the write sequence must not tear the snapshot.
        host_rtc = {1'b1, 64'h4000260111082400};
        wait(done);
        @(negedge clk);
        if (writes != 18) $fatal(1, "wrong write count");
        check_passthrough();
        hps_write = 0; hps_read = 0;
        for (integer i = 0; i < 18; i = i + 1)
            check_register(expected_address[i], expected_data[i]);
        check_register(8'h0D, 8'h80);
        check_register(8'h37, 8'h20);
        // Guest changes minutes, then resets. Loader must stay done and the
        // RTC live register must survive the normal hardware reset as well.
        @(negedge clk);
        io_address = 0; io_writedata = 8'h02; io_write = 1;
        @(negedge clk);
        io_address = 1; io_writedata = 8'h17;
        @(negedge clk);
        io_write = 0; system_reset = 1;
        repeat (5) @(negedge clk);
        system_reset = 0;
        host_rtc[64] = ~host_rtc[64];
        repeat (25) @(negedge clk);
        if (!done || writes != 18) $fatal(1, "startup retriggered");
        check_register(8'h02, 8'h17);
        hps_address = 16'hF402; hps_writedata = 16'h0018; hps_write = 1;
        @(negedge clk);
        hps_write = 0;
        check_register(8'h02, 8'h18);
        $display("PASS: host RTC sequence, snapshot, checksum overflow, RTC readback, reset persistence and bus arbitration");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "TIMEOUT");
    end
endmodule
