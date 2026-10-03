`timescale 1ns/1ps

// ROM-aware floppy interrupt regression.  This does not attempt an entire
// disk boot.  It proves the still-unverified boundary in isolation:
//
//   PC3086 ROM reset sequence -> production FDC reset IRQ -> virtual PIC
//   IRQ6/INTA -> the *real* F000:2F57 ROM handler -> BDA 0040:003E ->
//   the real F000:2F1B ROM wait routine returns.
//
// The test uses the production 8088 and floppy RTL.  No FPGA build is needed.
module i8088_pc3086_fdc_irq_tb;
  localparam [19:0] RESET_VECTOR = 20'hFFFF0;
  localparam [19:0] BDA_FDC_FLAG = 20'h0043E;
`ifdef PC3086_ROM_INT13_READ
  // PC3086's real floppy dispatcher intentionally includes a controller
  // settle delay at F000:2F98.  This is far longer under the cycle-accurate
  // 8088 model than the IRQ-only regression, so it needs a separate bound.
  localparam integer MAX_CYCLES = 5000000;
`else
  localparam integer MAX_CYCLES = 700000;
`endif

  reg core_clk = 1'b0;
  reg clk = 1'b0;
  reg reset = 1'b1;
  reg fdc_rst_n = 1'b0;
  reg ready = 1'b1;
  reg nmi = 1'b0;
  wire [19:0] ad_out;
  wire [7:0] dout;
  wire lock_n, s6_3_mux, biu_done, debug_nmi_caught;
  wire [2:0] s2_s0_out, segment;
  wire [15:0] debug_ax, debug_bx, debug_biu_data_latch, debug_pfq_addr, debug_cs;
  wire [7:0] debug_biu_state;
  wire [12:0] debug_uaddr, debug_write_uaddr;
  wire [15:0] debug_alu, debug_write_request_data, debug_write_t1_data;
  wire [15:0] debug_write_alu, debug_write_ax, debug_write_bx, debug_eu_dataout;
  wire [19:0] debug_write_address;
  wire [7:0] debug_write_code;

  reg [7:0] memory [0:1048575];
  reg [19:0] bus_address = 20'h00000;
  reg [2:0] last_status = 3'b111;
  reg last_mux = 1'b0;
  reg last_biu_done = 1'b0;
  reg [31:0] cycle_count = 0;

  reg inta_data_drive = 1'b0;
  reg io_read_data_drive = 1'b0;
  // floppy.v treats io_read/io_write as single bus transactions.  The 8088
  // holds its status lines for several core clocks, so model an FDC access as
  // a one-clock strobe instead of passing that level through directly.
  reg fdc_io_read_strobe = 1'b0;
  reg fdc_io_write_strobe = 1'b0;
  reg [7:0] fdc_io_writedata = 8'h00;
  // Simulation-only bus turnaround adapter.  floppy.v registers its external
  // io_readdata one core clock after a read strobe.  Capture the production
  // controller's registered result byte on that following clock, then hold it
  // throughout the rest of the BIU transaction.  This models an external
  // peripheral meeting the 8088's T3 data-setup requirement without changing
  // either production RTL block.
  reg [7:0] fdc_read_data_latched = 8'h00;
  reg fdc_read_data_pending = 1'b0;
  // Marks an FDC read from T1 through BIU completion.  Besides preventing a
  // duplicate controller strobe when S[2:0] is observed later, this lets the
  // testbench present the registered FDC byte before the 8088 samples AD_IN.
  reg fdc_read_cycle_active = 1'b0;
`ifdef PC3086_ROM_INT13_READ
  // The production core has no RTC peripheral.  The PC3086 disk services
  // consult CMOS registers 16h/17h when translating the logical INT 13h
  // drive into a physical floppy.  Leaving these ports backed by the F4
  // fill pattern makes that translation depend on an accidental RAM byte,
  // so provide the small, deterministic RTC subset used by this regression.
  // Register 17h bit 3 is deliberately clear: it selects the normal A/B
  // order, matching a single drive mounted as FDD0 below.
  reg [7:0] rtc_index = 8'h00;
  reg rtc_read_cycle_active = 1'b0;
  reg rtc_read_trace_active = 1'b0;
  reg [7:0] rtc_read_data_latched = 8'h00;
  reg [15:0] last_rom_checkpoint = 16'hFFFF;
  wire rtc_selected = (biu_transaction_address[15:0] == 16'h0071);
  wire [7:0] rtc_read_data = ((rtc_index == 8'h16) || (rtc_index == 8'h17)) ?
                             8'h00 : 8'h00;
  // One trace record per FDC data-port transaction.  This couples the byte
  // registered by floppy.v to the byte the 8088 reports at BIU completion,
  // without logging unrelated instruction/data reads.
  reg fdc_read_trace_active = 1'b0;
  reg [7:0] fdc_read_trace_driven = 8'h00;
`endif
  reg pic_irq_pending = 1'b0;
  reg fdc_irq_armed = 1'b1;
  reg saw_dor_disable = 1'b0;
  reg saw_dor_enable = 1'b0;
  reg saw_fdc_irq = 1'b0;
  reg saw_inta = 1'b0;
  reg saw_eoi = 1'b0;
  reg saw_bda_set = 1'b0;
  reg saw_bda_clear = 1'b0;
`ifdef PC3086_ROM_INT13_READ
  // The ROM-facing test mounts the same 720 KiB geometry used by the hardware
  // investigation and emulates just enough of the SD and DMA side of MiSTer
  // to complete one boot-sector transfer.  This exercises the production 765
  // command/result path without requiring an FPGA build or a real SD core.
  reg [3:0] mgmt_config_address = 4'd0;
  reg mgmt_config_write = 1'b0;
  reg [15:0] mgmt_config_writedata = 16'd0;
  reg disk_stream_write = 1'b0;
  reg [7:0] disk_stream_data = 8'h00;
  reg [9:0] disk_stream_count = 10'd0;
  reg fdc_dma_ack = 1'b0;
  reg [9:0] dma_byte_count = 10'd0;
  reg       fdc_request_active = 1'b0;
  reg       current_transfer = 1'b0;
  reg [1:0] completed_transfers = 2'd0;
  reg [1:0] int13_return_count = 2'd0;
  reg saw_media_read_request = 1'b0;
  reg saw_dma_terminal_count = 1'b0;
  wire [3:0] fdc_mgmt_address = disk_stream_write ? 4'hF : mgmt_config_address;
  wire fdc_mgmt_write = disk_stream_write | mgmt_config_write;
  wire [15:0] fdc_mgmt_writedata = disk_stream_write ? { 8'h00, disk_stream_data } : mgmt_config_writedata;
  reg saw_read_data = 1'b0;
  reg [3:0] read_packet_count = 4'd0;
  reg [7:0] read_packet [0:7];
`endif

  always #5 core_clk = ~core_clk;
  always #40 clk = ~clk;

  // Do not infer the address from the externally multiplexed AD pins.  After
  // T1, AD_OUT carries write data, and adjacent reads need not change the
  // externally visible S2:S0 value.  The production BIU has already latched
  // the physical base and offset for the whole transaction; using that
  // simulator-visible state makes this fixture behave like stable external
  // address latches without altering synthesised RTL.
  wire [19:0] biu_transaction_address =
      dut.cpu.u_biu_core.addr_out_temp_base + dut.cpu.u_biu_core.addr_out_temp_offset;
  // s_bits is latched with the request before BIU T1.  Unlike the externally
  // registered S2:S0 pins, it tells the fixture whether the T1 address is for
  // an I/O read or an I/O write.  This matters for 3F5: treating a command
  // write as a data read consumes floppy.v's pending interrupt result.
  wire [2:0] biu_transaction_code = dut.cpu.u_biu_core.s_bits;
`ifdef PC3086_ROM_INT13_READ
  // Register visibility is confined to this simulator fixture.  SI is the
  // ROM's physical-drive selector; exporting it from production RTL would add
  // no hardware value, whereas observing it here explains the command byte.
  wire [15:0] debug_si = dut.cpu.u_eu_core.eu_register_si;
  wire [15:0] debug_dx = dut.cpu.u_eu_core.eu_register_dx;
  wire [15:0] debug_bp = dut.cpu.u_eu_core.eu_register_bp;
`endif
  wire fdc_selected = (biu_transaction_address[15:3] == 13'h007e);
  wire fdc_io_read = fdc_io_read_strobe;
  wire fdc_io_write = fdc_io_write_strobe;
  wire [7:0] fdc_io_readdata;
  wire fdc_irq;
  wire intr = pic_irq_pending;
`ifdef PC3086_ROM_INT13_READ
  wire [1:0] fdc_request;
  wire fdc_dma_req;
  wire [7:0] fdc_dma_writedata;
  // dma_req deasserts while ACK is high, so model the 8237 handshake with a
  // registered acknowledgement.  TC is asserted on the same acknowledged
  // byte as the 512th transfer, making AH=02/AL=01 stop after one sector.
  wire fdc_dma_tc = fdc_dma_ack && (dma_byte_count == 10'd511);

  function [7:0] boot_sector_byte;
    input [9:0] index;
    begin
      case (index)
        10'd0:   boot_sector_byte = 8'hEB;
        10'd1:   boot_sector_byte = 8'h3C;
        10'd2:   boot_sector_byte = 8'h90;
        10'd510: boot_sector_byte = 8'h55;
        10'd511: boot_sector_byte = 8'hAA;
        default: boot_sector_byte = index[7:0] ^ 8'hA5;
      endcase
    end
  endfunction
`endif

  // This is intentionally a minimal edge-latched virtual 8259: it delivers
  // vector 0Eh for FDC IRQ6 and consumes the ROM's 66h EOI.  The controller
  // itself, including the DOR reset event, is production RTL.
  always @(posedge core_clk) begin
    if (!fdc_rst_n) begin
      pic_irq_pending <= 1'b0;
      fdc_irq_armed <= 1'b1;
    end else begin
      if (!fdc_irq)
        fdc_irq_armed <= 1'b1;
      else if (fdc_irq_armed) begin
        pic_irq_pending <= 1'b1;
        fdc_irq_armed <= 1'b0;
        saw_fdc_irq <= 1'b1;
        $display("FDC IRQ edge");
      end
      // An 8259 removes the request from its pending set when the CPU
      // acknowledges it.  Keep the interrupt in service until the ROM's EOI,
      // but do not issue the same vector repeatedly during the two INTA bus
      // cycles.
      if (s2_s0_out == 3'b000)
        pic_irq_pending <= 1'b0;
    end
  end

`ifdef PC3086_ROM_INT13_READ
  // Minimal external-media and DMA model for the focused INT 13h regression.
  // floppy.v requests a full 512-byte SD sector through management address F;
  // feed deterministic sectors and acknowledge DMA transfers. The test
  // issues the boot read followed immediately by the boot loader's first
  // root-directory read, exercising repeated controller use.
  always @(posedge core_clk) begin
    if (!fdc_rst_n) begin
      disk_stream_write <= 1'b0;
      disk_stream_data <= 8'h00;
      disk_stream_count <= 10'd0;
      fdc_dma_ack <= 1'b0;
      dma_byte_count <= 10'd0;
      fdc_request_active <= 1'b0;
      current_transfer <= 1'b0;
      completed_transfers <= 2'd0;
      saw_media_read_request <= 1'b0;
      saw_dma_terminal_count <= 1'b0;
    end else begin
      disk_stream_write <= 1'b0;
      if (!reset && fdc_request == 2'b01 && !fdc_request_active) begin
        fdc_request_active <= 1'b1;
        disk_stream_count <= 10'd0;
        dma_byte_count <= 10'd0;
        current_transfer <= completed_transfers[0];
        $display("SD model: starting sector transfer %0d (logical sector %0d)",
                 completed_transfers, fdc.sd_sector);
      end else if (fdc_request != 2'b01) begin
        fdc_request_active <= 1'b0;
      end
      if (!reset && fdc_request == 2'b01 && disk_stream_count < 10'd512) begin
        saw_media_read_request <= 1'b1;
        disk_stream_write <= 1'b1;
        disk_stream_data <= boot_sector_byte(disk_stream_count);
        disk_stream_count <= disk_stream_count + 1'b1;
      end

      // Register ACK to avoid a combinational dma_req/dma_ack loop.  The FDC
      // consumes dma_writedata on the following clock while ACK is high.
      fdc_dma_ack <= fdc_dma_req;
      if (fdc_dma_ack) begin
        memory[(current_transfer ? 20'h00500 : 20'h07C00) + dma_byte_count] <= fdc_dma_writedata;
        if (dma_byte_count == 10'd511) begin
          saw_dma_terminal_count <= 1'b1;
          completed_transfers <= completed_transfers + 1'b1;
          $display("DMA model: terminal count after 512 bytes, signature=%02h%02h",
                   fdc_dma_writedata, boot_sector_byte(10'd510));
        end
        dma_byte_count <= dma_byte_count + 1'b1;
      end
    end
  end
`endif

  floppy fdc (
    .clk(core_clk), .rst_n(fdc_rst_n),
`ifdef PC3086_ROM_INT13_READ
    .dma_req(fdc_dma_req), .dma_ack(fdc_dma_ack), .dma_tc(fdc_dma_tc), .dma_readdata(8'h00), .dma_writedata(fdc_dma_writedata),
`else
    .dma_req(), .dma_ack(1'b0), .dma_tc(1'b0), .dma_readdata(8'h00), .dma_writedata(),
`endif
    .irq(fdc_irq),
    .io_address(biu_transaction_address[2:0]), .io_read(fdc_io_read), .io_readdata(fdc_io_readdata),
    .io_write(fdc_io_write), .io_writedata(fdc_io_writedata), .fdd0_inserted(),
`ifdef PC3086_ROM_INT13_READ
    .mgmt_address(fdc_mgmt_address), .mgmt_fddn(1'b0), .mgmt_write(fdc_mgmt_write), .mgmt_writedata(fdc_mgmt_writedata),
`else
    .mgmt_address(4'h0), .mgmt_fddn(1'b0), .mgmt_write(1'b0), .mgmt_writedata(16'h0000),
`endif
    .mgmt_read(1'b0), .mgmt_readdata(), .wp(2'b00), .clock_rate(28'd1000),
`ifdef PC3086_ROM_INT13_READ
    .request(fdc_request)
`else
    .request()
`endif
  );

  // The BIU needs port/INTA data to remain driven beyond the active-status
  // phase, until its registered sample.  The adapter above freezes the FDC
  // byte after floppy.v has registered it; this avoids a simulator-only
  // nonblocking-assignment race with the BIU AD_IN pipeline.
  // Keep the FDC byte selected for the whole BIU transaction.  The external
  // S2:S0 monitor may already have moved on by the time the BIU reaches its
  // registered data-input state, so io_read_data_drive is not a valid gate
  // for this fixture's FDC reads.
wire [7:0] din = inta_data_drive ? 8'h0E :
                 fdc_read_cycle_active ? fdc_read_data_latched :
`ifdef PC3086_ROM_INT13_READ
                 rtc_read_cycle_active ? rtc_read_data_latched :
`endif
                 io_read_data_drive ? fdc_read_data_latched :
                 memory[biu_transaction_address];

  pc3086_test_cpu dut (
    .CORE_CLK(core_clk), .CLK(clk), .RESET(reset), .READY(ready),
    .INTR(intr), .NMI(nmi), .ad_out(ad_out), .dout(dout), .din(din),
    .lock_n(lock_n), .s6_3_mux(s6_3_mux), .s2_s0_out(s2_s0_out),
    .SEGMENT(segment), .biu_done(biu_done), .cycle_accrate(1'b0),
    .clock_cycle_counter_division_ratio(8'h00), .clock_cycle_counter_decrement_value(8'h00),
    .shift_read_timing(1'b0), .DEBUG_NMI_CAUGHT(debug_nmi_caught),
    .DEBUG_CS(debug_cs), .DEBUG_PFQ_ADDR(debug_pfq_addr), .DEBUG_EU_BIU_DATAOUT(debug_eu_dataout),
    .DEBUG_EU_AX(debug_ax), .DEBUG_EU_BX(debug_bx), .DEBUG_EU_DATAOUT_UADDR(debug_uaddr),
    .DEBUG_EU_DATAOUT_ALU(debug_alu), .DEBUG_BIU_DATA_LATCH(debug_biu_data_latch),
    .DEBUG_BIU_STATE(debug_biu_state), .DEBUG_BIU_WRITE_ADDRESS(debug_write_address),
    .DEBUG_BIU_WRITE_CODE(debug_write_code), .DEBUG_BIU_WRITE_REQUEST_DATA(debug_write_request_data),
    .DEBUG_BIU_WRITE_T1_DATA(debug_write_t1_data), .DEBUG_BIU_WRITE_EU_UADDR(debug_write_uaddr),
    .DEBUG_BIU_WRITE_EU_ALU(debug_write_alu), .DEBUG_BIU_WRITE_EU_AX(debug_write_ax),
    .DEBUG_BIU_WRITE_EU_BX(debug_write_bx)
  );

  task fail;
    input [8*100-1:0] reason;
    begin
      $display("FAIL: %0s CS:IP=%04h:%04h AX=%04h FDC=%b pending=%b", reason,
               debug_cs, debug_pfq_addr, debug_ax, fdc_irq, pic_irq_pending);
`ifdef PC3086_ROM_INT13_READ
      // Keep failures self-contained: these are production floppy RTL state
      // registers, exposed only by the simulator.  In particular,
      // reset_sensei distinguishes an unconsumed DOR-reset completion from a
      // BIOS-issued RECALIBRATE/SEEK completion.
      $display("FDC state=%0d busy=%b seek=%b cmd=%02h size=%0d left=%0d reset-sense=%0d reply-left=%0d delay=%0d srt=%0d steps=%0d",
               fdc.state, fdc.busy, fdc.in_seek_mode, fdc.pending_command,
               fdc.command_size, fdc.command_left, fdc.reset_sensei,
               fdc.reply_left, fdc.delay_rate, fdc.delay_srt, fdc.delay_steps);
`endif
      $fatal(1, "PC3086 FDC IRQ regression failed");
    end
  endtask

`ifdef PC3086_ROM_INT13_READ
  task write_media;
    input [3:0] address;
    input [15:0] data;
    begin
      @(negedge core_clk);
      mgmt_config_address = address;
      mgmt_config_writedata = data;
      mgmt_config_write = 1'b1;
      @(negedge core_clk);
      mgmt_config_write = 1'b0;
    end
  endtask
`endif

  integer i;
  initial begin
    for (i = 0; i < 1048576; i = i + 1) memory[i] = 8'hF4;
    $readmemh("pc3086-system-mirrored.hex", memory, 20'hF0000, 20'hFFFFF);

    // IVT IRQ6 -> the PC3086 ROM handler at F000:2F57.
    memory[20'h00038] = 8'h57; memory[20'h00039] = 8'h2F;
    memory[20'h0003A] = 8'h00; memory[20'h0003B] = 8'hF0;

`ifdef PC3086_ROM_INT13_READ
    // POST normally installs the diskette parameter table at INT 1Eh.  This
    // focused fixture enters the already-initialised ROM service directly,
    // so provide the same 9-sector table explicitly instead of allowing the
    // dispatcher to read the F4-filled test memory through IVT 1Eh.
    //
    // Bytes are: SRT/HUT, HLT/ND, motor-off, sector-size, sectors/track,
    // read-gap, data-length, format-gap, format-fill, head-settle, motor-on.
    memory[20'h00078] = 8'h00; memory[20'h00079] = 8'h1E;
    memory[20'h0007A] = 8'h00; memory[20'h0007B] = 8'hF0;
    memory[20'hF1E00] = 8'hDF; memory[20'hF1E01] = 8'h02;
    memory[20'hF1E02] = 8'h25; memory[20'hF1E03] = 8'h02;
    memory[20'hF1E04] = 8'h09; memory[20'hF1E05] = 8'h2A;
    memory[20'hF1E06] = 8'hFF; memory[20'hF1E07] = 8'h50;
    memory[20'hF1E08] = 8'hF6; memory[20'hF1E09] = 8'h19;
    memory[20'hF1E0A] = 8'h04;

    // F000:2F94 loads CX=01C6 and spins at F000:2F98 while the physical
    // drive motor settles.  Retain the ROM control flow, but reduce that
    // fixture-only delay to one iteration: the production controller is
    // already deterministic and this test is concerned with the command
    // packet, not wall-clock motor spin-up.
    // Preserve the DOR write and one trip through the loop.  The ROM normally
    // performs 125 * AH motor-settle loops, which would otherwise dominate a
    // software test.  AH=1 and the unconditional jump retain the exit path.
    memory[20'hF2F8B] = 8'hB4; memory[20'hF2F8C] = 8'h01; memory[20'hF2F8D] = 8'h90;
    memory[20'hF2F8E] = 8'hEB; memory[20'hF2F8F] = 8'h02;
    memory[20'hF2F95] = 8'h01; memory[20'hF2F96] = 8'h00;

    // F000:2e1f is only the FDC reset/recalibration helper.  Vector INT 13h
    // to the PC3086 function dispatcher at F000:2c8a, which dispatches AH
    // (including AH=02 read sectors) as INT 19h expects.
    memory[20'h0004C] = 8'h8A; memory[20'h0004D] = 8'h2C;
    memory[20'h0004E] = 8'h00; memory[20'h0004F] = 8'hF0;
`endif

    // reset vector -> a tiny setup program in unused F000:1F00 space.
    memory[RESET_VECTOR+0] = 8'hEA; memory[RESET_VECTOR+1] = 8'h00;
    memory[RESET_VECTOR+2] = 8'h1F; memory[RESET_VECTOR+3] = 8'h00;
    memory[RESET_VECTOR+4] = 8'hF0;
    // ES=SS=0, stack 8000 and enable IRQs.  The PC3086 INT 13h wrapper
    // establishes DS before using the BDA.
    memory[20'hF1F00]=8'hB8; memory[20'hF1F01]=8'h00; memory[20'hF1F02]=8'h00;
    memory[20'hF1F03]=8'h50; memory[20'hF1F04]=8'h07; // push ax; pop es
    memory[20'hF1F05]=8'h8E; memory[20'hF1F06]=8'hD0; // mov ss,ax
    memory[20'hF1F07]=8'hBC; memory[20'hF1F08]=8'h00; memory[20'hF1F09]=8'h80;
    memory[20'hF1F0A]=8'hFB; memory[20'hF1F0B]=8'h90; // sti; nop
`ifdef PC3086_ROM_INT13_READ
    // Reset and drain the controller exactly as firmware does, then issue
    // the INT 19h boot-sector request through the real INT 13h vector.  The
    // regression now follows this through media streaming, DMA and the ROM's
    // final result-status return.
    memory[20'hF1F0C]=8'hBA; memory[20'hF1F0D]=8'hF2; memory[20'hF1F0E]=8'h03;
    memory[20'hF1F0F]=8'hB0; memory[20'hF1F10]=8'h08; memory[20'hF1F11]=8'hEE;
    memory[20'hF1F12]=8'hB0; memory[20'hF1F13]=8'h0C; memory[20'hF1F14]=8'hEE;
    memory[20'hF1F15]=8'hE8; memory[20'hF1F16]=8'h03; memory[20'hF1F17]=8'h10;
    // A 765 produces one SENSE INTERRUPT STATUS record per drive after a
    // controller reset.  Consume all four before entering INT 13h.  The
    // firmware's post-reset initialisation does this; leaving three pending
    // records in this isolated fixture can otherwise make a later ROM
    // recalibration appear to complete at the wrong point.
    memory[20'hF1F18]=8'hBA; memory[20'hF1F19]=8'hF5; memory[20'hF1F1A]=8'h03;
    memory[20'hF1F1B]=8'hB0; memory[20'hF1F1C]=8'h08; memory[20'hF1F1D]=8'hEE;
    memory[20'hF1F1E]=8'hEC; memory[20'hF1F1F]=8'hEC;
    memory[20'hF1F20]=8'hB0; memory[20'hF1F21]=8'h08; memory[20'hF1F22]=8'hEE;
    memory[20'hF1F23]=8'hEC; memory[20'hF1F24]=8'hEC;
    memory[20'hF1F25]=8'hB0; memory[20'hF1F26]=8'h08; memory[20'hF1F27]=8'hEE;
    memory[20'hF1F28]=8'hEC; memory[20'hF1F29]=8'hEC;
    memory[20'hF1F2A]=8'hB0; memory[20'hF1F2B]=8'h08; memory[20'hF1F2C]=8'hEE;
    memory[20'hF1F2D]=8'hEC; memory[20'hF1F2E]=8'hEC;
    // INT 19 request: AH=02, AL=01, CH=0, CL=1, DH=0, DL=0, ES:BX=0000:7c00.
    memory[20'hF1F2F]=8'hB8; memory[20'hF1F30]=8'h01; memory[20'hF1F31]=8'h02;
    memory[20'hF1F32]=8'hB9; memory[20'hF1F33]=8'h01; memory[20'hF1F34]=8'h00;
    memory[20'hF1F35]=8'hBA; memory[20'hF1F36]=8'h00; memory[20'hF1F37]=8'h00;
    memory[20'hF1F38]=8'hBB; memory[20'hF1F39]=8'h00; memory[20'hF1F3A]=8'h7C;
    memory[20'hF1F3B]=8'hCD; memory[20'hF1F3C]=8'h13;
    // Preserve the BIOS return status before emitting the fixture-complete
    // marker.  INT 13h returns its error/result in AH, while the old marker
    // overwrote AL with A7 and concealed that value from the trace.  E8 is a
    // harness-only diagnostic port; production RTL never decodes it.
    memory[20'hF1F3D]=8'h86; memory[20'hF1F3E]=8'hC4; // xchg al,ah
    memory[20'hF1F3F]=8'hE6; memory[20'hF1F40]=8'hE8; // out e8,al (INT13 AH)
    // The DOS boot sector next asks for root-directory LBA 7: CHS 0/0/8.
    memory[20'hF1F41]=8'hB8; memory[20'hF1F42]=8'h01; memory[20'hF1F43]=8'h02;
    memory[20'hF1F44]=8'hB9; memory[20'hF1F45]=8'h08; memory[20'hF1F46]=8'h00;
    memory[20'hF1F47]=8'hBA; memory[20'hF1F48]=8'h00; memory[20'hF1F49]=8'h00;
    memory[20'hF1F4A]=8'hBB; memory[20'hF1F4B]=8'h00; memory[20'hF1F4C]=8'h05;
    memory[20'hF1F4D]=8'hCD; memory[20'hF1F4E]=8'h13;
    memory[20'hF1F4F]=8'h86; memory[20'hF1F50]=8'hC4;
    memory[20'hF1F51]=8'hE6; memory[20'hF1F52]=8'hE8;
    memory[20'hF1F53]=8'hB0; memory[20'hF1F54]=8'hA7; memory[20'hF1F55]=8'hE6;
    memory[20'hF1F56]=8'hE9; memory[20'hF1F57]=8'hF4;
`else
    // DOR reset toggle, then call the real ROM F000:2F1B waiter.  E9:A6
    // marks return from the real routine.
    memory[20'hF1F0C]=8'hBA; memory[20'hF1F0D]=8'hF2; memory[20'hF1F0E]=8'h03;
    memory[20'hF1F0F]=8'hB0; memory[20'hF1F10]=8'h08; memory[20'hF1F11]=8'hEE;
    memory[20'hF1F12]=8'hB0; memory[20'hF1F13]=8'h0C; memory[20'hF1F14]=8'hEE;
    memory[20'hF1F15]=8'hE8; memory[20'hF1F16]=8'h03; memory[20'hF1F17]=8'h10;
    memory[20'hF1F18]=8'hB0; memory[20'hF1F19]=8'hA6; memory[20'hF1F1A]=8'hE6;
    memory[20'hF1F1B]=8'hE9; memory[20'hF1F1C]=8'hF4;
`endif
    memory[BDA_FDC_FLAG] = 8'h00;

`ifdef PC3086_ROM_INT13_READ
    // The direct INT 13h fixture skips POST, which normally supplies these
    // BIOS Data Area values.  Describe one installed floppy (logical A:),
    // no pending motor/seek state, and clear per-drive status.  This is
    // configuration state, not a workaround for the controller model.
    memory[20'h00410] = 8'h00; memory[20'h00411] = 8'h00;
    memory[20'h0043E] = 8'h00; memory[20'h0043F] = 8'h00;
    memory[20'h00440] = 8'h00; memory[20'h00441] = 8'h00;
    memory[20'h00442] = 8'h00; memory[20'h00443] = 8'h00;
    memory[20'h00490] = 8'h00; memory[20'h00491] = 8'h00;
    memory[20'h00494] = 8'h00; memory[20'h00495] = 8'h00;

    $display("i8088 PC3086 ROM INT 13h regression: boot-sector request -> READ DATA packet");
`else
    $display("i8088 PC3086 ROM FDC IRQ6 regression: FDC reset -> F000:2F57 -> F000:2F1B");
`endif
    repeat (20) @(posedge core_clk);
    fdc_rst_n = 1'b1;
`ifdef PC3086_ROM_INT13_READ
    // Mounted 720 KiB media: present, write enabled, 80 cylinders, 9 sectors,
    // 1,440 sectors total and two heads.
    write_media(4'd0, 16'd1);
    write_media(4'd1, 16'd0);
    write_media(4'd2, 16'd80);
    write_media(4'd3, 16'd9);
    write_media(4'd4, 16'd1440);
    write_media(4'd5, 16'd2);
`endif
    reset = 1'b0;
  end

  always @(posedge core_clk) begin
    #1;
    if (!reset) begin
`ifdef PC3086_ROM_INT13_READ
      // Simulator-only visibility of the complete controller-read path.  The
      // value in floppy.io_readdata is the byte driven towards the 8088.
      // biu_max's internal latched_data_in/biu_return_data_int are used
      // below to show the CPU-side sample.  DEBUG_BIU_DATA_LATCH is an
      // output latch, not a data-input capture point.
      if (fdc_io_read_strobe) begin
        fdc_read_trace_driven = fdc_io_readdata;
        $display("FDC-RD port=%0h driven=%02h reply-next=%02h", bus_address[2:0],
                 fdc_io_readdata, fdc.reply[7:0]);
      end
      // floppy.v registers io_readdata on the edge that consumes our strobe.
      // This testbench executes after that nonblocking update (#1 above), so
      // this is the first point at which the actual FDC result is available.
      // Sampling at arm time instead returns the preceding command byte (08
      // during the ROM's reset/SENSE sequence).
      if (fdc_read_data_pending && fdc_io_read_strobe) begin
        fdc_read_data_latched = fdc_io_readdata;
        fdc_read_data_pending = 1'b0;
      end
      if (fdc_read_trace_active && biu_done && !last_biu_done) begin
        $display("FDC-RD CPU-sample=%02h return=%02h latched=%02h din=%02h active=%b state=%0h (controller drove %02h)",
                 dut.cpu.u_biu_core.latched_data_in, dut.cpu.u_biu_core.biu_return_data_int[7:0],
                 fdc_read_data_latched, din, fdc_read_cycle_active,
                 debug_biu_state, fdc_read_trace_driven);
        fdc_read_trace_active = 1'b0;
        // The state machine visits state 07 before the BIU reports this read
        // complete (state 0b).  Releasing there made the data mux fall back
        // to the previous command byte before the registered data latch.
        // This transaction-specific completion edge is the safe release.
        fdc_read_cycle_active = 1'b0;
      end
      if (rtc_read_trace_active && biu_done && !last_biu_done) begin
        $display("RTC read index=%02h CPU-sample=%02h return=%02h", rtc_index,
                 dut.cpu.u_biu_core.latched_data_in, dut.cpu.u_biu_core.biu_return_data_int[7:0]);
        rtc_read_trace_active = 1'b0;
        rtc_read_cycle_active = 1'b0;
      end
`endif
      // A strobe set below is sampled by floppy.v on the following edge.
      // Clear the preceding one only after that sampling edge has occurred.
`ifdef PC3086_ROM_INT13_READ
      // Show what floppy.v actually consumed, separately from the byte that
      // the 8088 presented when the strobe was armed.  This makes a missing
      // bus phase distinguishable from a ROM-generated command byte.
      if (fdc_io_write_strobe)
        $display("FDC-WR consumed=%02h state=%0d cmd=%02h size=%0d left=%0d",
                 fdc_io_writedata, fdc.state, fdc.pending_command,
                 fdc.command_size, fdc.command_left);
`endif
      fdc_io_read_strobe = 1'b0;
      fdc_io_write_strobe = 1'b0;

      // Keep a monitor-only copy for log messages.  The live bus model uses
      // biu_transaction_address above, so these assignments cannot affect
      // the CPU data returned by RAM or the FDC.
      if (debug_biu_state == 8'h01)
        bus_address = biu_transaction_address;

`ifdef PC3086_ROM_INT13_READ
      // These are the ROM decision points around drive translation, motor
      // selection and recalibration.  AX/BX plus the BDA bytes make a later
      // command-parameter mismatch reproducible without another FPGA run.
      if (debug_cs == 16'hF000 &&
          (debug_pfq_addr == 16'h1738 || debug_pfq_addr == 16'h174D ||
           debug_pfq_addr == 16'h176C || debug_pfq_addr == 16'h2EA5 ||
           debug_pfq_addr == 16'h2EEF || debug_pfq_addr == 16'h2EF6 ||
           debug_pfq_addr == 16'h2F69) &&
          last_rom_checkpoint != debug_pfq_addr) begin
        last_rom_checkpoint = debug_pfq_addr;
        $display("ROM-CHECK %04h AX=%04h BX=%04h SI=%04h DX=%04h BP=%04h BDA410=%02h:%02h 43e=%02h 43f=%02h 440=%02h 494=%02h",
                 debug_pfq_addr, debug_ax, debug_bx, debug_si, debug_dx, debug_bp,
                 memory[20'h00410], memory[20'h00411], memory[20'h0043E],
                 memory[20'h0043F], memory[20'h00440], memory[20'h00494]);
      end else if (debug_cs != 16'hF000 ||
                   (debug_pfq_addr != 16'h1738 && debug_pfq_addr != 16'h174D &&
                    debug_pfq_addr != 16'h176C && debug_pfq_addr != 16'h2EA5 &&
                    debug_pfq_addr != 16'h2EEF && debug_pfq_addr != 16'h2EF6 &&
                    debug_pfq_addr != 16'h2F69)) begin
        last_rom_checkpoint = 16'hFFFF;
      end
`endif

      // S2_S0_OUT is itself registered by the 8088, so it cannot qualify T1:
      // by the time it says I/O read (T2), floppy.v's registered result is
      // one CORE_CLK late for biu_max's AD_IN pipeline.  Use the request's
      // internal transaction code to qualify T1, so a 3F5 command write never
      // masquerades as a result-byte read.  Retain the qualified T2/T3 path
      // only as a fallback for a BIU variant that exposes its address late.
      if (biu_transaction_code == 3'b001 &&
          (debug_biu_state == 8'h01 ||
           ((debug_biu_state == 8'h02 || debug_biu_state == 8'h03) &&
            s2_s0_out == 3'b001)) && !fdc_read_cycle_active &&
          biu_transaction_address[15:3] == 13'h007e) begin
        bus_address = biu_transaction_address;
        io_read_data_drive = 1'b1;
        fdc_io_read_strobe = 1'b1;
        fdc_read_data_pending = 1'b1;
        fdc_read_cycle_active = 1'b1;
`ifdef PC3086_ROM_INT13_READ
        fdc_read_trace_active = 1'b1;
        $display("FDC-RD armed early port=%0h state=%0h", biu_transaction_address[2:0], debug_biu_state);
`endif
      end
`ifdef PC3086_ROM_INT13_READ
      // Port 71h needs the same T1-to-completion hold as the FDC data port:
      // the 8088 samples data after the address pins are multiplexed away.
      // It is safe to recognise it by address in this ROM-only fixture;
      // physical RAM 00071h is not used by the service under test.
      if (debug_biu_state == 8'h01 && rtc_selected && !rtc_read_cycle_active) begin
        rtc_read_data_latched = rtc_read_data;
        rtc_read_cycle_active = 1'b1;
        rtc_read_trace_active = 1'b1;
      end
`endif
      cycle_count = cycle_count + 1;
      if (cycle_count > MAX_CYCLES) fail("timeout waiting for ROM floppy command");
      if (s2_s0_out != last_status) begin
        if (s2_s0_out == 3'b001) begin
          bus_address = biu_transaction_address;
          io_read_data_drive = 1'b1;
          // Normally this read was armed above at T1/T2.  Retain this
          // fallback so the general IRQ regression also remains usable if a
          // future BIU timing change moves the status visibility point.
          if (biu_transaction_address[15:3] == 13'h007e && !fdc_read_cycle_active) begin
            fdc_io_read_strobe = 1'b1;
            fdc_read_data_pending = 1'b1;
            fdc_read_cycle_active = 1'b1;
`ifdef PC3086_ROM_INT13_READ
            fdc_read_trace_active = 1'b1;
`endif
          end
`ifdef PC3086_ROM_INT13_READ
          if (ad_out[15:0] == 16'h03F5)
            $display("IOR 03f5=%02h @%04h:%04h", fdc_io_readdata, debug_cs, debug_pfq_addr);
`endif
        end else if (s2_s0_out == 3'b000) begin
          bus_address = biu_transaction_address;
          inta_data_drive = 1'b1;
          saw_inta = 1'b1;
          $display("PIC INTA @%04h:%04h", debug_cs, debug_pfq_addr);
        end else if (s2_s0_out != 3'b111) begin
          bus_address = biu_transaction_address;
          io_read_data_drive = 1'b0;
        end
        last_status = s2_s0_out;
      end
      if (inta_data_drive && s2_s0_out == 3'b101)
        inta_data_drive = 1'b0;
      if (s2_s0_out == 3'b110 && s6_3_mux && !last_mux) begin
        memory[biu_transaction_address] = dout;
        if (biu_transaction_address == BDA_FDC_FLAG && dout[7]) begin
          saw_bda_set = 1'b1;
          $display("ROM IRQ6 set BDA 043E=%02h @%04h:%04h", dout, debug_cs, debug_pfq_addr);
        end
        if (biu_transaction_address == BDA_FDC_FLAG && !dout[7] && saw_bda_set)
          saw_bda_clear = 1'b1;
      end
      // Do not retire fdc_read_cycle_active from a generic BIU state: the
      // adjacent transaction can still be completing when the FDC read is
      // armed.  PC3086_ROM_INT13_READ instead retires it using the tagged
      // transaction completion above.
`ifndef PC3086_ROM_INT13_READ
      if (fdc_read_cycle_active && biu_done && !last_biu_done)
        fdc_read_cycle_active = 1'b0;
`endif
      last_biu_done = biu_done;
      if (s2_s0_out == 3'b010 && s6_3_mux && !last_mux) begin
        $display("IOW %04h=%02h @%04h:%04h", biu_transaction_address[15:0], dout, debug_cs, debug_pfq_addr);
`ifdef PC3086_ROM_INT13_READ
        if (biu_transaction_address[15:0] == 16'h0070) begin
          rtc_index = dout;
          $display("RTC index=%02h", dout);
        end
        if (biu_transaction_address[15:0] == 16'h00E8) begin
          $display("INT13 read %0d return AH=%02h", int13_return_count, dout);
          if (dout !== 8'h00)
            fail("ROM INT 13h reported a read failure");
          if (int13_return_count == 0) begin
            if (!saw_read_data || !saw_media_read_request || !saw_dma_terminal_count ||
                completed_transfers != 1 || dma_byte_count != 10'd512)
              fail("first INT 13h returned without a complete DMA sector transfer");
          end else begin
            if (completed_transfers != 2 || dma_byte_count != 10'd512)
              fail("second INT 13h returned without a complete DMA sector transfer");
            if (memory[20'h07C00] !== 8'hEB || memory[20'h07C01] !== 8'h3C ||
                memory[20'h07DFE] !== 8'h55 || memory[20'h07DFF] !== 8'hAA ||
                memory[20'h00500] !== 8'hEB || memory[20'h00501] !== 8'h3C)
              fail("DMA sector data did not reach both requested ES:BX buffers");
            $display("PASS: production FDC/DMA completed consecutive PC3086 ROM boot and root-sector reads");
            $finish;
          end
          int13_return_count = int13_return_count + 1'b1;
        end
`endif
        if (biu_transaction_address[15:3] == 13'h007e) begin
          fdc_io_writedata = dout;
          fdc_io_write_strobe = 1'b1;
        end
`ifdef PC3086_ROM_INT13_READ
        if (biu_transaction_address[15:0] == 16'h03F5)
          $display("FDC-WR arm=%02h AX=%04h BX=%04h DPT=%02h,%02h,%02h state=%0d busy=%b cmd=%02h size=%0d left=%0d reply-left=%0d @%04h:%04h",
                   dout, debug_ax, debug_bx,
                   memory[20'hF1E00], memory[20'hF1E01], memory[20'hF1E02],
                   fdc.state, fdc.busy, fdc.pending_command,
                   fdc.command_size, fdc.command_left, fdc.reply_left,
                   debug_cs, debug_pfq_addr);
        if (biu_transaction_address[15:0] == 16'h03F5) begin
          if (!saw_read_data && dout == 8'hE6) begin
            saw_read_data = 1'b1;
            read_packet_count = 4'd0;
            $display("ROM issued READ DATA E6h");
          end else if (saw_read_data && read_packet_count < 8) begin
            read_packet[read_packet_count] = dout;
            if (read_packet_count == 7) begin
              if (read_packet[0] !== 8'h00 || read_packet[1] !== 8'h00 ||
                  read_packet[2] !== 8'h00 || read_packet[3] !== 8'h01 ||
                  read_packet[4] !== 8'h02 || read_packet[5] !== 8'h12 ||
                  read_packet[6] !== 8'h2A || read_packet[7] !== 8'hFF)
                fail("ROM READ DATA packet did not match boot sector geometry");
              $display("ROM submitted READ DATA %02h %02h %02h %02h %02h %02h %02h %02h %02h",
                       read_packet[0], read_packet[1], read_packet[2], read_packet[3], read_packet[4],
                       read_packet[5], read_packet[6], read_packet[7], 8'hFF);
            end
            read_packet_count = read_packet_count + 1'b1;
          end
        end
`endif
        if (biu_transaction_address[15:0] == 16'h0020 && dout == 8'h66) begin
          saw_eoi = 1'b1;
          $display("PIC EOI 66h");
        end
        if (biu_transaction_address[15:0] == 16'h03F2 && dout == 8'h08) saw_dor_disable = 1'b1;
        if (biu_transaction_address[15:0] == 16'h03F2 && dout == 8'h0C) saw_dor_enable = 1'b1;
        if (biu_transaction_address[15:0] == 16'h00E9 && dout == 8'hA6) begin
          if (!saw_dor_disable || !saw_dor_enable || !saw_fdc_irq || !saw_inta || !saw_eoi ||
              !saw_bda_set || !saw_bda_clear)
            fail("ROM wait returned without the complete FDC/PIC/BDA contract");
          $display("PASS: production FDC IRQ6 reached real PC3086 ROM handler and released F000:2F1B");
          $finish;
        end
      end
      last_mux = s6_3_mux;
    end
  end
endmodule
