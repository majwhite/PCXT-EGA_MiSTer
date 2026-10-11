`timescale 1ns/1ps
// Focused integration: production XT2IDE, ide and hps_ext. The small glue below
// mirrors Peripherals.sv (including its delayed strobes), not a full CPU/HPS.
module xtide_ata_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1;
    reg [15:0] address = 0;
    reg rd_n = 1, wr_n = 1;
    reg [7:0] data_in = 0;
    wire [7:0] data_out;
    wire cs_n = !(address[15:4] == 12'h030);
    wire cs1_n, cs3_n, ata_rd_n, ata_wr_n;
    wire [2:0] ata_address;
    wire [15:0] ata_out;
    wire [31:0] ata_in;
    wire [2:0] request;
    wire [1:0] present;
    wire ignore_access;
    reg [1:0] use_mmc = 0;

    XT2IDE adapter (
        .clock(clk), .reset(reset), .high_speed(1'b0),
        .chip_select_n(cs_n), .io_read_n(rd_n), .io_write_n(wr_n),
        .address({1'b0,address[3:0]}), .data_bus_in(data_in), .data_bus_out(data_out),
        .ide_cs1fx(cs1_n), .ide_cs3fx(cs3_n),
        .ide_io_read_n(ata_rd_n), .ide_io_write_n(ata_wr_n),
        .ide_address(ata_address), .ide_data_bus_in(ata_in[15:0]),
        .ide_data_bus_out(ata_out)
    );
    wire control_cs = !cs3_n && (&ata_address[2:1]);
    wire ata_rd = !ata_rd_n && (!cs1_n || control_cs);
    wire ata_wr = !ata_wr_n && (!cs1_n || control_cs);
    reg read_1, prev_read, prev_write;
    reg [3:0] address_1;
    reg [15:0] writedata;
    always @(posedge clk) begin
        read_1 <= ata_rd;
        prev_read <= read_1;
        prev_write <= ata_wr;
        address_1 <= {control_cs,ata_address};
        writedata <= ata_out;
    end

    tri [35:0] ext_bus;
    reg [15:0] hps_data = 0;
    reg hps_strobe = 0, hps_enable = 0;
    assign ext_bus[31:16] = hps_data;
    assign ext_bus[33] = hps_strobe;
    assign ext_bus[35:34] = {1'b0,hps_enable};
    wire [15:0] mgmt_addr, mgmt_out, mgmt_in;
    wire mgmt_rd, mgmt_wr;
    hps_ext management (
        .clk_sys(clk), .EXT_BUS(ext_bus), .ext_din(mgmt_in),
        .ext_dout(mgmt_out), .ext_addr(mgmt_addr),
        .ext_rd(mgmt_rd), .ext_wr(mgmt_wr), .ext_midi(),
        .ext_req({5'd0,request}), .ext_hotswap(2'b00)
    );
    wire mgmt_cs = mgmt_addr[15:8] == 8'hf0;
    ide disk (
        .clk(clk), .rst_n(!reset), .irq(), .drq(), .use_fast(1'b0),
        .no_data(), .drive_en(present), .io_address(address_1),
        .io_read(ata_rd && !prev_read), .io_readdata(ata_in),
        .io_write(!ata_wr && prev_write), .io_writedata({16'd0,writedata}),
        .io_32(1'b0), .io_wait(), .request(request),
        .mgmt_address(mgmt_addr[3:0]), .mgmt_write(mgmt_wr && mgmt_cs),
        .mgmt_writedata(mgmt_out), .mgmt_read(mgmt_rd && mgmt_cs),
        .mgmt_readdata(mgmt_in), .primary_only(use_mmc == 2),
        .secondary_only(use_mmc == 1), .ignore_access(ignore_access)
    );

    task tick(input integer n);
        repeat(n) begin @(posedge clk); #1; end
    endtask
    task hps_word(input [15:0] value);
        @(negedge clk); hps_data = value; hps_strobe = 1;
        tick(1);
        @(negedge clk); hps_strobe = 0;
        tick(3);
    endtask
    task hps_begin(input [15:0] command, input [15:0] addr);
        @(negedge clk); hps_enable = 0;
        tick(2);
        @(negedge clk); hps_enable = 1;
        hps_word(command); hps_word(addr); hps_word(0); // protocol dummy
    endtask
    task hps_end;
        @(negedge clk); hps_enable = 0;
        tick(3);
    endtask
    task mgmt_write(input [15:0] addr, input [15:0] value);
        hps_begin(16'h61,addr); hps_word(value); hps_end();
    endtask
    task outb(input [15:0] port, input [7:0] value);
        @(negedge clk); address = port; data_in = value;
        tick(3); // address setup, before active strobe
        @(negedge clk); wr_n = 0;
        tick(8);
        @(negedge clk); wr_n = 1;
        tick(5); // hold address/data through delayed trailing-edge write
    endtask
    task inb(input [15:0] port, output [7:0] value);
        @(negedge clk); address = port;
        tick(3);
        @(negedge clk); rd_n = 0;
        tick(8); value = data_out;
        @(negedge clk); rd_n = 1;
        tick(5);
    endtask
    task expect_byte(input [15:0] port, input [7:0] expected);
        reg [7:0] actual;
        inb(port,actual);
        if(actual !== expected)
            $fatal(1,"port %h: got %h expected %h",port,actual,expected);
    endtask
    task respond_block(input [15:0] seed);
        integer i;
        // One sector: 256 ATA words; status DRDY+DRQ, final block.
        mgmt_write(16'hf000,16'h0001);
        hps_begin(16'h61,16'hf0ff); // FF address stays fixed for streaming
        for(i=0;i<256;i=i+1) hps_word(seed+i);
        hps_end();
        mgmt_write(16'hf005,16'h4a00);
        if(request !== 0 || disk.status !== 8'h48)
            $fatal(1,"management completion did not clear request/set DRQ");
        for(i=0;i<256;i=i+1) begin
            expect_byte(16'h300,(seed+i)&255);
            expect_byte(16'h308,((seed+i)>>8)&255);
        end
        if(disk.io_cnt !== 256 || disk.status !== 8'h40 || request !== 0)
            $fatal(1,"incorrect block completion: cnt=%d status=%h request=%b",
                   disk.io_cnt,disk.status,request);
    endtask

    initial begin
        tick(5); reset = 0; tick(5);
        if(present !== 0) $fatal(1,"drive present before mount");
        expect_byte(16'h307,8'hff);
        mgmt_write(16'he006,16'h0009); // wrong management chip select
        if(present !== 0) $fatal(1,"wrong management address set presence");
        mgmt_write(16'hf006,16'h0009); // update master only: present=1
        if(present !== 1) $fatal(1,"HPS presence update lost");
        @(negedge clk); reset = 1;
        tick(3);
        @(negedge clk); reset = 0;
        tick(3);
        if(present !== 1 || request !== 6)
            $fatal(1,"reset lost mount or failed to request HPS reset response");
        mgmt_write(16'hf005,16'h4000); // emulate reset response, DRDY
        expect_byte(16'h307,8'h40);
        expect_byte(16'h30e,8'h40); // alternate status
        outb(16'h302,8'h55); expect_byte(16'h302,8'h55);
        outb(16'h303,8'haa); expect_byte(16'h303,8'haa);
        // XT-CF uses doubled offsets: IDENTIFY at 30E becomes DEVICE CONTROL,
        // not COMMAND, and EC's SRST bit actually holds this controller reset.
        outb(16'h30e,8'hec);
        if(disk.cmd !== 0 || disk.sw_reset !== 1 || request !== 6)
            $fatal(1,"XT-CF mismatch was not reproduced");
        outb(16'h30e,0); mgmt_write(16'hf005,16'h4000);
        outb(16'h327,8'hec); // unmapped base must not issue command
        if(request !== 0) $fatal(1,"320h alias unexpectedly decoded");
        outb(16'h306,8'ha0);
        use_mmc = 1; tick(3);
        if(!ignore_access) $fatal(1,"MMC master routing not applied");
        use_mmc = 2; tick(3);
        if(ignore_access) $fatal(1,"MMC slave routing incorrectly hid master");
        use_mmc = 0;
        outb(16'h307,8'hec);
        if(disk.cmd !== 8'hec || request !== 4)
            $fatal(1,"rev-1 IDENTIFY did not reach ATA/HPS");
        hps_begin(16'h62,16'hf005); hps_word(0);
        if(ext_bus[15:0] !== 16'heca0)
            $fatal(1,"HPS command readback incorrect: %h",ext_bus[15:0]);
        hps_end();
        respond_block(16'h1234);
        outb(16'h302,1); outb(16'h303,1);
        outb(16'h304,0); outb(16'h305,0);
        outb(16'h307,8'h20);
        if(disk.cmd !== 8'h20 || request !== 4)
            $fatal(1,"READ SECTORS did not reach ATA/HPS");
        respond_block(16'h5600);
        // Exercise data writes: high byte first, then low byte commits word.
        outb(16'h307,8'h30);
        mgmt_write(16'hf000,16'h0001);
        mgmt_write(16'hf005,16'h4800);
        outb(16'h308,8'hab); outb(16'h300,8'hcd);
        outb(16'h308,8'h12); outb(16'h300,8'h34);
        if(disk.io_cnt !== 2 || disk.io_buf0.mem[0] !== 16'habcd ||
           disk.io_buf1.mem[0] !== 16'h1234)
            $fatal(1,"rev-1 high-byte write latch/ordering incorrect");
        mgmt_write(16'hf006,16'h0008); // unmount
        if(present !== 0) $fatal(1,"unmount did not clear presence");
        expect_byte(16'h307,8'hff);
        $display("PASS: HPS presence, XT-CF mismatch, rev-1 IDENTIFY/READ, byte ordering");
        $finish;
    end
    initial begin #1000000; $fatal(1,"TIMEOUT"); end
endmodule

// Icarus model of bram.vhd's synchronous dual-port RAM. Not synthesized.
module dpram #(parameter addr_width=8, data_width=8) (
    input clock,
    input [addr_width-1:0] address_a, address_b,
    input [data_width-1:0] data_a, data_b,
    input wren_a, wren_b,
    output reg [data_width-1:0] q_a, q_b
);
    reg [data_width-1:0] mem [0:(1<<addr_width)-1];
    always @(posedge clock) begin
        if(wren_a) mem[address_a] <= data_a;
        if(wren_b) mem[address_b] <= data_b;
        q_a <= mem[address_a]; q_b <= mem[address_b];
    end
endmodule
