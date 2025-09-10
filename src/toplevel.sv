`timescale 1ns / 1ps


module toplevel(
    input logic clk1,
    input logic rst,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic VGA_HS,
    output logic VGA_VS
    );
    
    
    
    //clocking wizard stuff
        logic clk_pix_locked;
        logic clk_pix;
        logic sys_clk;
    clk_wiz_0 clock_inst0 ( //25.2 Mhz
    .clk_out1(clk_pix),
    .clk_out2(sys_clk), //21.5
     .clk_in1(clk1),
     .locked(clk_pix_locked),
     .reset(rst)
     ); 
     
     
     
     
  ;
    
    
    logic [3:0] cpu_clk_divider;
logic cpu_clk;

always_ff @(posedge sys_clk) begin
    if (rst) begin
        cpu_clk_divider <= 0;
        cpu_clk <= 0;
    end else begin
        if (cpu_clk_divider == 6) begin  // Divide by 6 → ~3.58 MHz
            cpu_clk_divider <= 0;
            cpu_clk <= ~cpu_clk;         // Toggle → ~1.79 MHz
        end else begin
            cpu_clk_divider <= cpu_clk_divider + 1;
        end
    end
end
    //cpu logic 
    logic [15:0] cpu_addr;
    logic [7:0] cpu_datain;
    logic [7:0] cpu_dout;
    logic WE;
    logic IRQ;
    logic NMI;
    logic RDY;
    logic [7:0] databus;
    cpu cpu(
        .clk(cpu_clk), //21.47 MHz
        .reset(rst),
        .AB(cpu_addr), //16
        .DI(cpu_datain), //8
        .DO(cpu_dout), //8
        .WE(WE),
        .IRQ(IRQ),
        .NMI(NMI),
        .RDY(RDY)
        );
    logic [15:0] ram_addr;
    
    logic [7:0] ram_dout;
   cpu_ram cpu_ram(
        .clk(cpu_clk),
        .rst(rst),
        .addr(ram_addr),
        .data_in(cpu_dout),
        .we(WE),
        .data_out(ram_dout)
        );
    logic prg_ena;
    logic [14:0] prg_addr;
    logic [7:0] prg_data;
    prg_rom prg_rom(
        .clk(cpu_clk),
        .ena(prg_ena),
        .addr(prg_addr),
        .data(prg_data)
        );
  //ppu stuff
    logic [7:0] ppu_dout, ppu_din;
    logic [15:0] ppu_addr;
    logic [9:0] sx, sy;
    logic hsync, vsync, de;
    logic [1:0] nes_pixel;
ppu ppu1 (
    .clk(sys_clk),              // Or pixel clock if you run PPU at 25 MHz
    .cpu_clk(cpu_clk),
    .rst(rst),
    .reg_selc(cpu_addr[2:0]),
    .data_in(cpu_dout),
    .read_write(WE),
    .data_out(ppu_dout),
    .pixel(nes_pixel),          // 2-bit NES pixel
    .sx(sx),
    .sy(sy),
    .nmi(NMI)

);    
      always_comb begin
        ram_addr = cpu_addr & 16'h07FF;
        prg_addr = cpu_addr - 16'h8000;
        ppu_addr = cpu_addr;
        ppu_din = cpu_dout;
        
        
        if (cpu_addr < 16'h2000) begin
        databus = ram_dout;
        prg_ena = 0;
        end else if (cpu_addr < 16'h4000) begin
        databus = ppu_dout;
        prg_ena = 0;
        end else if (cpu_addr >= 16'h8000) begin
        databus = prg_data;
        prg_ena = 1;
        end else begin
        databus = 8'hFF;
        prg_ena = 0;
        end
    end
        
        always_comb begin 
            if(WE) cpu_datain = cpu_dout; //writing
            else cpu_datain = databus; //reading
        end
 
    
    logic [7:0] ppu_pixel_rgb;

    always_comb begin
        case (nes_pixel)
            2'b00: ppu_pixel_rgb = 8'h00; // black
            2'b01: ppu_pixel_rgb = 8'h55; // dark gray
            2'b10: ppu_pixel_rgb = 8'hAA; // light gray
            2'b11: ppu_pixel_rgb = 8'hFF; // white
        endcase
    end
    
ppu_to_vga vga_inst (
    .clk(clk_pix),
    .rst(rst),
    .ppu_pixel(nes_pixel),  // 2-bit NES pixel
    .ppu_x(sx),
    .ppu_y(sy),

    .vga_r(VGA_R),
    .vga_g(VGA_G),
    .vga_b(VGA_B),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS)
);

    
    
   
 
endmodule
