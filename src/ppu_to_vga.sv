`timescale 1ns / 1ps

module ppu_to_vga (
    input  logic        clk,           // 25.175 MHz pixel clock
    input  logic        rst,
    input  logic [1:0]  ppu_pixel,     // 2-bit NES pixel
    input  logic [9:0]  ppu_x,         // 0-255
    input  logic [9:0]  ppu_y,         // 0-239

    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b,
    output logic        VGA_HS,
    output logic        VGA_VS
);

    // VGA timing constants for 640x480 @ 60Hz
    localparam H_VISIBLE_AREA   = 640;
    localparam H_FRONT_PORCH    = 16;
    localparam H_SYNC_PULSE     = 96;
    localparam H_BACK_PORCH     = 48;
    localparam H_TOTAL          = H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    localparam V_VISIBLE_AREA   = 480;
    localparam V_FRONT_PORCH    = 10;
    localparam V_SYNC_PULSE     = 2;
    localparam V_BACK_PORCH     = 33;
    localparam V_TOTAL          = V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    logic [9:0] h_cnt = 0;
    logic [9:0] v_cnt = 0;

    // Sync pulse logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    // Generate sync signals
    assign VGA_HS = ~(h_cnt >= H_VISIBLE_AREA + H_FRONT_PORCH &&
                      h_cnt <  H_VISIBLE_AREA + H_FRONT_PORCH + H_SYNC_PULSE);

    assign VGA_VS = ~(v_cnt >= V_VISIBLE_AREA + V_FRONT_PORCH &&
                      v_cnt <  V_VISIBLE_AREA + V_FRONT_PORCH + V_SYNC_PULSE);

    // Scaled NES pixel coordinates
    logic [9:0] scaled_x = ppu_x * 2;
    logic [9:0] scaled_y = ppu_y * 2;

    // RGB output logic
    logic [3:0] pixel_r, pixel_g, pixel_b;

    always_comb begin
        unique case (ppu_pixel)
            2'b00: begin pixel_r = 4'd0;  pixel_g = 4'd0;  pixel_b = 4'd0;  end // black
            2'b01: begin pixel_r = 4'd5;  pixel_g = 4'd5;  pixel_b = 4'd5;  end // dark gray
            2'b10: begin pixel_r = 4'd10; pixel_g = 4'd10; pixel_b = 4'd10; end // light gray
            2'b11: begin pixel_r = 4'd15; pixel_g = 4'd15; pixel_b = 4'd15; end // white
            default: begin pixel_r = 4'd0; pixel_g = 4'd0; pixel_b = 4'd0; end
        endcase
    end

    // Draw each NES pixel as 2x2 block
    always_comb begin
        if (h_cnt >= scaled_x && h_cnt < scaled_x + 2 &&
            v_cnt >= scaled_y && v_cnt < scaled_y + 2) begin
            vga_r = pixel_r;
            vga_g = pixel_g;
            vga_b = pixel_b;
        end else begin
            vga_r = 4'd0;
            vga_g = 4'd0;
            vga_b = 4'd0;
        end
    end

endmodule
