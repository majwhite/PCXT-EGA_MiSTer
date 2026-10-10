`timescale 1ns/1ps

// Execute the unmodified mouse-coordinate POST at FC00:0483 against the
// production stationary-mouse decoder. Only success/error exits are patched.
module i8088_pc3086_mouse_post_tb;
  reg core_clk = 0, clk = 0, reset = 1;
  always #5 core_clk = ~core_clk;
  always #105 clk = ~clk;
  reg [7:0] memory [0:1048575];
  reg [19:0] bus_address = 0;
  reg [2:0] last_status = 3'b111;
  reg last_mux = 0, io_drive = 0;
  wire [19:0] ad_out;
  wire [7:0] dout;
  wire [2:0] status;
  wire mux, mouse_selected;
  wire [7:0] mouse_data;
  wire [7:0] din = io_drive ? (mouse_selected ? mouse_data : 8'hFF)
                          : memory[bus_address];
  integer cycles = 0, reads = 0, writes = 0;

  PC3086_MOUSE_COORDINATES mouse (
    .address(bus_address), .iorq(io_drive), .address_enable_n(1'b0),
    .selected(mouse_selected), .read_data(mouse_data)
  );
  pc3086_test_cpu cpu (
    .CORE_CLK(core_clk), .CLK(clk), .RESET(reset), .READY(1'b1),
    .INTR(1'b0), .NMI(1'b0), .ad_out(ad_out), .dout(dout), .din(din),
    .s6_3_mux(mux), .s2_s0_out(status), .cycle_accrate(1'b0),
    .clock_cycle_counter_division_ratio(8'h00),
    .clock_cycle_counter_decrement_value(8'h00), .shift_read_timing(1'b0)
  );

  integer i;
  initial begin
    for (i = 0; i < 1048576; i = i + 1) memory[i] = 8'hF4;
    $readmemh("pc3086-system-mirrored.hex", memory, 20'hF0000, 20'hFFFFF);
    memory[20'hFFFF0] = 8'hEA;
    memory[20'hFFFF1] = 8'h83; memory[20'hFFFF2] = 8'h04;
    memory[20'hFFFF3] = 8'h00; memory[20'hFFFF4] = 8'hFC;
    // Success returns to peripheral initialization at FC00:0170.
    memory[20'hFC170] = 8'hB0; memory[20'hFC171] = 8'h55;
    memory[20'hFC172] = 8'hE6; memory[20'hFC173] = 8'hE9;
    memory[20'hFC174] = 8'hF4;
    // Preserve AL, the BIOS error number, at its shared error dispatcher.
    memory[20'hFD9FE] = 8'hE6; memory[20'hFD9FF] = 8'hE9;
    memory[20'hFDA00] = 8'hF4;
    repeat (20) @(posedge core_clk);
    reset = 0;
  end

  always @(posedge core_clk) begin
    #1;
    if (!reset) begin
      cycles = cycles + 1;
      if (cycles > 50000) $fatal(1, "mouse POST timeout");
      if (status != last_status) begin
        if (status != 3'b111) begin
          bus_address = ad_out;
          io_drive = (status == 3'b001);
          if (io_drive && (bus_address[15:0] == 16'h0078 ||
                           bus_address[15:0] == 16'h007A)) begin
            #1;
            if (!mouse_selected) $fatal(1, "production mouse decoder did not select");
            reads = reads + 1;
            $display("MOUSE RD %04h=%02h", bus_address[15:0], mouse_data);
          end
        end
        last_status = status;
      end
      if (status == 3'b010 && mux && !last_mux) begin
        if (bus_address[15:0] == 16'h0078 || bus_address[15:0] == 16'h007A) begin
          writes = writes + 1;
          if (dout !== 8'h00) $fatal(1, "unexpected mouse POST write %02h", dout);
        end
        if (bus_address[15:0] == 16'h00E9) begin
          if (dout !== 8'h55) $fatal(1, "ROM mouse POST error %02h", dout);
          if (reads != 2 || writes != 2)
            $fatal(1, "POST skipped coordinates: reads=%0d writes=%0d", reads, writes);
          $display("PASS: real ROM mouse-coordinate POST (%0d cycles)", cycles);
          $finish;
        end
      end
      last_mux = mux;
    end
  end
endmodule

// Ordinary builds must not claim these ports. Check qualification and aliases
// in both configurations, independently of the ROM test.
module pc3086_mouse_decode_tb;
  reg [19:0] address = 0;
  reg iorq = 1, aen = 0;
  wire selected;
  wire [7:0] data;
  PC3086_MOUSE_COORDINATES dut (
    .address(address), .iorq(iorq), .address_enable_n(aen),
    .selected(selected), .read_data(data)
  );
  task check;
    input [19:0] port;
    input expected;
    begin
      address = port;
      #1;
      if (selected !== expected || data !== 8'h00)
        $fatal(1, "mouse decode port=%05h selected=%b expected=%b data=%02h",
               port, selected, expected, data);
    end
  endtask
  initial begin
`ifdef PC3086_LEGACY_PPI
    check(20'h00078, 1); check(20'h0007A, 1);
`else
    check(20'h00078, 0); check(20'h0007A, 0);
`endif
    check(20'h00079, 0); check(20'h0007B, 0);
    check(20'h00178, 0); check(20'h0017A, 0);
    iorq = 0; check(20'h00078, 0);
    iorq = 1; aen = 1; check(20'h0007A, 0);
    $display("PASS: mouse decoder qualification and aliases");
    $finish;
  end
endmodule
