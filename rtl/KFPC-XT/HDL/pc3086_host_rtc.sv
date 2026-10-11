// Fresh-configuration-only RTC seed. Deliberately no system reset input:
// guest resets must not replace a guest-set date/time with the host clock.
module pc3086_host_rtc (
    input  wire        clk,
    input  wire [64:0] host_rtc,
    input  wire [15:0] hps_address,
    input  wire [15:0] hps_writedata,
    input  wire        hps_write,
    input  wire        hps_read,
    output wire [15:0] mgmt_address,
    output wire [15:0] mgmt_writedata,
    output wire        mgmt_write,
    output wire        mgmt_read,
    output logic       done = 1'b0
);
    logic toggle_last = 1'b0;
    logic writing = 1'b0;
    logic [4:0] step = 5'd0;
    logic [55:0] calendar = 56'd0;
    wire [7:0] seconds = calendar[7:0];
    wire [7:0] minutes = calendar[15:8];
    wire [7:0] hours   = calendar[23:16];
    wire [7:0] day     = calendar[31:24];
    wire [7:0] month   = calendar[39:32];
    wire [7:0] year    = calendar[47:40];
    wire [7:0] weekday = calendar[55:48] + 8'd1;
    wire [7:0] checksum = minutes + hours + weekday + day + month + year + 8'h20;

    function automatic valid_bcd(input [7:0] value, input [7:0] low, input [7:0] high);
        valid_bcd = value[3:0] <= 4'd9 && value[7:4] <= 4'd9 && value >= low && value <= high;
    endfunction

    // Main_MiSTer user_io.cpp send_rtc(): BCD sec/min/hour/day/month/year,
    // binary weekday (Sunday=0), flags. hps_io toggles bit 64 after receipt.
    wire valid_calendar = valid_bcd(host_rtc[7:0],   8'h00, 8'h59) &&
                          valid_bcd(host_rtc[15:8],  8'h00, 8'h59) &&
                          valid_bcd(host_rtc[23:16], 8'h00, 8'h23) &&
                          valid_bcd(host_rtc[31:24], 8'h01, 8'h31) &&
                          valid_bcd(host_rtc[39:32], 8'h01, 8'h12) &&
                          valid_bcd(host_rtc[47:40], 8'h00, 8'h99) &&
                          host_rtc[55:48] <= 8'd6;

    always @(posedge clk) begin
        toggle_last <= host_rtc[64];
        if (!done && !writing && (host_rtc[64] != toggle_last) && valid_calendar) begin
            calendar <= host_rtc[55:0];
            writing <= 1'b1;
            step <= 5'd0;
        end else if (writing) begin
            if (step == 5'd17) begin
                writing <= 1'b0;
                done <= 1'b1;
            end else step <= step + 5'd1;
        end
    end

    logic [7:0] address;
    logic [7:0] data;
    always @* begin
        address = 8'h00;
        data = 8'h00;
        case (step)
             0: begin address = 8'h0B; data = 8'h02; end // BCD, 24-hour, no IRQs
             1: begin address = 8'h0A; data = 8'h26; end // normal divider/rate
             2: begin address = 8'h00; data = seconds; end
             3: begin address = 8'h02; data = minutes; end
             4: begin address = 8'h04; data = hours; end
             5: begin address = 8'h06; data = weekday; end
             6: begin address = 8'h07; data = day; end
             7: begin address = 8'h08; data = month; end
             8: begin address = 8'h09; data = year; end
             9: begin address = 8'h0E; data = minutes; end
            10: begin address = 8'h0F; data = hours; end
            11: begin address = 8'h10; data = weekday; end
            12: begin address = 8'h11; data = day; end
            13: begin address = 8'h12; data = month; end
            14: begin address = 8'h13; data = year; end
            15: begin address = 8'h14; data = 8'h20; end
            16: begin address = 8'h32; data = 8'h20; end
            17: begin address = 8'h15; data = checksum; end
            default: begin end
        endcase
    end

    // Waiting for HPS does not monopolize the disk/management bus. During
    // the 18 startup writes the machine is still held in reset by !done.
    assign mgmt_address   = writing ? {8'hF4, address} : hps_address;
    assign mgmt_writedata = writing ? {8'h00, data} : hps_writedata;
    assign mgmt_write     = writing ? 1'b1 : hps_write;
    assign mgmt_read      = writing ? 1'b0 : hps_read;
endmodule
