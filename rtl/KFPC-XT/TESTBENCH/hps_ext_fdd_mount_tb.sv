`timescale 1ns/1ps

// Regression for the MiSTer mounted-floppy control path.
//
// It drives the same hps_ext command (0x61) and F2xx address window used by
// PCXT-EGA.sv/Peripherals.sv, then checks that floppy.v receives the complete
// 720 KiB geometry for drive A.  This intentionally bypasses the CPU: the
// existing PC3086 INT 13h test covers the CPU/765/DMA side independently.
module hps_ext_fdd_mount_tb;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg [15:0] host_din = 16'd0;
    reg        host_strobe = 1'b0;
    reg        host_enable = 1'b0;

    tri [35:0] ext_bus;
    assign ext_bus[31:16] = host_din;
    assign ext_bus[33]    = host_strobe;
    assign ext_bus[35:34] = host_enable ? 2'b01 : 2'b00;

    wire [15:0] ext_dout;
    wire [15:0] ext_addr;
    wire        ext_rd;
    wire        ext_wr;
    wire        ext_midi;

    hps_ext hps_ext_inst (
        .clk_sys    (clk),
        .EXT_BUS    (ext_bus),
        .ext_din    (16'd0),
        .ext_dout   (ext_dout),
        .ext_addr   (ext_addr),
        .ext_rd     (ext_rd),
        .ext_wr     (ext_wr),
        // Keep the FDD-read request asserted while the configuration command
        // starts.  hps_ext must return it in the command header that HPS
        // samples, independently of the later F2xx writes.
        .ext_req    (8'h80),
        .ext_hotswap(2'b00),
        .ext_midi   (ext_midi)
    );

    // This is deliberately the same F2xx decode used by Peripherals.sv.
    wire mgmt_fdd_cs = (ext_addr[15:8] == 8'hF2);
    wire mgmt_write  = ext_wr & mgmt_fdd_cs;

    wire       fdd0_inserted;
    wire [1:0] fdd_request;
    wire [15:0] mgmt_readdata;

    floppy floppy_inst (
        .clk            (clk),
        .rst_n          (1'b0),
        .dma_req        (),
        .dma_ack        (1'b0),
        .dma_tc         (1'b0),
        .dma_readdata   (8'd0),
        .dma_writedata  (),
        .irq            (),
        .io_address     (3'd0),
        .io_read        (1'b0),
        .io_readdata    (),
        .io_write       (1'b0),
        .io_writedata   (8'd0),
        .fdd0_inserted  (fdd0_inserted),
        .mgmt_address   (ext_addr[3:0]),
        .mgmt_fddn      (ext_addr[7]),
        .mgmt_write     (mgmt_write),
        .mgmt_writedata (ext_dout),
        .mgmt_read      (ext_rd & mgmt_fdd_cs),
        .mgmt_readdata  (mgmt_readdata),
        .wp             (2'b00),
        .clock_rate     (28'd28_636_360),
        .request        (fdd_request)
    );

    reg [15:0] seen_addr [0:6];
    reg [15:0] seen_data [0:6];
    reg [15:0] host_reply = 16'd0;
    integer seen_count = 0;

    always @(posedge clk) begin
        if(mgmt_write) begin
            seen_addr[seen_count] <= ext_addr;
            seen_data[seen_count] <= ext_dout;
            seen_count <= seen_count + 1;
        end
    end

    task automatic hps_write(input [15:0] addr, input [15:0] data);
        begin
            @(negedge clk); host_enable = 1'b1; host_strobe = 1'b1; host_din = 16'h0061;
            @(posedge clk);
            // io_dout is registered on the command cycle and is available to
            // HPS before it sends the address/data fields.
            @(negedge clk); host_reply = ext_bus[15:0]; host_din = addr;
            @(negedge clk); host_din = 16'h0000;
            @(negedge clk); host_din = data;
            @(negedge clk); host_enable = 1'b0; host_strobe = 1'b0; host_din = 16'h0000;
            repeat(2) @(posedge clk);
        end
    endtask

    task automatic check(input bit condition, input string message);
        begin
            if(!condition) begin
                $display("FAIL: %0s", message);
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat(2) @(posedge clk);

        // MiSTer mount configuration for a 3.5-inch 720 KiB image.
        hps_write(16'hF200, 16'h0001); // drive A present
        check(host_reply == 16'hE080, "HPS command header did not expose FDD request");
        hps_write(16'hF201, 16'h0000); // not write protected
        hps_write(16'hF202, 16'h0050); // 80 cylinders
        hps_write(16'hF203, 16'h0009); // 9 sectors/track
        hps_write(16'hF204, 16'h05A0); // 1440 sectors
        hps_write(16'hF205, 16'h0002); // 2 heads

        check(seen_count == 6, "expected one F2xx write per mount field");
        check(seen_addr[0] == 16'hF200 && seen_data[0] == 16'h0001, "F200 presence write missing");
        check(seen_addr[1] == 16'hF201 && seen_data[1] == 16'h0000, "F201 write-protect write missing");
        check(seen_addr[2] == 16'hF202 && seen_data[2] == 16'h0050, "F202 cylinder write missing");
        check(seen_addr[3] == 16'hF203 && seen_data[3] == 16'h0009, "F203 sector/track write missing");
        check(seen_addr[4] == 16'hF204 && seen_data[4] == 16'h05A0, "F204 sector-count write missing");
        check(seen_addr[5] == 16'hF205 && seen_data[5] == 16'h0002, "F205 heads write missing");
        check(fdd0_inserted, "F2xx presence did not make drive A inserted");
        check(floppy_inst.wp_sys[0] == 1'b0, "write-protect state was not cleared");
        check(floppy_inst.media_cylinders[0] == 8'd80, "wrong cylinder count");
        check(floppy_inst.media_sectors_per_track[0] == 8'd9, "wrong sectors/track");
        check(floppy_inst.media_sector_count[0] == 16'd1440, "wrong sector count");
        check(floppy_inst.media_heads[0] == 2'd2, "wrong head count");

        // F2FF is the data stream port. hps_ext must not carry into F300.
        hps_write(16'hF2FF, 16'h00A5);
        check(seen_count == 7 && seen_addr[6] == 16'hF2FF && seen_data[6] == 16'h00A5,
              "F2FF stream-port write missing");
        check(ext_addr == 16'hF2FF, "F2FF must not auto-increment into F300");

        $display("PASS: hps_ext command 61 configures F2xx drive-A mount and preserves F2FF stream port");
        $finish;
    end
endmodule
