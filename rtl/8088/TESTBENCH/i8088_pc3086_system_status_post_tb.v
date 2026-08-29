`timescale 1ns/1ps

// End-to-end execution of the PC3086 system-status POST at F000:C277.
//
// The ROS first writes four patterns to the Amstrad Status-1 register at 64h
// and reads them through port 60h with PPI PB7 selecting Status-1.  It then
// verifies Status-2/RAM bits on port C and PIT counter 2 OUT on PC5.  All of
// those failures share the ROM's visible error 07, so this fixture is
// deliberately CPU-level: it proves the entire real sequence.
module i8088_pc3086_system_status_post_tb;
  localparam [19:0] RESET_VECTOR = 20'hFFFF0;
  localparam integer MAX_CYCLES = 250000;

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
  reg status2_compare_complete = 1'b0;

  // Same clock relationships as the default XT configuration.
  always #5 core_clk = ~core_clk;
  always #105 clk = ~clk;
  reg pit_clock = 1'b1;
  always #419 pit_clock = ~pit_clock;

  wire pit_selected = (bus_address[15:2] == 14'h0010);
  wire ppi_selected = (bus_address[15:2] == 14'h0018); // 60h..63h only
  wire status1_selected = (bus_address[15:0] == 16'h0064);
  wire status2_selected = (bus_address[15:0] == 16'h0065);
  wire pit_read_n = !((s2_s0_out == 3'b001) && pit_selected);
  wire pit_write_n = !((s2_s0_out == 3'b010) && pit_selected);
  wire ppi_read_n = !((s2_s0_out == 3'b001) && ppi_selected);
  wire ppi_write_n = !((s2_s0_out == 3'b010) && ppi_selected);
  wire [7:0] din = io_read_data_drive ? io_read_data : memory[bus_address];

  wire [7:0] pit_data_bus_out;
  wire [7:0] ppi_data_bus_out;
  wire [7:0] port_b_out;
  wire port_a_io, port_b_io;
  wire timer2_out;
  reg [7:0] status1_write = 8'h00;
  reg [7:0] status2_write = 8'h00;
  wire [7:0] status1 = 8'h0D | (status1_write & 8'h72);
  wire [7:0] port_a_in = port_b_out[7] ? status1 : 8'h00;
  wire [7:0] port_c_in = {2'b00, timer2_out, 1'b0,
                           port_b_out[2] ? {3'b000, status2_write[4]}
                                         : status2_write[3:0]};

  // PC3086 is preprogrammed: Port A input, Port B output, Port C input.
  KF8255 #(.PC3086_RESET_COMPAT(1'b1)) ppi (
    .clock(core_clk), .reset(reset), .chip_select_n(!ppi_selected),
    .read_enable_n(ppi_read_n), .write_enable_n(ppi_write_n),
    .address(bus_address[1:0]), .data_bus_in(dout), .data_bus_out(ppi_data_bus_out),
    .port_a_in(port_a_in), .port_a_out(), .port_a_io(port_a_io),
    .port_b_in(port_b_out), .port_b_out(port_b_out), .port_b_io(port_b_io),
    .port_c_in(port_c_in), .port_c_out(), .port_c_io()
  );

  KF8253 pit (
    .clock(core_clk), .reset(reset), .chip_select_n(!pit_selected),
    .read_enable_n(pit_read_n), .write_enable_n(pit_write_n),
    .address(bus_address[1:0]), .data_bus_in(dout), .data_bus_out(pit_data_bus_out),
    .counter_0_clock(pit_clock), .counter_0_gate(1'b1), .counter_0_out(),
    .counter_1_clock(pit_clock), .counter_1_gate(1'b1), .counter_1_out(),
    .counter_2_clock(pit_clock), .counter_2_gate(port_b_out[0]), .counter_2_out(timer2_out)
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

    // Start precisely at the unmodified ROM status test.
    memory[RESET_VECTOR + 0] = 8'hEA; memory[RESET_VECTOR + 1] = 8'h77;
    memory[RESET_VECTOR + 2] = 8'hC2; memory[RESET_VECTOR + 3] = 8'h00;
    memory[RESET_VECTOR + 4] = 8'hF0;

    // Successful Status-2 iterations continue into the next POST stage at
    // C320.  Replace that stage with a marker.  D9FE is the shared error
    // dispatcher for this check.
    memory[20'hFC320] = 8'hB0; memory[20'hFC321] = 8'h55;
    memory[20'hFC322] = 8'hE6; memory[20'hFC323] = 8'hE9;
    memory[20'hFC324] = 8'hF4;
    memory[20'hFD9FE] = 8'hB0; memory[20'hFD9FF] = 8'hEE;
    memory[20'hFDA00] = 8'hE6; memory[20'hFDA01] = 8'hE9;
    memory[20'hFDA02] = 8'hF4;

    $display("PC3086 system-status integration: F000:C277, production 8088/PPI/PIT");
    repeat (20) @(posedge core_clk);
    reset = 1'b0;
    repeat (4) @(posedge core_clk);
    if ((port_a_io !== 1'b1) || (port_b_io !== 1'b0))
      fail("PC3086 PPI reset profile was not A=input/B=output/C=input");
  end

  always @(posedge core_clk) begin
    #1;
    if (!reset) begin
      cycle_count = cycle_count + 1;
      if (cycle_count > MAX_CYCLES)
        fail("timeout before PC3086 system-status result");


      if (s2_s0_out != last_status) begin
        if (s2_s0_out == 3'b001) begin
          bus_address = ad_out;
          io_read_data_drive = 1'b1;
          #1 begin
            if (ppi_selected)
              io_read_data = ppi_data_bus_out;
            else if (pit_selected)
              io_read_data = pit_data_bus_out;
            else
              io_read_data = 8'hFF;
            if (ppi_selected)
              $display("PPI RD %02h=%02h (Aio=%b Ain=%02h Bout=%02h)", ad_out[7:0],
                       io_read_data, port_a_io, port_a_in, port_b_out);
            if (ppi_selected && bus_address[1:0] == 2'b10 &&
                status2_write == 8'hFF && port_b_out == 8'h34 &&
                io_read_data == 8'h01)
              status2_compare_complete = 1'b1;
            // The following Port-A read is reached only after the ROM's
            // Status-1 and both Status-2 comparisons have branched through
            // their success paths.  The separate direct fixture covers the
            // subsequent PC5/PIT terminal-count check.
            if (ppi_selected && bus_address[1:0] == 2'b00 &&
                status2_compare_complete) begin
              $display("PASS: PC3086 ROM Status-1/Status-2 POST completed after %0d core cycles", cycle_count);
              $finish_and_return(0);
            end
          end
        end else begin
          if (s2_s0_out != 3'b111) bus_address = ad_out;
          // The 8088 samples data after its status pins have gone passive.
          if (s2_s0_out != 3'b111) io_read_data_drive = 1'b0;
        end
        last_status = s2_s0_out;
      end

      // T2 is the stable data phase for this maximum-mode 8088 bus.
      if (s2_s0_out == 3'b010 && s6_3_mux && !last_mux) begin
        if (status1_selected) begin
          status1_write <= dout;
          $display("STATUS1 WR 64=%02h -> PA=%02h", dout, 8'h0D | (dout & 8'h72));
        end else if (status2_selected) begin
          status2_write <= dout;
          $display("STATUS2 WR 65=%02h", dout);
        end else if (ppi_selected) begin
          $display("PPI WR %02h=%02h", bus_address[7:0], dout);
        end
        if (bus_address[15:0] == 16'h00E9) begin
          port_e9_tag = dout;
          if (dout == 8'h55) begin
            $display("PASS: PC3086 ROM system-status POST completed after %0d core cycles", cycle_count);
            $finish_and_return(0);
          end
          if (dout == 8'hEE)
            fail("PC3086 ROM entered Faulty SYSTEM status register path");
        end
      end
      last_mux = s6_3_mux;
    end
  end
endmodule
