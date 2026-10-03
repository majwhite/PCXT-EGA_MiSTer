`timescale 1ns/1ps

// Self-checking regression for the instruction sequence used by the PC3086
// BIOS keyboard handler when it advances the BDA keyboard-tail pointer:
//
//   mov bx, [041Ch]
//   inc bx
//   inc bx
//   mov [041Ch], bx
//
// This intentionally observes the real maximum-mode bus interface rather
// than the debug overlay's retained "last write" registers.  It therefore
// provides a transaction-correlated answer without an FPGA build.
module i8088_bda_tail_tb;

  localparam [19:0] RESET_VECTOR = 20'hFFFF0;
  localparam [19:0] BDA_TAIL     = 20'h0041C;
  localparam integer MAX_CYCLES  = 400000;

  reg core_clk = 1'b0;
  reg clk = 1'b0;
  reg reset = 1'b1;
  reg ready = 1'b1;
  reg intr = 1'b0;
  reg nmi = 1'b0;

  wire [19:0] ad_out;
  wire [7:0] dout;
  wire lock_n;
  wire s6_3_mux;
  wire [2:0] s2_s0_out;
  wire [2:0] segment;
  wire biu_done;

  wire [15:0] debug_ax;
  wire [15:0] debug_bx;
  wire [15:0] debug_biu_data_latch;
  wire [7:0] debug_biu_state;
  wire [12:0] debug_uaddr;
  wire [15:0] debug_alu;
  wire [19:0] debug_write_address;
  wire [7:0] debug_write_code;
  wire [15:0] debug_write_request_data;
  wire [15:0] debug_write_t1_data;
  wire [12:0] debug_write_uaddr;
  wire [15:0] debug_write_alu;
  wire [15:0] debug_write_ax;
  wire [15:0] debug_write_bx;
  wire [15:0] debug_cs;
  wire [15:0] debug_pfq_addr;
  wire debug_nmi_caught;
  wire [15:0] debug_eu_dataout;

  reg [7:0] memory [0:1048575];
  reg [19:0] bus_address = 20'h00000;
  reg [2:0] last_status = 3'b111;
  reg last_mux = 1'b0;
  reg [31:0] cycle_count = 0;
  reg saw_tail_low = 1'b0;
  reg saw_tail_high = 1'b0;
  reg saw_queue_low = 1'b0;
  reg saw_queue_high = 1'b0;
  reg [2:0] keyboard_write_count = 3'd0;
  reg [19:0] keyboard_write_address [0:3];
  reg [7:0] keyboard_write_data [0:3];
  reg saw_inta = 1'b0;
  reg inta_data_drive = 1'b0;
  reg io_read_data_drive = 1'b0;
  reg [7:0] io_read_data = 8'hF4;
  reg failed = 1'b0;

`ifdef PC3086_IRQ_FULL_ROM_FIXTURE
  // The real IRQ1 handler leaves the make code in AH and places the ASCII
  // translation in AL, so the first BIOS queue word for set-1 'A' is 1E61h.
  localparam [7:0] EXPECTED_QUEUE_HIGH = 8'h1E;
`else
  // The controlled helper fixtures supply AX=0061h.
  localparam [7:0] EXPECTED_QUEUE_HIGH = 8'h00;
`endif

  // 100 MHz internal core clock and a substantially slower 8088 pin clock.
  always #5 core_clk = ~core_clk;
  always #40 clk = ~clk;

  // The BIU pipelines AD_IN before sampling it.  bus_address is latched at
  // T1, so this remains stable throughout each read data phase.
  // The external 8259 provides the interrupt type during INTA.  It is
  // deliberately held at 09h for both byte phases: biu_max retains the
  // second phase as the type byte, and this keeps the fixture independent of
  // the PIC's first-acknowledge bus-drive convention.
`ifdef PC3086_IRQ_FULL_ROM_FIXTURE
  wire [7:0] din = inta_data_drive ? 8'h09 :
                   io_read_data_drive ? io_read_data : memory[bus_address];
`elsif PC3086_IRQ_FIXTURE
  wire [7:0] din = inta_data_drive ? 8'h09 : memory[bus_address];
`else
  wire [7:0] din = memory[bus_address];
`endif

  pc3086_test_cpu dut (
    .CORE_CLK(core_clk),
    .CLK(clk),
    .RESET(reset),
    .READY(ready),
    .INTR(intr),
    .NMI(nmi),
    .ad_out(ad_out),
    .dout(dout),
    .din(din),
    .lock_n(lock_n),
    .s6_3_mux(s6_3_mux),
    .s2_s0_out(s2_s0_out),
    .SEGMENT(segment),
    .biu_done(biu_done),
    .cycle_accrate(1'b0),
    .clock_cycle_counter_division_ratio(8'h00),
    .clock_cycle_counter_decrement_value(8'h00),
    .shift_read_timing(1'b0),
    .DEBUG_NMI_CAUGHT(debug_nmi_caught),
    .DEBUG_CS(debug_cs),
    .DEBUG_PFQ_ADDR(debug_pfq_addr),
    .DEBUG_EU_BIU_DATAOUT(debug_eu_dataout),
    .DEBUG_EU_AX(debug_ax),
    .DEBUG_EU_BX(debug_bx),
    .DEBUG_EU_DATAOUT_UADDR(debug_uaddr),
    .DEBUG_EU_DATAOUT_ALU(debug_alu),
    .DEBUG_BIU_DATA_LATCH(debug_biu_data_latch),
    .DEBUG_BIU_STATE(debug_biu_state),
    .DEBUG_BIU_WRITE_ADDRESS(debug_write_address),
    .DEBUG_BIU_WRITE_CODE(debug_write_code),
    .DEBUG_BIU_WRITE_REQUEST_DATA(debug_write_request_data),
    .DEBUG_BIU_WRITE_T1_DATA(debug_write_t1_data),
    .DEBUG_BIU_WRITE_EU_UADDR(debug_write_uaddr),
    .DEBUG_BIU_WRITE_EU_ALU(debug_write_alu),
    .DEBUG_BIU_WRITE_EU_AX(debug_write_ax),
    .DEBUG_BIU_WRITE_EU_BX(debug_write_bx)
  );

  task fail;
    input [8*96-1:0] reason;
    begin
      failed = 1'b1;
      $display("FAIL: %0s", reason);
      $display("  tail=%02h%02h BX=%04h AX=%04h uaddr=%04h dataout=%04h",
               memory[BDA_TAIL + 1], memory[BDA_TAIL], debug_bx, debug_ax,
               debug_uaddr, debug_eu_dataout);
      $finish_and_return(1);
    end
  endtask

  task pass;
    begin
      $display("PASS: BDA tail advanced 001E -> %02h%02h", memory[BDA_TAIL + 1], memory[BDA_TAIL]);
      $display("  ordered writes: %05h=%02h %05h=%02h %05h=%02h %05h=%02h",
               keyboard_write_address[0], keyboard_write_data[0],
               keyboard_write_address[1], keyboard_write_data[1],
               keyboard_write_address[2], keyboard_write_data[2],
               keyboard_write_address[3], keyboard_write_data[3]);
      $display("  bus write data was transaction-correlated at T2; final BX=%04h", debug_bx);
      $finish_and_return(0);
    end
  endtask

  integer i;
  initial begin
    for (i = 0; i < 1048576; i = i + 1)
      memory[i] = 8'hF4; // Halt if control escapes the fixture.

`ifdef PC3086_IRQ_FULL_ROM_FIXTURE
    // Full-ROM external IRQ1 fixture.  Only the reset-vector transfer and
    // IVT entry are supplied by the testbench; the IRQ1 handler, scan-code
    // translation tables, BDA updates and return path all come from the
    // byte-for-byte PC3086 system ROM.  The virtual PPI returns set-1 1Eh
    // ('A') at port 60h and 00h at 61h.
    $readmemh("pc3086-system-mirrored.hex", memory, 20'hF0000, 20'hFFFFF);

    memory[RESET_VECTOR +  0] = 8'hEA; // jmp far F000:1200
    memory[RESET_VECTOR +  1] = 8'h00;
    memory[RESET_VECTOR +  2] = 8'h12;
    memory[RESET_VECTOR +  3] = 8'h00;
    memory[RESET_VECTOR +  4] = 8'hF0;

    // STI has its architecturally required one-instruction delay.  The NOP
    // and short loop leave a repeatable boundary for the external IRQ.
    memory[20'hF1200] = 8'hFB; // sti
    memory[20'hF1201] = 8'h90; // nop
    memory[20'hF1202] = 8'hEB; // jmp short F1201
    memory[20'hF1203] = 8'hFD;

    // IRQ1 is PIC vector 09h; IVT[09] = F000:108Bh.
    memory[20'h00024] = 8'h8B;
    memory[20'h00025] = 8'h10;
    memory[20'h00026] = 8'h00;
    memory[20'h00027] = 8'hF0;
`elsif PC3086_IRQ_FIXTURE
    // External IRQ1-context fixture.  This uses the 8088's real INTR/INTA
    // machinery, IVT fetch, interrupt stack frame and IRET path.  The BIOS
    // IRQ1 entry/prologue is copied byte-for-byte, while its scan-code helper
    // is a small controlled stub that supplies translated AX=0061 then calls
    // the actual PC3086 tail-update subroutine below.  Keyboard translation
    // was already established by hardware capture; this isolates the CPU and
    // bus context without needing a new FPGA image.
    memory[RESET_VECTOR +  0] = 8'hEA; // jmp far F000:1100
    memory[RESET_VECTOR +  1] = 8'h00;
    memory[RESET_VECTOR +  2] = 8'h11;
    memory[RESET_VECTOR +  3] = 8'h00;
    memory[RESET_VECTOR +  4] = 8'hF0;

    // STI has its architecturally required one-instruction delay.  The NOP
    // followed by a short loop leaves a clean, repeatable interrupt boundary.
    memory[20'hF1100] = 8'hFB; // sti
    memory[20'hF1101] = 8'h90; // nop
    memory[20'hF1102] = 8'hEB; // jmp short F1101
    memory[20'hF1103] = 8'hFD;

    // IRQ1 is PIC vector 09h; IVT[09] = F000:108Bh.
    memory[20'h00024] = 8'h8B;
    memory[20'h00025] = 8'h10;
    memory[20'h00026] = 8'h00;
    memory[20'h00027] = 8'hF0;

    // PC3086 IRQ1 entry at F000:108B..F000:10B0.
    memory[20'hF108B] = 8'h1E; // push ds
    memory[20'hF108C] = 8'h52; // push dx
    memory[20'hF108D] = 8'h51; // push cx
    memory[20'hF108E] = 8'h53; // push bx
    memory[20'hF108F] = 8'h50; // push ax
    memory[20'hF1090] = 8'hE4; memory[20'hF1091] = 8'h60; // in al,60
    memory[20'hF1092] = 8'h8A; memory[20'hF1093] = 8'hE0; // mov ah,al
    memory[20'hF1094] = 8'hE4; memory[20'hF1095] = 8'h61; // in al,61
    memory[20'hF1096] = 8'h0C; memory[20'hF1097] = 8'h80; // or al,80
    memory[20'hF1098] = 8'hE6; memory[20'hF1099] = 8'h61; // out 61,al
    memory[20'hF109A] = 8'h24; memory[20'hF109B] = 8'h7F; // and al,7f
    memory[20'hF109C] = 8'hE6; memory[20'hF109D] = 8'h61; // out 61,al
    memory[20'hF109E] = 8'h8A; memory[20'hF109F] = 8'hD4; // mov dl,ah
    memory[20'hF10A0] = 8'h31; memory[20'hF10A1] = 8'hC0; // xor ax,ax
    memory[20'hF10A2] = 8'h8E; memory[20'hF10A3] = 8'hD8; // mov ds,ax
    memory[20'hF10A4] = 8'hE8; memory[20'hF10A5] = 8'h0A; memory[20'hF10A6] = 8'h00; // call F10B1
    memory[20'hF10A7] = 8'hB0; memory[20'hF10A8] = 8'h61; // mov al,61
    memory[20'hF10A9] = 8'hE6; memory[20'hF10AA] = 8'h20; // out 20,al
    memory[20'hF10AB] = 8'h58; // pop ax
    memory[20'hF10AC] = 8'h5B; // pop bx
    memory[20'hF10AD] = 8'h59; // pop cx
    memory[20'hF10AE] = 8'h5A; // pop dx
    memory[20'hF10AF] = 8'h1F; // pop ds
    memory[20'hF10B0] = 8'hCF; // iret

    // Controlled replacement for the scan-code translation helper at F10B1.
    // The real observed A key already reaches the BIOS as 0061h; this stub
    // lets the regression concentrate on the interrupt/BIU boundary.
    memory[20'hF10B1] = 8'hB8; memory[20'hF10B2] = 8'h61; memory[20'hF10B3] = 8'h00;
    memory[20'hF10B4] = 8'hE8; memory[20'hF10B5] = 8'hF5; memory[20'hF10B6] = 8'h00; // call F11AC
    memory[20'hF10B7] = 8'hC3; // ret

    // F000:11AC..F000:11DD from pc3086-system-mirrored.rom.
    memory[20'hF11AC] = 8'h80; memory[20'hF11AD] = 8'h26;
    memory[20'hF11AE] = 8'h96; memory[20'hF11AF] = 8'h04;
    memory[20'hF11B0] = 8'hFC; // and byte [0496], FCh
    memory[20'hF11B1] = 8'h40; // inc ax
    memory[20'hF11B2] = 8'h74; memory[20'hF11B3] = 8'h2E;
    memory[20'hF11B4] = 8'h48; // dec ax
    memory[20'hF11B5] = 8'h8B; memory[20'hF11B6] = 8'h1E;
    memory[20'hF11B7] = 8'h1C; memory[20'hF11B8] = 8'h04;
    memory[20'hF11B9] = 8'h53; // push bx
    memory[20'hF11BA] = 8'h43; // inc bx
    memory[20'hF11BB] = 8'h43; // inc bx
    memory[20'hF11BC] = 8'h3B; memory[20'hF11BD] = 8'h1E;
    memory[20'hF11BE] = 8'h82; memory[20'hF11BF] = 8'h04;
    memory[20'hF11C0] = 8'h72; memory[20'hF11C1] = 8'h04;
    memory[20'hF11C2] = 8'h8B; memory[20'hF11C3] = 8'h1E;
    memory[20'hF11C4] = 8'h80; memory[20'hF11C5] = 8'h04;
    memory[20'hF11C6] = 8'h3B; memory[20'hF11C7] = 8'h1E;
    memory[20'hF11C8] = 8'h1A; memory[20'hF11C9] = 8'h04;
    memory[20'hF11CA] = 8'h74; memory[20'hF11CB] = 8'h12;
    memory[20'hF11CC] = 8'h89; memory[20'hF11CD] = 8'h1E;
    memory[20'hF11CE] = 8'h1C; memory[20'hF11CF] = 8'h04;
    memory[20'hF11D0] = 8'h5B; // pop bx
    memory[20'hF11D1] = 8'h06; // push es
    memory[20'hF11D2] = 8'hB9; memory[20'hF11D3] = 8'h40;
    memory[20'hF11D4] = 8'h00;
    memory[20'hF11D5] = 8'h8E; memory[20'hF11D6] = 8'hC1;
    memory[20'hF11D7] = 8'h26; memory[20'hF11D8] = 8'h89;
    memory[20'hF11D9] = 8'h07; memory[20'hF11DA] = 8'h07;
    memory[20'hF11DB] = 8'hB0; memory[20'hF11DC] = 8'h00;
    memory[20'hF11DD] = 8'hC3;
`elsif PC3086_HANDLER_FIXTURE
    // Reset begins at FFFF:0000.  Transfer to a small F000 setup stub which
    // calls the byte-accurate PC3086 BIOS handler at F000:11AC.  This covers
    // the real surrounding instructions (including PUSH/POP BX and the BDA
    // comparisons), not merely the four-instruction minimum sequence.
    memory[RESET_VECTOR +  0] = 8'hEA; // jmp far F000:1100
    memory[RESET_VECTOR +  1] = 8'h00;
    memory[RESET_VECTOR +  2] = 8'h11;
    memory[RESET_VECTOR +  3] = 8'h00;
    memory[RESET_VECTOR +  4] = 8'hF0;

    memory[20'hF1100] = 8'hB8; // mov ax, 0061h (translated 'A')
    memory[20'hF1101] = 8'h61;
    memory[20'hF1102] = 8'h00;
    memory[20'hF1103] = 8'hB9; // mov cx, 0000h: take F11AC path
    memory[20'hF1104] = 8'h00;
    memory[20'hF1105] = 8'h00;
    memory[20'hF1106] = 8'hE8; // call F11ACh
    memory[20'hF1107] = 8'hA3;
    memory[20'hF1108] = 8'h00;
    memory[20'hF1109] = 8'hF4;

    // F000:11AC..F000:11DD from pc3086-system-mirrored.rom.  Keeping this
    // byte sequence here makes a waveform meaningful even without mounting
    // the PC3086 ROM in a simulator.
    memory[20'hF11AC] = 8'h80; memory[20'hF11AD] = 8'h26;
    memory[20'hF11AE] = 8'h96; memory[20'hF11AF] = 8'h04;
    memory[20'hF11B0] = 8'hFC; // and byte [0496], FCh
    memory[20'hF11B1] = 8'h40; // inc ax
    memory[20'hF11B2] = 8'h74; memory[20'hF11B3] = 8'h2E;
    memory[20'hF11B4] = 8'h48; // dec ax
    memory[20'hF11B5] = 8'h8B; memory[20'hF11B6] = 8'h1E;
    memory[20'hF11B7] = 8'h1C; memory[20'hF11B8] = 8'h04;
    memory[20'hF11B9] = 8'h53; // push bx
    memory[20'hF11BA] = 8'h43; // inc bx
    memory[20'hF11BB] = 8'h43; // inc bx
    memory[20'hF11BC] = 8'h3B; memory[20'hF11BD] = 8'h1E;
    memory[20'hF11BE] = 8'h82; memory[20'hF11BF] = 8'h04;
    memory[20'hF11C0] = 8'h72; memory[20'hF11C1] = 8'h04;
    memory[20'hF11C2] = 8'h8B; memory[20'hF11C3] = 8'h1E;
    memory[20'hF11C4] = 8'h80; memory[20'hF11C5] = 8'h04;
    memory[20'hF11C6] = 8'h3B; memory[20'hF11C7] = 8'h1E;
    memory[20'hF11C8] = 8'h1A; memory[20'hF11C9] = 8'h04;
    memory[20'hF11CA] = 8'h74; memory[20'hF11CB] = 8'h12;
    memory[20'hF11CC] = 8'h89; memory[20'hF11CD] = 8'h1E;
    memory[20'hF11CE] = 8'h1C; memory[20'hF11CF] = 8'h04;
    memory[20'hF11D0] = 8'h5B; // pop bx
    memory[20'hF11D1] = 8'h06; // push es
    memory[20'hF11D2] = 8'hB9; memory[20'hF11D3] = 8'h40;
    memory[20'hF11D4] = 8'h00;
    memory[20'hF11D5] = 8'h8E; memory[20'hF11D6] = 8'hC1;
    memory[20'hF11D7] = 8'h26; memory[20'hF11D8] = 8'h89;
    memory[20'hF11D9] = 8'h07; memory[20'hF11DA] = 8'h07;
    memory[20'hF11DB] = 8'hB0; memory[20'hF11DC] = 8'h00;
    memory[20'hF11DD] = 8'hC3;
`else
    // DS starts at zero after reset.  The exact sequence exercised by the
    // PC3086 keyboard ISR is installed at the real 8088 reset vector.
    memory[RESET_VECTOR +  0] = 8'h8B; // mov bx, [041Ch]
    memory[RESET_VECTOR +  1] = 8'h1E;
    memory[RESET_VECTOR +  2] = 8'h1C;
    memory[RESET_VECTOR +  3] = 8'h04;
    memory[RESET_VECTOR +  4] = 8'h43; // inc bx
    memory[RESET_VECTOR +  5] = 8'h43; // inc bx
    memory[RESET_VECTOR +  6] = 8'h89; // mov [041Ch], bx
    memory[RESET_VECTOR +  7] = 8'h1E;
    memory[RESET_VECTOR +  8] = 8'h1C;
    memory[RESET_VECTOR +  9] = 8'h04;
    memory[RESET_VECTOR + 10] = 8'hF4; // hlt
`endif

    memory[BDA_TAIL + 0] = 8'h1E;
    memory[BDA_TAIL + 1] = 8'h00;
    memory[20'h0041A] = 8'h1E; // head: empty buffer
    memory[20'h0041B] = 8'h00;
    memory[20'h00480] = 8'h1E; // buffer start
    memory[20'h00481] = 8'h00;
    memory[20'h00482] = 8'h3E; // buffer end
    memory[20'h00483] = 8'h00;
    memory[20'h00417] = 8'h00; // keyboard shift flags
    memory[20'h00418] = 8'h00; // keyboard shift flags
    memory[20'h00496] = 8'h00; // keyboard state/insert flags

`ifdef PC3086_IRQ_FULL_ROM_FIXTURE
    $display("i8088 full-PC3086-ROM IRQ1 regression: injected set-1 scan 1E");
`elsif PC3086_IRQ_FIXTURE
    $display("i8088 PC3086 IRQ1-context regression: INTR -> INTA -> IRQ1 -> F000:11AC");
`elsif PC3086_HANDLER_FIXTURE
    $display("i8088 PC3086 handler regression: F000:11AC, initial [0041C]=001E");
`else
    $display("i8088 BDA-tail regression: initial [0041C]=001E");
`endif
    repeat (20) @(posedge core_clk);
    reset = 1'b0;
`ifdef PC3086_IRQ_FIXTURE
    intr = 1'b1;
`endif
  end

  // Latch the physical address at each bus T1.  The BIU holds the address on
  // AD during T1 and later replaces its low byte with write data.
  always @(posedge core_clk) begin
    #1;
    if (!reset) begin
      cycle_count = cycle_count + 1;
      if (cycle_count > MAX_CYCLES)
        fail("timeout waiting for the BDA-tail write");

      if (s2_s0_out != last_status) begin
`ifdef PC3086_IRQ_FULL_ROM_FIXTURE
        // Port data, just like INTA data, must remain present after the
        // status pins have returned to passive and until the BIU's registered
        // sample. The next active bus cycle replaces or releases it.
        if (s2_s0_out != 3'b111) begin
          if (s2_s0_out == 3'b001) begin // I/O read
            io_read_data_drive = 1'b1;
            case (ad_out[15:0])
              16'h0060: io_read_data = 8'h1E; // keyboard scan code: A
              16'h0061: io_read_data = 8'h00; // PPI port-B idle state
              default:  io_read_data = 8'hFF;
            endcase
            $display("BUS IR %04h=%02h", ad_out[15:0], io_read_data);
          end else if (s2_s0_out != 3'b000) begin
            io_read_data_drive = 1'b0;
          end
        end
`endif
        if (s2_s0_out != 3'b111) begin
          bus_address = ad_out;
          if (s2_s0_out == 3'b000) begin
            $display("BUS INTA");
            saw_inta = 1'b1;
            // S2:S0 returns idle before the BIU's registered data sample.
            // Keep the virtual PIC's type byte driven through both INTA byte
            // phases and release it when the subsequent IVT fetch starts.
            inta_data_drive = 1'b1;
            intr = 1'b0; // one IRQ only; IRET restores IF.
          end else if (s2_s0_out == 3'b101)
            $display("BUS MR %05h", ad_out);
          else if (s2_s0_out == 3'b110)
            $display("BUS MW %05h", ad_out);
        end
        last_status = s2_s0_out;
      end

`ifdef PC3086_IRQ_FIXTURE
      if (inta_data_drive && s2_s0_out == 3'b101)
        inta_data_drive = 1'b0;
`endif

      // S6_3_MUX rises for T2: that is the first unambiguous point at which
      // AD[7:0] carries the write datum for this byte transaction.
      if (s2_s0_out == 3'b110 && s6_3_mux && !last_mux) begin
        $display("BUS WD %05h=%02h (BX=%04h U=%04h)",
                 bus_address, dout, debug_bx, debug_write_uaddr);
        memory[bus_address] = dout;

        // This is deliberately sampled at the unambiguous write-data phase,
        // not at ALE or from a later live data bus.  It is the reference
        // transaction stream against which the FPGA trace recorder must be
        // validated before a KBF capture can be treated as a core fault.
        if (bus_address >= BDA_TAIL && bus_address <= BDA_TAIL + 3) begin
          if (keyboard_write_count >= 4)
            fail("unexpected fifth keyboard-tail/queue write");
          keyboard_write_address[keyboard_write_count] = bus_address;
          keyboard_write_data[keyboard_write_count] = dout;
          keyboard_write_count = keyboard_write_count + 1'b1;
        end

        if (bus_address == BDA_TAIL) begin
          saw_tail_low = 1'b1;
          if (dout != 8'h20)
            fail("low byte of [0041C] is stale; expected 20");
        end
        if (bus_address == BDA_TAIL + 1) begin
          saw_tail_high = 1'b1;
          if (dout != 8'h00)
            fail("high byte of [0041D] is wrong; expected 00");
        end
        if (bus_address == BDA_TAIL + 2) begin
          saw_queue_low = 1'b1;
          if (dout != 8'h61)
            fail("low byte of first keyboard queue word is wrong; expected 61");
        end
        if (bus_address == BDA_TAIL + 3) begin
          saw_queue_high = 1'b1;
          if (dout != EXPECTED_QUEUE_HIGH)
            fail("high byte of first keyboard queue word is wrong");
        end
      end
      last_mux = s6_3_mux;

      if (saw_tail_low && saw_tail_high) begin
`ifdef PC3086_IRQ_FIXTURE
        if (!saw_inta)
          fail("tail write occurred without an external INTA cycle");
`endif
        if ({memory[BDA_TAIL + 1], memory[BDA_TAIL]} != 16'h0020)
          fail("stored BDA tail does not equal 0020");
`ifdef PC3086_HANDLER_FIXTURE
        if (!(saw_queue_low && saw_queue_high)) begin
          // The handler fixtures must prove the complete tail-plus-queue
          // ordering; the minimal fixture intentionally stops at the tail.
        end else if (keyboard_write_count != 3'd4 ||
                     keyboard_write_address[0] != 20'h0041C || keyboard_write_data[0] != 8'h20 ||
                     keyboard_write_address[1] != 20'h0041D || keyboard_write_data[1] != 8'h00 ||
                     keyboard_write_address[2] != 20'h0041E || keyboard_write_data[2] != 8'h61 ||
                     keyboard_write_address[3] != 20'h0041F || keyboard_write_data[3] != EXPECTED_QUEUE_HIGH)
          fail("keyboard tail/queue write order differs from PC3086 contract");
        else
          pass();
`elsif PC3086_IRQ_FIXTURE
        if (!(saw_queue_low && saw_queue_high)) begin
          // Wait for the IRQ1 handler to store AX at ES:[BX].
        end else if (keyboard_write_count != 3'd4 ||
                     keyboard_write_address[0] != 20'h0041C || keyboard_write_data[0] != 8'h20 ||
                     keyboard_write_address[1] != 20'h0041D || keyboard_write_data[1] != 8'h00 ||
                     keyboard_write_address[2] != 20'h0041E || keyboard_write_data[2] != 8'h61 ||
                     keyboard_write_address[3] != 20'h0041F || keyboard_write_data[3] != EXPECTED_QUEUE_HIGH)
          fail("full-ROM keyboard tail/queue write order differs from PC3086 contract");
        else
          pass();
`else
        pass();
`endif
      end
    end
  end

  initial begin
`ifdef PC3086_IRQ_FULL_ROM_FIXTURE
    $dumpfile("i8088_bda_tail_full_irq_tb.vcd");
`elsif PC3086_IRQ_FIXTURE
    $dumpfile("i8088_bda_tail_irq_tb.vcd");
`elsif PC3086_HANDLER_FIXTURE
    $dumpfile("i8088_bda_tail_handler_tb.vcd");
`else
    $dumpfile("i8088_bda_tail_minimum_tb.vcd");
`endif
    $dumpvars(0, i8088_bda_tail_tb);
  end
endmodule
