`timescale 1ns/1ps

// Starts at the real PC3086 foreground sequence immediately after setup:
//   F000:0A4C  mov ah,00 / int 16h / CR / LF / int 19h
//
// IRQ1-to-BDA delivery is covered by i8088_bda_tail_tb.  This companion
// regression proves that, once a key is available, the processor returns
// through the ROM sequence and reaches the boot vector.  INT 10h and INT 19h
// are deliberately tagged stubs so the assertion observes real INTA/IVT/IRET
// mechanics without needing a VGA or disk model.
module i8088_pc3086_postkey_boot_tb;
  localparam [19:0] RESET_VECTOR = 20'hFFFF0;
  localparam integer MAX_CYCLES = 500000;

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
  reg [2:0] tag_count = 0;
  reg [7:0] tags [0:2];

  always #5 core_clk = ~core_clk;
  always #40 clk = ~clk;
  wire [7:0] din = memory[bus_address];

  pc3086_test_cpu dut (
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
    input [8*96-1:0] reason;
    begin
      $display("FAIL: %0s CS:IP=%04h:%04h AX=%04h tags=%0d",
               reason, debug_cs, debug_pfq_addr, debug_ax, tag_count);
      $finish_and_return(1);
    end
  endtask

  integer i;
  initial begin
    for (i = 0; i < 1048576; i = i + 1) memory[i] = 8'hF4;
    $readmemh("pc3086-system-mirrored.hex", memory, 20'hF0000, 20'hFFFFF);

    // Establish a conventional stack before entering the real ROM foreground
    // code. The reset vector reaches this setup stub, which then far-jumps to
    // F000:0A4C (the instruction directly before INT 16h).
    memory[RESET_VECTOR + 0] = 8'hEA; memory[RESET_VECTOR + 1] = 8'h00;
    memory[RESET_VECTOR + 2] = 8'h1F; memory[RESET_VECTOR + 3] = 8'h00;
    memory[RESET_VECTOR + 4] = 8'hF0;
    memory[20'hF1F00] = 8'hB8; memory[20'hF1F01] = 8'h00; memory[20'hF1F02] = 8'h00; // mov ax,0
    memory[20'hF1F03] = 8'h8E; memory[20'hF1F04] = 8'hD0; // mov ss,ax
    memory[20'hF1F05] = 8'hBC; memory[20'hF1F06] = 8'h00; memory[20'hF1F07] = 8'h80; // mov sp,8000
    memory[20'hF1F08] = 8'hEA; memory[20'hF1F09] = 8'h4C; memory[20'hF1F0A] = 8'h0A;
    memory[20'hF1F0B] = 8'h00; memory[20'hF1F0C] = 8'hF0; // jmp F000:0A4C

    // INT 16h is the already-proven post-key contract: return the queued
    // PC3086 'A' word. The foreground ROM then owns the entire path to INT19.
    memory[20'h00058] = 8'h00; memory[20'h00059] = 8'h1E;
    memory[20'h0005A] = 8'h00; memory[20'h0005B] = 8'hF0;
    memory[20'hF1E00] = 8'hB8; memory[20'hF1E01] = 8'h61; memory[20'hF1E02] = 8'h1E; // mov ax,1E61
    memory[20'hF1E03] = 8'hCF; // iret

    // Both INT 10h calls tag port E9 then IRET. INT 19h tags 19h and halts.
    memory[20'h00040] = 8'h10; memory[20'h00041] = 8'h1E;
    memory[20'h00042] = 8'h00; memory[20'h00043] = 8'hF0;
    memory[20'hF1E10] = 8'hB0; memory[20'hF1E11] = 8'hA0;
    memory[20'hF1E12] = 8'hE6; memory[20'hF1E13] = 8'hE9; memory[20'hF1E14] = 8'hCF;
    memory[20'h00064] = 8'h20; memory[20'h00065] = 8'h1E;
    memory[20'h00066] = 8'h00; memory[20'h00067] = 8'hF0;
    memory[20'hF1E20] = 8'hB0; memory[20'hF1E21] = 8'h19;
    memory[20'hF1E22] = 8'hE6; memory[20'hF1E23] = 8'hE9; memory[20'hF1E24] = 8'hF4;

    $display("i8088 PC3086 post-key boot regression: F000:0A4C -> INT16 -> INT10x2 -> INT19");
    repeat (20) @(posedge core_clk);
    reset = 1'b0;
  end

  always @(posedge core_clk) begin
    #1;
    if (!reset) begin
      cycle_count = cycle_count + 1;
      if (cycle_count > MAX_CYCLES) fail("timeout before INT 19h boot handoff");
      if (s2_s0_out != last_status) begin
        if (s2_s0_out != 3'b111) begin
          bus_address = ad_out;
          if (s2_s0_out == 3'b001) $display("BUS IR %04h", ad_out[15:0]);
          if (s2_s0_out == 3'b010) $display("BUS IW %04h", ad_out[15:0]);
        end
        last_status = s2_s0_out;
      end
      // INT/IRET use the real stack, so commit every memory write at the
      // unambiguous T2 data phase before inspecting the tagged I/O writes.
      if (s2_s0_out == 3'b110 && s6_3_mux && !last_mux)
        memory[bus_address] = dout;
      if (s2_s0_out == 3'b010 && s6_3_mux && !last_mux) begin
        if (bus_address[15:0] == 16'h00E9) begin
          if (tag_count >= 3) fail("unexpected fourth post-key handoff tag");
          tags[tag_count] = dout;
          tag_count = tag_count + 1'b1;
          $display("POSTKEY TAG %02h", dout);
          if (tag_count == 3) begin
            if (tags[0] != 8'hA0 || tags[1] != 8'hA0 || dout != 8'h19)
              fail("ROM did not perform INT10, INT10, INT19 in order");
            $display("PASS: PC3086 foreground key return reached INT 19h boot vector");
            $finish_and_return(0);
          end
        end
      end
      last_mux = s6_3_mux;
    end
  end

  initial begin
    $dumpfile("i8088_pc3086_postkey_boot_tb.vcd");
    $dumpvars(0, i8088_pc3086_postkey_boot_tb);
  end
endmodule
