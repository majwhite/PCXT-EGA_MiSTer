//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`ifndef CONF_STR_SYSTEM
// MiSTer Main recognises PCXT-EGA as a PC-XT variant while retaining this
// separate name for the core's saved configuration.
`define CONF_STR_SYSTEM "PCXT-EGA;UART115200:115200;"
`endif
`ifndef ENABLE_OPL2
`define ENABLE_OPL2 0
`endif
`ifndef ENABLE_CMS
`define ENABLE_CMS 0
`endif
`ifndef ENABLE_EMS
`define ENABLE_EMS 0
`endif
`ifndef ENABLE_UMB
`define ENABLE_UMB 0
`endif

module emu
    (
        //Master input clock
        input         CLK_50M,

        //Async reset from top-level module.
        //Can be used as initial reset.
        input         RESET,

        //Must be passed to hps_io module
        inout  [48:0] HPS_BUS,

        //Base video clock. Usually equals to CLK_SYS.
        output        CLK_VIDEO,

        //Multiple resolutions are supported using different CE_PIXEL rates.
        //Must be based on CLK_VIDEO
        output        CE_PIXEL,

        //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
        //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
        output [12:0] VIDEO_ARX,
        output [12:0] VIDEO_ARY,

        output  [7:0] VGA_R,
        output  [7:0] VGA_G,
        output  [7:0] VGA_B,
        output        VGA_HS,
        output        VGA_VS,
        output        VGA_DE,    // = ~(VBlank | HBlank)
        output        VGA_F1,
        output [1:0]  VGA_SL,
        output        VGA_SCALER, // Force VGA scaler
        output        VGA_DISABLE,

        input  [11:0] HDMI_WIDTH,
        input  [11:0] HDMI_HEIGHT,
        output        HDMI_FREEZE,
        output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

		`ifdef MISTER_FB
        // Use framebuffer in DDRAM (USE_FB=1 in qsf)
        // FB_FORMAT:
        //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
        //    [3]   : 0=16bits 565 1=16bits 1555
        //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
        //
        // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
        output        FB_EN,
        output  [4:0] FB_FORMAT,
        output [11:0] FB_WIDTH,
        output [11:0] FB_HEIGHT,
        output [31:0] FB_BASE,
        output [13:0] FB_STRIDE,
        input         FB_VBL,
        input         FB_LL,
        output        FB_FORCE_BLANK,

		`ifdef MISTER_FB_PALETTE
        // Palette control for 8bit modes.
        // Ignored for other video modes.
        output        FB_PAL_CLK,
        output  [7:0] FB_PAL_ADDR,
        output [23:0] FB_PAL_DOUT,
        input  [23:0] FB_PAL_DIN,
        output        FB_PAL_WR,
		`endif
		`endif

        output        LED_USER,  // 1 - ON, 0 - OFF.

        // b[1]: 0 - LED status is system status OR'd with b[0]
        //       1 - LED status is controled solely by b[0]
        // hint: supply 2'b00 to let the system control the LED.
        output  [1:0] LED_POWER,
        output  [1:0] LED_DISK,

        // I/O board button press simulation (active high)
        // b[1]: user button
        // b[0]: osd button
        output  [1:0] BUTTONS,

        input         CLK_AUDIO, // 24.576 MHz
        output [15:0] AUDIO_L,
        output [15:0] AUDIO_R,
        output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
        output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

        //ADC
        inout   [3:0] ADC_BUS,

        //SD-SPI
        output        SD_SCK,
        output        SD_MOSI,
        input         SD_MISO,
        output        SD_CS,
        input         SD_CD,

        //High latency DDR3 RAM interface
        //Use for non-critical time purposes
        output        DDRAM_CLK,
        input         DDRAM_BUSY,
        output  [7:0] DDRAM_BURSTCNT,
        output [28:0] DDRAM_ADDR,
        input  [63:0] DDRAM_DOUT,
        input         DDRAM_DOUT_READY,
        output        DDRAM_RD,
        output [63:0] DDRAM_DIN,
        output  [7:0] DDRAM_BE,
        output        DDRAM_WE,

        //SDRAM interface with lower latency
        output        SDRAM_CLK,
        output        SDRAM_CKE,
        output [12:0] SDRAM_A,
        output  [1:0] SDRAM_BA,
        inout  [15:0] SDRAM_DQ,
        output        SDRAM_DQML,
        output        SDRAM_DQMH,
        output        SDRAM_nCS,
        output        SDRAM_nCAS,
        output        SDRAM_nRAS,
        output        SDRAM_nWE,

		`ifdef MISTER_DUAL_SDRAM
        //Secondary SDRAM
        //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
        input         SDRAM2_EN,
        output        SDRAM2_CLK,
        output [12:0] SDRAM2_A,
        output  [1:0] SDRAM2_BA,
        inout  [15:0] SDRAM2_DQ,
        output        SDRAM2_nCS,
        output        SDRAM2_nCAS,
        output        SDRAM2_nRAS,
        output        SDRAM2_nWE,
		`endif

        input         UART_CTS,
        output        UART_RTS,
        input         UART_RXD,
        output        UART_TXD,
        output        UART_DTR,
        input         UART_DSR,

        // Open-drain User port.
        // 0 - D+/RX
        // 1 - D-/TX
        // 2..6 - USR2..USR6
        // Set USER_OUT to 1 to read from USER_IN.
        input   [6:0] USER_IN,
        output  [6:0] USER_OUT,

        input         OSD_STATUS
    );

    ///////// Default values for ports not used in this core /////////

    assign ADC_BUS  = 'Z;
    //assign USER_OUT = '1;
    //assign {UART_RTS, UART_TXD, UART_DTR} = 0;
    assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
    //assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
    assign SDRAM_CLK = clk_chipset;
    assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

    assign VGA_F1 = 0;
    assign VGA_SCALER = 0;
    assign VGA_DISABLE = 0;
    assign HDMI_FREEZE = 0;
    assign HDMI_BLACKOUT = 0;
    assign HDMI_BOB_DEINT = 0;

    assign LED_DISK = 0;
    assign LED_POWER = 0;
    assign BUTTONS = 0;

    assign LED_USER = 0;
    //led fdd_led(clk_cpu, |mgmt_req[7:6], LED_USER);


    //////////////////////////////////////////////////////////////////
    // Status Bit Map:
    //              Upper                          Lower
    // 0         1         2         3          4         5         6
    // 01234567890123456789012345678901 23456789012345678901234567890123
    // 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
    // XXXXX XXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXX

	`include "build_id.v"

    localparam CONF_STR_ROM = "P1FC0,ROM,PCXT BIOS:;";
    localparam CONF_STR_CMS = (`ENABLE_CMS ? "P2OA,C/MS Audio,Enabled,Disabled;" : "");
    localparam CONF_STR_OPL2 = (`ENABLE_OPL2 ? "P2oAB,OPL2,Adlib 388h,SB FM 388h/228h, Disabled;" : "");
    localparam CONF_STR_EMS = (`ENABLE_EMS ? "P3OB,2MB EMS D000-DFFF,Enabled,Disabled;P3-;" : "");
    localparam CONF_STR_UMB = (`ENABLE_UMB ? "P3OC,UMB C400-CFFF,Enabled,Disabled;P3-;" : "");

    localparam CONF_STR = {
		`CONF_STR_SYSTEM,
		"S0,IMGIMAVFD,Floppy A:;",
		"S1,IMGIMAVFD,Floppy B:;",
		"OJK,Write Protect,None,A:,B:,A: & B:;",
		"-;",
		"S2,VHD,IDE 0-0;",
		"S3,VHD,IDE 0-1;",
		"OLM,2nd SD card,Disable,IDE 0-0,IDE 0-1;",
		"-;",
		"OHI,CPU Speed,4.77MHz,7.16MHz,9.54MHz,PC/AT 3.5MHz;",
		"-;",
		"P1,System & BIOS;",
		"P1-;",
		"P1O7,Boot Splash Screen,Yes,No;",
		"P1-;",
		CONF_STR_ROM,
		"P1FC2,ROM,EC00 BIOS:;",
		"P1FC3,ROM,EGA BIOS:;",
		"P1-;",
		"P1OUV,BIOS Writable,None,EC00,Main,All;",
		"P1-;",	
		"P2,Audio & Video;",
		"P2-;",
		CONF_STR_CMS,
		CONF_STR_OPL2,
		"P2o01,Speaker Volume,1,2,3,4;",
		"P2o45,Audio Boost,No,2x,4x;",
		"P2o67,Stereo Mix,none,25%,50%,100%;",
		"P2-;",
		"P2oEH,CRT H offset,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;",
		"P2oIK,CRT V offset,0,1,2,3,4,5,6,7;",        
		"P2oMO,VSync Width,Auto,1,2,3,4,5,6,7;",
		"P2oPR,HSync Width,Auto,1,2,3,4,5,6,7;",
        "P2-;",
		"P2O12,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
		"P2O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
		"P2OEG,Display,Full Color,Green,Amber,B&W,Red,Blue,Fuchsia,Purple;",
		"P2OT,VGA Mode 13h,Off,On;",
		"P2-;",
		"P3,Hardware;",
		"P3-;",
		CONF_STR_EMS,
		CONF_STR_UMB,
		"P3ONO,Joystick 1, Analog, Digital, Disabled;",
		"P3OPQ,Joystick 2, Analog, Digital, Disabled;",
		"P3OR,Sync Joy to CPU Speed,No,Yes;",
		"P3OS,Swap Joysticks,No,Yes;",
		"P3-;",	
		"-;",
		"R0,Reset & apply settings;",
		"J,Fire 1,Fire 2;",
		"V,v",`BUILD_DATE
	};

    wire forced_scandoubler;
    wire vga_mode13_active_video;
    wire ega_dot_toggle;
    wire ega_dot_clock_sel;
    wire ega_scandouble_active;
    wire [1:0] buttons;
    wire [63:0] status;
    wire vga_mode13_osd = status[29];
    wire [7:0]  xtctl;

    //Keyboard Ps2
    wire        ps2_kbd_clk_out;
    wire        ps2_kbd_data_out;
    wire        ps2_kbd_clk_in;
    wire        ps2_kbd_data_in;

    //Mouse PS2
    wire        ps2_mouse_clk_out;
    wire        ps2_mouse_data_out;
    wire        ps2_mouse_clk_in;
    wire        ps2_mouse_data_in;

    wire        ioctl_download;
    wire  [7:0] ioctl_index;
    wire        ioctl_wr;
    wire [24:0] ioctl_addr;
    wire [15:0] ioctl_data;
    reg         ioctl_wait;

    wire [21:0] gamma_bus;

    wire [13:0] joy0, joy1;
    wire [15:0] joya0, joya1;
    wire [4:0]  joy_opts = status[27:23];

    wire [1:0] scale = status[2:1];
    wire [2:0] screen_mode = status[16:14];
    wire [1:0] ar = status[9:8];
    wire [2:0] vsync_width_osd = status[56:54];  // 0=Auto (use register), 1-7=override
    wire [2:0] hsync_width_osd = status[59:57];  // 0=Auto, 1-7=fixed width (Nx16 pixel clocks)

    reg [1:0]   scale_video_ff;
    reg [2:0]   screen_mode_video_ff;
    wire        video_scandoubler_en = (scale_video_ff > 0) || forced_scandoubler;
    wire [15:0] status_menumask = {12'd0, 2'b11, status[5]};

    wire VGA_VBlank_border;
    wire std_hsyncwidth;
    wire pause_core;

    always @(posedge clk_57_272)
    begin
        scale_video_ff          <= scale;
        screen_mode_video_ff    <= screen_mode;
        VIDEO_ARX               <= (!ar) ? 12'd4 : (ar - 1'd1);
        VIDEO_ARY               <= (!ar) ? 12'd3 : 12'd0;
    end

    hps_io #(.CONF_STR(CONF_STR), .PS2DIV(2000), .PS2WE(1), .WIDE(1)) hps_io 
	(
		.clk_sys(clk_chipset),
		.HPS_BUS(HPS_BUS),
		.EXT_BUS(EXT_BUS),
		.gamma_bus(gamma_bus),

		.forced_scandoubler(forced_scandoubler),

		.buttons(buttons),
		.status(status),
		.status_menumask(status_menumask),

		.ps2_kbd_clk_in		(ps2_kbd_clk_out),
		.ps2_kbd_data_in	(ps2_kbd_data_out),
		.ps2_kbd_clk_out	(ps2_kbd_clk_in),
		.ps2_kbd_data_out	(ps2_kbd_data_in),

		.ps2_mouse_clk_out    (ps2_mouse_clk_out),
		.ps2_mouse_data_out   (ps2_mouse_data_out),
		.ps2_mouse_clk_in     (ps2_mouse_clk_in),
		.ps2_mouse_data_in    (ps2_mouse_data_in),

		.joystick_0(joy0),
		.joystick_1(joy1),
		.joystick_l_analog_0(joya0),
		.joystick_l_analog_1(joya1),

		//ioctl
		.ioctl_download(ioctl_download),
		.ioctl_index(ioctl_index),
		.ioctl_wr(ioctl_wr),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_data),
		.ioctl_wait(ioctl_wait)
	);


    wire [15:0] mgmt_din;
    wire [15:0] mgmt_dout;
    wire [15:0] mgmt_addr;
    wire        mgmt_rd;
    wire        mgmt_wr;
    wire  [7:0] mgmt_req;
    assign mgmt_req[5:3] = 3'b000;

    wire [35:0] EXT_BUS;
    hps_ext hps_ext  
	(
		.clk_sys(clk_chipset),
		.EXT_BUS(EXT_BUS),

		.ext_din(mgmt_din),
		.ext_dout(mgmt_dout),
		.ext_addr(mgmt_addr),
		.ext_rd(mgmt_rd),
		.ext_wr(mgmt_wr),

		.ext_req(mgmt_req),
		.ext_hotswap(2'b00)
	);

    //
    ///////////////////////   CLOCKS   /////////////////////////////
    //

    wire clk_sys;
    wire pll_locked;

    wire clk_100;
    wire clk_28_636;
    wire clk_57_272;
    wire clk_video_out_ps;
    reg clk_14_318 = 1'b0;
    wire clk_cpu;
    logic cpu_ce_posedge;
    logic cpu_ce_negedge;
    logic peripheral_ce;
    wire clk_chipset;

    localparam [27:0] cur_rate = 28'd50000000;

    pll pll 
	(
		.refclk(CLK_50M),
		.rst(0),
		.outclk_0(clk_100),
        .outclk_1(clk_chipset),
		.locked(pll_locked)
	);

    wire pll_system_locked;

    pll_system pll_system_inst (
        .refclk(CLK_50M),
        .rst(0),
        .outclk_0(clk_28_636),
        .outclk_1(clk_57_272),
        .outclk_2(clk_video_out_ps),
        .locked(pll_system_locked)
    );

    wire reset_wire = RESET | status[0] | buttons[1] | !pll_locked | !pll_system_locked  | splashscreen | splash_pending;
    wire video_retime_reset = RESET | status[0] | buttons[1] | !pll_locked | !pll_system_locked | splash_pending;
    (* ASYNC_REG = "TRUE" *) logic [1:0] video_retime_reset_sync = 2'b11;
    wire video_retime_reset_local = video_retime_reset_sync[1];

    // The output retime registers run on the phase-shifted video clock.
    // Reset asserts asynchronously but is released only on that clock.
    always_ff @(posedge clk_video_out_ps or posedge video_retime_reset) begin
        if (video_retime_reset)
            video_retime_reset_sync <= 2'b11;
        else
            video_retime_reset_sync <= {video_retime_reset_sync[0], 1'b0};
    end
    wire reset_sdram_wire = RESET | !pll_locked;

    //////////////////////////////////////////////////////////////////

    // TODO: messy, use a single clock domain at least
    always @(posedge clk_28_636)
    begin
        clk_14_318 <= ~clk_14_318;  // 14.318Mhz, UART reference and splash timebase
    end

    //////////////////////////////////////////////////////////////////

    logic  biu_done;
    logic  [7:0] clock_cycle_counter_division_ratio;
    logic  [7:0] clock_cycle_counter_decrement_value;
    logic        shift_read_timing;
    logic  [1:0] ram_read_wait_cycle;
    logic  [1:0] ram_write_wait_cycle;
    logic        cycle_accrate;
    logic  [1:0] clk_select;
    wire   [1:0] clk_select_next = ((xtctl[3:2] == 2'b00) && ~xtctl[7]) ? status[18:17] :
                                   (xtctl[7] ? 2'b11 : xtctl[3:2] - 2'b01);

    always @(posedge clk_chipset, posedge reset)
    begin
        if (reset)
            clk_select <= 2'b00;
        else if (biu_done)
            clk_select <= clk_select_next;
    end

    XT_CE_Generator u_XT_CE_Generator
    (
        .clock                              (clk_chipset),
        .reset                              (reset),
        .clk_select_load                    (biu_done),
        .clk_select                         (clk_select_next),
        .cpu_clk_pin                        (clk_cpu),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .peripheral_ce                      (peripheral_ce),
        .cycle_accrate                      (cycle_accrate),
        .clock_cycle_counter_division_ratio (clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing                  (shift_read_timing),
        .ram_read_wait_cycle                (ram_read_wait_cycle),
        .ram_write_wait_cycle               (ram_write_wait_cycle)
    );
    //////////////////////////////////////////////////////////////////

    logic reset = 1'b1;
    logic [15:0] reset_count = 16'h0000;
    logic reset_sdram = 1'b1;
    logic [15:0] reset_sdram_count = 16'h0000;

    always @(posedge clk_chipset, posedge reset_wire)
    begin
        if (reset_wire)
        begin
            reset <= 1'b1;
            reset_count <= 16'h0000;
        end
        else if (reset)
        begin
            if (reset_count != 16'hffff)
            begin
                reset <= 1'b1;
                reset_count <= reset_count + 16'h0001;
            end
            else
            begin
                reset <= 1'b0;
                reset_count <= reset_count;
            end
        end
        else
        begin
            reset <= 1'b0;
            reset_count <= reset_count;
        end
    end

    logic reset_cpu_ff = 1'b1;
    logic reset_cpu = 1'b1;
    logic [15:0] reset_cpu_count = 16'h0000;

    always @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
            reset_cpu_ff <= 1'b1;
        else
            reset_cpu_ff <= reset;
    end

    always @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            reset_cpu <= 1'b1;
            reset_cpu_count <= 16'h0000;
        end
        else if (reset_cpu)
        begin
            reset_cpu <= reset_cpu_ff;
            reset_cpu_count <= 16'h0000;
        end
        else
        begin
            if (reset_cpu_count != 16'h002A)
            begin
                reset_cpu <= reset_cpu_ff;
                reset_cpu_count <= reset_cpu_count + 16'h0001;
            end
            else
            begin
                reset_cpu <= 1'b0;
                reset_cpu_count <= reset_cpu_count;
            end
        end
    end

    always @(posedge clk_chipset, posedge reset_sdram_wire)
    begin
        if (reset_sdram_wire)
        begin
            reset_sdram <= 1'b1;
            reset_sdram_count <= 16'h0000;
        end
        else if (reset_sdram)
        begin
            if (reset_sdram_count != 16'hffff)
            begin
                reset_sdram <= 1'b1;
                reset_sdram_count <= reset_sdram_count + 16'h0001;
            end
            else
            begin
                reset_sdram <= 1'b0;
                reset_sdram_count <= reset_sdram_count;
            end
        end
        else
        begin
            reset_sdram <= 1'b0;
            reset_sdram_count <= reset_sdram_count;
        end
    end

    //
    ///////////////////////   BIOS LOADER   ////////////////////////////
    //

    reg [4:0]  bios_load_state = 4'h0;
    reg [2:0]  bios_protect_flag;
    reg        bios_access_request;
    reg [19:0] bios_access_address;
    reg [15:0] bios_write_data;
    reg        bios_write_n;
    reg [7:0]  bios_write_wait_cnt;
    reg        bios_write_byte_cnt;
    wire       ega_bios_loaded;
    wire       ega_bios_write_protect;
    wire [1:0] ega_video_switches;
    wire select_pcxt  = (ioctl_index[5:0] == 0) && (ioctl_addr[24:16] == 9'b000000000);
    wire select_xtide = ioctl_index == 2;
    wire select_ega_bios = (ioctl_index[5:0] == 3) && (ioctl_addr[24:16] == 9'b000000000);

    // File identity, rather than the current address, defines the lifetime of
    // an upload.  ioctl_addr is not guaranteed to have the new file's first
    // address until its first data beat arrives.
    wire ega_bios_download_active = ioctl_download && (ioctl_index[5:0] == 6'd3);
    wire ega_bios_write_complete = (bios_load_state == 4'h04) &&
                                   bios_write_byte_cnt && select_ega_bios;

    // The loader returns to state 01 between every 16-bit word.  Treating that
    // state as the start of a new EGA download cleared the presence flag again
    // after every word (and once more at end-of-file), so the XT motherboard
    // switches continued to advertise CGA even though an EGA ROM was present.
    ega_bios_loaded_latch ega_bios_presence (
        .clock              (clk_chipset),
        .reset              (reset_sdram),
        .sdram_initialized  (initilized_sdram),
        .download_active    (ega_bios_download_active),
        .write_complete     (ega_bios_write_complete),
        .loaded             (ega_bios_loaded),
        .write_protect      (ega_bios_write_protect),
        .video_switches     (ega_video_switches)
    );

    wire [19:0] bios_access_address_wire = select_pcxt  ? { 4'b1111, ioctl_addr[15:0]} :
         select_xtide ? { 6'b111011, ioctl_addr[13:0]} :
         select_ega_bios ? { 4'b1100, ioctl_addr[15:0]} :
         20'hFFFFF;

    wire bios_load_n = ~(ioctl_download & (select_pcxt | select_xtide | select_ega_bios));

    always @(posedge clk_chipset, posedge reset_sdram)
    begin
        if (reset_sdram)
        begin
            bios_protect_flag   <= 3'b011;
            bios_access_request <= 1'b0;
            bios_access_address <= 20'hFFFFF;
            bios_write_data     <= 16'hFFFF;
            bios_write_n        <= 1'b1;
            bios_write_wait_cnt <= 'h0;
            bios_write_byte_cnt <= 1'h0;
            ioctl_wait          <= 1'b1;
            bios_load_state     <= 4'h00;
        end
        else if (~initilized_sdram)
        begin
            bios_protect_flag   <= 3'b011;
            bios_access_request <= 1'b0;
            bios_access_address <= 20'hFFFFF;
            bios_write_data     <= 16'hFFFF;
            bios_write_n        <= 1'b1;
            bios_write_wait_cnt <= 'h0;
            bios_write_byte_cnt <= 1'h0;
            ioctl_wait          <= 1'b1;
            bios_load_state     <= 4'h00;
        end
        else
        begin
            casez (bios_load_state)
                4'h00:
                begin
                    bios_protect_flag   <= {ega_bios_write_protect, ~status[31:30]};  // ega/f000/ec00 protection
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= 1'h0;
                    if (~ioctl_download)
                    begin
                        bios_access_request <= 1'b0;
                        ioctl_wait          <= 1'b0;
                    end
                    else
                    begin
                        bios_access_request <= 1'b1;
                        ioctl_wait          <= 1'b1;
                    end

                    if ((ioctl_download) && (~processor_ready) && (address_direction))
                        bios_load_state <= 4'h01;
                    else
                        bios_load_state <= 4'h00;
                end
                4'h01:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_write_byte_cnt <= 1'h0;
                    if (~ioctl_download)
                    begin
                        bios_access_address <= 20'hFFFFF;
                        bios_write_data     <= 16'hFFFF;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b0;
                        bios_load_state     <= 4'h00;
                    end
                    else if ((~ioctl_wr) || (bios_load_n))
                    begin
                        bios_access_address <= 20'hFFFFF;
                        bios_write_data     <= 16'hFFFF;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b0;
                        bios_load_state     <= 4'h01;
                    end
                    else
                    begin
                        bios_access_address <= bios_access_address_wire;
                        bios_write_data     <= ioctl_data;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b1;
                        bios_load_state     <= 4'h02;
                    end
                end
                4'h02:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address;
                    bios_write_data     <= bios_write_data;
                    bios_write_byte_cnt <= bios_write_byte_cnt;
                    ioctl_wait          <= 1'b1;
                    bios_write_wait_cnt <= bios_write_wait_cnt + 'h1;

                    if (bios_write_wait_cnt != 'd20)
                    begin
                        bios_write_n        <= 1'b0;
                        bios_load_state     <= 4'h02;
                    end
                    else
                    begin
                        bios_write_n        <= 1'b1;
                        bios_load_state     <= 4'h03;
                    end
                end
                4'h03:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address;
                    bios_write_data     <= bios_write_data;
                    bios_write_n        <= 1'b1;
                    bios_write_byte_cnt <= bios_write_byte_cnt;
                    ioctl_wait          <= 1'b1;
                    bios_write_wait_cnt <= bios_write_wait_cnt + 'h1;

                    if (bios_write_wait_cnt != 'h40)
                        bios_load_state     <= 4'h03;
                    else
                        bios_load_state     <= 4'h04;
                end
                4'h04:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address + 'h1;
                    bios_write_data     <= {8'hFF, bios_write_data[15:8]};
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= ~bios_write_byte_cnt;
                    ioctl_wait          <= 1'b1;
                    if (bios_write_byte_cnt == 1'b0)
                        bios_load_state     <= 4'h02;
                    else
                        bios_load_state     <= 4'h01;
                end
                default:
                begin
                    bios_protect_flag   <= {ega_bios_write_protect, 2'b11};
                    bios_access_request <= 1'b0;
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= 1'h0;
                    ioctl_wait          <= 1'b0;
                    bios_load_state     <= 4'h00;
                end
            endcase
        end
    end


    //////////////////////////////////////////////////////////////////

    //
    // Splash screen
    //
    reg splash_off = 1'b1;
    reg [24:0] splash_cnt = 0;
    reg [3:0] splash_cnt2 = 0;
    reg splashscreen = 1'b0;
    reg splash_pending = 1'b1;
    reg [23:0] splash_boot_cnt = 24'd0;
    reg phys_reset_hold = 0;
    reg [23:0] phys_reset_cnt = 24'd0;
    localparam [23:0] PHYS_RESET_HOLD = 24'd2863600;
    localparam [23:0] SPLASH_BOOT_WAIT = 24'd14318000;

    always @ (posedge clk_14_318)
    begin
        splash_off <= status[7];
        if (RESET || buttons[1])
        begin
            phys_reset_hold <= 1'b1;
            phys_reset_cnt <= 24'd0;
        end
        else if (phys_reset_hold)
        begin
            if (phys_reset_cnt == PHYS_RESET_HOLD)
                phys_reset_hold <= 1'b0;
            else
                phys_reset_cnt <= phys_reset_cnt + 24'd1;
        end

        if (splash_pending)
        begin
            if (~splash_off)
            begin
                splashscreen <= 1'b1;
                splash_cnt <= 0;
                splash_cnt2 <= 0;
                splash_pending <= 1'b0;
                splash_boot_cnt <= 24'd0;
            end
            else if (splash_boot_cnt == SPLASH_BOOT_WAIT)
            begin
                splash_pending <= 1'b0;
            end
            else
            begin
                splash_boot_cnt <= splash_boot_cnt + 24'd1;
            end
        end
        else if (splashscreen)
        begin
            if (splash_off)
            begin
                splashscreen <= 0;
            end
            else if(splash_cnt2 == 5) // 5 seconds delay
            begin
                splashscreen <= 0;
            end
            else if (splash_cnt == 14318000)
            begin // 1 second at 14.318Mhz
                splash_cnt2 <= splash_cnt2 + 1;
                splash_cnt <= 0;
            end
            else
                splash_cnt <= splash_cnt + 1;
        end

    end

    //
    // Input F/F PS2_CLK
    //
    logic   device_clock_ff;
    logic   device_clock;

    always_ff @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            device_clock_ff <= 1'b0;
            device_clock    <= 1'b0;
        end
        else
        begin
            device_clock_ff <= ps2_kbd_clk_in;
            device_clock    <= device_clock_ff ;
        end
    end


    //
    // Input F/F PS2_DAT
    //
    logic   device_data_ff;
    logic   device_data;

    always_ff @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            device_data_ff <= 1'b0;
            device_data    <= 1'b0;
        end
        else
        begin
            device_data_ff <= ps2_kbd_data_in;
            device_data    <= device_data_ff;
        end
    end


    wire [7:0] data_bus;
    wire INTA_n;
    wire [19:0] cpu_ad_out;
    reg  [19:0] cpu_address;
    wire [7:0] cpu_data_bus;
    wire processor_ready;
    wire interrupt_to_cpu;
    wire address_latch_enable;
    wire address_direction;

    wire lock_n;
    wire [2:0]processor_status;

`ifdef PC3086_POST_TRACE
    // Kept at the CPU/chipset boundary so this debug-only probe sees every
    // motherboard I/O transaction, independent of which peripheral owns it.
    wire io_read_n;
    wire io_write_n;
    wire memory_read_n;
    wire memory_write_n;
    wire [7:0] pc3086_keyboard_scancode;
    wire pc3086_keyboard_irq;
    wire pc3086_keyboard_enabled;
    wire [7:0] pc3086_keyboard_port_a;
    wire [7:0] pc3086_keyboard_ppi_data;
    wire [1:0] pc3086_fdd_present;
    wire pc3086_fdd_wp;
    wire [7:0] pc3086_fdd_cylinders;
    wire [7:0] pc3086_fdd_sectors_per_track;
    wire [15:0] pc3086_fdd_sector_count;
    wire [1:0] pc3086_fdd_heads;
    wire pc3086_fdd_irq, pc3086_fdd_dma_req, pc3086_fdd_dma_ack;
    wire pc3086_fdd_dma_strobe, pc3086_fdd_dma_tc;
    wire [7:0] pc3086_fdd_dma_data;
    wire [7:0] pc3086_tail_write_cpu_low;
    wire [7:0] pc3086_tail_write_cpu_high;
    wire [7:0] pc3086_tail_write_sdram_low;
    wire [7:0] pc3086_tail_write_sdram_high;
    wire [7:0] pc3086_tail_write_queue_cpu_low;
    wire [7:0] pc3086_tail_write_queue_cpu_high;
    wire [7:0] pc3086_tail_write_queue_sdram_low;
    wire [7:0] pc3086_tail_write_queue_sdram_high;
    wire [1:0] pc3086_tail_write_cpu_valid;
    wire [1:0] pc3086_tail_write_sdram_valid;
    wire [1:0] pc3086_tail_write_queue_cpu_valid;
    wire [1:0] pc3086_tail_write_queue_sdram_valid;
    wire [3:0] pc3086_tail_write_cpu_low_count;
    wire [3:0] pc3086_tail_write_cpu_high_count;
    wire [3:0] pc3086_tail_write_queue_cpu_low_count;
    wire [3:0] pc3086_tail_write_queue_cpu_high_count;
    wire [3:0] pc3086_tail_write_sdram_low_count;
    wire [3:0] pc3086_tail_write_sdram_high_count;
    wire [3:0] pc3086_tail_write_queue_sdram_low_count;
    wire [3:0] pc3086_tail_write_queue_sdram_high_count;
    wire [31:0] pc3086_boot_sector_sdram_data;
    wire [3:0] pc3086_boot_sector_sdram_valid;
    wire [31:0] pc3086_root_dir_sdram_data;
    wire [3:0]  pc3086_root_dir_sdram_valid;
`endif

    wire [3:0]   dma_acknowledge_n;

    logic   [7:0]   port_b_out;
    logic   [7:0]   port_c_in;
    wire    [2:0]   timer_counter_out;
    wire    [1:0]   fdd_present;
    reg     [7:0]   sw;

    wire    [5:0]   sw_base;
    wire    [1:0]   sw_floppy;

    // sw_base[5:4] is the motherboard video switch pair the BIOS copies into bits
    // 5:4 of the equipment word at 40:10. 2'b00 means "adapter with its own option
    // ROM" (EGA), 2'b10 means CGA 80x25. Loading the EGA BIOS is what installs the
    // card, so track it: otherwise the equipment word claims CGA and software that
    // trusts it, such as Titus The Fox, picks the CGA path and renders nothing.
    assign  sw_base = {ega_video_switches, 4'b1101};
    assign  sw_floppy = fdd_present[1] ? 2'b01 : 2'b00;
    assign  sw = {sw_floppy, sw_base}; // DIP switches (video adapter and floppy count)
    // PC/XT PPI system-status inputs: the lower nibble is the selected DIP
    // switch bank and bit 5 is the PIT channel-2 OUT pin.  PC3086 POST
    // explicitly checks that bit 5 goes low then high after programming
    // channel 2 in mode 0.  The remaining unimplemented inputs model inactive
    // cassette, I/O-channel-check, and parity-check signals.
    assign  port_c_in[7:4] = {2'b00, timer_counter_out[2], 1'b0};
    assign  port_c_in[3:0] = port_b_out[3] ? sw[7:4] : sw[3:0];


    wire ems_enabled_sel = `ENABLE_EMS ? ~status[11] : 1'b0;
    wire [1:0] ems_address_sel = 2'b01; // Fixed D000 page frame avoids EGA and XT-IDE ROM conflicts.
    wire umb_enabled_sel = `ENABLE_UMB ? ~status[12] : 1'b0;

    always @(posedge clk_chipset)
    begin
        if (address_latch_enable)
            cpu_address <= cpu_ad_out;
        else
            cpu_address <= cpu_address;
    end

    CHIPSET #(.clk_rate(cur_rate)) u_CHIPSET
	(
		.clock                              (clk_chipset),
		.cpu_ce_posedge                     (cpu_ce_posedge),
		.cpu_ce_negedge                     (cpu_ce_negedge),
		.clk_sys                            (clk_chipset),
		.peripheral_ce                      (peripheral_ce),
		.clk_select                         (clk_select),
		.reset                              (reset_cpu),
		.video_reset                        (video_retime_reset),
		.sdram_reset                        (reset_sdram),
		.cpu_address                        (cpu_address),
		.cpu_data_bus                       (cpu_data_bus),
		.processor_status                   (processor_status),
		.processor_lock_n                   (lock_n),
	//	.processor_transmit_or_receive_n    (processor_transmit_or_receive_n),
		.processor_ready                    (processor_ready),
		.interrupt_to_cpu                   (interrupt_to_cpu),
		.splashscreen                       (splashscreen),
		.std_hsyncwidth                     (std_hsyncwidth),
		.clk_video                        (clk_28_636),
		.de_o                               (de_o),
		.VGA_R                              (r),
		.VGA_G                              (g),
		.VGA_B                              (b),
		.VGA_HSYNC                          (HSync),
		.VGA_VSYNC                          (VSync),
		.VGA_HBlank                         (HBlank),
		.VGA_VBlank                         (VBlank),
		.VGA_VBlank_border                  (VGA_VBlank_border),
		.vga_mode13_osd                    (vga_mode13_osd),
		.vga_mode13_active_out             (vga_mode13_active_video),
	//	.address                            (address),
		.address_ext                        (bios_access_address),
		.ext_access_request                 (bios_access_request),
		.address_direction                  (address_direction),
		.data_bus                           (data_bus),
		.data_bus_ext                       (bios_write_data[7:0]),
	//	.data_bus_direction                 (data_bus_direction),
		.address_latch_enable               (address_latch_enable),
	//  .io_channel_check                   (),
		.io_channel_ready                   (1'b1),
		.interrupt_request                  (0),    // use?	-> It does not seem to be necessary.
	`ifdef PC3086_POST_TRACE
		.io_read_n                          (io_read_n),
	`endif
		.io_read_n_ext                      (1'b1),
	//  .io_read_n_direction                (io_read_n_direction),
	`ifdef PC3086_POST_TRACE
		.io_write_n                         (io_write_n),
	`endif
		.io_write_n_ext                     (1'b1),
	//  .io_write_n_direction               (io_write_n_direction),
	`ifdef PC3086_POST_TRACE
		.memory_read_n                       (memory_read_n),
	`endif
		.memory_read_n_ext                  (1'b1),
	//  .memory_read_n_direction            (memory_read_n_direction),
	`ifdef PC3086_POST_TRACE
		.memory_write_n                       (memory_write_n),
	`endif
		.memory_write_n_ext                 (bios_write_n),
	//  .memory_write_n_direction           (memory_write_n_direction),
		.dma_request                        (0),    // use?	-> I don't know if it will ever be necessary, at least not during testing.
		.dma_acknowledge_n                  (dma_acknowledge_n),
	//  .address_enable_n                   (address_enable_n),
	//  .terminal_count_n                   (terminal_count_n)
		.timer_counter_out                  (timer_counter_out),
		.port_b_out                         (port_b_out),
		.port_c_in                          (port_c_in),
		.port_b_in                          (port_b_out),
		.speaker_out                        (speaker_out),
		.ps2_clock                          (device_clock),
		.ps2_data                           (device_data),
		.ps2_clock_out                      (ps2_kbd_clk_out),
		.ps2_data_out                       (ps2_kbd_data_out),
		.ps2_mouseclk_in                    (ps2_mouse_clk_out),
		.ps2_mousedat_in                    (ps2_mouse_data_out),
		.ps2_mouseclk_out                   (ps2_mouse_clk_in),
		.ps2_mousedat_out                   (ps2_mouse_data_in),
		.joy_opts                           (joy_opts),           //Joy0-Disabled, Joy0-Type, Joy1-Disabled, Joy1-Type, turbo_sync
		.joy0                               (status[28] ? joy1 : joy0),
		.joy1                               (status[28] ? joy0 : joy1),
		.joya0                              (status[28] ? joya1 : joya0),
		.joya1                              (status[28] ? joya0 : joya1),
		.jtopl2_snd_e                       (jtopl2_snd_e),
		.opl2_io                            (xtctl[4] ? 2'b10 : status[43:42]),
		.cms_en                             (~status[10]),
		.o_cms_l                            (cms_l_snd_e),
		.o_cms_r                            (cms_r_snd_e),
		.clk_uart                           (clk_uart2_en),
		.uart2_rx                           (uart_rx),
		.uart2_tx                           (uart_tx),
		.uart2_cts_n                        (uart_cts),
		.uart2_dcd_n                        (uart_dcd),
		.uart2_dsr_n                        (uart_dsr),
		.uart2_rts_n                        (uart_rts),
		.uart2_dtr_n                        (uart_dtr),
		.enable_sdram                       (1'b1),
		.initilized_sdram                   (initilized_sdram),
		.sdram_clock                        (SDRAM_CLK),
		.sdram_address                      (SDRAM_A),
		.sdram_cke                          (SDRAM_CKE),
		.sdram_cs                           (SDRAM_nCS),
		.sdram_ras                          (SDRAM_nRAS),
		.sdram_cas                          (SDRAM_nCAS),
		.sdram_we                           (SDRAM_nWE),
		.sdram_ba                           (SDRAM_BA),
		.sdram_dq_in                        (SDRAM_DQ_IN),
		.sdram_dq_out                       (SDRAM_DQ_OUT),
		.sdram_dq_io                        (SDRAM_DQ_IO),
		.sdram_ldqm                         (SDRAM_DQML),
		.sdram_udqm                         (SDRAM_DQMH),
		.ems_enabled                        (ems_enabled_sel),
		.ems_address                        (ems_address_sel),
		.umb_enabled                        (umb_enabled_sel),
		.bios_protect_flag                  (bios_protect_flag),
		.use_mmc                            (use_mmc),
		.spi_clk                            (spi_clk),
		.spi_cs                             (spi_cs),
		.spi_mosi                           (spi_mosi),
		.spi_miso                           (spi_miso),
		.mgmt_readdata                      (mgmt_din),
		.mgmt_writedata                     (mgmt_dout),
		.mgmt_address                       (mgmt_addr),
		.mgmt_write                         (mgmt_wr),
		.mgmt_read                          (mgmt_rd),
		.floppy_wp                          (status[20:19]),
		.fdd_present                        (fdd_present),
		.fdd_request                        (mgmt_req[7:6]),
		.ide0_request                       (mgmt_req[2:0]),
		.xtctl                              (xtctl),
		.wait_count_clk_en                  (cpu_ce_negedge),
		.ram_read_wait_cycle                (ram_read_wait_cycle),
		.ram_write_wait_cycle               (ram_write_wait_cycle),
		.pause_core                         (pause_core),
		.video_scandoubler_en                  (video_scandoubler_en),
		.ega_dot_toggle                     (ega_dot_toggle),
		.ega_dot_clock_sel                  (ega_dot_clock_sel),
		.ega_scandouble_active              (ega_scandouble_active),
		.crt_h_offset                       (status[49:46]),
		.crt_v_offset                       (status[52:50]),
		.vsync_width_osd                    (vsync_width_osd),
		.hsync_width_osd                    (hsync_width_osd)
`ifdef PC3086_POST_TRACE
		,.debug_keyboard_scancode            (pc3086_keyboard_scancode)
		,.debug_keyboard_irq                 (pc3086_keyboard_irq)
		,.debug_keyboard_enabled             (pc3086_keyboard_enabled)
		,.debug_keyboard_port_a              (pc3086_keyboard_port_a)
		,.debug_keyboard_ppi_data            (pc3086_keyboard_ppi_data)
		,.debug_fdd_present                   (pc3086_fdd_present)
		,.debug_fdd_wp                        (pc3086_fdd_wp)
		,.debug_fdd_cylinders                 (pc3086_fdd_cylinders)
		,.debug_fdd_sectors_per_track         (pc3086_fdd_sectors_per_track)
		,.debug_fdd_sector_count              (pc3086_fdd_sector_count)
		,.debug_fdd_heads                     (pc3086_fdd_heads)
		,.debug_fdd_irq                       (pc3086_fdd_irq)
		,.debug_fdd_dma_req                   (pc3086_fdd_dma_req)
		,.debug_fdd_dma_ack                   (pc3086_fdd_dma_ack)
		,.debug_fdd_dma_strobe                (pc3086_fdd_dma_strobe)
		,.debug_fdd_dma_tc                    (pc3086_fdd_dma_tc)
		,.debug_fdd_dma_data                  (pc3086_fdd_dma_data)
		,.debug_tail_write_cpu_low           (pc3086_tail_write_cpu_low)
		,.debug_tail_write_cpu_high          (pc3086_tail_write_cpu_high)
		,.debug_tail_write_sdram_low         (pc3086_tail_write_sdram_low)
		,.debug_tail_write_sdram_high        (pc3086_tail_write_sdram_high)
		,.debug_tail_write_queue_cpu_low     (pc3086_tail_write_queue_cpu_low)
		,.debug_tail_write_queue_cpu_high    (pc3086_tail_write_queue_cpu_high)
		,.debug_tail_write_queue_sdram_low   (pc3086_tail_write_queue_sdram_low)
		,.debug_tail_write_queue_sdram_high  (pc3086_tail_write_queue_sdram_high)
		,.debug_tail_write_cpu_valid         (pc3086_tail_write_cpu_valid)
		,.debug_tail_write_sdram_valid       (pc3086_tail_write_sdram_valid)
		,.debug_tail_write_queue_cpu_valid   (pc3086_tail_write_queue_cpu_valid)
		,.debug_tail_write_queue_sdram_valid (pc3086_tail_write_queue_sdram_valid)
		,.debug_tail_write_cpu_low_count     (pc3086_tail_write_cpu_low_count)
		,.debug_tail_write_cpu_high_count    (pc3086_tail_write_cpu_high_count)
		,.debug_tail_write_queue_cpu_low_count(pc3086_tail_write_queue_cpu_low_count)
		,.debug_tail_write_queue_cpu_high_count(pc3086_tail_write_queue_cpu_high_count)
		,.debug_tail_write_sdram_low_count   (pc3086_tail_write_sdram_low_count)
		,.debug_tail_write_sdram_high_count  (pc3086_tail_write_sdram_high_count)
		,.debug_tail_write_queue_sdram_low_count(pc3086_tail_write_queue_sdram_low_count)
		,.debug_tail_write_queue_sdram_high_count(pc3086_tail_write_queue_sdram_high_count)
		,.debug_boot_sector_sdram_data          (pc3086_boot_sector_sdram_data)
		,.debug_boot_sector_sdram_valid         (pc3086_boot_sector_sdram_valid)
		,.debug_root_dir_sdram_data             (pc3086_root_dir_sdram_data)
		,.debug_root_dir_sdram_valid            (pc3086_root_dir_sdram_valid)
`endif
	);

    wire [15:0] SDRAM_DQ_IN;
    wire [15:0] SDRAM_DQ_OUT;
    wire        SDRAM_DQ_IO;
    wire        initilized_sdram;

    assign SDRAM_DQ_IN = SDRAM_DQ;
    assign SDRAM_DQ = ~SDRAM_DQ_IO ? SDRAM_DQ_OUT : 16'hZZZZ;

    wire s6_3_mux;
    wire [2:0] SEGMENT;
`ifdef PC3086_POST_TRACE
    wire pc3086_nmi_caught;
    wire [15:0] pc3086_debug_cs;
    wire [15:0] pc3086_debug_pfq_addr;
    wire [15:0] pc3086_debug_eu_biu_dataout;
    wire [15:0] pc3086_debug_eu_ax;
    wire [15:0] pc3086_debug_eu_bx;
    wire [15:0] pc3086_debug_eu_cx;
    wire [15:0] pc3086_debug_eu_dx;
    wire [12:0] pc3086_debug_eu_dataout_uaddr;
    wire [15:0] pc3086_debug_eu_dataout_alu;
    wire [15:0] pc3086_debug_biu_data_latch;
    wire [7:0]  pc3086_debug_biu_state;
    wire [19:0] pc3086_debug_biu_write_address;
    wire [7:0]  pc3086_debug_biu_write_code;
    wire [15:0] pc3086_debug_biu_write_request_data;
    wire [15:0] pc3086_debug_biu_write_t1_data;
    wire [12:0] pc3086_debug_biu_write_eu_uaddr;
    wire [15:0] pc3086_debug_biu_write_eu_alu;
    wire [15:0] pc3086_debug_biu_write_eu_ax;
    wire [15:0] pc3086_debug_biu_write_eu_bx;
`endif

    i8088 B1 	
	(
		.CORE_CLK(clk_100),
		.CLK(clk_cpu),

		.RESET(reset_cpu),
		.READY(processor_ready && ~pause_core),
		.NMI(1'b0),
		.INTR(interrupt_to_cpu),

		.ad_out(cpu_ad_out),
		.dout(cpu_data_bus),
		.din(data_bus),

		.lock_n(lock_n),
		.s6_3_mux(s6_3_mux),
		.s2_s0_out(processor_status),
		.SEGMENT(SEGMENT),

		.biu_done(biu_done),
		.cycle_accrate(cycle_accrate),
		.clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
		.clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
		.shift_read_timing(shift_read_timing)
`ifdef PC3086_POST_TRACE
		,.DEBUG_NMI_CAUGHT(pc3086_nmi_caught)
		,.DEBUG_CS(pc3086_debug_cs)
		,.DEBUG_PFQ_ADDR(pc3086_debug_pfq_addr)
		,.DEBUG_EU_BIU_DATAOUT(pc3086_debug_eu_biu_dataout)
		,.DEBUG_EU_AX(pc3086_debug_eu_ax)
		,.DEBUG_EU_BX(pc3086_debug_eu_bx)
		,.DEBUG_EU_CX(pc3086_debug_eu_cx)
		,.DEBUG_EU_DX(pc3086_debug_eu_dx)
		,.DEBUG_EU_DATAOUT_UADDR(pc3086_debug_eu_dataout_uaddr)
		,.DEBUG_EU_DATAOUT_ALU(pc3086_debug_eu_dataout_alu)
		,.DEBUG_BIU_DATA_LATCH(pc3086_debug_biu_data_latch)
		,.DEBUG_BIU_STATE(pc3086_debug_biu_state)
		,.DEBUG_BIU_WRITE_ADDRESS(pc3086_debug_biu_write_address)
		,.DEBUG_BIU_WRITE_CODE(pc3086_debug_biu_write_code)
		,.DEBUG_BIU_WRITE_REQUEST_DATA(pc3086_debug_biu_write_request_data)
		,.DEBUG_BIU_WRITE_T1_DATA(pc3086_debug_biu_write_t1_data)
		,.DEBUG_BIU_WRITE_EU_UADDR(pc3086_debug_biu_write_eu_uaddr)
		,.DEBUG_BIU_WRITE_EU_ALU(pc3086_debug_biu_write_eu_alu)
		,.DEBUG_BIU_WRITE_EU_AX(pc3086_debug_biu_write_eu_ax)
		,.DEBUG_BIU_WRITE_EU_BX(pc3086_debug_biu_write_eu_bx)
`endif
	);

    //
    ////////////////////////////  AUDIO  ///////////////////////////////////
    //

    wire [15:0] cms_l_snd_e;
    wire [16:0] cms_l_snd = {cms_l_snd_e[15],cms_l_snd_e};
    wire [15:0] cms_r_snd_e;
    wire [16:0] cms_r_snd = {cms_r_snd_e[15],cms_r_snd_e};
	 
    wire [15:0] jtopl2_snd_e;
    wire [16:0] jtopl2_snd = {jtopl2_snd_e[15], jtopl2_snd_e};
    wire [16:0] spk_vol =  {2'b00, {3'b000,~speaker_out} << status[33:32], 11'd0};
    wire        speaker_out;

    localparam [3:0] comp_f1 = 4;
    localparam [3:0] comp_a1 = 2;
    localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
    localparam       comp_b1 = comp_x1 * comp_a1;

    localparam [3:0] comp_f2 = 8;
    localparam [3:0] comp_a2 = 4;
    localparam       comp_x2 = ((32767 * (comp_f2 - 1)) / ((comp_f2 * comp_a2) - 1)) + 1; // +1 to make sure it won't overflow
    localparam       comp_b2 = comp_x2 * comp_a2;

    function [15:0] compr;
        input [15:0] inp;
        reg [15:0] v, v1, v2;
        begin
            v  = inp[15] ? (~inp) + 1'd1 : inp;
            v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
            v2 = (v < comp_x2[15:0]) ? (v * comp_a2) : (((v - comp_x2[15:0])/comp_f2) + comp_b2[15:0]);
            v  = status[37] ? v2 : v1;
            compr = inp[15] ? ~(v-1'd1) : v;
        end
    endfunction

    reg [15:0] cmp_l;
    reg [15:0] out_l;
    always @(posedge clk_chipset)
    begin
        reg [16:0] tmp_l;

        tmp_l <= jtopl2_snd + cms_l_snd + spk_vol;

        // clamp the output
        out_l <= (^tmp_l[16:15]) ? {tmp_l[16], {15{tmp_l[15]}}} : tmp_l[15:0];

        cmp_l <= compr(out_l);
    end
	 
    reg [15:0] cmp_r;
    reg [15:0] out_r;
    always @(posedge clk_chipset)
    begin
        reg [16:0] tmp_r;

        tmp_r <= jtopl2_snd + cms_r_snd + spk_vol;

        // clamp the output
        out_r <= (^tmp_r[16:15]) ? {tmp_r[16], {15{tmp_r[15]}}} : tmp_r[15:0];

        cmp_r <= compr(out_r);
    end

    assign AUDIO_L   = pause_core ? 1'b0 : status[37:36] ? cmp_l : out_l;
    assign AUDIO_R   = pause_core ? 1'b0 : status[37:36] ? cmp_r : out_r;
    assign AUDIO_S   = 1;
    assign AUDIO_MIX = status[39:38];

    //
    ////////////////////////////  UART  ///////////////////////////////////
    //

    //assign USER_OUT = {1'b1, 1'b1, uart_dtr, 1'b1, uart_rts, uart_tx, 1'b1};

    //
    // Pin | USB Name |   |Signal
    // ----+----------+---+-------------
    // 0   | D+       | I |RX
    // 1   | D-       | O |TX
    // 2   | TX-      | O |RTS
    // 3   | GND_d    | I |CTS
    // 4   | RX+      | O |DTR
    // 5   | RX-      | I |DSR
    // 6   | TX+      | I |DCD
    //

    logic clk_uart_ff_1;
    logic clk_uart_ff_2;
    logic clk_uart_ff_3;
    logic clk_uart_en;
    logic clk_uart2_en;
    logic [2:0] clk_uart2_counter;

    always @(posedge clk_chipset)
    begin
        clk_uart_ff_1 <= clk_14_318;
        clk_uart_ff_2 <= clk_uart_ff_1;
        clk_uart_ff_3 <= clk_uart_ff_2;
        clk_uart_en   <= ~clk_uart_ff_3 & clk_uart_ff_2;
    end

    always @(posedge clk_chipset)
    begin
        if (clk_uart_en)
        begin
            if (3'd7 != clk_uart2_counter)
            begin
                clk_uart2_counter <= clk_uart2_counter +3'd1;
                clk_uart2_en <= 1'b0;
            end
            else
            begin
                clk_uart2_counter <= 3'd0;
                clk_uart2_en <= 1'b1;
            end
        end
        else
        begin
            clk_uart2_counter <= clk_uart2_counter;
            clk_uart2_en <= 1'b0;
        end
    end

    wire uart_tx, uart_rts, uart_dtr;

    assign UART_TXD = uart_tx;
    assign UART_RTS = uart_rts;
    assign UART_DTR = uart_dtr;

    wire uart_rx  = UART_RXD;
    wire uart_cts = UART_CTS;
    wire uart_dsr = UART_DSR;
    wire uart_dcd = UART_DTR;


    /// UART2

    assign USER_OUT = {1'b1, 1'b1, uart2_dtr, 1'b1, uart2_rts, uart2_tx, 1'b1};

    //
    // Pin | USB Name |   |Signal
    // ----+----------+---+-------------
    // 0   | D+       | I |RX
    // 1   | D-       | O |TX
    // 2   | TX-      | O |RTS
    // 3   | GND_d    | I |CTS
    // 4   | RX+      | O |DTR
    // 5   | RX-      | I |DSR
    // 6   | TX+      | I |DCD
    //

    wire uart2_tx, uart2_rts, uart2_dtr;

    wire uart2_rx  = USER_IN[0];
    wire uart2_cts = USER_IN[3];
    wire uart2_dsr = USER_IN[5];
    wire uart2_dcd = USER_IN[6];

    //
    ///////////////////////   MMC     ///////////////////////
    //
    logic [1:0]  use_mmc;
    logic spi_clk;
    logic spi_cs;
    logic spi_mosi;
    logic spi_miso;

    always @(posedge clk_chipset)
        if (reset)
            use_mmc <= status[22:21];
        else
            use_mmc <= use_mmc;

    assign  SD_SCK      = spi_clk;
    assign  SD_MOSI     = spi_mosi;
    assign  spi_miso    = SD_MISO;
    assign  SD_CS       = spi_cs;

    //
    ///////////////////////   VIDEO   ///////////////////////
    //

    wire HBlank;
    wire HSync;
    wire VBlank;
    wire VSync;
    wire de_o;
    wire [5:0] r, g, b;
    reg [7:0] raux_video, gaux_video, baux_video;
	 wire [7:0] VGA_R_AUX, VGA_G_AUX, VGA_B_AUX;
    wire CLK_VIDEO_PIPELINE;
    wire CE_PIXEL_CREDITS;

    wire  [7:0] VGA_R_video;
    wire  [7:0] VGA_G_video;
    wire  [7:0] VGA_B_video;
    wire        VGA_HS_video;
    wire        VGA_VS_video;
    wire        VGA_DE_video;
    wire [21:0] gamma_bus_video;
    wire        CE_PIXEL_video;
    reg         ce_pixel_28 = 1'b0;
    wire        vga_video_direct = vga_mode13_active_video;

    // The EGA dot rate is no longer a fixed 14.318 MHz: in the 16.257 MHz
    // modes consecutive dots can land on adjacent clk_28_636 edges, which in
    // this domain would be a single wide level with only one rising edge.  The
    // EGA exports a toggle instead, one flip per dot.  Exactly one
    // synchroniser stage before the XOR: both clocks come from pll_system with
    // a 2:1 ratio and no phase shift, and a second stage would push the enable
    // past the end of the short dots of the 16.257 MHz pattern.
    reg         ega_dot_toggle_d = 1'b0;
    reg         ega_dot_toggle_dd = 1'b0;

    always @(posedge clk_57_272)
    begin
        ega_dot_toggle_d  <= ega_dot_toggle;
        ega_dot_toggle_dd <= ega_dot_toggle_d;
    end

    wire        ce_pixel_dot = ega_dot_toggle_d ^ ega_dot_toggle_dd;
    wire        ce_pixel_video = (ega_scandouble_active || vga_video_direct) ? ce_pixel_28 : ce_pixel_dot;

    reg  [7:0]  VGA_R_video_src = 8'd0;
    reg  [7:0]  VGA_G_video_src = 8'd0;
    reg  [7:0]  VGA_B_video_src = 8'd0;
    reg         VGA_HS_video_src = 1'b0;
    reg         VGA_VS_video_src = 1'b0;
    reg         VGA_DE_video_src = 1'b0;
    reg         LHBL_video_src = 1'b1;
    reg         LVBL_video_src = 1'b1;
    reg         CE_PIXEL_video_src = 1'b0;
    reg  [7:0]  VGA_R_video_ps = 8'd0;
    reg  [7:0]  VGA_G_video_ps = 8'd0;
    reg  [7:0]  VGA_B_video_ps = 8'd0;
    reg         VGA_HS_video_ps = 1'b0;
    reg         VGA_VS_video_ps = 1'b0;
    reg         VGA_DE_video_ps = 1'b0;
    reg         LHBL_video_ps = 1'b1;
    reg         LVBL_video_ps = 1'b1;
    reg         CE_PIXEL_video_ps = 1'b0;
    reg         CE_PIXEL_video_ps_d = 1'b0;
    reg  [7:0]  VGA_R_video_hdmi, VGA_G_video_hdmi, VGA_B_video_hdmi;
    reg         VGA_HS_video_hdmi, VGA_VS_video_hdmi, VGA_DE_video_hdmi;
    reg         LHBL_video_hdmi, LVBL_video_hdmi;
    reg         CE_PIXEL_video_hdmi = 1'b0;

    assign CLK_VIDEO = clk_video_out_ps;
    assign CLK_VIDEO_PIPELINE = clk_57_272;

    always @(posedge clk_57_272)
        ce_pixel_28 <= ~ce_pixel_28;

    assign VGA_SL = {scale_video_ff==3, scale_video_ff==2};

    wire   scandoubler = video_scandoubler_en;

    wire color = (screen_mode_video_ff == 3'd0);

    reg        video_pause_core_buf;
    reg        video_pause_core;

    always @ (posedge clk_video_out_ps) begin
        video_pause_core_buf    <= pause_core;
        video_pause_core        <= video_pause_core_buf;
    end

    wire LHBL = (ega_scandouble_active || vga_video_direct) ? HBlank : ~de_o;
    wire LVBL = VBlank;

    wire haux_video, vaux_video, hbaux_video, vbaux_video;

    // Sync and blanking go through the converter with the colour so they come
    // out of it with the same delay.  Mode 13h only takes the undelayed pair
    // below in Full Color: once a monochrome Display option is picked it has
    // to run through the converter like every other mode, both for the tint
    // and to stay time-aligned with it, or the picture is full colour again.
    video_monochrome_converter video_mono
	(
		.clk_vid(CLK_VIDEO_PIPELINE),
		.ce_pix(ce_pixel_video),

		.R({r, 2'b00}),
		.G({g, 2'b00}),
		.B({b, 2'b00}),

		.HSync(HSync),
		.VSync(VSync),
		.HBlank(LHBL),
		.VBlank(LVBL),

		.gfx_mode(screen_mode_video_ff),

		.R_OUT(raux_video),
		.G_OUT(gaux_video),
		.B_OUT(baux_video),

		.HSync_OUT(haux_video),
		.VSync_OUT(vaux_video),
		.HBlank_OUT(hbaux_video),
		.VBlank_OUT(vbaux_video)
	);

    wire       pre2x_LHBL, pre2x_LVBL;
    wire [7:0] pre2x_r, pre2x_g, pre2x_b;
    wire [23:0] credits_rgb_out;
    wire vga_video_direct_color = vga_video_direct && color;
    wire [7:0] video_mixer_r = vga_video_direct_color ? {r, r[5:4]} : raux_video;
    wire [7:0] video_mixer_g = vga_video_direct_color ? {g, g[5:4]} : gaux_video;
    wire [7:0] video_mixer_b = vga_video_direct_color ? {b, b[5:4]} : baux_video;
    wire video_mixer_hs = vga_video_direct_color ? HSync : haux_video;
    wire video_mixer_vs = vga_video_direct_color ? VSync : vaux_video;
    wire video_mixer_hb = vga_video_direct_color ? LHBL  : hbaux_video;
    wire video_mixer_vb = vga_video_direct_color ? LVBL  : vbaux_video;
	 

	video_mixer #(.GAMMA(1)) video_mixer_main
	(
		.*,

		.CLK_VIDEO(CLK_VIDEO_PIPELINE),
		.CE_PIXEL(CE_PIXEL_video),
		.ce_pix(ce_pixel_video),

		.freeze_sync(),

		.R(video_mixer_r),
		.G(video_mixer_g),
		.B(video_mixer_b),

		.HBlank(video_mixer_hb),
		.VBlank(video_mixer_vb),
		.HSync(video_mixer_hs),
		.VSync(video_mixer_vs),

		.scandoubler(1'b0),
		.hq2x(scale_video_ff==1),
		.gamma_bus(gamma_bus_video),

		.VGA_R(VGA_R_video),
		.VGA_G(VGA_G_video),
		.VGA_B(VGA_B_video),
		.VGA_VS(VGA_VS_video),
		.VGA_HS(VGA_HS_video),
		.VGA_DE(VGA_DE_video)

	);

    always @(posedge clk_57_272)
    begin
        VGA_R_video_src <= VGA_R_video;
        VGA_G_video_src <= VGA_G_video;
        VGA_B_video_src <= VGA_B_video;
        VGA_HS_video_src <= VGA_HS_video;
        VGA_VS_video_src <= VGA_VS_video;
        VGA_DE_video_src <= VGA_DE_video;
        LHBL_video_src <= LHBL;
        LVBL_video_src <= LVBL;
        CE_PIXEL_video_src <= CE_PIXEL_video;
    end

    // Retimes the exact-frequency video output onto a phase-shifted sibling clock.
    always @(posedge clk_video_out_ps or posedge video_retime_reset_local)
    begin
        if (video_retime_reset_local)
        begin
            VGA_R_video_ps <= 8'd0;
            VGA_G_video_ps <= 8'd0;
            VGA_B_video_ps <= 8'd0;
            VGA_HS_video_ps <= 1'b0;
            VGA_VS_video_ps <= 1'b0;
            VGA_DE_video_ps <= 1'b0;
            LHBL_video_ps <= 1'b1;
            LVBL_video_ps <= 1'b1;
            CE_PIXEL_video_ps <= 1'b0;
            CE_PIXEL_video_ps_d <= 1'b0;
            VGA_R_video_hdmi <= 8'd0;
            VGA_G_video_hdmi <= 8'd0;
            VGA_B_video_hdmi <= 8'd0;
            VGA_HS_video_hdmi <= 1'b0;
            VGA_VS_video_hdmi <= 1'b0;
            VGA_DE_video_hdmi <= 1'b0;
            LHBL_video_hdmi <= 1'b1;
            LVBL_video_hdmi <= 1'b1;
            CE_PIXEL_video_hdmi <= 1'b0;
        end
        else
        begin
            CE_PIXEL_video_hdmi <= CE_PIXEL_video_ps & ~CE_PIXEL_video_ps_d;
            if (CE_PIXEL_video_ps & ~CE_PIXEL_video_ps_d)
            begin
                VGA_R_video_hdmi <= VGA_R_video_ps;
                VGA_G_video_hdmi <= VGA_G_video_ps;
                VGA_B_video_hdmi <= VGA_B_video_ps;
                VGA_HS_video_hdmi <= VGA_HS_video_ps;
                VGA_VS_video_hdmi <= VGA_VS_video_ps;
                VGA_DE_video_hdmi <= VGA_DE_video_ps;
                LHBL_video_hdmi <= LHBL_video_ps;
                LVBL_video_hdmi <= LVBL_video_ps;
            end

            CE_PIXEL_video_ps_d <= CE_PIXEL_video_ps;
            CE_PIXEL_video_ps <= CE_PIXEL_video_src;
            VGA_R_video_ps <= VGA_R_video_src;
            VGA_G_video_ps <= VGA_G_video_src;
            VGA_B_video_ps <= VGA_B_video_src;
            VGA_HS_video_ps <= VGA_HS_video_src;
            VGA_VS_video_ps <= VGA_VS_video_src;
            VGA_DE_video_ps <= VGA_DE_video_src;
            LHBL_video_ps <= LHBL_video_src;
            LVBL_video_ps <= LVBL_video_src;
        end
    end

    assign VGA_R_AUX  =  VGA_R_video_hdmi;
    assign VGA_G_AUX  =  VGA_G_video_hdmi;
    assign VGA_B_AUX  =  VGA_B_video_hdmi;
    assign gamma_bus =  gamma_bus_video;
    assign CE_PIXEL_CREDITS = CE_PIXEL_video_hdmi;
    wire credits_hb = LHBL_video_hdmi;
    wire credits_vb = LVBL_video_hdmi;
    jtframe_credits #(
        .PAGES  (4),
        .COLW   (8),
        .BLKPOL (1)
    ) u_credits(
        .rst        ( reset      ),
        .clk        ( clk_video_out_ps ),
        .pxl_cen    ( CE_PIXEL_CREDITS ),

        // input image
        .HB         ( credits_hb  ),
        .VB         ( credits_vb ),
        .rgb_in     ( { VGA_R_AUX, VGA_G_AUX, VGA_B_AUX } ),
        .rotate     ( 2'd0  ),
        .toggle     ( 1'b0  ),
        .fast_scroll( 1'b0  ),
        .border     ( 1'b0 ),

        .vram_din   ( 8'h0  ),
        .vram_dout  (       ),
        .vram_addr  ( 8'h0  ),
        .vram_we    ( 1'b0  ),
        .vram_ctrl  ( 3'b0  ),
        .enable     ( video_pause_core ),

        // output image
        .HB_out     ( pre2x_LHBL      ),
        .VB_out     ( pre2x_LVBL      ),
        .rgb_out    ( credits_rgb_out )
    );

`ifdef PC3086_POST_TRACE
    wire [23:0] pc3086_trace_rgb;
    wire        pc3086_trace_hs, pc3086_trace_vs, pc3086_trace_de;
    wire        pc3086_trace_ce;
    wire        pc3086_trace_overlay_active;
    pc3086_post_trace u_pc3086_post_trace
    (
        .clk_trace     (clk_chipset),
        .reset         (reset_cpu),
        .io_read_n     (io_read_n),
        .io_write_n    (io_write_n),
        .address_latch_enable (address_latch_enable),
        .processor_status (processor_status),
        .cpu_address   (cpu_ad_out),
        .cpu_data      (cpu_data_bus),
        .cpu_read_data (data_bus),
        .memory_read_n (memory_read_n),
        .memory_write_n(memory_write_n),
        .nmi_caught    (pc3086_nmi_caught),
        .debug_cs      (pc3086_debug_cs),
        .debug_pfq_addr(pc3086_debug_pfq_addr),
        .debug_eu_biu_data(pc3086_debug_eu_biu_dataout),
        .debug_eu_ax   (pc3086_debug_eu_ax),
        .debug_eu_bx   (pc3086_debug_eu_bx),
        .debug_eu_cx   (pc3086_debug_eu_cx),
        .debug_eu_dx   (pc3086_debug_eu_dx),
        .root_dir_sdram_data  (pc3086_root_dir_sdram_data),
        .root_dir_sdram_valid (pc3086_root_dir_sdram_valid),
        .debug_eu_dataout_uaddr(pc3086_debug_eu_dataout_uaddr),
        .debug_eu_dataout_alu(pc3086_debug_eu_dataout_alu),
        .debug_biu_data_latch(pc3086_debug_biu_data_latch),
        .debug_biu_state(pc3086_debug_biu_state),
        .debug_biu_write_address(pc3086_debug_biu_write_address),
        .debug_biu_write_code(pc3086_debug_biu_write_code),
        .debug_biu_write_request_data(pc3086_debug_biu_write_request_data),
        .debug_biu_write_t1_data(pc3086_debug_biu_write_t1_data),
        .debug_biu_write_eu_uaddr(pc3086_debug_biu_write_eu_uaddr),
        .debug_biu_write_eu_alu(pc3086_debug_biu_write_eu_alu),
        .debug_biu_write_eu_ax(pc3086_debug_biu_write_eu_ax),
        .debug_biu_write_eu_bx(pc3086_debug_biu_write_eu_bx),
        .keyboard_scancode(pc3086_keyboard_scancode),
        .keyboard_irq  (pc3086_keyboard_irq),
        .keyboard_enabled(pc3086_keyboard_enabled),
        .keyboard_port_b(port_b_out),
        .keyboard_port_a(pc3086_keyboard_port_a),
        .keyboard_ppi_data(pc3086_keyboard_ppi_data),
        .fdd_present   (pc3086_fdd_present),
        .fdd_wp        (pc3086_fdd_wp),
        .fdd_cylinders (pc3086_fdd_cylinders),
        .fdd_sectors_per_track(pc3086_fdd_sectors_per_track),
        .fdd_sector_count(pc3086_fdd_sector_count),
        .fdd_heads     (pc3086_fdd_heads),
        .fdd_irq       (pc3086_fdd_irq),
        .fdd_dma_req   (pc3086_fdd_dma_req),
        .fdd_dma_ack   (pc3086_fdd_dma_ack),
        .fdd_dma_strobe(pc3086_fdd_dma_strobe),
        .fdd_dma_tc    (pc3086_fdd_dma_tc),
        .fdd_dma_data  (pc3086_fdd_dma_data),
        // HPS FDD-provider transport: these are passive taps only.  They
        // make the debug RBF show whether the mounted image configuration and
        // F2FF sector bytes actually cross the HPS/FPGA boundary.
        .mgmt_address  (mgmt_addr),
        .mgmt_write    (mgmt_wr),
        .mgmt_read     (mgmt_rd),
        .mgmt_writedata(mgmt_dout),
        .mgmt_readdata (mgmt_din),
        .fdd_request   (mgmt_req[7:6]),
        .ram_tail_write_cpu_low(pc3086_tail_write_cpu_low),
        .ram_tail_write_cpu_high(pc3086_tail_write_cpu_high),
        .ram_tail_write_sdram_low(pc3086_tail_write_sdram_low),
        .ram_tail_write_sdram_high(pc3086_tail_write_sdram_high),
        .ram_tail_write_queue_cpu_low(pc3086_tail_write_queue_cpu_low),
        .ram_tail_write_queue_cpu_high(pc3086_tail_write_queue_cpu_high),
        .ram_tail_write_queue_sdram_low(pc3086_tail_write_queue_sdram_low),
        .ram_tail_write_queue_sdram_high(pc3086_tail_write_queue_sdram_high),
        .ram_tail_write_cpu_valid(pc3086_tail_write_cpu_valid),
        .ram_tail_write_sdram_valid(pc3086_tail_write_sdram_valid),
        .ram_tail_write_queue_cpu_valid(pc3086_tail_write_queue_cpu_valid),
        .ram_tail_write_queue_sdram_valid(pc3086_tail_write_queue_sdram_valid),
        .ram_tail_write_cpu_low_count(pc3086_tail_write_cpu_low_count),
        .ram_tail_write_cpu_high_count(pc3086_tail_write_cpu_high_count),
        .ram_tail_write_queue_cpu_low_count(pc3086_tail_write_queue_cpu_low_count),
        .ram_tail_write_queue_cpu_high_count(pc3086_tail_write_queue_cpu_high_count),
        .ram_tail_write_sdram_low_count(pc3086_tail_write_sdram_low_count),
        .ram_tail_write_sdram_high_count(pc3086_tail_write_sdram_high_count),
        .ram_tail_write_queue_sdram_low_count(pc3086_tail_write_queue_sdram_low_count),
        .ram_tail_write_queue_sdram_high_count(pc3086_tail_write_queue_sdram_high_count),
        .boot_sector_sdram_data(pc3086_boot_sector_sdram_data),
        .boot_sector_sdram_valid(pc3086_boot_sector_sdram_valid),

        .clk_video     (clk_video_out_ps),
        .rgb_out       (pc3086_trace_rgb),
        .hs_out        (pc3086_trace_hs),
        .vs_out        (pc3086_trace_vs),
        .de_out        (pc3086_trace_de),
        .ce_out        (pc3086_trace_ce),
        .overlay_active(pc3086_trace_overlay_active)
    );

    // Keep normal EGA output visible through POST and the "press any key"
    // prompt. The diagnostic raster takes ownership only after the BIOS has
    // queued that key and subsequently touches an FDC port, so its evidence
    // window starts with the actual boot attempt rather than controller setup.
    assign {VGA_R, VGA_G, VGA_B} = pc3086_trace_overlay_active ? pc3086_trace_rgb : credits_rgb_out;
    assign VGA_HS = pc3086_trace_overlay_active ? pc3086_trace_hs : VGA_HS_video_hdmi;
    assign VGA_VS = pc3086_trace_overlay_active ? pc3086_trace_vs : VGA_VS_video_hdmi;
    assign VGA_DE = pc3086_trace_overlay_active ? pc3086_trace_de : VGA_DE_video_hdmi;
    assign CE_PIXEL = pc3086_trace_overlay_active ? pc3086_trace_ce : CE_PIXEL_video_hdmi;
`else
    assign {VGA_R, VGA_G, VGA_B} = credits_rgb_out;
    assign VGA_HS =  VGA_HS_video_hdmi;
    assign VGA_VS =  VGA_VS_video_hdmi;
    assign VGA_DE =  VGA_DE_video_hdmi;
    assign CE_PIXEL  =  CE_PIXEL_video_hdmi;
`endif


endmodule

`ifdef PC3086_POST_TRACE
// Temporary PC3086 POST probe.  The trace side uses the chipset clock; the
// display side only samples stable registers, so an occasional mixed frame is
// harmless and no CPU/video clock crossing can stall the machine.
module pc3086_post_trace
(
    input              clk_trace,
    input              reset,
    input              io_read_n,
    input              io_write_n,
    input              address_latch_enable,
    input      [2:0]   processor_status,
    input      [19:0]  cpu_address,
    input      [7:0]   cpu_data,
    input      [7:0]   cpu_read_data,
    input              memory_read_n,
    input              memory_write_n,
    input              nmi_caught,
    input      [15:0]  debug_cs,
    input      [15:0]  debug_pfq_addr,
    input      [15:0]  debug_eu_biu_data,
    input      [15:0]  debug_eu_ax,
    input      [15:0]  debug_eu_bx,
    input      [15:0]  debug_eu_cx,
    input      [15:0]  debug_eu_dx,
    input      [31:0]  root_dir_sdram_data,
    input      [3:0]   root_dir_sdram_valid,
    input      [12:0]  debug_eu_dataout_uaddr,
    input      [15:0]  debug_eu_dataout_alu,
    input      [15:0]  debug_biu_data_latch,
    input      [7:0]   debug_biu_state,
    input      [19:0]  debug_biu_write_address,
    input      [7:0]   debug_biu_write_code,
    input      [15:0]  debug_biu_write_request_data,
    input      [15:0]  debug_biu_write_t1_data,
    input      [12:0]  debug_biu_write_eu_uaddr,
    input      [15:0]  debug_biu_write_eu_alu,
    input      [15:0]  debug_biu_write_eu_ax,
    input      [15:0]  debug_biu_write_eu_bx,
    input      [7:0]   keyboard_scancode,
    input              keyboard_irq,
    input              keyboard_enabled,
    input      [7:0]   keyboard_port_b,
    input      [7:0]   keyboard_port_a,
    input      [7:0]   keyboard_ppi_data,
    input      [1:0]   fdd_present,
    input              fdd_wp,
    input      [7:0]   fdd_cylinders,
    input      [7:0]   fdd_sectors_per_track,
    input      [15:0]  fdd_sector_count,
    input      [1:0]   fdd_heads,
    input              fdd_irq,
    input              fdd_dma_req,
    input              fdd_dma_ack,
    input              fdd_dma_strobe,
    input              fdd_dma_tc,
    input      [7:0]   fdd_dma_data,
    input      [15:0]  mgmt_address,
    input              mgmt_write,
    input              mgmt_read,
    input      [15:0]  mgmt_writedata,
    input      [15:0]  mgmt_readdata,
    input      [1:0]   fdd_request,
    input      [7:0]   ram_tail_write_cpu_low,
    input      [7:0]   ram_tail_write_cpu_high,
    input      [7:0]   ram_tail_write_sdram_low,
    input      [7:0]   ram_tail_write_sdram_high,
    input      [7:0]   ram_tail_write_queue_cpu_low,
    input      [7:0]   ram_tail_write_queue_cpu_high,
    input      [7:0]   ram_tail_write_queue_sdram_low,
    input      [7:0]   ram_tail_write_queue_sdram_high,
    input      [1:0]   ram_tail_write_cpu_valid,
    input      [1:0]   ram_tail_write_sdram_valid,
    input      [1:0]   ram_tail_write_queue_cpu_valid,
    input      [1:0]   ram_tail_write_queue_sdram_valid,
    input      [3:0]   ram_tail_write_cpu_low_count,
    input      [3:0]   ram_tail_write_cpu_high_count,
    input      [3:0]   ram_tail_write_queue_cpu_low_count,
    input      [3:0]   ram_tail_write_queue_cpu_high_count,
    input      [3:0]   ram_tail_write_sdram_low_count,
    input      [3:0]   ram_tail_write_sdram_high_count,
    input      [3:0]   ram_tail_write_queue_sdram_low_count,
    input      [3:0]   ram_tail_write_queue_sdram_high_count,
    input      [31:0]  boot_sector_sdram_data,
    input      [3:0]   boot_sector_sdram_valid,

    input              clk_video,
    output reg [23:0]  rgb_out,
    output reg         hs_out,
    output reg         vs_out,
    output reg         de_out,
    output reg         ce_out,
    output reg         overlay_active
);
    reg        pending_io;
    reg        pending_write;
    reg        pending_seen;
    reg [15:0] pending_port;
    reg [15:0] event_port [0:3];
    reg [7:0]  event_data [0:3];
    reg        event_write [0:3];
    reg [15:0] loop_port;
    reg        loop_write;
    reg [7:0]  loop_count;
    reg [19:0] code_address [0:12];
    reg [7:0]  code_data [0:12];
    // PFQ_ADDR_OUT advances only as the execution unit consumes bytes.  Keep
    // a separate history from bus fetches so a tight branch can be identified
    // without mistaking speculative prefetch for executed code.
    reg [19:0] exec_address [0:12];
    reg [15:0] exec_last_cs;
    reg [15:0] exec_last_pfq_addr;
    reg [23:0] exec_hold_count;
    // Post-INT13 handoff probe.  These fields are armed only after a READ
    // DATA result has completed, then retain whether the EU consumed bytes
    // from the conventional boot-sector entry window at 0000:7C00.
    reg        boot_exec_seen;
    reg [19:0] boot_exec_first;
    reg [19:0] boot_exec_last;
    reg [7:0]  boot_exec_count;
    // At 0000:7CCD the DOS boot loader has finished calculating the first
    // root-directory LBA and is about to call its INT 13h read helper.
    // For this 720 KiB image AX must be 0007 (root begins at LBA 7).
    reg [15:0] boot_root_lba;
    reg        boot_root_lba_valid;
    reg [15:0] boot_root_chs_cx;
    reg [15:0] boot_root_chs_dx;
    reg [15:0] boot_root_chs_ax;
    reg        boot_root_chs_valid;
    // AX returned by the root-directory INT 13h call. AH is the BIOS status
    // (00 on success); it distinguishes a pre-FDC BIOS rejection from a
    // later media-stream failure without another instrumented build.
    reg [15:0] boot_root_int13_result;
    reg        boot_root_int13_result_valid;
    // The DOS boot sector derives the first root-directory LBA from these
    // BPB bytes. Record the bytes as the CPU actually reads them, after the
    // boot read, to separate a RAM-read defect from incorrect 8088 arithmetic.
    reg        pending_bpb_read;
    reg [2:0]  pending_bpb_read_slot;
    reg [7:0]  boot_bpb_read0, boot_bpb_read1, boot_bpb_read2, boot_bpb_read3;
    reg [3:0]  boot_bpb_read_valid;
    reg        intack_active;
    reg [7:0]  intack_count;
    reg [15:0] intack_cs;
    reg [15:0] intack_pfq_addr;
    // Most recently interrupted mainline positions, sampled at the first
    // INTA T1.  This is more useful than the IRQ0 handler address that is
    // inevitably visible when it later sends its PIC EOI.
    reg [19:0] irq_return_address [0:3];
    // Preserve the raw six 8088 stack-write bytes following INTA as well.
    // They are kept in bus order rather than decoded here: that avoids making
    // assumptions about the core's interrupt microcycle ordering.
    reg        irq_stack_capture;
    reg        pending_irq_stack_write;
    reg        pending_irq_stack_seen;
    reg [2:0]  irq_stack_count;
    reg [7:0]  irq_stack_data [0:5];
    reg        keyboard_irq_prev;
    reg        keyboard_enabled_prev;
    reg        keyboard_bat_pending;
    reg        keyboard_bat_seen;
    reg        keyboard_trace_active;
    reg        keyboard_read_seen;
    reg        keyboard_clear_high_seen;
    reg        keyboard_handshake_seen;
    reg        keyboard_tail_seen;
    reg        keyboard_queue_seen;
    // These are sourced by RAM's own acceptance/SDRAM issue points, rather
    // than reconstructing a write from an earlier ALE phase and a later data
    // phase.  They make the keyboard hand-off a trustworthy milestone.
    reg        keyboard_ram_commit_seen;
    reg        keyboard_ram_commit_ok;
    reg        keyboard_ram_capture_armed;
    reg [3:0]  keyboard_ram_cpu_low_base;
    reg [3:0]  keyboard_ram_cpu_high_base;
    reg [3:0]  keyboard_ram_queue_cpu_low_base;
    reg [3:0]  keyboard_ram_queue_cpu_high_base;
    reg [3:0]  keyboard_ram_sdram_low_base;
    reg [3:0]  keyboard_ram_sdram_high_base;
    reg [3:0]  keyboard_ram_queue_sdram_low_base;
    reg [3:0]  keyboard_ram_queue_sdram_high_base;
    reg [6:0]  rtc_index;
    reg        rtc_index_valid;
    reg [7:0]  rtc_checksum_seen;
    reg [7:0]  rtc_checksum_last_data;
    reg [7:0]  stop_keyboard_scancode;
    reg [7:0]  stop_keyboard_port_b;
    reg [7:0]  stop_keyboard_port_a;
    reg [7:0]  stop_keyboard_ppi_data;
    reg [7:0]  stop_keyboard_read_first;
    reg [7:0]  stop_keyboard_read_data;
    reg [7:0]  stop_keyboard_clear_data;
    reg [7:0]  stop_keyboard_tail;
    reg [7:0]  keyboard_tail_write_low;
    reg [7:0]  keyboard_tail_write_high;
    reg [15:0] keyboard_tail_eu_data;
    reg [15:0] keyboard_tail_eu_ax;
    reg [15:0] keyboard_tail_eu_bx;
    reg [12:0] keyboard_tail_eu_dataout_uaddr;
    reg [15:0] keyboard_tail_eu_dataout_alu;
    reg [15:0] keyboard_tail_biu_data_latch;
    reg [7:0]  keyboard_tail_biu_state;
    reg [19:0] keyboard_tail_launch_address;
    reg [7:0]  keyboard_tail_launch_code;
    reg [15:0] keyboard_tail_launch_request;
    reg [15:0] keyboard_tail_launch_t1;
    reg [7:0]  stop_keyboard_queue_low;
    reg [7:0]  stop_keyboard_queue_high;
    reg [7:0]  keyboard_head_low;
    reg [7:0]  keyboard_head_high;
    reg [7:0]  keyboard_tail_high;
    reg [19:0] keyboard_queue_address;
    reg        pending_keyboard_bda_read;
    reg        pending_keyboard_bda_read_seen;
    reg [19:0] pending_keyboard_bda_read_address;
    // Retain the BIOS's first keyboard-buffer initialisation stores.  These
    // eight bytes should be 1E:00, 1E:00, 1E:00 and 3E:00 respectively; a
    // discrepancy here pinpoints a word-store/data-bus problem before any
    // later keyboard event can obscure it.
    reg        pending_bda_init_write;
    reg        pending_bda_init_seen;
    reg [2:0]  pending_bda_init_index;
    reg [7:0]  bda_init_data [0:7];
    reg [7:0]  bda_init_valid;
    reg        pending_keyboard_write;
    reg        pending_keyboard_write_seen;
    reg [19:0] pending_keyboard_write_address;
    reg        pending_code;
    reg        code_seen;
    reg [19:0] pending_code_address;
    reg        fatal_freeze;
    localparam [2:0] STOP_NONE = 3'd0, STOP_DATA = 3'd1, STOP_VEC = 3'd2,
                     STOP_PASS = 3'd3, STOP_HOLD = 3'd4, STOP_IRQ0 = 3'd5,
                     STOP_KBD = 3'd6, STOP_KBUF = 3'd7;
    reg [2:0]  stop_reason;
    reg [19:0] stop_address;
    reg [15:0] stop_cs;
    reg [15:0] stop_pfq_addr;
    reg        nmi_seen;
    reg        pending_iv10;
    reg        pending_iv10_seen;
    reg [1:0]  pending_iv10_byte;
    reg [7:0]  iv10_data [0:3];
    reg [3:0]  iv10_valid;
    // FDC boot capture.  The trace observes host I/O plus the controller's
    // DMA/IRQ boundary.  Nothing here feeds back into the floppy subsystem.
    reg        fdc_active;
    reg        fdc_read_active;
    reg        fdc_irq_prev;
    reg        fdc_req_prev;
    reg        fdc_tc_prev;
    reg [3:0]  fdc_command_count;
    reg [3:0]  fdc_result_count;
    reg        fdc_result_live;
    reg [2:0]  fdc_result_slot;
    // Keep only the READ DATA fields and result bytes which locate a floppy
    // boot failure.  Fixed registers deliberately avoid variable-indexed
    // arrays and their wide mux/routing cost in the debug revision.
    reg [7:0]  fdc_cmd_opcode, fdc_cmd_drive_head, fdc_cmd_cyl;
    reg [7:0]  fdc_cmd_head, fdc_cmd_sector, fdc_cmd_size, fdc_cmd_eot;
    reg [7:0]  fdc_res_st0, fdc_res_st1, fdc_res_st2, fdc_res_cyl;
    reg [7:0]  fdc_res_head, fdc_res_sector, fdc_res_size;
    reg [2:0]  fdc_first_count;
    reg [7:0]  fdc_first0, fdc_first1, fdc_first2, fdc_first3;
    // The final two transfer bytes should be 55 AA for a boot sector.
    reg [7:0]  fdc_dma_tail0;
    reg [7:0]  fdc_dma_tail1;
    // Completed READ DATA records, newest first.  These survive the next
    // command so the boot-sector result is visible after the BIOS reports an
    // error rather than only while the transfer is active.
    reg [3:0]  fdc_read_history_valid;
    reg [3:0]  fdc_read_history_count;
    reg [7:0]  fdc_read0_cyl,    fdc_read0_head,    fdc_read0_sector;
    reg [15:0] fdc_read0_bytes;
    reg [7:0]  fdc_read0_st0,    fdc_read0_st1,     fdc_read0_st2;
    reg [7:0]  fdc_read0_tail0,  fdc_read0_tail1;
    reg [7:0]  fdc_read1_cyl,    fdc_read1_head,    fdc_read1_sector;
    reg [15:0] fdc_read1_bytes;
    reg [7:0]  fdc_read1_st0,    fdc_read1_st1,     fdc_read1_st2;
    reg [7:0]  fdc_read1_tail0,  fdc_read1_tail1;
    reg [7:0]  fdc_read2_cyl,    fdc_read2_head,    fdc_read2_sector;
    reg [15:0] fdc_read2_bytes;
    reg [7:0]  fdc_read2_st0,    fdc_read2_st1,     fdc_read2_st2;
    reg [7:0]  fdc_read2_tail0,  fdc_read2_tail1;
    reg [7:0]  fdc_read3_cyl,    fdc_read3_head,    fdc_read3_sector;
    reg [15:0] fdc_read3_bytes;
    reg [7:0]  fdc_read3_st0,    fdc_read3_st1,     fdc_read3_st2;
    reg [7:0]  fdc_read3_tail0,  fdc_read3_tail1;
    reg [15:0] fdc_command_cs;
    reg [15:0] fdc_command_pfq_addr;
    reg [7:0]  fdc_dor;
    reg [7:0]  fdc_msr;
    // Controller-side boot snapshot.  CCR/DSR and DIR are independent of
    // READ DATA and make a missing command distinguishable from a rate or
    // media-change setup failure.  ST3 is retained when the BIOS issues
    // SENSE DRIVE STATUS (04h).
    reg [7:0]  fdc_ccr;
    reg [7:0]  fdc_dir;
    reg        fdc_st3_pending;
    reg        fdc_st3_read_live;
    reg [7:0]  fdc_st3;
    // Once all eight READ DATA parameters are present, latch a compact,
    // derived explanation of a controller-side rejection.  This is only a
    // passive diagnosis of the exact gates used by floppy.v; it cannot alter
    // FDC behaviour.  Bits: 0 motor, 1 media, 2 N, 3 cylinder, 4 head,
    // 5 sector/EOT, 6 drive 1 (geometry display is drive A), 7 reserved.
    reg        fdc_read_packet_complete;
    reg [7:0]  fdc_read_reject;
    // Last complete 765 command opcodes before the READ DATA command. These
    // distinguish controller setup from a BIOS that never enters boot read.
    reg [3:0]  fdc_command_params_remaining;
    // The boot-attempt history is deliberately longer than the first FDC
    // probe: a normal BIOS may issue SPECIFY, RECALIBRATE, SENSE and SEEK
    // before READ DATA.  Keeping eight fixed registers remains cheap.
    reg [7:0]  fdc_hist0, fdc_hist1, fdc_hist2, fdc_hist3;
    reg [7:0]  fdc_hist4, fdc_hist5, fdc_hist6, fdc_hist7;
    // Arm only once the BIOS has actually queued the key pressed at its boot
    // prompt.  The first subsequent FDC port access is the start of the
    // boot attempt, even when it is merely an MSR poll rather than READ DATA.
    reg        fdc_postkey_armed;
    reg        fdc_postkey_active;
    reg [15:0] fdc_postkey_last_port;
    reg        fdc_postkey_last_write;
    reg [7:0]  fdc_postkey_last_data;
    reg [7:0]  fdc_postkey_access_count;
    // A fixed, first-in transcript of the data-register conversation after
    // the boot-prompt key.  It retains both command bytes and the returned
    // SENSE/result bytes, then freezes after sixteen entries so one photo is
    // sufficient to reconstruct the controller handshake.
    reg [7:0]  fdc_tx0, fdc_tx1, fdc_tx2, fdc_tx3;
    reg [7:0]  fdc_tx4, fdc_tx5, fdc_tx6, fdc_tx7;
    reg [7:0]  fdc_tx8, fdc_tx9, fdc_tx10, fdc_tx11;
    reg [7:0]  fdc_tx12, fdc_tx13, fdc_tx14, fdc_tx15;
    reg [15:0] fdc_tx_write;
    reg [4:0]  fdc_tx_count;
    reg        fdc_tx_read_live;
    reg [3:0]  fdc_tx_read_slot;
    reg [15:0] fdc_irq_count;
    reg [15:0] fdc_req_count;
    reg [15:0] fdc_dma_count;
    reg [7:0]  fdc_tc_count;
    // Persistent mount configuration evidence plus an attempt-local view of
    // F2FF sector transfers.  Edge detection avoids counting a bus level for
    // more than one chipset cycle.
    reg        mgmt_write_prev, mgmt_read_prev;
    reg [1:0]  fdd_request_prev;
    reg [7:0]  fdd_cfg_write_count, fdd_cfg_seen, fdd_cfg0;
    reg [15:0] fdd_host_write_count, fdd_host_read_count;
    reg [7:0]  fdd_host_last_write, fdd_host_last_read;
    reg [15:0] fdd_request_change_count;
    integer trace_i;

    function [3:0] fdc_parameter_count;
        input [7:0] opcode;
        begin
            case (opcode[4:0])
                5'h03: fdc_parameter_count = 4'd2; // SPECIFY
                5'h04, 5'h07, 5'h0A: fdc_parameter_count = 4'd1; // SENSE/RECAL/READ ID
                5'h05, 5'h06: fdc_parameter_count = 4'd8; // WRITE/READ DATA
                5'h0D: fdc_parameter_count = 4'd5; // FORMAT TRACK
                5'h0F: fdc_parameter_count = 4'd2; // SEEK
                default: fdc_parameter_count = 4'd0;
            endcase
        end
    endfunction

    always @(posedge clk_trace) begin
        if (reset) begin
            pending_io <= 1'b0;
            pending_write <= 1'b0;
            pending_seen <= 1'b0;
            pending_port <= 0;
            event_port[0] <= 0; event_port[1] <= 0; event_port[2] <= 0; event_port[3] <= 0;
            event_data[0] <= 0; event_data[1] <= 0; event_data[2] <= 0; event_data[3] <= 0;
            event_write[0] <= 0; event_write[1] <= 0; event_write[2] <= 0; event_write[3] <= 0;
            loop_port <= 0;
            loop_write <= 0;
            loop_count <= 0;
            for (trace_i = 0; trace_i < 13; trace_i = trace_i + 1) begin
                code_address[trace_i] <= 0;
                code_data[trace_i] <= 0;
                exec_address[trace_i] <= 0;
            end
            exec_last_cs <= 0;
            exec_last_pfq_addr <= 0;
            exec_hold_count <= 0;
            boot_exec_seen <= 1'b0;
            boot_exec_first <= 20'h00000;
            boot_exec_last <= 20'h00000;
            boot_exec_count <= 8'h00;
            boot_root_lba <= 16'h0000;
            boot_root_lba_valid <= 1'b0;
            boot_root_chs_cx <= 16'h0000;
            boot_root_chs_dx <= 16'h0000;
            boot_root_chs_ax <= 16'h0000;
            boot_root_chs_valid <= 1'b0;
            boot_root_int13_result <= 16'h0000;
            boot_root_int13_result_valid <= 1'b0;
            pending_bpb_read <= 1'b0;
            pending_bpb_read_slot <= 3'd0;
            boot_bpb_read0 <= 8'h00; boot_bpb_read1 <= 8'h00;
            boot_bpb_read2 <= 8'h00; boot_bpb_read3 <= 8'h00;
            boot_bpb_read_valid <= 4'b0000;
            intack_active <= 1'b0;
            intack_count <= 0;
            intack_cs <= 0;
            intack_pfq_addr <= 0;
            irq_return_address[0] <= 0; irq_return_address[1] <= 0;
            irq_return_address[2] <= 0; irq_return_address[3] <= 0;
            irq_stack_capture <= 1'b0;
            pending_irq_stack_write <= 1'b0;
            pending_irq_stack_seen <= 1'b0;
            irq_stack_count <= 0;
            irq_stack_data[0] <= 0; irq_stack_data[1] <= 0;
            irq_stack_data[2] <= 0; irq_stack_data[3] <= 0;
            irq_stack_data[4] <= 0; irq_stack_data[5] <= 0;
            keyboard_irq_prev <= 1'b0;
            keyboard_enabled_prev <= 1'b0;
            keyboard_bat_pending <= 1'b0;
            keyboard_bat_seen <= 1'b0;
            keyboard_trace_active <= 1'b0;
            keyboard_read_seen <= 1'b0;
            keyboard_clear_high_seen <= 1'b0;
            keyboard_handshake_seen <= 1'b0;
            keyboard_tail_seen <= 1'b0;
            keyboard_queue_seen <= 1'b0;
            keyboard_ram_commit_seen <= 1'b0;
            keyboard_ram_commit_ok <= 1'b0;
            keyboard_ram_capture_armed <= 1'b0;
            keyboard_ram_cpu_low_base <= 4'h0;
            keyboard_ram_cpu_high_base <= 4'h0;
            keyboard_ram_queue_cpu_low_base <= 4'h0;
            keyboard_ram_queue_cpu_high_base <= 4'h0;
            keyboard_ram_sdram_low_base <= 4'h0;
            keyboard_ram_sdram_high_base <= 4'h0;
            keyboard_ram_queue_sdram_low_base <= 4'h0;
            keyboard_ram_queue_sdram_high_base <= 4'h0;
            rtc_index <= 7'h00;
            rtc_index_valid <= 1'b0;
            rtc_checksum_seen <= 8'h00;
            rtc_checksum_last_data <= 8'h00;
            stop_keyboard_scancode <= 0;
            stop_keyboard_port_b <= 0;
            stop_keyboard_port_a <= 0;
            stop_keyboard_ppi_data <= 0;
            stop_keyboard_read_first <= 0;
            stop_keyboard_read_data <= 0;
            stop_keyboard_clear_data <= 0;
            stop_keyboard_tail <= 0;
            keyboard_tail_write_low <= 0;
            keyboard_tail_write_high <= 0;
            keyboard_tail_eu_data <= 0;
            keyboard_tail_eu_ax <= 0;
            keyboard_tail_eu_bx <= 0;
            keyboard_tail_eu_dataout_uaddr <= 0;
            keyboard_tail_eu_dataout_alu <= 0;
            keyboard_tail_biu_data_latch <= 0;
            keyboard_tail_biu_state <= 0;
            keyboard_tail_launch_address <= 0; keyboard_tail_launch_code <= 0;
            keyboard_tail_launch_request <= 0; keyboard_tail_launch_t1 <= 0;
            stop_keyboard_queue_low <= 0;
            stop_keyboard_queue_high <= 0;
            keyboard_head_low <= 0;
            keyboard_head_high <= 0;
            keyboard_tail_high <= 0;
            keyboard_queue_address <= 0;
            pending_keyboard_bda_read <= 1'b0;
            pending_keyboard_bda_read_seen <= 1'b0;
            pending_keyboard_bda_read_address <= 0;
            pending_bda_init_write <= 1'b0;
            pending_bda_init_seen <= 1'b0;
            pending_bda_init_index <= 0;
            bda_init_data[0] <= 0; bda_init_data[1] <= 0;
            bda_init_data[2] <= 0; bda_init_data[3] <= 0;
            bda_init_data[4] <= 0; bda_init_data[5] <= 0;
            bda_init_data[6] <= 0; bda_init_data[7] <= 0;
            bda_init_valid <= 0;
            pending_keyboard_write <= 1'b0;
            pending_keyboard_write_seen <= 1'b0;
            pending_keyboard_write_address <= 0;
            pending_code <= 0;
            code_seen <= 0;
            pending_code_address <= 0;
            fatal_freeze <= 1'b0;
            stop_reason <= STOP_NONE;
            stop_address <= 0;
            stop_cs <= 0;
            stop_pfq_addr <= 0;
            nmi_seen <= 1'b0;
            pending_iv10 <= 0;
            pending_iv10_seen <= 0;
            pending_iv10_byte <= 0;
            iv10_data[0] <= 0; iv10_data[1] <= 0; iv10_data[2] <= 0; iv10_data[3] <= 0;
            iv10_valid <= 0;
            fdc_active <= 1'b0;
            fdc_read_active <= 1'b0;
            fdc_irq_prev <= 1'b0;
            fdc_req_prev <= 1'b0;
            fdc_tc_prev <= 1'b0;
            fdc_command_count <= 0;
            fdc_result_count <= 0;
            fdc_result_live <= 1'b0;
            fdc_result_slot <= 0;
            fdc_cmd_opcode <= 0; fdc_cmd_drive_head <= 0; fdc_cmd_cyl <= 0;
            fdc_cmd_head <= 0; fdc_cmd_sector <= 0; fdc_cmd_size <= 0; fdc_cmd_eot <= 0;
            fdc_res_st0 <= 0; fdc_res_st1 <= 0; fdc_res_st2 <= 0; fdc_res_cyl <= 0;
            fdc_res_head <= 0; fdc_res_sector <= 0; fdc_res_size <= 0;
            fdc_first_count <= 0;
            fdc_first0 <= 0; fdc_first1 <= 0; fdc_first2 <= 0; fdc_first3 <= 0;
            fdc_dor <= 0;
            fdc_msr <= 0;
            fdc_ccr <= 0;
            fdc_dir <= 0;
            fdc_st3_pending <= 1'b0;
            fdc_st3_read_live <= 1'b0;
            fdc_st3 <= 0;
            fdc_read_packet_complete <= 1'b0;
            fdc_read_reject <= 0;
            fdc_command_params_remaining <= 0;
            fdc_hist0 <= 0; fdc_hist1 <= 0; fdc_hist2 <= 0; fdc_hist3 <= 0;
            fdc_hist4 <= 0; fdc_hist5 <= 0; fdc_hist6 <= 0; fdc_hist7 <= 0;
            fdc_postkey_armed <= 1'b0;
            fdc_postkey_active <= 1'b0;
            fdc_postkey_last_port <= 0;
            fdc_postkey_last_write <= 1'b0;
            fdc_postkey_last_data <= 0;
            fdc_postkey_access_count <= 0;
            fdc_tx0 <= 0; fdc_tx1 <= 0; fdc_tx2 <= 0; fdc_tx3 <= 0;
            fdc_tx4 <= 0; fdc_tx5 <= 0; fdc_tx6 <= 0; fdc_tx7 <= 0;
            fdc_tx8 <= 0; fdc_tx9 <= 0; fdc_tx10 <= 0; fdc_tx11 <= 0;
            fdc_tx12 <= 0; fdc_tx13 <= 0; fdc_tx14 <= 0; fdc_tx15 <= 0;
            fdc_tx_write <= 0;
            fdc_tx_count <= 0;
            fdc_tx_read_live <= 1'b0;
            fdc_tx_read_slot <= 0;
            fdc_dma_tail0 <= 0;
            fdc_dma_tail1 <= 0;
            fdc_read_history_valid <= 0;
            fdc_read_history_count <= 0;
            fdc_read0_cyl <= 0; fdc_read0_head <= 0; fdc_read0_sector <= 0; fdc_read0_bytes <= 0;
            fdc_read0_st0 <= 0; fdc_read0_st1 <= 0; fdc_read0_st2 <= 0; fdc_read0_tail0 <= 0; fdc_read0_tail1 <= 0;
            fdc_read1_cyl <= 0; fdc_read1_head <= 0; fdc_read1_sector <= 0; fdc_read1_bytes <= 0;
            fdc_read1_st0 <= 0; fdc_read1_st1 <= 0; fdc_read1_st2 <= 0; fdc_read1_tail0 <= 0; fdc_read1_tail1 <= 0;
            fdc_read2_cyl <= 0; fdc_read2_head <= 0; fdc_read2_sector <= 0; fdc_read2_bytes <= 0;
            fdc_read2_st0 <= 0; fdc_read2_st1 <= 0; fdc_read2_st2 <= 0; fdc_read2_tail0 <= 0; fdc_read2_tail1 <= 0;
            fdc_read3_cyl <= 0; fdc_read3_head <= 0; fdc_read3_sector <= 0; fdc_read3_bytes <= 0;
            fdc_read3_st0 <= 0; fdc_read3_st1 <= 0; fdc_read3_st2 <= 0; fdc_read3_tail0 <= 0; fdc_read3_tail1 <= 0;
            fdc_command_cs <= 0;
            fdc_command_pfq_addr <= 0;
            fdc_irq_count <= 0;
            fdc_req_count <= 0;
            fdc_dma_count <= 0;
            fdc_tc_count <= 0;
            mgmt_write_prev <= 1'b0;
            mgmt_read_prev <= 1'b0;
            fdd_request_prev <= 2'b00;
            fdd_cfg_write_count <= 0;
            fdd_cfg_seen <= 0;
            fdd_cfg0 <= 0;
            fdd_host_write_count <= 0;
            fdd_host_read_count <= 0;
            fdd_host_last_write <= 0;
            fdd_host_last_read <= 0;
            fdd_request_change_count <= 0;
        end else begin
            // Start a clean, post-key evidence window.  keyboard_queue_seen
            // is set only after IRQ1 has accepted and committed the user's
            // boot-prompt key, so controller initialisation cannot pollute
            // either the history or the counters below.
            if (keyboard_queue_seen && !fdc_postkey_armed) begin
                fdc_postkey_armed <= 1'b1;
                fdc_postkey_active <= 1'b0;
                fdc_active <= 1'b0;
                fdc_read_active <= 1'b0;
                fdc_command_params_remaining <= 0;
                fdc_hist0 <= 0; fdc_hist1 <= 0; fdc_hist2 <= 0; fdc_hist3 <= 0;
                fdc_hist4 <= 0; fdc_hist5 <= 0; fdc_hist6 <= 0; fdc_hist7 <= 0;
                fdc_irq_count <= 0; fdc_req_count <= 0; fdc_dma_count <= 0; fdc_tc_count <= 0;
                fdc_command_count <= 0; fdc_result_count <= 0; fdc_result_live <= 1'b0;
                fdc_first_count <= 0;
                fdc_first0 <= 0; fdc_first1 <= 0; fdc_first2 <= 0; fdc_first3 <= 0;
                fdc_dma_tail0 <= 0; fdc_dma_tail1 <= 0;
                fdc_read_history_valid <= 0;
                fdc_read_history_count <= 0;
                fdc_read0_cyl <= 0; fdc_read0_head <= 0; fdc_read0_sector <= 0; fdc_read0_bytes <= 0;
                fdc_read0_st0 <= 0; fdc_read0_st1 <= 0; fdc_read0_st2 <= 0; fdc_read0_tail0 <= 0; fdc_read0_tail1 <= 0;
                fdc_read1_cyl <= 0; fdc_read1_head <= 0; fdc_read1_sector <= 0; fdc_read1_bytes <= 0;
                fdc_read1_st0 <= 0; fdc_read1_st1 <= 0; fdc_read1_st2 <= 0; fdc_read1_tail0 <= 0; fdc_read1_tail1 <= 0;
                fdc_read2_cyl <= 0; fdc_read2_head <= 0; fdc_read2_sector <= 0; fdc_read2_bytes <= 0;
                fdc_read2_st0 <= 0; fdc_read2_st1 <= 0; fdc_read2_st2 <= 0; fdc_read2_tail0 <= 0; fdc_read2_tail1 <= 0;
                fdc_read3_cyl <= 0; fdc_read3_head <= 0; fdc_read3_sector <= 0; fdc_read3_bytes <= 0;
                fdc_read3_st0 <= 0; fdc_read3_st1 <= 0; fdc_read3_st2 <= 0; fdc_read3_tail0 <= 0; fdc_read3_tail1 <= 0;
                fdc_cmd_opcode <= 0; fdc_cmd_drive_head <= 0; fdc_cmd_cyl <= 0;
                fdc_cmd_head <= 0; fdc_cmd_sector <= 0; fdc_cmd_size <= 0; fdc_cmd_eot <= 0;
                fdc_res_st0 <= 0; fdc_res_st1 <= 0; fdc_res_st2 <= 0; fdc_res_cyl <= 0;
                fdc_res_head <= 0; fdc_res_sector <= 0; fdc_res_size <= 0;
                fdc_command_cs <= 0; fdc_command_pfq_addr <= 0;
                fdc_ccr <= 0;
                fdc_dir <= 0;
                fdc_st3_pending <= 1'b0;
                fdc_st3_read_live <= 1'b0;
                fdc_st3 <= 0;
                fdc_read_packet_complete <= 1'b0;
                fdc_read_reject <= 0;
                fdc_postkey_last_port <= 0;
                fdc_postkey_last_write <= 1'b0;
                fdc_postkey_last_data <= 0;
                fdc_postkey_access_count <= 0;
                fdc_tx0 <= 0; fdc_tx1 <= 0; fdc_tx2 <= 0; fdc_tx3 <= 0;
                fdc_tx4 <= 0; fdc_tx5 <= 0; fdc_tx6 <= 0; fdc_tx7 <= 0;
                fdc_tx8 <= 0; fdc_tx9 <= 0; fdc_tx10 <= 0; fdc_tx11 <= 0;
                fdc_tx12 <= 0; fdc_tx13 <= 0; fdc_tx14 <= 0; fdc_tx15 <= 0;
                fdc_tx_write <= 0;
                fdc_tx_count <= 0;
                fdc_tx_read_live <= 1'b0;
                fdc_tx_read_slot <= 0;
                boot_exec_seen <= 1'b0;
                boot_exec_first <= 20'h00000;
                boot_exec_last <= 20'h00000;
                boot_exec_count <= 8'h00;
                boot_root_lba <= 16'h0000;
                boot_root_lba_valid <= 1'b0;
                boot_root_chs_cx <= 16'h0000;
                boot_root_chs_dx <= 16'h0000;
                boot_root_chs_ax <= 16'h0000;
                boot_root_chs_valid <= 1'b0;
                boot_root_int13_result <= 16'h0000;
                boot_root_int13_result_valid <= 1'b0;
                pending_bpb_read <= 1'b0;
                boot_bpb_read0 <= 8'h00; boot_bpb_read1 <= 8'h00;
                boot_bpb_read2 <= 8'h00; boot_bpb_read3 <= 8'h00;
                boot_bpb_read_valid <= 4'b0000;
                fdd_host_write_count <= 0;
                fdd_host_read_count <= 0;
                fdd_host_last_write <= 0;
                fdd_host_last_read <= 0;
                fdd_request_change_count <= 0;
                fdd_request_prev <= fdd_request;
            end
            // Do not clear this evidence at the boot-prompt key: image mount
            // configuration normally happens before POST and must survive
            // until the eventual FDC attempt.
            if (mgmt_write && !mgmt_write_prev &&
                mgmt_address >= 16'hF200 && mgmt_address <= 16'hF205) begin
                if (!(&fdd_cfg_write_count))
                    fdd_cfg_write_count <= fdd_cfg_write_count + 1'b1;
                fdd_cfg_seen[mgmt_address[2:0]] <= 1'b1;
                if (mgmt_address == 16'hF200)
                    fdd_cfg0 <= mgmt_writedata[7:0];
            end
            if (fdc_postkey_armed && mgmt_write && !mgmt_write_prev &&
                mgmt_address == 16'hF2FF) begin
                if (!(&fdd_host_write_count))
                    fdd_host_write_count <= fdd_host_write_count + 1'b1;
                fdd_host_last_write <= mgmt_writedata[7:0];
            end
            if (fdc_postkey_armed && mgmt_read && !mgmt_read_prev &&
                mgmt_address == 16'hF2FF) begin
                if (!(&fdd_host_read_count))
                    fdd_host_read_count <= fdd_host_read_count + 1'b1;
                fdd_host_last_read <= mgmt_readdata[7:0];
            end
            if (fdc_postkey_armed && fdd_request != fdd_request_prev &&
                !(&fdd_request_change_count))
                fdd_request_change_count <= fdd_request_change_count + 1'b1;
            mgmt_write_prev <= mgmt_write;
            mgmt_read_prev <= mgmt_read;
            fdd_request_prev <= fdd_request;
            if (fdd_irq && !fdc_irq_prev && !(&fdc_irq_count))
                fdc_irq_count <= fdc_irq_count + 1'b1;
            if (fdd_dma_req && !fdc_req_prev && !(&fdc_req_count))
                fdc_req_count <= fdc_req_count + 1'b1;
            if (fdd_dma_strobe && fdc_read_active) begin
                if (!(&fdc_dma_count))
                    fdc_dma_count <= fdc_dma_count + 1'b1;
                if (fdc_first_count < 3'd4) begin
                    case (fdc_first_count)
                        0: fdc_first0 <= fdd_dma_data;
                        1: fdc_first1 <= fdd_dma_data;
                        2: fdc_first2 <= fdd_dma_data;
                        default: fdc_first3 <= fdd_dma_data;
                    endcase
                    fdc_first_count <= fdc_first_count + 1'b1;
                end
                fdc_dma_tail0 <= fdc_dma_tail1;
                fdc_dma_tail1 <= fdd_dma_data;
            end
            if (fdd_dma_tc && !fdc_tc_prev && !(&fdc_tc_count))
                fdc_tc_count <= fdc_tc_count + 1'b1;
            fdc_irq_prev <= fdd_irq;
            fdc_req_prev <= fdd_dma_req;
            fdc_tc_prev <= fdd_dma_tc;
            // PFQ_ADDR_OUT advances only as the EU consumes an instruction
            // byte.  Start sampling after the BIOS has received the FDC
            // result, so ROM setup cannot be confused with boot execution.
            if (fdc_read_history_valid[0] &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) >= 20'h07C00 &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) <= 20'h07DFF) begin
                if (!boot_exec_seen) begin
                    boot_exec_seen <= 1'b1;
                    boot_exec_first <= {debug_cs, 4'b0000} + debug_pfq_addr;
                end
                boot_exec_last <= {debug_cs, 4'b0000} + debug_pfq_addr;
                if (!(&boot_exec_count))
                    boot_exec_count <= boot_exec_count + 1'b1;
            end
            // 7CCD is the CALL after `mov dx,[7C52]` / `mov ax,[7C50]`.
            // Capture AX before CALL changes the execution context.  A small
            // window accommodates the PFQ's instruction-boundary timing.
            if (fdc_read_history_valid[0] && !boot_root_lba_valid &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) >= 20'h07CCD &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) <= 20'h07CD0) begin
                boot_root_lba <= debug_eu_ax;
                boot_root_lba_valid <= 1'b1;
            end
            // The sector helper executes INT 13h at 7D9B after loading the
            // complete CHS request into CX and DX. LBA 7 must be CX=0008,
            // DX=0000 (cylinder 0, sector 8, head 0, drive A:).
            if (fdc_read_history_valid[0] && !boot_root_chs_valid &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) >= 20'h07D9B &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) <= 20'h07D9D) begin
                boot_root_chs_cx <= debug_eu_cx;
                boot_root_chs_dx <= debug_eu_dx;
                boot_root_chs_ax <= debug_eu_ax;
                boot_root_chs_valid <= 1'b1;
            end
            // The INT 13h at 7D9B returns through the helper to its caller at
            // 7CD5. AX there retains the BIOS result (AH=status, AL=sectors
            // transferred on success). PFQ reaches 7D9D before INT executes,
            // so it is not a completion observation point.
            if (fdc_read_history_valid[0] && !boot_root_int13_result_valid &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) >= 20'h07CD5 &&
                ({debug_cs, 4'b0000} + debug_pfq_addr) <= 20'h07CD6) begin
                boot_root_int13_result <= debug_eu_ax;
                boot_root_int13_result_valid <= 1'b1;
            end
            // Capture a history only when the execution-side queue pointer
            // changes.  A long unchanged value is a useful, unambiguous
            // indication of a CPU hold/stall; normal delay loops still move
            // through their instruction stream and do not trigger it.
            if (!fatal_freeze &&
                !(debug_cs == 16'hFC00 && debug_pfq_addr >= 16'h19FC &&
                  debug_pfq_addr <= 16'h1A00)) begin
                if (debug_cs != exec_last_cs ||
                    debug_pfq_addr != exec_last_pfq_addr) begin
                    for (trace_i = 12; trace_i > 0; trace_i = trace_i - 1)
                        exec_address[trace_i] <= exec_address[trace_i-1];
                    exec_address[0] <= {debug_cs, 4'b0000} + debug_pfq_addr;
                    exec_last_cs <= debug_cs;
                    exec_last_pfq_addr <= debug_pfq_addr;
                    exec_hold_count <= 0;
                end else if (&exec_hold_count) begin
                    pending_code <= 1'b0;
                    fatal_freeze <= 1'b1;
                    stop_reason <= STOP_HOLD;
                    stop_address <= {debug_cs, 4'b0000} + debug_pfq_addr;
                    stop_cs <= debug_cs;
                    stop_pfq_addr <= debug_pfq_addr;
                end else begin
                    exec_hold_count <= exec_hold_count + 1'b1;
                end
            end

            // Status 000 is the 8088 interrupt-acknowledge bus cycle.  Save
            // the execution-side pointer at its first T1, before the timer
            // handler's own instructions replace the useful mainline trace.
            if (address_latch_enable) begin
                if (processor_status == 3'b000) begin
                    if (!intack_active) begin
                        intack_active <= 1'b1;
                        if (!(&intack_count))
                            intack_count <= intack_count + 1'b1;
                        intack_cs <= debug_cs;
                        intack_pfq_addr <= debug_pfq_addr;
                        for (trace_i = 3; trace_i > 0; trace_i = trace_i - 1)
                            irq_return_address[trace_i] <= irq_return_address[trace_i-1];
                        irq_return_address[0] <= {debug_cs, 4'b0000} + debug_pfq_addr;
                        irq_stack_capture <= 1'b1;
                        irq_stack_count <= 0;
                    end
                end else begin
                    intack_active <= 1'b0;
                end
            end

            // Enabling the existing PS/2 implementation sends FF (reset) to
            // the keyboard.  Its normal AA self-test reply must not be
            // mistaken for a user scan code; consume that one expected reply
            // and preserve the next event for this diagnostic.
            if (!keyboard_enabled)
                keyboard_bat_pending <= 1'b0;
            else if (keyboard_enabled && !keyboard_enabled_prev)
                keyboard_bat_pending <= 1'b1;

            if (!fatal_freeze && keyboard_irq && !keyboard_irq_prev &&
                keyboard_enabled) begin
                if (keyboard_bat_pending && keyboard_scancode == 8'hAA) begin
                    keyboard_bat_pending <= 1'b0;
                    keyboard_bat_seen <= 1'b1;
                end else if (!keyboard_handshake_seen && !keyboard_queue_seen) begin
                    // Preserve the actual key, then follow the PC/XT PPI
                    // handshake (read 60h; pulse bit 7 of 61h) before
                    // freezing. This distinguishes a decoder-only event from
                    // an IRQ1/PIC or BIOS-handler failure.
                    keyboard_trace_active <= 1'b1;
                    keyboard_read_seen <= 1'b0;
                    keyboard_clear_high_seen <= 1'b0;
                    keyboard_handshake_seen <= 1'b0;
                    keyboard_tail_seen <= 1'b0;
                    stop_keyboard_scancode <= keyboard_scancode;
                    stop_keyboard_port_b <= keyboard_port_b;
                end
            end
            keyboard_irq_prev <= keyboard_irq;
            keyboard_enabled_prev <= keyboard_enabled;

            // The 8088 multiplexes address/data.  Capture the address only
            // in T1 (ALE) and qualify it by the 8288 status encoding:
            // 001 = I/O read, 010 = I/O write.  Sampling cpu_address when a
            // later command strobe changes can otherwise report a code-fetch
            // address as though it were an I/O port.
`ifdef PC3086_TRACE_EXEC_STOP
            // PFQ_ADDR_OUT advances when the EU consumes instruction bytes.
            // Unlike a bus code fetch, it cannot match bytes speculatively
            // fetched past a pending RET/JMP.
            if (!fatal_freeze && debug_cs == 16'hFC00 &&
                debug_pfq_addr >= 16'h19FC && debug_pfq_addr <= 16'h1A00) begin
                pending_code <= 1'b0;
                fatal_freeze <= 1'b1;
                stop_reason <= STOP_VEC;
                stop_address <= {debug_cs, 4'b0000} + debug_pfq_addr;
                stop_cs <= debug_cs;
                stop_pfq_addr <= debug_pfq_addr;
            end else
`endif
            if (address_latch_enable) begin
`ifdef PC3086_TRACE_STOP_PASS
                if (processor_status == 3'b100 && !fatal_freeze &&
                    cpu_address >= 20'hFC4A0 && cpu_address <= 20'hFC4A4) begin
                    // The diagnostic LPT gate override reached the normal
                    // post-gate continuation rather than the ROS checksum
                    // terminal path.
                    pending_code <= 1'b0;
                    fatal_freeze <= 1'b1;
                    stop_reason <= STOP_PASS;
                    stop_address <= cpu_address;
                    stop_cs <= debug_cs;
                    stop_pfq_addr <= debug_pfq_addr;
`else
                if (1'b0) begin
`endif
`ifndef PC3086_TRACE_ALLOW_POST_GATE_PREFETCH
                end else if (processor_status == 3'b100 && !fatal_freeze &&
                    cpu_address[19:16] == 4'hF &&
                    cpu_address[13:0] >= 14'h0196 && cpu_address[13:0] <= 14'h01BE) begin
                    // The 16 KiB PC3086 ROM aliases over F0000h-FFFFFh. This
                    // raw offset is a ROM data table, not executable code.
                    // Freeze on its first fetch to retain the transfer path.
                    pending_code <= 1'b0;
                    fatal_freeze <= 1'b1;
                    stop_reason <= STOP_DATA;
                    stop_address <= cpu_address;
                    stop_cs <= debug_cs;
                    stop_pfq_addr <= debug_pfq_addr;
`endif
`ifndef PC3086_TRACE_EXEC_STOP
                end else if (processor_status == 3'b100 && !fatal_freeze &&
                    cpu_address >= 20'hFD9FC && cpu_address <= 20'hFDA00) begin
                    // Fallback: the PC3086 vector-2 terminal handler.
                    pending_code <= 1'b0;
                    fatal_freeze <= 1'b1;
                    stop_reason <= STOP_VEC;
                    stop_address <= cpu_address;
                    stop_cs <= debug_cs;
                    stop_pfq_addr <= debug_pfq_addr;
`endif
                end else if (processor_status == 3'b100 && !fatal_freeze) begin
                    pending_code_address <= cpu_address;
                    pending_code <= 1'b1;
                    code_seen <= 1'b0;
                end else begin
                    pending_code <= 1'b0;
                end
                pending_io <= (processor_status == 3'b001) || (processor_status == 3'b010);
                pending_write <= (processor_status == 3'b010);
                pending_seen <= 1'b0;
                pending_port <= cpu_address[15:0];

                // INT 10h's vector is the four bytes at physical 00040h.
                // Sampling the actual vector-memory transaction avoids
                // inferring the target from a later code-fetch trace.
                pending_iv10 <= (processor_status == 3'b101) &&
                                (cpu_address[19:2] == 18'h00010);
                pending_iv10_seen <= 1'b0;
                pending_iv10_byte <= cpu_address[1:0];
                // BPB fields: reserved sectors, FAT count, root-entry low
                // byte, and sectors/FAT low byte. Expected from msdos5.img:
                // 01, 02, 70, 03. Exact-address qualification excludes code
                // fetches and observes the CPU's returned RAM data.
                pending_bpb_read <= fdc_read_history_valid[0] &&
                                    processor_status == 3'b101 &&
                                    (cpu_address == 20'h07C0E ||
                                     cpu_address == 20'h07C10 ||
                                     cpu_address == 20'h07C11 ||
                                     cpu_address == 20'h07C16);
                case (cpu_address)
                    20'h07C0E: pending_bpb_read_slot <= 3'd0;
                    20'h07C10: pending_bpb_read_slot <= 3'd1;
                    20'h07C11: pending_bpb_read_slot <= 3'd2;
                    default:    pending_bpb_read_slot <= 3'd3;
                endcase
                // After a real key has completed its port-60h/61h handshake,
                // follow the BIOS queue update: it writes the new tail at
                // 0041Ch, then stores the translated key at tail-2.
                pending_keyboard_write <= keyboard_handshake_seen &&
                                          processor_status == 3'b110 &&
                                          cpu_address[19:8] == 12'h004;
                pending_keyboard_write_seen <= 1'b0;
                pending_keyboard_write_address <= cpu_address;
                pending_keyboard_bda_read <= keyboard_handshake_seen &&
                                             processor_status == 3'b101 &&
                                             cpu_address >= 20'h0041A &&
                                             cpu_address <= 20'h0041D;
                pending_keyboard_bda_read_seen <= 1'b0;
                pending_keyboard_bda_read_address <= cpu_address;
                pending_bda_init_write <= 1'b0;
                pending_bda_init_seen <= 1'b0;
                case (cpu_address)
                    20'h0041A: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd0; end
                    20'h0041B: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd1; end
                    20'h0041C: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd2; end
                    20'h0041D: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd3; end
                    20'h00480: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd4; end
                    20'h00481: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd5; end
                    20'h00482: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd6; end
                    20'h00483: begin pending_bda_init_write <= processor_status == 3'b110; pending_bda_init_index <= 3'd7; end
                    default: ;
                endcase
                pending_irq_stack_write <= irq_stack_capture &&
                                           irq_stack_count < 3'd6 &&
                                           processor_status == 3'b110;
                pending_irq_stack_seen <= 1'b0;
            end else if (pending_io && !pending_seen &&
                         ((pending_write && !io_write_n) || (!pending_write && !io_read_n))) begin
                event_port[3] <= event_port[2]; event_data[3] <= event_data[2]; event_write[3] <= event_write[2];
                event_port[2] <= event_port[1]; event_data[2] <= event_data[1]; event_write[2] <= event_write[1];
                event_port[1] <= event_port[0]; event_data[1] <= event_data[0]; event_write[1] <= event_write[0];
                event_port[0] <= pending_port;
                // Writes source the CPU data bus. I/O reads instead need the
                // chipset-returned value; the first observation can still be
                // from the preceding bus cycle, so keep updating it below
                // while /IOR remains asserted.
                event_data[0] <= pending_write ? cpu_data : cpu_read_data;
                event_write[0] <= pending_write;
                pending_seen <= 1'b1;

                // Capture every FDC host access after the boot-prompt key.
                // This must include DOR and MSR accesses: absence of a READ
                // DATA command is itself useful evidence, and the trace must
                // still become visible in that case.
                if (fdc_postkey_armed &&
                    (pending_port == 16'h03F2 || pending_port == 16'h03F4 ||
                     pending_port == 16'h03F5 || pending_port == 16'h03F7)) begin
                    fdc_postkey_active <= 1'b1;
                    fdc_postkey_last_port <= pending_port;
                    fdc_postkey_last_write <= pending_write;
                    fdc_postkey_last_data <= pending_write ? cpu_data : cpu_read_data;
                    if (!(&fdc_postkey_access_count))
                        fdc_postkey_access_count <= fdc_postkey_access_count + 1'b1;
                end

                // 765 data register traffic. A READ DATA command has opcode
                // xxx00110b followed by eight parameters. Retain its fixed
                // CHRN/EOT fields, completion status and first transfer bytes.
                if (pending_port == 16'h03F2 && pending_write)
                    fdc_dor <= cpu_data;
                // Both DSR (3F4 write) and CCR (3F7 write) select the data
                // rate. Keep the last programmed value even if the BIOS uses
                // the alternate register.
                if ((pending_port == 16'h03F4 || pending_port == 16'h03F7) && pending_write)
                    fdc_ccr <= cpu_data;
                if (pending_port == 16'h03F4 && !pending_write)
                    fdc_msr <= cpu_read_data;
                if (pending_port == 16'h03F5) begin
                    fdc_active <= 1'b1;
                    // Keep the first complete post-key data-register
                    // dialogue.  Reads are written into their reserved slot
                    // below, once the registered I/O mux has settled.
                    if (fdc_postkey_armed && fdc_tx_count < 5'd16) begin
                        if (pending_write) begin
                            case (fdc_tx_count[3:0])
                                0: fdc_tx0 <= cpu_data;   1: fdc_tx1 <= cpu_data;
                                2: fdc_tx2 <= cpu_data;   3: fdc_tx3 <= cpu_data;
                                4: fdc_tx4 <= cpu_data;   5: fdc_tx5 <= cpu_data;
                                6: fdc_tx6 <= cpu_data;   7: fdc_tx7 <= cpu_data;
                                8: fdc_tx8 <= cpu_data;   9: fdc_tx9 <= cpu_data;
                                10: fdc_tx10 <= cpu_data; 11: fdc_tx11 <= cpu_data;
                                12: fdc_tx12 <= cpu_data; 13: fdc_tx13 <= cpu_data;
                                14: fdc_tx14 <= cpu_data; default: fdc_tx15 <= cpu_data;
                            endcase
                            fdc_tx_write[fdc_tx_count[3:0]] <= 1'b1;
                        end else begin
                            fdc_tx_write[fdc_tx_count[3:0]] <= 1'b0;
                            fdc_tx_read_live <= 1'b1;
                            fdc_tx_read_slot <= fdc_tx_count[3:0];
                        end
                        fdc_tx_count <= fdc_tx_count + 1'b1;
                    end
                    if (pending_write) begin
                        // Identify command boundaries independently of the
                        // READ DATA parameter capture below. The history is
                        // observational and uses only fixed registers.
                        if (fdc_command_params_remaining == 0) begin
                            fdc_hist7 <= fdc_hist6;
                            fdc_hist6 <= fdc_hist5;
                            fdc_hist5 <= fdc_hist4;
                            fdc_hist4 <= fdc_hist3;
                            fdc_hist3 <= fdc_hist2;
                            fdc_hist2 <= fdc_hist1;
                            fdc_hist1 <= fdc_hist0;
                            fdc_hist0 <= cpu_data;
                            fdc_command_params_remaining <= fdc_parameter_count(cpu_data);
                            fdc_cmd_opcode <= cpu_data;
                            fdc_command_cs <= debug_cs;
                            fdc_command_pfq_addr <= debug_pfq_addr;
                            if (cpu_data[4:0] == 5'h04)
                                fdc_st3_pending <= 1'b1;
                        end else begin
                            fdc_command_params_remaining <= fdc_command_params_remaining - 1'b1;
                            // 04h has exactly one parameter.  The following
                            // data-register read is its ST3 result.
                            if (fdc_st3_pending && fdc_command_params_remaining == 4'd1) begin
                                fdc_st3_pending <= 1'b0;
                                fdc_st3_read_live <= 1'b1;
                            end
                        end
                        if (cpu_data[4:0] == 5'h06) begin
                            fdc_read_active <= 1'b1;
                            fdc_cmd_opcode <= cpu_data;
                            fdc_command_cs <= debug_cs;
                            fdc_command_pfq_addr <= debug_pfq_addr;
                            fdc_command_count <= 4'd1;
                            fdc_result_count <= 0;
                            fdc_result_live <= 1'b0;
                            fdc_cmd_drive_head <= 0; fdc_cmd_cyl <= 0; fdc_cmd_head <= 0;
                            fdc_cmd_sector <= 0; fdc_cmd_size <= 0; fdc_cmd_eot <= 0;
                            fdc_res_st0 <= 0; fdc_res_st1 <= 0; fdc_res_st2 <= 0; fdc_res_cyl <= 0;
                            fdc_res_head <= 0; fdc_res_sector <= 0; fdc_res_size <= 0;
                            fdc_first_count <= 0;
                            fdc_first0 <= 0; fdc_first1 <= 0; fdc_first2 <= 0; fdc_first3 <= 0;
                            fdc_dma_count <= 0;
                            fdc_tc_count <= 0;
                            fdc_dma_tail0 <= 0;
                            fdc_dma_tail1 <= 0;
                            fdc_read_packet_complete <= 1'b0;
                            fdc_read_reject <= 0;
                        end else if (fdc_read_active && fdc_command_count < 4'd9) begin
                            case (fdc_command_count)
                                1: fdc_cmd_drive_head <= cpu_data;
                                2: fdc_cmd_cyl <= cpu_data;
                                3: fdc_cmd_head <= cpu_data;
                                4: fdc_cmd_sector <= cpu_data;
                                5: fdc_cmd_size <= cpu_data;
                                6: fdc_cmd_eot <= cpu_data;
                                default: ;
                            endcase
                            // Count eight is the DTL parameter. All CHRN/EOT
                            // values captured above are settled by this point.
                            if (fdc_command_count == 4'd8) begin
                                fdc_read_packet_complete <= 1'b1;
                                fdc_read_reject[0] <= fdc_cmd_drive_head[0] ? !fdc_dor[5] : !fdc_dor[4];
                                fdc_read_reject[1] <= !fdd_present[fdc_cmd_drive_head[0]];
                                fdc_read_reject[2] <= (fdc_cmd_size != 8'h02);
                                fdc_read_reject[3] <= (fdc_cmd_cyl >= fdd_cylinders);
                                fdc_read_reject[4] <= (fdc_cmd_head != {7'b0,fdc_cmd_drive_head[2]}) ||
                                                      (fdc_cmd_head >= {6'b0,fdd_heads});
                                fdc_read_reject[5] <= (fdc_cmd_sector == 0) ||
                                                      (fdc_cmd_sector > fdd_sectors_per_track) ||
                                                      (fdc_cmd_sector > fdc_cmd_eot);
                                fdc_read_reject[6] <= fdc_cmd_drive_head[0];
                                fdc_read_reject[7] <= 1'b0;
                            end
                            fdc_command_count <= fdc_command_count + 1'b1;
                        end
                    end else if (fdc_read_active && fdc_result_count < 4'd7) begin
                        fdc_result_slot <= fdc_result_count[2:0];
                        fdc_result_live <= 1'b1;
                        fdc_result_count <= fdc_result_count + 1'b1;
                    end
                end
                if (loop_port == pending_port && loop_write == pending_write) begin
                    if (!(&loop_count)) loop_count <= loop_count + 1'b1;
                end else begin
                    loop_port <= pending_port;
                    loop_write <= pending_write;
                    loop_count <= 8'd1;
                end
                // 60h to PIC command port 20h is the PC3086 IRQ0 EOI.  Once
                // it repeats long enough to be a visible symptom, retain the
                // mainline position saved at interrupt acknowledgement.
                // Once the keyboard gate is live, leave the foreground timer
                // loop running: a keyboard IRQ must be allowed to complete so
                // the diagnostic can retain the final BIOS queue write.
                if (!fatal_freeze && !keyboard_enabled && pending_write && pending_port == 16'h0020 &&
                    cpu_data == 8'h60 && loop_port == pending_port &&
                    loop_write && loop_count >= 8'h7F) begin
                    fatal_freeze <= 1'b1;
                    stop_reason <= STOP_IRQ0;
                    stop_address <= {debug_cs, 4'b0000} + debug_pfq_addr;
                    stop_cs <= debug_cs;
                    stop_pfq_addr <= debug_pfq_addr;
                end

                if (!fatal_freeze && keyboard_trace_active) begin
                    if (!pending_write && pending_port == 16'h0060) begin
                        stop_keyboard_port_a <= keyboard_port_a;
                        stop_keyboard_ppi_data <= keyboard_ppi_data;
                        // The chipset's I/O-read mux is registered. Keep both
                        // the first observed CPU-bus value and the last value
                        // while /IOR is active: the first can still be the
                        // preceding bus cycle, whereas the latter is settled.
                        stop_keyboard_read_first <= cpu_read_data;
                        stop_keyboard_read_data <= cpu_read_data;
                        keyboard_read_seen <= 1'b1;
                    end else if (pending_write && pending_port == 16'h0061) begin
                        stop_keyboard_clear_data <= cpu_data;
                        if (cpu_data[7]) begin
                            keyboard_clear_high_seen <= 1'b1;
                        end else if (keyboard_read_seen && keyboard_clear_high_seen) begin
                            // Do not stop here: the normal BIOS IRQ1 handler
                            // has not yet translated and enqueued the key.
                            keyboard_trace_active <= 1'b0;
                            keyboard_handshake_seen <= 1'b1;
                            // The RAM probe retains BDA initialisation writes.
                            // Take a counter baseline at the completed PPI
                            // handshake, so a later commit is necessarily for
                            // this keyboard transaction rather than boot-time
                            // setup that happened before it.
                            keyboard_ram_capture_armed <= 1'b1;
                            keyboard_ram_cpu_low_base <= ram_tail_write_cpu_low_count;
                            keyboard_ram_cpu_high_base <= ram_tail_write_cpu_high_count;
                            keyboard_ram_queue_cpu_low_base <= ram_tail_write_queue_cpu_low_count;
                            keyboard_ram_queue_cpu_high_base <= ram_tail_write_queue_cpu_high_count;
                            keyboard_ram_sdram_low_base <= ram_tail_write_sdram_low_count;
                            keyboard_ram_sdram_high_base <= ram_tail_write_sdram_high_count;
                            keyboard_ram_queue_sdram_low_base <= ram_tail_write_queue_sdram_low_count;
                            keyboard_ram_queue_sdram_high_base <= ram_tail_write_queue_sdram_high_count;
                        end
                    end
                end
            end

            // The RAM mux is registered.  Keep sampling throughout /MEMR,
            // just as the I/O trace does, so the final value is the settled
            // read byte rather than the preceding multiplexed bus phase.
            if (pending_bpb_read && !memory_read_n) begin
                case (pending_bpb_read_slot)
                    0: begin boot_bpb_read0 <= cpu_read_data; boot_bpb_read_valid[0] <= 1'b1; end
                    1: begin boot_bpb_read1 <= cpu_read_data; boot_bpb_read_valid[1] <= 1'b1; end
                    2: begin boot_bpb_read2 <= cpu_read_data; boot_bpb_read_valid[2] <= 1'b1; end
                    default: begin boot_bpb_read3 <= cpu_read_data; boot_bpb_read_valid[3] <= 1'b1; end
                endcase
            end

            // Overwrite the early port-60h read with the final value observed
            // during the same /IOR assertion.
            if (keyboard_trace_active && pending_io && !pending_write &&
                pending_port == 16'h0060 && !io_read_n)
                stop_keyboard_read_data <= cpu_read_data;

            // Apply the same settle rule to the general I/O ring. This makes
            // port 71h (and every other traced input) show the value that was
            // actually available at the end of the bus read rather than a
            // potentially stale value sampled at its leading edge.
            if (pending_io && !pending_write && !io_read_n)
                event_data[0] <= cpu_read_data;

            // As with the general I/O ring, retain a settled value for the
            // final post-key FDC read rather than the value present at /IOR's
            // leading edge.
            if (fdc_postkey_active && pending_io && !pending_write && !io_read_n &&
                (pending_port == 16'h03F2 || pending_port == 16'h03F4 ||
                 pending_port == 16'h03F5 || pending_port == 16'h03F7))
                fdc_postkey_last_data <= cpu_read_data;

            if (pending_io && !pending_write && pending_port == 16'h03F7 && !io_read_n)
                fdc_dir <= cpu_read_data;

            if (fdc_st3_read_live && pending_io && !pending_write &&
                pending_port == 16'h03F5 && !io_read_n)
                fdc_st3 <= cpu_read_data;
            else if (fdc_st3_read_live && (io_read_n || !pending_io))
                fdc_st3_read_live <= 1'b0;

            // The data-bus mux settles after the leading edge of an I/O read.
            // Use a fixed case instead of an array index: this keeps the
            // passive result capture small and placement-friendly.
            if (fdc_result_live && pending_io && !pending_write &&
                pending_port == 16'h03F5 && !io_read_n) begin
                case (fdc_result_slot)
                    0: fdc_res_st0 <= cpu_read_data;
                    1: fdc_res_st1 <= cpu_read_data;
                    2: fdc_res_st2 <= cpu_read_data;
                    3: fdc_res_cyl <= cpu_read_data;
                    4: fdc_res_head <= cpu_read_data;
                    5: fdc_res_sector <= cpu_read_data;
                    default: fdc_res_size <= cpu_read_data;
                endcase
            end
    else if (fdc_result_live && (io_read_n || !pending_io)) begin
      // Preserve completed READ DATA results.  The live result registers are
      // useful while the command is in progress, but this history makes a
      // boot-sector result available after the BIOS has moved on to its error
      // message.
      if (fdc_read_active && fdc_result_slot == 3'd6) begin
        fdc_read3_cyl   <= fdc_read2_cyl;
        fdc_read3_head  <= fdc_read2_head;
        fdc_read3_sector <= fdc_read2_sector;
        fdc_read3_bytes <= fdc_read2_bytes;
        fdc_read3_st0   <= fdc_read2_st0;
        fdc_read3_st1   <= fdc_read2_st1;
        fdc_read3_st2   <= fdc_read2_st2;
        fdc_read3_tail0 <= fdc_read2_tail0;
        fdc_read3_tail1 <= fdc_read2_tail1;

        fdc_read2_cyl   <= fdc_read1_cyl;
        fdc_read2_head  <= fdc_read1_head;
        fdc_read2_sector <= fdc_read1_sector;
        fdc_read2_bytes <= fdc_read1_bytes;
        fdc_read2_st0   <= fdc_read1_st0;
        fdc_read2_st1   <= fdc_read1_st1;
        fdc_read2_st2   <= fdc_read1_st2;
        fdc_read2_tail0 <= fdc_read1_tail0;
        fdc_read2_tail1 <= fdc_read1_tail1;

        fdc_read1_cyl   <= fdc_read0_cyl;
        fdc_read1_head  <= fdc_read0_head;
        fdc_read1_sector <= fdc_read0_sector;
        fdc_read1_bytes <= fdc_read0_bytes;
        fdc_read1_st0   <= fdc_read0_st0;
        fdc_read1_st1   <= fdc_read0_st1;
        fdc_read1_st2   <= fdc_read0_st2;
        fdc_read1_tail0 <= fdc_read0_tail0;
        fdc_read1_tail1 <= fdc_read0_tail1;

        fdc_read0_cyl   <= fdc_res_cyl;
        fdc_read0_head  <= fdc_res_head;
        fdc_read0_sector <= fdc_res_sector;
        fdc_read0_bytes <= fdc_dma_count;
        fdc_read0_st0   <= fdc_res_st0;
        fdc_read0_st1   <= fdc_res_st1;
        fdc_read0_st2   <= fdc_res_st2;
        fdc_read0_tail0 <= fdc_dma_tail0;
        fdc_read0_tail1 <= fdc_dma_tail1;
        fdc_read_history_valid <= {fdc_read_history_valid[2:0], 1'b1};
        if (!(&fdc_read_history_count))
          fdc_read_history_count <= fdc_read_history_count + 1'b1;
      end
      fdc_result_live <= 1'b0;
    end

            // As above, complete the post-key transcript read only after
            // the FDC's registered data output is stable on the CPU bus.
            if (fdc_tx_read_live && pending_io && !pending_write &&
                pending_port == 16'h03F5 && !io_read_n) begin
                case (fdc_tx_read_slot)
                    0: fdc_tx0 <= cpu_read_data;   1: fdc_tx1 <= cpu_read_data;
                    2: fdc_tx2 <= cpu_read_data;   3: fdc_tx3 <= cpu_read_data;
                    4: fdc_tx4 <= cpu_read_data;   5: fdc_tx5 <= cpu_read_data;
                    6: fdc_tx6 <= cpu_read_data;   7: fdc_tx7 <= cpu_read_data;
                    8: fdc_tx8 <= cpu_read_data;   9: fdc_tx9 <= cpu_read_data;
                    10: fdc_tx10 <= cpu_read_data; 11: fdc_tx11 <= cpu_read_data;
                    12: fdc_tx12 <= cpu_read_data; 13: fdc_tx13 <= cpu_read_data;
                    14: fdc_tx14 <= cpu_read_data; default: fdc_tx15 <= cpu_read_data;
                endcase
            end
            else if (fdc_tx_read_live && (io_read_n || !pending_io))
                fdc_tx_read_live <= 1'b0;

            // PC3086 uses CMOS ports 70h/71h.  Once IRQ1 has completed, keep
            // a compact audit of reads from the BIOS checksum range 0Eh..15h.
            // It is intentionally observational: reaching this point is a
            // useful later milestone, but the temporary probe must not alter
            // the firmware's timing or prevent it from continuing to boot.
            if (keyboard_handshake_seen && pending_io && pending_write &&
                pending_port == 16'h0070 && !io_write_n) begin
                rtc_index <= cpu_data[6:0];
                rtc_index_valid <= 1'b1;
            end
            if (keyboard_handshake_seen && pending_io && !pending_write &&
                pending_port == 16'h0071 && !io_read_n && rtc_index_valid &&
                rtc_index >= 7'h0E && rtc_index <= 7'h15) begin
                rtc_checksum_seen[rtc_index - 7'h0E] <= 1'b1;
                rtc_checksum_last_data <= cpu_read_data;
            end

            // Do not infer the BDA update from muxed CPU pins.  The old
            // valid-bit test meant only "seen since reset" and therefore
            // accepted the BIOS's earlier BDA initialisation stores as soon
            // as a real key completed its PPI handshake.  Compare each RAM
            // acceptance/SDRAM issue counter with the baseline captured at
            // that handshake: every byte below is now necessarily part of
            // the current keyboard transaction.
            if (keyboard_ram_capture_armed && !keyboard_ram_commit_seen &&
                ram_tail_write_cpu_low_count != keyboard_ram_cpu_low_base &&
                ram_tail_write_cpu_high_count != keyboard_ram_cpu_high_base &&
                ram_tail_write_queue_cpu_low_count != keyboard_ram_queue_cpu_low_base &&
                ram_tail_write_queue_cpu_high_count != keyboard_ram_queue_cpu_high_base &&
                ram_tail_write_sdram_low_count != keyboard_ram_sdram_low_base &&
                ram_tail_write_sdram_high_count != keyboard_ram_sdram_high_base &&
                ram_tail_write_queue_sdram_low_count != keyboard_ram_queue_sdram_low_base &&
                ram_tail_write_queue_sdram_high_count != keyboard_ram_queue_sdram_high_base) begin
                keyboard_ram_commit_seen <= 1'b1;
                keyboard_queue_seen <= 1'b1;
                keyboard_ram_commit_ok <=
                    ram_tail_write_cpu_low == ram_tail_write_sdram_low &&
                    ram_tail_write_cpu_high == ram_tail_write_sdram_high &&
                    ram_tail_write_queue_cpu_low == ram_tail_write_queue_sdram_low &&
                    ram_tail_write_queue_cpu_high == ram_tail_write_queue_sdram_high;
                if (!fatal_freeze &&
                    !(ram_tail_write_cpu_low == ram_tail_write_sdram_low &&
                      ram_tail_write_cpu_high == ram_tail_write_sdram_high &&
                      ram_tail_write_queue_cpu_low == ram_tail_write_queue_sdram_low &&
                      ram_tail_write_queue_cpu_high == ram_tail_write_queue_sdram_high)) begin
                    fatal_freeze <= 1'b1;
                    stop_reason <= STOP_KBUF;
                    stop_address <= 20'h0041E;
                    stop_cs <= debug_cs;
                    stop_pfq_addr <= debug_pfq_addr;
                end
            end

            if (pending_keyboard_write && !memory_write_n) begin
                pending_keyboard_write_seen <= 1'b1;
                if (pending_keyboard_write_address == 20'h0041C) begin
                    keyboard_tail_write_low <= cpu_data;
                    keyboard_tail_eu_data <= debug_biu_write_request_data;
                    keyboard_tail_eu_ax <= debug_biu_write_eu_ax;
                    keyboard_tail_eu_bx <= debug_biu_write_eu_bx;
                    keyboard_tail_eu_dataout_uaddr <= debug_biu_write_eu_uaddr;
                    keyboard_tail_eu_dataout_alu <= debug_biu_write_eu_alu;
                    keyboard_tail_biu_data_latch <= debug_biu_data_latch;
                    keyboard_tail_biu_state <= debug_biu_state;
                    keyboard_tail_launch_address <= debug_biu_write_address;
                    keyboard_tail_launch_code <= debug_biu_write_code;
                    keyboard_tail_launch_request <= debug_biu_write_request_data;
                    keyboard_tail_launch_t1 <= debug_biu_write_t1_data;
                    keyboard_queue_address <= 20'h00400 + {12'h000, cpu_data} - 20'd2;
                    keyboard_tail_seen <= 1'b1;
                end else if (pending_keyboard_write_address == 20'h0041D) begin
                    keyboard_tail_write_high <= cpu_data;
                    keyboard_tail_eu_data <= debug_biu_write_request_data;
                    keyboard_tail_eu_ax <= debug_biu_write_eu_ax;
                    keyboard_tail_eu_bx <= debug_biu_write_eu_bx;
                    keyboard_tail_eu_dataout_uaddr <= debug_biu_write_eu_uaddr;
                    keyboard_tail_eu_dataout_alu <= debug_biu_write_eu_alu;
                    keyboard_tail_biu_data_latch <= debug_biu_data_latch;
                    keyboard_tail_biu_state <= debug_biu_state;
                    keyboard_tail_launch_address <= debug_biu_write_address;
                    keyboard_tail_launch_code <= debug_biu_write_code;
                    keyboard_tail_launch_request <= debug_biu_write_request_data;
                    keyboard_tail_launch_t1 <= debug_biu_write_t1_data;
                end else if (keyboard_tail_seen &&
                             pending_keyboard_write_address == keyboard_queue_address) begin
                    stop_keyboard_queue_low <= cpu_data;
                end else if (keyboard_tail_seen &&
                             pending_keyboard_write_address == keyboard_queue_address + 1'b1) begin
                    stop_keyboard_queue_high <= cpu_data;
                    keyboard_queue_seen <= 1'b1;
                end
            end

            if (pending_keyboard_bda_read && !memory_read_n) begin
                pending_keyboard_bda_read_seen <= 1'b1;
                case (pending_keyboard_bda_read_address[1:0])
                    2'b10: keyboard_head_low <= cpu_read_data;
                    2'b11: keyboard_head_high <= cpu_read_data;
                    2'b00: stop_keyboard_tail <= cpu_read_data;
                    2'b01: keyboard_tail_high <= cpu_read_data;
                endcase
            end

            if (pending_bda_init_write && !memory_write_n) begin
                pending_bda_init_seen <= 1'b1;
                // Retain the first transaction for each byte, but update it
                // throughout that transaction so the recorded value is its
                // final data phase rather than its multiplexed address phase.
                if (!bda_init_valid[pending_bda_init_index] ||
                    pending_bda_init_seen) begin
                    bda_init_data[pending_bda_init_index] <= cpu_data;
                    bda_init_valid[pending_bda_init_index] <= 1'b1;
                end
            end

            if (pending_irq_stack_write && !pending_irq_stack_seen &&
                !memory_write_n) begin
                pending_irq_stack_seen <= 1'b1;
                irq_stack_data[irq_stack_count] <= cpu_data;
                if (irq_stack_count == 3'd5)
                    irq_stack_capture <= 1'b0;
                else
                    irq_stack_count <= irq_stack_count + 1'b1;
            end

            if (pending_code && !code_seen && !memory_read_n && !fatal_freeze) begin
                for (trace_i = 12; trace_i > 0; trace_i = trace_i - 1) begin
                    code_address[trace_i] <= code_address[trace_i-1];
                    code_data[trace_i] <= code_data[trace_i-1];
                end
                code_address[0] <= pending_code_address;
                code_data[0] <= cpu_read_data;
                code_seen <= 1'b1;
            end

            if (pending_iv10 && !pending_iv10_seen && !memory_read_n) begin
                iv10_data[pending_iv10_byte] <= cpu_read_data;
                iv10_valid[pending_iv10_byte] <= 1'b1;
                pending_iv10_seen <= 1'b1;
            end

            if (nmi_caught)
                nmi_seen <= 1'b1;
        end
    end

    // Synchronise each display field into the video clock domain. They remain
    // stable between I/O transactions, which is vastly longer than two pixels.
    reg [15:0] v_port [0:3];
    reg [7:0]  v_data [0:3];
    reg        v_write [0:3];
    reg [15:0] v_loop_port;
    reg        v_loop_write;
    reg [7:0]  v_loop_count;
    reg [19:0] v_code_address [0:12];
    reg [7:0]  v_code_data [0:12];
    reg [19:0] v_exec_address [0:12];
    reg        v_boot_exec_seen;
    reg [19:0] v_boot_exec_first;
    reg [19:0] v_boot_exec_last;
    reg [7:0]  v_boot_exec_count;
    reg [15:0] v_boot_root_lba;
    reg        v_boot_root_lba_valid;
    reg [15:0] v_boot_root_chs_cx;
    reg [15:0] v_boot_root_chs_dx;
    reg [15:0] v_boot_root_chs_ax;
    reg        v_boot_root_chs_valid;
    reg [15:0] v_boot_root_int13_result;
    reg        v_boot_root_int13_result_valid;
    reg [31:0] v_root_dir_sdram_data;
    reg [3:0]  v_root_dir_sdram_valid;
    reg [7:0]  v_boot_bpb_read0, v_boot_bpb_read1, v_boot_bpb_read2, v_boot_bpb_read3;
    reg [3:0]  v_boot_bpb_read_valid;
    reg [7:0]  v_intack_count;
    reg [15:0] v_intack_cs;
    reg [15:0] v_intack_pfq_addr;
    reg [19:0] v_irq_return_address [0:3];
    reg [7:0]  v_irq_stack_data [0:5];
    reg [2:0]  v_irq_stack_count;
    reg [7:0]  v_keyboard_scancode;
    reg        v_keyboard_enabled;
    reg        v_keyboard_bat_seen;
    reg        v_keyboard_handshake_seen;
    reg        v_keyboard_queue_seen;
    reg        v_keyboard_ram_commit_seen;
    reg        v_keyboard_ram_commit_ok;
    reg [7:0]  v_stop_keyboard_scancode;
    reg [7:0]  v_stop_keyboard_port_b;
    reg [7:0]  v_stop_keyboard_port_a;
    reg [7:0]  v_stop_keyboard_ppi_data;
    reg [7:0]  v_stop_keyboard_read_first;
    reg [7:0]  v_stop_keyboard_read_data;
    reg [7:0]  v_stop_keyboard_clear_data;
    reg [7:0]  v_stop_keyboard_tail;
    reg [7:0]  v_keyboard_tail_write_low;
    reg [7:0]  v_keyboard_tail_write_high;
    reg [15:0] v_keyboard_tail_eu_data;
    reg [15:0] v_keyboard_tail_eu_ax;
    reg [15:0] v_keyboard_tail_eu_bx;
    reg [12:0] v_keyboard_tail_eu_dataout_uaddr;
    reg [15:0] v_keyboard_tail_eu_dataout_alu;
    reg [15:0] v_keyboard_tail_biu_data_latch;
    reg [7:0]  v_keyboard_tail_biu_state;
    reg [19:0] v_keyboard_tail_launch_address;
    reg [7:0]  v_keyboard_tail_launch_code;
    reg [15:0] v_keyboard_tail_launch_request;
    reg [15:0] v_keyboard_tail_launch_t1;
    reg [7:0]  v_stop_keyboard_queue_low;
    reg [7:0]  v_stop_keyboard_queue_high;
    reg [7:0]  v_keyboard_head_low;
    reg [7:0]  v_keyboard_head_high;
    reg [7:0]  v_keyboard_tail_high;
    reg [7:0]  v_ram_tail_write_cpu_low;
    reg [7:0]  v_ram_tail_write_cpu_high;
    reg [7:0]  v_ram_tail_write_sdram_low;
    reg [7:0]  v_ram_tail_write_sdram_high;
    reg [7:0]  v_ram_tail_write_queue_cpu_low;
    reg [7:0]  v_ram_tail_write_queue_cpu_high;
    reg [7:0]  v_ram_tail_write_queue_sdram_low;
    reg [7:0]  v_ram_tail_write_queue_sdram_high;
    reg [1:0]  v_ram_tail_write_cpu_valid;
    reg [1:0]  v_ram_tail_write_sdram_valid;
    reg [1:0]  v_ram_tail_write_queue_cpu_valid;
    reg [1:0]  v_ram_tail_write_queue_sdram_valid;
    reg [3:0]  v_ram_tail_write_cpu_low_count;
    reg [3:0]  v_ram_tail_write_cpu_high_count;
    reg [6:0]  v_rtc_index;
    reg        v_rtc_index_valid;
    reg [7:0]  v_rtc_checksum_seen;
    reg [7:0]  v_rtc_checksum_last_data;
    reg [7:0]  v_bda_init_data [0:7];
    reg [7:0]  v_bda_init_valid;
    reg [7:0]  v_iv10_data [0:3];
    reg [3:0]  v_iv10_valid;
    reg        v_fatal_freeze;
    reg [2:0]  v_stop_reason;
    reg [19:0] v_stop_address;
    reg [15:0] v_stop_cs;
    reg [15:0] v_stop_pfq_addr;
    reg        v_nmi_seen;
    reg        v_fdc_active;
    reg        v_fdc_read_active;
    reg        v_fdc_postkey_active;
    reg [15:0] v_fdc_postkey_last_port;
    reg        v_fdc_postkey_last_write;
    reg [7:0]  v_fdc_postkey_last_data;
    reg [7:0]  v_fdc_postkey_access_count;
    reg [7:0]  v_fdc_tx0, v_fdc_tx1, v_fdc_tx2, v_fdc_tx3;
    reg [7:0]  v_fdc_tx4, v_fdc_tx5, v_fdc_tx6, v_fdc_tx7;
    reg [7:0]  v_fdc_tx8, v_fdc_tx9, v_fdc_tx10, v_fdc_tx11;
    reg [7:0]  v_fdc_tx12, v_fdc_tx13, v_fdc_tx14, v_fdc_tx15;
    reg [15:0] v_fdc_tx_write;
    reg [4:0]  v_fdc_tx_count;
    reg [1:0]  v_fdd_present;
    reg        v_fdd_wp;
    reg [7:0]  v_fdd_cylinders;
    reg [7:0]  v_fdd_sectors_per_track;
    reg [15:0] v_fdd_sector_count;
    reg [1:0]  v_fdd_heads;
    reg        v_fdd_irq;
    reg        v_fdd_dma_req;
    reg        v_fdd_dma_ack;
    reg        v_fdd_dma_tc;
    reg [7:0]  v_fdc_dor;
    reg [7:0]  v_fdc_msr;
    reg [7:0]  v_fdc_ccr;
    reg [7:0]  v_fdc_dir;
    reg [7:0]  v_fdc_st3;
    reg        v_fdc_read_packet_complete;
    reg [7:0]  v_fdc_read_reject;
    reg [7:0]  v_fdc_hist0, v_fdc_hist1, v_fdc_hist2, v_fdc_hist3;
    reg [7:0]  v_fdc_hist4, v_fdc_hist5, v_fdc_hist6, v_fdc_hist7;
    reg [15:0] v_fdc_irq_count;
    reg [15:0] v_fdc_req_count;
    reg [15:0] v_fdc_dma_count;
    reg [3:0]  v_fdc_read_history_valid;
    reg [3:0]  v_fdc_read_history_count;
    reg [31:0] v_boot_sector_sdram_data;
    reg [3:0]  v_boot_sector_sdram_valid;
    reg [7:0]  v_fdc_read0_cyl, v_fdc_read0_head, v_fdc_read0_sector;
    reg [15:0] v_fdc_read0_bytes;
    reg [7:0]  v_fdc_read0_st0, v_fdc_read0_st1, v_fdc_read0_st2;
    reg [7:0]  v_fdc_read0_tail0, v_fdc_read0_tail1;
    reg [7:0]  v_fdc_read1_cyl, v_fdc_read1_head, v_fdc_read1_sector;
    reg [15:0] v_fdc_read1_bytes;
    reg [7:0]  v_fdc_read1_st0, v_fdc_read1_st1, v_fdc_read1_st2;
    reg [7:0]  v_fdc_read1_tail0, v_fdc_read1_tail1;
    reg [7:0]  v_fdc_read2_cyl, v_fdc_read2_head, v_fdc_read2_sector;
    reg [15:0] v_fdc_read2_bytes;
    reg [7:0]  v_fdc_read2_st0, v_fdc_read2_st1, v_fdc_read2_st2;
    reg [7:0]  v_fdc_read2_tail0, v_fdc_read2_tail1;
    reg [7:0]  v_fdc_read3_cyl, v_fdc_read3_head, v_fdc_read3_sector;
    reg [15:0] v_fdc_read3_bytes;
    reg [7:0]  v_fdc_read3_st0, v_fdc_read3_st1, v_fdc_read3_st2;
    reg [7:0]  v_fdc_read3_tail0, v_fdc_read3_tail1;
    reg [7:0]  v_fdc_tc_count;
    reg [7:0]  v_fdd_cfg_write_count, v_fdd_cfg_seen, v_fdd_cfg0;
    reg [15:0] v_fdd_host_write_count, v_fdd_host_read_count;
    reg [7:0]  v_fdd_host_last_write, v_fdd_host_last_read;
    reg [15:0] v_fdd_request_change_count;
    reg [1:0]  v_fdd_request;
    reg [3:0]  v_fdc_command_count;
    reg [3:0]  v_fdc_result_count;
    reg [7:0]  v_fdc_cmd_opcode, v_fdc_cmd_drive_head, v_fdc_cmd_cyl;
    reg [7:0]  v_fdc_cmd_head, v_fdc_cmd_sector, v_fdc_cmd_size, v_fdc_cmd_eot;
    reg [7:0]  v_fdc_res_st0, v_fdc_res_st1, v_fdc_res_st2, v_fdc_res_cyl;
    reg [7:0]  v_fdc_res_head, v_fdc_res_sector, v_fdc_res_size;
    reg [2:0]  v_fdc_first_count;
    reg [7:0]  v_fdc_first0, v_fdc_first1, v_fdc_first2, v_fdc_first3;
    reg [7:0]  v_fdc_dma_tail0;
    reg [7:0]  v_fdc_dma_tail1;
    reg [15:0] v_fdc_command_cs;
    reg [15:0] v_fdc_command_pfq_addr;
    reg [27:0] v_detail_page_counter;
    integer i;
    always @(posedge clk_video) begin
        for (i = 0; i < 4; i = i + 1) begin
            v_port[i] <= event_port[i];
            v_data[i] <= event_data[i];
            v_write[i] <= event_write[i];
        end
        v_loop_port <= loop_port;
        v_loop_write <= loop_write;
        v_loop_count <= loop_count;
        for (i = 0; i < 13; i = i + 1) begin
            v_code_address[i] <= code_address[i];
            v_code_data[i] <= code_data[i];
            v_exec_address[i] <= exec_address[i];
        end
        v_boot_exec_seen <= boot_exec_seen;
        v_boot_exec_first <= boot_exec_first;
        v_boot_exec_last <= boot_exec_last;
        v_boot_exec_count <= boot_exec_count;
        v_boot_root_lba <= boot_root_lba;
        v_boot_root_lba_valid <= boot_root_lba_valid;
        v_boot_root_chs_cx <= boot_root_chs_cx;
        v_boot_root_chs_dx <= boot_root_chs_dx;
        v_boot_root_chs_ax <= boot_root_chs_ax;
        v_boot_root_chs_valid <= boot_root_chs_valid;
        v_boot_root_int13_result <= boot_root_int13_result;
        v_boot_root_int13_result_valid <= boot_root_int13_result_valid;
        v_root_dir_sdram_data <= root_dir_sdram_data;
        v_root_dir_sdram_valid <= root_dir_sdram_valid;
        v_boot_bpb_read0 <= boot_bpb_read0; v_boot_bpb_read1 <= boot_bpb_read1;
        v_boot_bpb_read2 <= boot_bpb_read2; v_boot_bpb_read3 <= boot_bpb_read3;
        v_boot_bpb_read_valid <= boot_bpb_read_valid;
        for (i = 0; i < 4; i = i + 1) begin
            v_iv10_data[i] <= iv10_data[i];
            v_irq_return_address[i] <= irq_return_address[i];
        end
        v_iv10_valid <= iv10_valid;
        for (i = 0; i < 6; i = i + 1)
            v_irq_stack_data[i] <= irq_stack_data[i];
        for (i = 0; i < 8; i = i + 1)
            v_bda_init_data[i] <= bda_init_data[i];
        v_bda_init_valid <= bda_init_valid;
        v_irq_stack_count <= irq_stack_count;
        v_fatal_freeze <= fatal_freeze;
        v_stop_reason <= stop_reason;
        v_stop_address <= stop_address;
        v_stop_cs <= stop_cs;
        v_stop_pfq_addr <= stop_pfq_addr;
        v_nmi_seen <= nmi_seen;
        v_intack_count <= intack_count;
        v_intack_cs <= intack_cs;
        v_intack_pfq_addr <= intack_pfq_addr;
        v_keyboard_scancode <= keyboard_scancode;
        v_keyboard_enabled <= keyboard_enabled;
        v_keyboard_bat_seen <= keyboard_bat_seen;
        v_keyboard_handshake_seen <= keyboard_handshake_seen;
        v_keyboard_queue_seen <= keyboard_queue_seen;
        v_keyboard_ram_commit_seen <= keyboard_ram_commit_seen;
        v_keyboard_ram_commit_ok <= keyboard_ram_commit_ok;
        v_stop_keyboard_scancode <= stop_keyboard_scancode;
        v_stop_keyboard_port_b <= stop_keyboard_port_b;
        v_stop_keyboard_port_a <= stop_keyboard_port_a;
        v_stop_keyboard_ppi_data <= stop_keyboard_ppi_data;
        v_stop_keyboard_read_first <= stop_keyboard_read_first;
        v_stop_keyboard_read_data <= stop_keyboard_read_data;
        v_stop_keyboard_clear_data <= stop_keyboard_clear_data;
        v_stop_keyboard_tail <= stop_keyboard_tail;
        v_keyboard_tail_write_low <= keyboard_tail_write_low;
        v_keyboard_tail_write_high <= keyboard_tail_write_high;
        v_keyboard_tail_eu_data <= keyboard_tail_eu_data;
        v_keyboard_tail_eu_ax <= keyboard_tail_eu_ax;
        v_keyboard_tail_eu_bx <= keyboard_tail_eu_bx;
        v_keyboard_tail_eu_dataout_uaddr <= keyboard_tail_eu_dataout_uaddr;
        v_keyboard_tail_eu_dataout_alu <= keyboard_tail_eu_dataout_alu;
        v_keyboard_tail_biu_data_latch <= keyboard_tail_biu_data_latch;
        v_keyboard_tail_biu_state <= keyboard_tail_biu_state;
        v_keyboard_tail_launch_address <= keyboard_tail_launch_address;
        v_keyboard_tail_launch_code <= keyboard_tail_launch_code;
        v_keyboard_tail_launch_request <= keyboard_tail_launch_request;
        v_keyboard_tail_launch_t1 <= keyboard_tail_launch_t1;
        v_stop_keyboard_queue_low <= stop_keyboard_queue_low;
        v_stop_keyboard_queue_high <= stop_keyboard_queue_high;
        v_keyboard_head_low <= keyboard_head_low;
        v_keyboard_head_high <= keyboard_head_high;
        v_keyboard_tail_high <= keyboard_tail_high;
        v_ram_tail_write_cpu_low <= ram_tail_write_cpu_low;
        v_ram_tail_write_cpu_high <= ram_tail_write_cpu_high;
        v_ram_tail_write_sdram_low <= ram_tail_write_sdram_low;
        v_ram_tail_write_sdram_high <= ram_tail_write_sdram_high;
        v_ram_tail_write_queue_cpu_low <= ram_tail_write_queue_cpu_low;
        v_ram_tail_write_queue_cpu_high <= ram_tail_write_queue_cpu_high;
        v_ram_tail_write_queue_sdram_low <= ram_tail_write_queue_sdram_low;
        v_ram_tail_write_queue_sdram_high <= ram_tail_write_queue_sdram_high;
        v_ram_tail_write_cpu_valid <= ram_tail_write_cpu_valid;
        v_ram_tail_write_sdram_valid <= ram_tail_write_sdram_valid;
        v_ram_tail_write_queue_cpu_valid <= ram_tail_write_queue_cpu_valid;
        v_ram_tail_write_queue_sdram_valid <= ram_tail_write_queue_sdram_valid;
        v_ram_tail_write_cpu_low_count <= ram_tail_write_cpu_low_count;
        v_ram_tail_write_cpu_high_count <= ram_tail_write_cpu_high_count;
        v_rtc_index <= rtc_index;
        v_rtc_index_valid <= rtc_index_valid;
        v_rtc_checksum_seen <= rtc_checksum_seen;
        v_rtc_checksum_last_data <= rtc_checksum_last_data;
        v_fdc_active <= fdc_active;
        v_fdc_read_active <= fdc_read_active;
        v_fdc_postkey_active <= fdc_postkey_active;
        v_fdc_postkey_last_port <= fdc_postkey_last_port;
        v_fdc_postkey_last_write <= fdc_postkey_last_write;
        v_fdc_postkey_last_data <= fdc_postkey_last_data;
        v_fdc_postkey_access_count <= fdc_postkey_access_count;
        v_fdc_tx0 <= fdc_tx0; v_fdc_tx1 <= fdc_tx1;
        v_fdc_tx2 <= fdc_tx2; v_fdc_tx3 <= fdc_tx3;
        v_fdc_tx4 <= fdc_tx4; v_fdc_tx5 <= fdc_tx5;
        v_fdc_tx6 <= fdc_tx6; v_fdc_tx7 <= fdc_tx7;
        v_fdc_tx8 <= fdc_tx8; v_fdc_tx9 <= fdc_tx9;
        v_fdc_tx10 <= fdc_tx10; v_fdc_tx11 <= fdc_tx11;
        v_fdc_tx12 <= fdc_tx12; v_fdc_tx13 <= fdc_tx13;
        v_fdc_tx14 <= fdc_tx14; v_fdc_tx15 <= fdc_tx15;
        v_fdc_tx_write <= fdc_tx_write;
        v_fdc_tx_count <= fdc_tx_count;
        v_fdd_cfg_write_count <= fdd_cfg_write_count;
        v_fdd_cfg_seen <= fdd_cfg_seen;
        v_fdd_cfg0 <= fdd_cfg0;
        v_fdd_host_write_count <= fdd_host_write_count;
        v_fdd_host_read_count <= fdd_host_read_count;
        v_fdd_host_last_write <= fdd_host_last_write;
        v_fdd_host_last_read <= fdd_host_last_read;
        v_fdd_request_change_count <= fdd_request_change_count;
        v_fdd_request <= fdd_request;
        v_fdd_present <= fdd_present;
        v_fdd_wp <= fdd_wp;
        v_fdd_cylinders <= fdd_cylinders;
        v_fdd_sectors_per_track <= fdd_sectors_per_track;
        v_fdd_sector_count <= fdd_sector_count;
        v_fdd_heads <= fdd_heads;
        v_fdd_irq <= fdd_irq;
        v_fdd_dma_req <= fdd_dma_req;
        v_fdd_dma_ack <= fdd_dma_ack;
        v_fdd_dma_tc <= fdd_dma_tc;
        v_fdc_dor <= fdc_dor;
        v_fdc_msr <= fdc_msr;
        v_fdc_ccr <= fdc_ccr;
        v_fdc_dir <= fdc_dir;
        v_fdc_st3 <= fdc_st3;
        v_fdc_read_packet_complete <= fdc_read_packet_complete;
        v_fdc_read_reject <= fdc_read_reject;
        v_fdc_hist0 <= fdc_hist0; v_fdc_hist1 <= fdc_hist1;
        v_fdc_hist2 <= fdc_hist2; v_fdc_hist3 <= fdc_hist3;
        v_fdc_hist4 <= fdc_hist4; v_fdc_hist5 <= fdc_hist5;
        v_fdc_hist6 <= fdc_hist6; v_fdc_hist7 <= fdc_hist7;
        v_fdc_irq_count <= fdc_irq_count;
        v_fdc_req_count <= fdc_req_count;
        v_fdc_dma_count <= fdc_dma_count;
        v_fdc_read_history_valid <= fdc_read_history_valid;
        v_fdc_read_history_count <= fdc_read_history_count;
        v_boot_sector_sdram_data <= boot_sector_sdram_data;
        v_boot_sector_sdram_valid <= boot_sector_sdram_valid;
        v_fdc_read0_cyl <= fdc_read0_cyl; v_fdc_read0_head <= fdc_read0_head; v_fdc_read0_sector <= fdc_read0_sector;
        v_fdc_read0_bytes <= fdc_read0_bytes;
        v_fdc_read0_st0 <= fdc_read0_st0; v_fdc_read0_st1 <= fdc_read0_st1; v_fdc_read0_st2 <= fdc_read0_st2;
        v_fdc_read0_tail0 <= fdc_read0_tail0; v_fdc_read0_tail1 <= fdc_read0_tail1;
        v_fdc_read1_cyl <= fdc_read1_cyl; v_fdc_read1_head <= fdc_read1_head; v_fdc_read1_sector <= fdc_read1_sector;
        v_fdc_read1_bytes <= fdc_read1_bytes;
        v_fdc_read1_st0 <= fdc_read1_st0; v_fdc_read1_st1 <= fdc_read1_st1; v_fdc_read1_st2 <= fdc_read1_st2;
        v_fdc_read1_tail0 <= fdc_read1_tail0; v_fdc_read1_tail1 <= fdc_read1_tail1;
        v_fdc_read2_cyl <= fdc_read2_cyl; v_fdc_read2_head <= fdc_read2_head; v_fdc_read2_sector <= fdc_read2_sector;
        v_fdc_read2_bytes <= fdc_read2_bytes;
        v_fdc_read2_st0 <= fdc_read2_st0; v_fdc_read2_st1 <= fdc_read2_st1; v_fdc_read2_st2 <= fdc_read2_st2;
        v_fdc_read2_tail0 <= fdc_read2_tail0; v_fdc_read2_tail1 <= fdc_read2_tail1;
        v_fdc_read3_cyl <= fdc_read3_cyl; v_fdc_read3_head <= fdc_read3_head; v_fdc_read3_sector <= fdc_read3_sector;
        v_fdc_read3_bytes <= fdc_read3_bytes;
        v_fdc_read3_st0 <= fdc_read3_st0; v_fdc_read3_st1 <= fdc_read3_st1; v_fdc_read3_st2 <= fdc_read3_st2;
        v_fdc_read3_tail0 <= fdc_read3_tail0; v_fdc_read3_tail1 <= fdc_read3_tail1;
        v_fdc_tc_count <= fdc_tc_count;
        v_fdc_command_count <= fdc_command_count;
        v_fdc_result_count <= fdc_result_count;
        v_fdc_cmd_opcode <= fdc_cmd_opcode;
        v_fdc_cmd_drive_head <= fdc_cmd_drive_head;
        v_fdc_cmd_cyl <= fdc_cmd_cyl;
        v_fdc_cmd_head <= fdc_cmd_head;
        v_fdc_cmd_sector <= fdc_cmd_sector;
        v_fdc_cmd_size <= fdc_cmd_size;
        v_fdc_cmd_eot <= fdc_cmd_eot;
        v_fdc_res_st0 <= fdc_res_st0;
        v_fdc_res_st1 <= fdc_res_st1;
        v_fdc_res_st2 <= fdc_res_st2;
        v_fdc_res_cyl <= fdc_res_cyl;
        v_fdc_res_head <= fdc_res_head;
        v_fdc_res_sector <= fdc_res_sector;
        v_fdc_res_size <= fdc_res_size;
        v_fdc_first_count <= fdc_first_count;
        v_fdc_first0 <= fdc_first0; v_fdc_first1 <= fdc_first1;
        v_fdc_first2 <= fdc_first2; v_fdc_first3 <= fdc_first3;
        v_fdc_dma_tail0 <= fdc_dma_tail0;
        v_fdc_dma_tail1 <= fdc_dma_tail1;
        v_fdc_command_cs <= fdc_command_cs;
        v_fdc_command_pfq_addr <= fdc_command_pfq_addr;
        if (reset || !v_fatal_freeze)
            v_detail_page_counter <= 0;
        else
            v_detail_page_counter <= v_detail_page_counter + 1'b1;
    end

    function [7:0] hex_char;
        input [3:0] value;
        begin
            hex_char = (value < 10) ? ("0" + value) : ("A" + value - 10);
        end
    endfunction

    function [7:0] fdc_tx_data_at;
        input [3:0] slot;
        begin
            case (slot)
                0: fdc_tx_data_at = v_fdc_tx0;   1: fdc_tx_data_at = v_fdc_tx1;
                2: fdc_tx_data_at = v_fdc_tx2;   3: fdc_tx_data_at = v_fdc_tx3;
                4: fdc_tx_data_at = v_fdc_tx4;   5: fdc_tx_data_at = v_fdc_tx5;
                6: fdc_tx_data_at = v_fdc_tx6;   7: fdc_tx_data_at = v_fdc_tx7;
                8: fdc_tx_data_at = v_fdc_tx8;   9: fdc_tx_data_at = v_fdc_tx9;
                10: fdc_tx_data_at = v_fdc_tx10; 11: fdc_tx_data_at = v_fdc_tx11;
                12: fdc_tx_data_at = v_fdc_tx12; 13: fdc_tx_data_at = v_fdc_tx13;
                14: fdc_tx_data_at = v_fdc_tx14; default: fdc_tx_data_at = v_fdc_tx15;
            endcase
        end
    endfunction

    function [7:0] trace_char;
        input [3:0] line;
        input [4:0] col;
        reg [15:0] p;
        reg [7:0] d;
        reg [19:0] ca;
        reg [7:0] cd;
        reg w;
        reg [3:0] tx_slot;
        reg [7:0] tx_data;
        reg read_valid;
        reg [7:0] read_cyl, read_head, read_sector;
        reg [15:0] read_bytes;
        reg [7:0] read_st0, read_st1, read_st2;
        begin
            p = 0; d = 0; ca = 0; cd = 0; w = 0; tx_slot = 0; tx_data = 0;
            read_valid = 0; read_cyl = 0; read_head = 0; read_sector = 0;
            read_bytes = 0; read_st0 = 0; read_st1 = 0; read_st2 = 0;
            if (line >= 2 && line <= 5) begin
                p = v_port[line-2]; d = v_data[line-2]; w = v_write[line-2];
            end
            if (line >= 2 && line <= 14) begin
                ca = v_code_address[line-2]; cd = v_code_data[line-2];
            end
            // Retain the completed READ DATA results.  The post-key FDC
            // overlay can otherwise scroll past the critical sector before a
            // photo is possible, particularly while an image is being mounted.
            case (line)
                8: begin read_valid = v_fdc_read_history_valid[0]; read_cyl = v_fdc_read0_cyl; read_head = v_fdc_read0_head; read_sector = v_fdc_read0_sector; read_bytes = v_fdc_read0_bytes; read_st0 = v_fdc_read0_st0; read_st1 = v_fdc_read0_st1; read_st2 = v_fdc_read0_st2; end
                default: begin end
            endcase
            trace_char = " ";
            // Once the RAM-side keyboard transaction has committed, keep a
            // stable evidence page on screen. This removes the photo-timing
            // race while still allowing the CPU to continue toward CMOS.
            // Compact FDC page: fixed fields only, so it is inexpensive to
            // fit but still answers every boot-path question in one photo.
            // Do not show it for controller setup alone: that must leave the
            // BIOS's normal boot prompt visible.  Once the boot-prompt key is
            // queued, however, any FDC host I/O is meaningful evidence.
            if (v_fdc_postkey_active) begin
                case (line)
                    0: case (col)
                        0:trace_char="F";1:trace_char="=";2:trace_char=hex_char({2'b00,v_fdd_present});
                        4:trace_char="W";5:trace_char="=";6:trace_char=v_fdd_wp ? "1" : "0";
                        8:trace_char="H";9:trace_char="=";10:trace_char=hex_char({2'b00,v_fdd_heads});
                        default:trace_char=" "; endcase
                    1: case (col)
                        0:trace_char="C";1:trace_char="=";2:trace_char=hex_char(v_fdd_cylinders[7:4]);3:trace_char=hex_char(v_fdd_cylinders[3:0]);
                        5:trace_char="S";6:trace_char="=";7:trace_char=hex_char(v_fdd_sectors_per_track[7:4]);8:trace_char=hex_char(v_fdd_sectors_per_track[3:0]);
                        10:trace_char="N";11:trace_char="=";12:trace_char=hex_char(v_fdd_sector_count[15:12]);13:trace_char=hex_char(v_fdd_sector_count[11:8]);14:trace_char=hex_char(v_fdd_sector_count[7:4]);15:trace_char=hex_char(v_fdd_sector_count[3:0]);
                        default:trace_char=" "; endcase
                    2: case (col)
                        0:trace_char="D";1:trace_char="=";2:trace_char=hex_char(v_fdc_dor[7:4]);3:trace_char=hex_char(v_fdc_dor[3:0]);
                        5:trace_char="M";6:trace_char="=";7:trace_char=hex_char(v_fdc_msr[7:4]);8:trace_char=hex_char(v_fdc_msr[3:0]);
                        10:trace_char="O";11:trace_char="P";12:trace_char="=";13:trace_char=hex_char(v_fdc_cmd_opcode[7:4]);14:trace_char=hex_char(v_fdc_cmd_opcode[3:0]);
                        default:trace_char=" "; endcase
                    3: case (col)
                        0:trace_char="I";1:trace_char="=";2:trace_char=hex_char(v_fdc_irq_count[15:12]);3:trace_char=hex_char(v_fdc_irq_count[11:8]);4:trace_char=hex_char(v_fdc_irq_count[7:4]);5:trace_char=hex_char(v_fdc_irq_count[3:0]);
                        7:trace_char="R";8:trace_char="=";9:trace_char=hex_char(v_fdc_req_count[15:12]);10:trace_char=hex_char(v_fdc_req_count[11:8]);11:trace_char=hex_char(v_fdc_req_count[7:4]);12:trace_char=hex_char(v_fdc_req_count[3:0]);
                        default:trace_char=" "; endcase
                    4: case (col)
                        0:trace_char="A";1:trace_char="=";2:trace_char=hex_char(v_fdc_read0_bytes[15:12]);3:trace_char=hex_char(v_fdc_read0_bytes[11:8]);4:trace_char=hex_char(v_fdc_read0_bytes[7:4]);5:trace_char=hex_char(v_fdc_read0_bytes[3:0]);
                        7:trace_char="Z";8:trace_char="=";9:trace_char=hex_char(v_fdc_read0_tail0[7:4]);10:trace_char=hex_char(v_fdc_read0_tail0[3:0]);11:trace_char=hex_char(v_fdc_read0_tail1[7:4]);12:trace_char=hex_char(v_fdc_read0_tail1[3:0]);
                        14:trace_char="H";15:trace_char=hex_char(v_fdc_read_history_count);
                        default:trace_char=" "; endcase
                    // SDRAM-side confirmation that the boot DMA landed at
                    // 7C00. M is bytes 7C00/01, Z is bytes 7DFE/FF, and V is
                    // a bit map of the four controller-owned write commits.
                    5: case (col)
                        0:trace_char="M";1:trace_char="=";
                        2:trace_char=hex_char(v_boot_sector_sdram_data[7:4]);3:trace_char=hex_char(v_boot_sector_sdram_data[3:0]);
                        4:trace_char=hex_char(v_boot_sector_sdram_data[15:12]);5:trace_char=hex_char(v_boot_sector_sdram_data[11:8]);
                        7:trace_char="Z";8:trace_char="=";
                        9:trace_char=hex_char(v_boot_sector_sdram_data[23:20]);10:trace_char=hex_char(v_boot_sector_sdram_data[19:16]);
                        11:trace_char=hex_char(v_boot_sector_sdram_data[31:28]);12:trace_char=hex_char(v_boot_sector_sdram_data[27:24]);
                        14:trace_char="V";15:trace_char=hex_char(v_boot_sector_sdram_valid);
                        default:trace_char=" "; endcase
                    // EU-side confirmation after the completed READ result:
                    // X is a hit flag, F the first 7Cxx execution address,
                    // and C a saturating number of consumed PFQ positions.
                    6: case (col)
                        0:trace_char="X";1:trace_char="=";2:trace_char=v_boot_exec_seen ? "1" : "0";
                        4:trace_char="F";5:trace_char="=";
                        6:trace_char=hex_char(v_boot_exec_first[15:12]);7:trace_char=hex_char(v_boot_exec_first[11:8]);8:trace_char=hex_char(v_boot_exec_first[7:4]);9:trace_char=hex_char(v_boot_exec_first[3:0]);
                        11:trace_char="C";12:trace_char="=";13:trace_char=hex_char(v_boot_exec_count[7:4]);14:trace_char=hex_char(v_boot_exec_count[3:0]);
                        default:trace_char=" "; endcase
                    7: case (col)
                        0:trace_char="L";1:trace_char="=";
                        2:trace_char=hex_char(v_boot_exec_last[15:12]);3:trace_char=hex_char(v_boot_exec_last[11:8]);4:trace_char=hex_char(v_boot_exec_last[7:4]);5:trace_char=hex_char(v_boot_exec_last[3:0]);
                        7:trace_char="T";8:trace_char="=";
                        9:trace_char=hex_char(v_boot_root_lba[15:12]);10:trace_char=hex_char(v_boot_root_lba[11:8]);11:trace_char=hex_char(v_boot_root_lba[7:4]);12:trace_char=hex_char(v_boot_root_lba[3:0]);
                        14:trace_char="V";15:trace_char=v_boot_root_lba_valid ? "1" : "0";
                        default:trace_char=" "; endcase
                    // Completed READ DATA results, newest first. Each row is
                    // CCHHSSBBBBS0S1S2: CHS, bytes moved, then ST0/ST1/ST2.
                    8: begin
                        if (v_boot_root_chs_valid) begin
                            case (col)
                                0:trace_char="A";1:trace_char="=";
                                2:trace_char=hex_char(v_boot_root_chs_ax[15:12]);3:trace_char=hex_char(v_boot_root_chs_ax[11:8]);4:trace_char=hex_char(v_boot_root_chs_ax[7:4]);5:trace_char=hex_char(v_boot_root_chs_ax[3:0]);
                                7:trace_char="E";8:trace_char="=";
                                9:trace_char=hex_char(v_boot_root_int13_result[15:12]);10:trace_char=hex_char(v_boot_root_int13_result[11:8]);11:trace_char=hex_char(v_boot_root_int13_result[7:4]);12:trace_char=hex_char(v_boot_root_int13_result[3:0]);
                                13:trace_char="V";14:trace_char="=";15:trace_char=v_boot_root_int13_result_valid ? "1" : "0";
                                default:trace_char=" ";
                            endcase
                        end else if (&v_root_dir_sdram_valid) begin
                            case (col)
                                0:trace_char="R";1:trace_char="=";
                                2:trace_char=hex_char(v_root_dir_sdram_data[7:4]);3:trace_char=hex_char(v_root_dir_sdram_data[3:0]);
                                4:trace_char=hex_char(v_root_dir_sdram_data[15:12]);5:trace_char=hex_char(v_root_dir_sdram_data[11:8]);
                                7:trace_char="S";8:trace_char="=";
                                9:trace_char=hex_char(v_root_dir_sdram_data[23:20]);10:trace_char=hex_char(v_root_dir_sdram_data[19:16]);
                                11:trace_char=hex_char(v_root_dir_sdram_data[31:28]);12:trace_char=hex_char(v_root_dir_sdram_data[27:24]);
                                13:trace_char="V";14:trace_char="=";15:trace_char="F";
                                default:trace_char=" ";
                            endcase
                        end else if (read_valid) begin
                            case (col)
                                0:trace_char="B";1:trace_char="=";
                                2:trace_char=hex_char(v_boot_bpb_read0[7:4]);3:trace_char=hex_char(v_boot_bpb_read0[3:0]);
                                4:trace_char=hex_char(v_boot_bpb_read1[7:4]);5:trace_char=hex_char(v_boot_bpb_read1[3:0]);
                                6:trace_char=hex_char(v_boot_bpb_read2[7:4]);7:trace_char=hex_char(v_boot_bpb_read2[3:0]);
                                8:trace_char=hex_char(v_boot_bpb_read3[7:4]);9:trace_char=hex_char(v_boot_bpb_read3[3:0]);
                                11:trace_char="V";12:trace_char="=";13:trace_char=hex_char(v_boot_bpb_read_valid);
                                default:trace_char=" ";
                            endcase
                        end
                    end
                    // READ DATA summary. RD means its opcode (06h) was seen;
                    // PK means all eight parameters were present. RJ is a
                    // bit map of the floppy.v start gates: 01 motor, 02 media,
                    // 04 N, 08 cylinder, 10 head, 20 sector/EOT, 40 drive B.
                    9: case (col)
                        0:trace_char="R";1:trace_char="D";2:trace_char="=";3:trace_char=v_fdc_read_active ? "1" : "0";
                        5:trace_char="P";6:trace_char="K";7:trace_char="=";8:trace_char=v_fdc_read_packet_complete ? "1" : "0";
                        10:trace_char="R";11:trace_char="J";12:trace_char="=";13:trace_char=hex_char(v_fdc_read_reject[7:4]);14:trace_char=hex_char(v_fdc_read_reject[3:0]);
                        default:trace_char=" "; endcase
                    10: case (col)
                        0:trace_char="D";1:trace_char="H";2:trace_char="=";3:trace_char=hex_char(v_fdc_cmd_drive_head[7:4]);4:trace_char=hex_char(v_fdc_cmd_drive_head[3:0]);
                        6:trace_char="C";7:trace_char="=";8:trace_char=hex_char(v_fdc_cmd_cyl[7:4]);9:trace_char=hex_char(v_fdc_cmd_cyl[3:0]);
                        11:trace_char="H";12:trace_char="=";13:trace_char=hex_char(v_fdc_cmd_head[7:4]);14:trace_char=hex_char(v_fdc_cmd_head[3:0]);
                        default:trace_char=" "; endcase
                    11: case (col)
                        0:trace_char="S";1:trace_char="=";2:trace_char=hex_char(v_fdc_cmd_sector[7:4]);3:trace_char=hex_char(v_fdc_cmd_sector[3:0]);
                        5:trace_char="N";6:trace_char="=";7:trace_char=hex_char(v_fdc_cmd_size[7:4]);8:trace_char=hex_char(v_fdc_cmd_size[3:0]);
                        10:trace_char="E";11:trace_char="=";12:trace_char=hex_char(v_fdc_cmd_eot[7:4]);13:trace_char=hex_char(v_fdc_cmd_eot[3:0]);
                        default:trace_char=" "; endcase
                    // HPS transport summary. G/M/V persist from image mount:
                    // config writes, F200..F205 seen bitmap, and F200 value.
                    // HW/HR are post-key F2FF writes/reads; Q counts request
                    // bit transitions and R is the live two-bit request value.
                    12: case (col)
                        0:trace_char="G";1:trace_char="=";2:trace_char=hex_char(v_fdd_cfg_write_count[7:4]);3:trace_char=hex_char(v_fdd_cfg_write_count[3:0]);
                        5:trace_char="M";6:trace_char="=";7:trace_char=hex_char(v_fdd_cfg_seen[7:4]);8:trace_char=hex_char(v_fdd_cfg_seen[3:0]);
                        10:trace_char="V";11:trace_char="=";12:trace_char=hex_char(v_fdd_cfg0[7:4]);13:trace_char=hex_char(v_fdd_cfg0[3:0]);
                        default:trace_char=" "; endcase
                    13: case (col)
                        0:trace_char="H";1:trace_char="W";2:trace_char="=";
                        3:trace_char=hex_char(v_fdd_host_write_count[15:12]);4:trace_char=hex_char(v_fdd_host_write_count[11:8]);5:trace_char=hex_char(v_fdd_host_write_count[7:4]);6:trace_char=hex_char(v_fdd_host_write_count[3:0]);
                        8:trace_char="D";9:trace_char="=";10:trace_char=hex_char(v_fdd_host_last_write[7:4]);11:trace_char=hex_char(v_fdd_host_last_write[3:0]);
                        default:trace_char=" "; endcase
                    14: case (col)
                        0:trace_char="H";1:trace_char="R";2:trace_char="=";
                        3:trace_char=hex_char(v_fdd_host_read_count[15:12]);4:trace_char=hex_char(v_fdd_host_read_count[11:8]);5:trace_char=hex_char(v_fdd_host_read_count[7:4]);6:trace_char=hex_char(v_fdd_host_read_count[3:0]);
                        8:trace_char="D";9:trace_char="=";10:trace_char=hex_char(v_fdd_host_last_read[7:4]);11:trace_char=hex_char(v_fdd_host_last_read[3:0]);
                        default:trace_char=" "; endcase
                    15: case (col)
                        0:trace_char="Q";1:trace_char="=";
                        2:trace_char=hex_char(v_fdd_request_change_count[15:12]);3:trace_char=hex_char(v_fdd_request_change_count[11:8]);4:trace_char=hex_char(v_fdd_request_change_count[7:4]);5:trace_char=hex_char(v_fdd_request_change_count[3:0]);
                        7:trace_char="R";8:trace_char="=";9:trace_char=hex_char({2'b00,v_fdd_request});
                        default:trace_char=" "; endcase
                    default:trace_char=" ";
                endcase
            end else if (v_keyboard_handshake_seen && v_keyboard_ram_commit_seen) begin
                case (line)
                    0: case (col)
                        0:trace_char="I"; 1:trace_char="=";
                        2:trace_char=hex_char(v_intack_cs[15:12]); 3:trace_char=hex_char(v_intack_cs[11:8]);
                        4:trace_char=hex_char(v_intack_cs[7:4]); 5:trace_char=hex_char(v_intack_cs[3:0]);
                        6:trace_char=":";
                        7:trace_char=hex_char(v_intack_pfq_addr[15:12]); 8:trace_char=hex_char(v_intack_pfq_addr[11:8]);
                        9:trace_char=hex_char(v_intack_pfq_addr[7:4]); 10:trace_char=hex_char(v_intack_pfq_addr[3:0]);
                        default:trace_char=" "; endcase
                    1: case (col)
                        0:trace_char="Q"; 1:trace_char="=";
                        2:trace_char=hex_char(v_stop_keyboard_queue_low[7:4]); 3:trace_char=hex_char(v_stop_keyboard_queue_low[3:0]);
                        4:trace_char=":";
                        5:trace_char=hex_char(v_stop_keyboard_queue_high[7:4]); 6:trace_char=hex_char(v_stop_keyboard_queue_high[3:0]);
                        7:trace_char=" "; 8:trace_char="H"; 9:trace_char="=";
                        10:trace_char=hex_char(v_keyboard_head_high[7:4]); 11:trace_char=hex_char(v_keyboard_head_high[3:0]);
                        12:trace_char=hex_char(v_keyboard_head_low[7:4]); 13:trace_char=hex_char(v_keyboard_head_low[3:0]);
                        default:trace_char=" "; endcase
                    2: case (col)
                        0:trace_char="W"; 1:trace_char="=";
                        2:trace_char=hex_char(v_keyboard_tail_write_high[7:4]); 3:trace_char=hex_char(v_keyboard_tail_write_high[3:0]);
                        4:trace_char=":";
                        5:trace_char=hex_char(v_keyboard_tail_write_low[7:4]); 6:trace_char=hex_char(v_keyboard_tail_write_low[3:0]);
                        8:trace_char="R"; 9:trace_char="=";
                        10:trace_char=hex_char(v_keyboard_tail_high[7:4]); 11:trace_char=hex_char(v_keyboard_tail_high[3:0]);
                        12:trace_char=":";
                        13:trace_char=hex_char(v_stop_keyboard_tail[7:4]); 14:trace_char=hex_char(v_stop_keyboard_tail[3:0]);
                        default:trace_char=" "; endcase
                    3: case (col)
                        0:trace_char="A"; 1:trace_char="=";
                        2:trace_char=hex_char(v_ram_tail_write_cpu_high[7:4]); 3:trace_char=hex_char(v_ram_tail_write_cpu_high[3:0]);
                        4:trace_char=":";
                        5:trace_char=hex_char(v_ram_tail_write_cpu_low[7:4]); 6:trace_char=hex_char(v_ram_tail_write_cpu_low[3:0]);
                        8:trace_char="M"; 9:trace_char="=";
                        10:trace_char=hex_char(v_ram_tail_write_sdram_high[7:4]); 11:trace_char=hex_char(v_ram_tail_write_sdram_high[3:0]);
                        12:trace_char=":";
                        13:trace_char=hex_char(v_ram_tail_write_sdram_low[7:4]); 14:trace_char=hex_char(v_ram_tail_write_sdram_low[3:0]);
                        default:trace_char=" "; endcase
                    4: case (col)
                        0:trace_char="Q"; 1:trace_char="=";
                        2:trace_char=hex_char(v_ram_tail_write_queue_cpu_high[7:4]); 3:trace_char=hex_char(v_ram_tail_write_queue_cpu_high[3:0]);
                        4:trace_char=hex_char(v_ram_tail_write_queue_cpu_low[7:4]); 5:trace_char=hex_char(v_ram_tail_write_queue_cpu_low[3:0]);
                        8:trace_char="S"; 9:trace_char="=";
                        10:trace_char=hex_char(v_ram_tail_write_queue_sdram_high[7:4]); 11:trace_char=hex_char(v_ram_tail_write_queue_sdram_high[3:0]);
                        12:trace_char=hex_char(v_ram_tail_write_queue_sdram_low[7:4]); 13:trace_char=hex_char(v_ram_tail_write_queue_sdram_low[3:0]);
                        default:trace_char=" "; endcase
                    5: case (col)
                        0:trace_char="V"; 1:trace_char="=";
                        2:trace_char=hex_char({2'b00, v_ram_tail_write_cpu_valid});
                        3:trace_char=hex_char({2'b00, v_ram_tail_write_sdram_valid});
                        4:trace_char=hex_char({2'b00, v_ram_tail_write_queue_cpu_valid});
                        5:trace_char=hex_char({2'b00, v_ram_tail_write_queue_sdram_valid});
                        8:trace_char="K"; 9:trace_char="=";
                        10:trace_char=v_keyboard_ram_commit_ok ? "O" : "X";
                        11:trace_char=v_keyboard_ram_commit_ok ? "K" : "!";
                        default:trace_char=" "; endcase
                    6: case (col)
                        0:trace_char="C"; 1:trace_char="=";
                        2:trace_char=hex_char(v_rtc_checksum_seen[7:4]); 3:trace_char=hex_char(v_rtc_checksum_seen[3:0]);
                        5:trace_char="I"; 6:trace_char="=";
                        7:trace_char=hex_char({1'b0, v_rtc_index[6:4]}); 8:trace_char=hex_char(v_rtc_index[3:0]);
                        10:trace_char="D"; 11:trace_char="=";
                        12:trace_char=hex_char(v_rtc_checksum_last_data[7:4]); 13:trace_char=hex_char(v_rtc_checksum_last_data[3:0]);
                        default:trace_char=" "; endcase
                    7: case (col)
                        0:trace_char="S"; 1:trace_char="=";
                        2:trace_char=hex_char(v_keyboard_tail_biu_state[7:4]); 3:trace_char=hex_char(v_keyboard_tail_biu_state[3:0]);
                        5:trace_char="U"; 6:trace_char="=";
                        7:trace_char="0"; 8:trace_char=hex_char(v_keyboard_tail_eu_dataout_uaddr[12:8]);
                        9:trace_char=hex_char(v_keyboard_tail_eu_dataout_uaddr[7:4]); 10:trace_char=hex_char(v_keyboard_tail_eu_dataout_uaddr[3:0]);
                        default:trace_char=" "; endcase
                    8: case (col)
                        0:trace_char="R"; 1:trace_char="=";
                        2:trace_char=hex_char(v_irq_return_address[0][19:16]); 3:trace_char=hex_char(v_irq_return_address[0][15:12]);
                        4:trace_char=hex_char(v_irq_return_address[0][11:8]); 5:trace_char=hex_char(v_irq_return_address[0][7:4]);
                        6:trace_char=hex_char(v_irq_return_address[0][3:0]);
                        8:trace_char="Z"; 9:trace_char="=";
                        10:trace_char=hex_char(v_keyboard_tail_eu_dataout_alu[15:12]); 11:trace_char=hex_char(v_keyboard_tail_eu_dataout_alu[11:8]);
                        12:trace_char=hex_char(v_keyboard_tail_eu_dataout_alu[7:4]); 13:trace_char=hex_char(v_keyboard_tail_eu_dataout_alu[3:0]);
                        default:trace_char=" "; endcase
                    // First writes to BDA 041A/1C and 0480/82.  The address
                    // prefix is implicit (04xx) to keep each pair legible.
                    9,10,11,12: case (col)
                        0:trace_char=(line == 9) ? "1" : (line == 10) ? "1" : "8";
                        1:trace_char=(line == 9) ? "A" : (line == 10) ? "C" : (line == 11) ? "0" : "2";
                        2:trace_char="=";
                        3:trace_char=hex_char(v_bda_init_data[(line-9)*2][7:4]); 4:trace_char=hex_char(v_bda_init_data[(line-9)*2][3:0]);
                        5:trace_char=":";
                        6:trace_char=hex_char(v_bda_init_data[(line-9)*2+1][7:4]); 7:trace_char=hex_char(v_bda_init_data[(line-9)*2+1][3:0]);
                        9:trace_char="V"; 10:trace_char="=";
                        11:trace_char=v_bda_init_valid[(line-9)*2] & v_bda_init_valid[(line-9)*2+1] ? "1" : "0";
                        default:trace_char=" "; endcase
                    13: case (col)
                        0:trace_char="A"; 1:trace_char="=";
                        2:trace_char=hex_char(v_keyboard_tail_eu_ax[15:12]); 3:trace_char=hex_char(v_keyboard_tail_eu_ax[11:8]);
                        4:trace_char=hex_char(v_keyboard_tail_eu_ax[7:4]); 5:trace_char=hex_char(v_keyboard_tail_eu_ax[3:0]);
                        7:trace_char="B"; 8:trace_char="=";
                        9:trace_char=hex_char(v_keyboard_tail_eu_bx[15:12]); 10:trace_char=hex_char(v_keyboard_tail_eu_bx[11:8]);
                        11:trace_char=hex_char(v_keyboard_tail_eu_bx[7:4]); 12:trace_char=hex_char(v_keyboard_tail_eu_bx[3:0]);
                        default:trace_char=" "; endcase
                    14: case (col)
                        0:trace_char="F"; 1:trace_char="=";
                        2:trace_char=hex_char(v_stop_keyboard_read_first[7:4]); 3:trace_char=hex_char(v_stop_keyboard_read_first[3:0]);
                        5:trace_char="L"; 6:trace_char="=";
                        7:trace_char=hex_char(v_stop_keyboard_read_data[7:4]); 8:trace_char=hex_char(v_stop_keyboard_read_data[3:0]);
                        default:trace_char=" "; endcase
                    15: case (col)
                        0:trace_char="S";1:trace_char="T";2:trace_char="O";3:trace_char="P";4:trace_char="=";
                        5:trace_char=(v_stop_reason == STOP_IRQ0) ? "I" : (v_stop_reason == STOP_KBUF) ? "K" : "R";
                        6:trace_char=(v_stop_reason == STOP_IRQ0) ? "R" : (v_stop_reason == STOP_KBUF) ? "B" : "U";
                        7:trace_char=(v_stop_reason == STOP_IRQ0) ? "0" : (v_stop_reason == STOP_KBUF) ? "F" : "N";
                        9:trace_char="P";10:trace_char="=";11:trace_char="1";
                        default:trace_char=" "; endcase
                    default:trace_char=" ";
                endcase
            end else begin
            case (line)
                0: case (col)
                    0:trace_char=v_fatal_freeze ? "D" : "E";1:trace_char="=";
                    2:trace_char=hex_char(v_fatal_freeze ? v_stop_address[19:16] : v_exec_address[0][19:16]);3:trace_char=hex_char(v_fatal_freeze ? v_stop_address[15:12] : v_exec_address[0][15:12]);4:trace_char=hex_char(v_fatal_freeze ? v_stop_address[11:8] : v_exec_address[0][11:8]);5:trace_char=hex_char(v_fatal_freeze ? v_stop_address[7:4] : v_exec_address[0][7:4]);6:trace_char=hex_char(v_fatal_freeze ? v_stop_address[3:0] : v_exec_address[0][3:0]);
                    8:trace_char=(v_fatal_freeze && ((v_stop_reason == STOP_KBD) || (v_stop_reason == STOP_KBUF) || v_keyboard_handshake_seen)) ? "B" : "N";
                    9:trace_char="=";
                    10:trace_char=(v_fatal_freeze && ((v_stop_reason == STOP_KBD) || (v_stop_reason == STOP_KBUF) || v_keyboard_handshake_seen)) ? hex_char(v_stop_keyboard_port_b[7:4]) : (v_nmi_seen ? "1" : "0");
                    11:trace_char=(v_fatal_freeze && ((v_stop_reason == STOP_KBD) || (v_stop_reason == STOP_KBUF) || v_keyboard_handshake_seen)) ? hex_char(v_stop_keyboard_port_b[3:0]) : " ";
                    12:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? "T" : ((v_fatal_freeze && (v_stop_reason == STOP_KBD || v_stop_reason == STOP_KBUF)) ? " " : "P");
                    13:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? (v_keyboard_bat_seen ? "1" : "0") : ((v_fatal_freeze && (v_stop_reason == STOP_KBD || v_stop_reason == STOP_KBUF)) ? " " : (v_keyboard_enabled ? "1" : "0")); default:trace_char=" "; endcase
                1: case (col)
                    0:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? "K" : (v_fatal_freeze ? ((v_stop_reason == STOP_IRQ0) ? "I" : "C") : (v_write[0] ? "W" : "R"));
                    1:trace_char="=";
                    2:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? hex_char(v_stop_keyboard_scancode[7:4]) : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_cs[15:12] : v_stop_cs[15:12]) : hex_char(v_port[0][15:12]));
                    3:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? hex_char(v_stop_keyboard_scancode[3:0]) : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_cs[11:8] : v_stop_cs[11:8]) : hex_char(v_port[0][11:8]));
                    4:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? " " : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_cs[7:4] : v_stop_cs[7:4]) : hex_char(v_port[0][7:4]));
                    5:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? "A" : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_cs[3:0] : v_stop_cs[3:0]) : hex_char(v_port[0][3:0]));
                    6:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? "=" : (v_fatal_freeze ? ":" : "=");
                    7:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? hex_char(v_stop_keyboard_port_a[7:4]) : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_pfq_addr[15:12] : v_stop_pfq_addr[15:12]) : hex_char(v_data[0][7:4]));
                    8:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? hex_char(v_stop_keyboard_port_a[3:0]) : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_pfq_addr[11:8] : v_stop_pfq_addr[11:8]) : hex_char(v_data[0][3:0]));
                    9:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? " " : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_pfq_addr[7:4] : v_stop_pfq_addr[7:4]) : " ");
                    10:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? "Q" : (v_fatal_freeze ? hex_char((v_stop_reason == STOP_IRQ0) ? v_intack_pfq_addr[3:0] : v_stop_pfq_addr[3:0]) : "L");
                    11:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? "=" : (v_fatal_freeze ? " " : "=");
                    12:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? hex_char(v_stop_keyboard_queue_low[7:4]) : (v_fatal_freeze ? " " : hex_char(v_loop_count[7:4]));
                    13:trace_char=(v_fatal_freeze && v_keyboard_handshake_seen) ? hex_char(v_stop_keyboard_queue_low[3:0]) : (v_fatal_freeze ? " " : hex_char(v_loop_count[3:0]));
                    default:trace_char=" "; endcase
                2,3,4,5,6,7,8,9,10,11,12,13,14: case (col)
                    0:trace_char="E";1:trace_char=" ";
                    2:trace_char=hex_char(v_exec_address[line-2][19:16]);3:trace_char=hex_char(v_exec_address[line-2][15:12]);4:trace_char=hex_char(v_exec_address[line-2][11:8]);5:trace_char=hex_char(v_exec_address[line-2][7:4]);6:trace_char=hex_char(v_exec_address[line-2][3:0]); default:trace_char=" "; endcase
                15: case (col)
                    0:trace_char="S";1:trace_char="T";2:trace_char="O";3:trace_char="P";4:trace_char="=";
                    5:trace_char=(v_stop_reason == STOP_DATA) ? "D" : (v_stop_reason == STOP_VEC) ? "V" : (v_stop_reason == STOP_PASS) ? "P" : (v_stop_reason == STOP_HOLD) ? "H" : (v_stop_reason == STOP_IRQ0) ? "I" : (v_stop_reason == STOP_KBD || v_stop_reason == STOP_KBUF) ? "K" : "R";
                    6:trace_char=(v_stop_reason == STOP_DATA) ? "A" : (v_stop_reason == STOP_VEC) ? "E" : (v_stop_reason == STOP_PASS) ? "A" : (v_stop_reason == STOP_HOLD) ? "L" : (v_stop_reason == STOP_IRQ0) ? "R" : (v_stop_reason == STOP_KBD) ? "C" : (v_stop_reason == STOP_KBUF) ? "B" : "U";
                    7:trace_char=(v_stop_reason == STOP_DATA) ? "T" : (v_stop_reason == STOP_VEC) ? "C" : (v_stop_reason == STOP_PASS) ? "S" : (v_stop_reason == STOP_HOLD) ? "D" : (v_stop_reason == STOP_IRQ0) ? "0" : (v_stop_reason == STOP_KBD) ? "L" : (v_stop_reason == STOP_KBUF) ? "F" : "N";
                    8:trace_char=(v_stop_reason == STOP_DATA) ? "A" : (v_stop_reason == STOP_PASS) ? "S" : " ";
                    9:trace_char="K";10:trace_char="=";11:trace_char=hex_char((v_fatal_freeze && v_keyboard_handshake_seen) ? v_stop_keyboard_scancode[7:4] : v_keyboard_scancode[7:4]);12:trace_char=hex_char((v_fatal_freeze && v_keyboard_handshake_seen) ? v_stop_keyboard_scancode[3:0] : v_keyboard_scancode[3:0]);
                    default:trace_char=" "; endcase
                default: case (col)
                    0:trace_char=w ? "W" : "R"; 1:trace_char=" ";
                    2:trace_char=hex_char(p[15:12]); 3:trace_char=hex_char(p[11:8]); 4:trace_char=hex_char(p[7:4]); 5:trace_char=hex_char(p[3:0]);
                    7:trace_char="=";
                    8:trace_char=hex_char(d[7:4]); 9:trace_char=hex_char(d[3:0]); default:trace_char=" "; endcase
            endcase
            end
        end
    endfunction

    function [4:0] glyph_row;
        input [7:0] c;
        input [2:0] row;
        begin
            glyph_row = 0;
            case (c)
                "0": case(row)0: glyph_row=5'b01110;1,2: glyph_row=5'b10001;3: glyph_row=5'b10101;4,5: glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "1": case(row)0:glyph_row=5'b00100;1:glyph_row=5'b01100;2,3,4,5:glyph_row=5'b00100;6:glyph_row=5'b01110;endcase
                "2": case(row)0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b00001;3:glyph_row=5'b00010;4:glyph_row=5'b00100;5:glyph_row=5'b01000;6:glyph_row=5'b11111;endcase
                "3": case(row)0:glyph_row=5'b11110;1,2:glyph_row=5'b00001;3:glyph_row=5'b01110;4,5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "4": case(row)0:glyph_row=5'b00010;1:glyph_row=5'b00110;2:glyph_row=5'b01010;3:glyph_row=5'b10010;4:glyph_row=5'b11111;5,6:glyph_row=5'b00010;endcase
                "5": case(row)0:glyph_row=5'b11111;1:glyph_row=5'b10000;2:glyph_row=5'b11110;3,4:glyph_row=5'b00001;5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "6": case(row)0:glyph_row=5'b00110;1:glyph_row=5'b01000;2:glyph_row=5'b10000;3:glyph_row=5'b11110;4,5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "7": case(row)0:glyph_row=5'b11111;1:glyph_row=5'b00001;2:glyph_row=5'b00010;3:glyph_row=5'b00100;4:glyph_row=5'b01000;5,6:glyph_row=5'b01000;endcase
                "8": case(row)0:glyph_row=5'b01110;1,2:glyph_row=5'b10001;3:glyph_row=5'b01110;4,5:glyph_row=5'b10001;6:glyph_row=5'b01110;endcase
                "9": case(row)0:glyph_row=5'b01110;1,2:glyph_row=5'b10001;3:glyph_row=5'b01111;4:glyph_row=5'b00001;5:glyph_row=5'b00010;6:glyph_row=5'b11100;endcase
                "A": case(row)0:glyph_row=5'b01110;1,2:glyph_row=5'b10001;3:glyph_row=5'b11111;4,5,6:glyph_row=5'b10001;endcase
                "B": case(row)0:glyph_row=5'b11110;1,2:glyph_row=5'b10001;3:glyph_row=5'b11110;4,5:glyph_row=5'b10001;6:glyph_row=5'b11110;endcase
                "C": case(row)0:glyph_row=5'b01111;1,2,3,4,5:glyph_row=5'b10000;6:glyph_row=5'b01111;endcase
                "D": case(row)0:glyph_row=5'b11110;1,2,3,4,5:glyph_row=5'b10001;6:glyph_row=5'b11110;endcase
                "E": case(row)0:glyph_row=5'b11111;1,2:glyph_row=5'b10000;3:glyph_row=5'b11110;4,5:glyph_row=5'b10000;6:glyph_row=5'b11111;endcase
                "F": case(row)0:glyph_row=5'b11111;1,2:glyph_row=5'b10000;3:glyph_row=5'b11110;4,5,6:glyph_row=5'b10000;endcase
                "H": case(row)0,1,2,4,5,6:glyph_row=5'b10001;3:glyph_row=5'b11111;endcase
                "I": case(row)0,6:glyph_row=5'b11111;1,2,3,4,5:glyph_row=5'b00100;endcase
                "K": case(row)0,1,5,6:glyph_row=5'b10001;2:glyph_row=5'b10010;3:glyph_row=5'b11100;4:glyph_row=5'b10010;endcase
                "L": case(row)0,1,2,3,4,5:glyph_row=5'b10000;6:glyph_row=5'b11111;endcase
                "N": case(row)0,4,5,6:glyph_row=5'b10001; 1:glyph_row=5'b11001;2:glyph_row=5'b10101;3:glyph_row=5'b10011;endcase
                "O": case(row)0,6:glyph_row=5'b01110;1,2,3,4,5:glyph_row=5'b10001;endcase
                "P": case(row)0:glyph_row=5'b11110;1,2:glyph_row=5'b10001;3:glyph_row=5'b11110;4,5,6:glyph_row=5'b10000;endcase
                "R": case(row)0:glyph_row=5'b11110;1,2:glyph_row=5'b10001;3:glyph_row=5'b11110;4:glyph_row=5'b10100;5:glyph_row=5'b10010;6:glyph_row=5'b10001;endcase
                "S": case(row)0:glyph_row=5'b01111;1,2:glyph_row=5'b10000;3:glyph_row=5'b01110;4,5:glyph_row=5'b00001;6:glyph_row=5'b11110;endcase
                "T": case(row)0:glyph_row=5'b11111;1,2,3,4,5,6:glyph_row=5'b00100;endcase
                "V": case(row)0,1,2,3,4:glyph_row=5'b10001;5:glyph_row=5'b01010;6:glyph_row=5'b00100;endcase
                "W": case(row)0,1,2,3,4:glyph_row=5'b10001;5:glyph_row=5'b10101;6:glyph_row=5'b01010;endcase
                "-": if(row==3) glyph_row=5'b01110;
                "=": if(row==2 || row==4) glyph_row=5'b11111;
                ":": if(row==2 || row==5) glyph_row=5'b00100;
                "@": case(row)0:glyph_row=5'b01110;1:glyph_row=5'b10001;2:glyph_row=5'b10111;3:glyph_row=5'b10101;4:glyph_row=5'b10111;5:glyph_row=5'b10000;6:glyph_row=5'b01111;endcase
            endcase
        end
    endfunction

    // The debug revision owns its output timing.  This deliberately avoids
    // guest EGA DE/sync, which may never begin when POST has stalled.
    // clk_video is 57.27 MHz, so emit a 28.64 MHz pixel enable.
    reg pixel_phase;
    reg [9:0] x;
    reg [9:0] y;
    wire active_video = x < 640 && y < 400;
    // Use power-of-two character cells.  The original temporary overlay used
    // /12 and %6 here, which inferred two hardware dividers in the video
    // clock path and made the debug revision needlessly hard to time-close.
    wire panel = active_video && x >= 8 && x < 232 && y >= 8 && y < 264;
    wire [3:0] text_line = (y - 8) >> 4;
    wire [4:0] text_col = (x - 8) >> 4;
    wire [2:0] text_row = ((y - 8) >> 1) & 3'b111;
    wire [2:0] text_bit = ((x - 8) >> 1) & 3'b111;
    wire [4:0] text_glyph = glyph_row(trace_char(text_line, text_col), text_row);
    wire text_pixel = panel && text_bit < 5 && text_glyph[4-text_bit];

    always @(posedge clk_video) begin
        if (reset) begin
            pixel_phase <= 0;
            x <= 0;
            y <= 0;
            overlay_active <= 0;
            rgb_out <= 0;
            hs_out <= 1;
            vs_out <= 1;
            de_out <= 0;
            ce_out <= 0;
        end else begin
            // This is intentionally sampled in the video domain. It can
            // change only once per reset (when post-key FDC I/O is accepted), so a
            // one-frame display-domain delay is harmless.
            overlay_active <= v_fdc_postkey_active;
            pixel_phase <= ~pixel_phase;
            ce_out <= pixel_phase;
            if (pixel_phase) begin
                de_out <= active_video;
                hs_out <= !((x >= 656) && (x < 752));
                vs_out <= !((y >= 490) && (y < 492));

                if (text_pixel) rgb_out <= 24'h00FF40;
                else if (panel) rgb_out <= 24'h001020;
                else rgb_out <= 0;

                if (x == 910 - 1) begin
                    x <= 0;
                    if (y == 525 - 1) y <= 0;
                    else y <= y + 1'b1;
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end
endmodule
`endif
