`timescale 1ns/1ps

// End-to-end execution of the PC3086 interval-timer POST at F000:C204.
//
// This test intentionally runs the production 8088 and production KF8253
// together.  The timer input is 1.193 MHz (the XT 14.318 MHz / 12 clock) and
// the 8088 CLK pin is the normal 4.77 MHz XT rate.  F000:C26F and F000:D9FE
// are replaced with tiny port-E9 markers so the fixture distinguishes the
// ROM's success path from its "Faulty interval timer" path without modelling
// the later POST devices.  Counter 1 is accelerated to keep the simulation
// short, so the ROM's real-time window check is neutralised; the fixture still
// executes its actual counter programming, latch/read sequence and the
// post-rollover success branch.
module i8088_pc3086_pit_post_tb;
  localparam [19:0] RESET_VECTOR = 20'hFFFF0;
  localparam integer MAX_CYCLES = 1200000;

  reg core_clk = 1'b0;
  reg clk = 1'b0;
  reg reset = 1'b1;
  reg ready = 1'b1;
  reg intr = 1'b0;
  reg nmi = 1'b0;
  wire [19:0] ad_out;
  wire [7:0] dout;
  wire lock_n, s6_3_mux, biu_done, debug_nmi_caught;
  wire [2:0] s2_s0_out, segment;
  wire [15:0] debug_ax, debug_bx, debug_biu_data_latch, debug_pfq_addr, debug_cs;
  wire [7:0] debug_biu_state;
  wire [12:0] debug_uaddr, debug_write_uaddr;
  wire [15:0] debug_alu, debug_write_request_data, debug_write_t1_data,
              debug_write_alu, debug_write_ax, debug_write_bx, debug_eu_dataout;
  wire [19:0] debug_write_address;
  wire [7:0] debug_write_code;

  reg [7:0] memory [0:1048575];
  reg [19:0] bus_address = 20'h00000;
  reg [2:0] last_status = 3'b111;
  reg last_mux = 1'b0;
  reg [31:0] cycle_count = 0;
  reg io_read_data_drive = 1'b0;
  reg [7:0] io_read_data = 8'hFF;
  reg [7:0] port_e9_tag = 8'h00;
  reg [7:0] port61_out = 8'h00;

  // Same clock relationships as XT_CE_Generator at its default 4.77 MHz
  // setting: 100 MHz chipset domain, 4.77 MHz 8088 CLK, 1.193 MHz PIT clock.
  always #5 core_clk = ~core_clk;
  always #105 clk = ~clk;

  reg pit_clock = 1'b1;
  always #419 pit_clock = ~pit_clock;
  // Counter 2's early read-back test retains the physical 1.193 MHz clock.
  // The standalone PIT regression covers all channels at that rate.  Only
  // counter 1's later long wrap window is accelerated heavily here, so this
  // full CPU/PIT test reaches the ROM's branch decision quickly without
  // weakening the counter 2 read/load verification.  The focused PIT test
  // retains the physical-rate counter behaviour.
  reg pit_clock_1 = 1'b1;
  always #10 pit_clock_1 = ~pit_clock_1;

  // The production KF8253 control block recognises a write on the rising
  // edge of WR#.  Keep decode valid for that trailing core-clock sample; the
  // 8088 status pins themselves have already returned passive by then.
  wire pit_selected = (bus_address[15:2] == 14'h0010);
  wire pit_read_n = !((s2_s0_out == 3'b001) && pit_selected);
  wire pit_write_n = !((s2_s0_out == 3'b010) && pit_selected);
  wire [7:0] pit_data_bus_out;
  wire [7:0] din = io_read_data_drive ? io_read_data : memory[bus_address];

  KF8253 pit (
    .clock(core_clk), .reset(reset), .chip_select_n(!pit_selected),
    .read_enable_n(pit_read_n), .write_enable_n(pit_write_n),
    .address(bus_address[1:0]), .data_bus_in(dout), .data_bus_out(pit_data_bus_out),
    .counter_0_clock(pit_clock), .counter_0_gate(1'b1), .counter_0_out(),
    .counter_1_clock(pit_clock_1), .counter_1_gate(1'b1), .counter_1_out(),
    .counter_2_clock(pit_clock), .counter_2_gate(port61_out[0]), .counter_2_out()
  );

  i8088 dut (
    .CORE_CLK(core_clk), .CLK(clk), .RESET(reset), .READY(ready),
    .INTR(intr), .NMI(nmi), .ad_out(ad_out), .dout(dout), .din(din),
    .lock_n(lock_n), .s6_3_mux(s6_3_mux), .s2_s0_out(s2_s0_out),
    .SEGMENT(segment), .biu_done(biu_done), .cycle_accrate(1'b0),
    .clock_cycle_counter_division_ratio(8'h00),
    .clock_cycle_counter_decrement_value(8'h00), .shift_read_timing(1'b0),
    .DEBUG_NMI_CAUGHT(debug_nmi_caught), .DEBUG_CS(debug_cs),
    .DEBUG_PFQ_ADDR(debug_pfq_addr), .DEBUG_EU_BIU_DATAOUT(debug_eu_dataout),
    .DEBUG_EU_AX(debug_ax), .DEBUG_EU_BX(debug_bx),
    .DEBUG_EU_DATAOUT_UADDR(debug_uaddr), .DEBUG_EU_DATAOUT_ALU(debug_alu),
    .DEBUG_BIU_DATA_LATCH(debug_biu_data_latch), .DEBUG_BIU_STATE(debug_biu_state),
    .DEBUG_BIU_WRITE_ADDRESS(debug_write_address), .DEBUG_BIU_WRITE_CODE(debug_write_code),
    .DEBUG_BIU_WRITE_REQUEST_DATA(debug_write_request_data),
    .DEBUG_BIU_WRITE_T1_DATA(debug_write_t1_data),
    .DEBUG_BIU_WRITE_EU_UADDR(debug_write_uaddr), .DEBUG_BIU_WRITE_EU_ALU(debug_write_alu),
    .DEBUG_BIU_WRITE_EU_AX(debug_write_ax), .DEBUG_BIU_WRITE_EU_BX(debug_write_bx)
  );

  task fail;
    input [8*120-1:0] reason;
    begin
      $display("FAIL: %0s CS:IP=%04h:%04h AX=%04h BX=%04h", reason,
               debug_cs, debug_pfq_addr, debug_ax, debug_bx);
      $finish_and_return(1);
    end
  endtask

  integer i;
  initial begin
    for (i = 0; i < 1048576; i = i + 1) memory[i] = 8'hF4;
    $readmemh("pc3086-system-mirrored.hex", memory, 20'hF0000, 20'hFFFFF);

    // Begin at the real timer POST, with the BIOS owning DS initialisation.
    memory[RESET_VECTOR + 0] = 8'hEA; memory[RESET_VECTOR + 1] = 8'h04;
    memory[RESET_VECTOR + 2] = 8'hC2; memory[RESET_VECTOR + 3] = 8'h00;
    memory[RESET_VECTOR + 4] = 8'hF0;

    // A successful timer test falls through to C26F; an error dispatcher is
    // entered at D9FE with AL=06.  Mark each route without modifying the code
    // that performs the timer operations themselves.
    memory[20'hFC26F] = 8'hB0; memory[20'hFC270] = 8'h55;
    memory[20'hFC271] = 8'hE6; memory[20'hFC272] = 8'hE9;
    memory[20'hFC273] = 8'hF4;
    memory[20'hFD9FE] = 8'hB0; memory[20'hFD9FF] = 8'hEE;
    memory[20'hFDA00] = 8'hE6; memory[20'hFDA01] = 8'hE9;
    memory[20'hFDA02] = 8'hF4;

    // C25A normally rejects a rollover which occurs too early in wall-clock
    // time.  C1 is intentionally accelerated in this CPU-level regression,
    // so retain the branch exercise while removing only that timing guard.
    memory[20'hFC25A] = 8'h31; memory[20'hFC25B] = 8'hC9; // xor cx,cx
    memory[20'hFC25C] = 8'h90; memory[20'hFC25D] = 8'h90;

    $display("PC3086 timer POST integration: F000:C204, 4.77 MHz CPU, 1.193 MHz PIT");
    repeat (20) @(posedge core_clk);
    reset = 1'b0;
  end

  always @(posedge core_clk) begin
    #1;
    if (!reset) begin
      cycle_count = cycle_count + 1;
      if ((cycle_count % 100000) == 0)
        $display("progress: core cycles=%0d CS:IP=%04h:%04h C1=%05h", cycle_count,
                 debug_cs, debug_pfq_addr, pit.u_KF8253_Counter_1.count);
      if (cycle_count > MAX_CYCLES)
        fail("timeout before PC3086 timer POST result");

      if (s2_s0_out != last_status) begin
        // The 8088 samples I/O data after the status pins return passive, so
        // retain a PIT read value until the next non-I/O cycle.
        if (s2_s0_out == 3'b001) begin
          bus_address = ad_out;
          io_read_data_drive = 1'b1;
          #1 io_read_data = pit_data_bus_out;
          // Counter 1 is the decision-making phase of the BIOS test.  Keep
          // its read-back visible in this integration fixture so a failing
          // ROM branch remains diagnosable without an FPGA build.
          if ((ad_out[7:0] == 8'h42) || (ad_out[7:0] == 8'h41))
            $display("PIT RD %02h=%02h", ad_out[7:0], io_read_data);
        end else begin
          if (s2_s0_out != 3'b111) bus_address = ad_out;
          // Keep a read datum across the passive status interval: biu_max
          // samples it after S2:S0 has returned to 111.
          if (s2_s0_out != 3'b111) io_read_data_drive = 1'b0;
        end
        last_status = s2_s0_out;
      end

      // T2 is the unambiguous write-data phase for this maximum-mode bus.
      if (s2_s0_out == 3'b010 && s6_3_mux && !last_mux) begin
        if ((bus_address[15:0] == 16'h0042) || (bus_address[15:0] == 16'h0041) ||
            ((bus_address[15:0] == 16'h0043) && (dout != 8'h48)))
          $display("PIT WR %02h=%02h", bus_address[7:0], dout);
        // F000:C208 writes 00h here, closing counter 2's speaker gate while
        // the ROM verifies its read/load register.  Match PERIPHERALS'
        // tim2gatespk behaviour rather than leaving the counter running.
        if (bus_address[15:0] == 16'h0061)
          port61_out = dout;
        if (bus_address[15:0] == 16'h00E9) begin
          port_e9_tag = dout;
          if (dout == 8'h55) begin
            $display("PASS: PC3086 ROM timer POST reached success path after %0d core cycles", cycle_count);
            $finish_and_return(0);
          end
          if (dout == 8'hEE) fail("PC3086 ROM entered Faulty interval timer path");
        end
      end
      last_mux = s6_3_mux;
    end
  end

endmodule
