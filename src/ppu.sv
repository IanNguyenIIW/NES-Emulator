
module ppu (
    input logic clk, //21.48 MHz clock
    
    input logic cpu_clk,
    input logic rst,
     
    
    

    input logic [2:0] reg_selc, //tied to corresponding cpu addr pins
    input logic [7:0] data_in,
    input logic read_write, //0==write ; 1==read
    output logic [7:0] data_out,
    //also some CS signal ehh 
    output logic [1:0] pixel,
    output logic [9:0] sx,
    output logic [9:0] sy,
    
    output logic nmi
    
);

    logic [7:0] PPUCTRL; //VPHB SINN write 
    logic [7:0] PPUMASK;
    logic [7:0] PPUSTATUS;
    logic [7:0] OAMADDR;
    logic [7:0] OAMDATA;
    logic [7:0] PPUSCROLL;
    logic [15:0] PPUADDR;
    logic [7:0] PPUDATA;
    logic [7:0] OAMDMA;
    
    logic [7:0] read_data; //TODO
    logic [7:0] ppu_bus;
    logic [7:0] vram_read;
    logic [15:0] addr_final;
    logic [12:0] pattern_addr;
    logic [7:0] pattern_data;
    
    logic w_toggle, inc_addr; 
    logic [7:0] x_scroll, y_scroll; // part of PPUSCROLL
    //internal registers
    logic [14:0] v_reg, t_reg;
    logic [2:0] x_reg;
    //
    logic ppu_access; 
    logic [13:0] vram_addr_ppu;
    logic rendering_enabled; 
    logic [7:0] tile_id;
    //control signals
    logic ppu_wren;
    
    always_ff @(posedge clk)begin
    
    
        if(inc_addr)begin
            if(PPUCTRL[2]) begin
                addr_final <= addr_final + 16'd32;
            end
            else begin
                addr_final <= addr_final + 1;
            end
            inc_addr <= 0;
        end
    
    
    
        //update registers based on addr and ppudata
        if(~read_write) begin //WRITING
            case(reg_selc)
            3'd0: begin //PPUCTRL
                PPUCTRL <= data_in;
                t_reg[11:10] <= data_in[1:0]; 
            end
            3'd1: begin //PPUSTATUS
                PPUMASK <= data_in; 
            end
           
            3'd3: begin //
                OAMADDR <= data_in;
            end
            3'd4: begin
                OAMDATA <= data_in;
                OAMADDR <= OAMADDR + 1'd1;
            end
            3'd5: begin //PPUSCROLL
                if(~w_toggle)begin
                    x_scroll <= data_in;
                    t_reg[4:0] <= data_in[7:3];
                    x_reg <= data_in[2:0];
                    w_toggle <= 1'b1;
                    
                end
                else begin
                    y_scroll <= data_in;
                    t_reg[9:5] <= data_in[7:3];
                    t_reg[14:12] <= data_in[2:0];
                    t_reg[11:10] <= PPUCTRL[1:0]; 
                    w_toggle <= 1'b0; //NVM might be redundant because in code the PPUSCROLL is always read(clearing w reg) before writes to PPU regs
                    
                    
                end
                  
            end
            3'd6: begin //ADDR
                if(~w_toggle)begin
                    PPUADDR[15:8] <= data_in;
                    t_reg[13:8] <= data_in[5:0];
                    t_reg[14] <= 0;
                    w_toggle <= 1'b1;
                end
                else begin
                    PPUADDR[7:0] <= data_in;
                    t_reg[7:0] <= data_in;
                    v_reg <= t_reg;
                    w_toggle <= 1'b0; //might be redundant because in code the PPUSCROLL is always read(clearing w reg) before writes to PPU regs
                    addr_final <= {PPUADDR[15:8], data_in};
                end
            end
            3'd7: begin //DATA
                ppu_wren <= 1;
                PPUDATA <= data_in;
                inc_addr <= 1;
            end
            
        endcase
        end
        else begin//READING
            case(reg_selc)
            3'd2: begin
                data_out <= PPUSTATUS;
                w_toggle <= 0;
                PPUSTATUS[7] <= 0;
            end
            3'd4: begin
                //data_out <= oam_readdata;  //
            
            end
            3'd7: begin
                
                data_out <= read_data;
                inc_addr <= 1;
            end
            endcase
        end
    end

    /* MEMORY MAPPING*/
    logic [13:0] chr_addr0;
    logic [7:0] chr_data;
    chr_rom chr_rom( //0x0000 - 0x1FFF Pattern memory
        .clk(clk),
        .ena(1),
        .addr(chr_addr0),
        .data(chr_data)
        );
    logic vram_en;
    vram vram(  //0x2000 - 0x3EFF
        .clk(ppu_clk),
        .rst(rst),
        .addr(ppu_access ? vram_addr_ppu : addr_final[13:0]),
        .data_in(PPUDATA),
        .we(ppu_access ? 1'b0 : vram_en),
        .data_out(vram_read)
        );
    
    parameter HA_END = 255; //256x240
    parameter HS_STA = HA_END + 16;
    parameter HS_END = HS_STA + 96;
    parameter LINE = 340;
    
    parameter VA_END = 239;           // end of active pixels
    parameter VS_STA = VA_END + 10;   // sync starts after front porch
    parameter VS_END = VS_STA + 2;    // sync ends
    parameter SCREEN = 260;           // last line on screen (after back porch)
    
    
  
    // calculate horizontal and vertical screen position
    always_ff @(posedge clk) begin
        if (sx == LINE) begin  // last pixel on line?
            sx <= 0;
            sy <= (sy == SCREEN) ? 0 : sy + 1;  // last line on screen?
        end else begin
            sx <= sx + 1;
        end
        if (rst) begin
            sx <= 0;
            sy <= 0;
        end
    end
    
    typedef enum logic [7:0] { //fsm
    
        FETCH,
        DECODE,
        EXECUTE,
        MEM_READ,
        MEM_WRITE,
        IMM
    } state_t;
    
    logic vblank_flag;
    always_ff @(posedge clk) begin
        if (sy == VS_STA && sx == 1 && rendering_enabled) begin
            PPUSTATUS[7] <= 1;  // set VBlank
        end
        else if (read_write && reg_selc == 3'd2) begin
            PPUSTATUS[7] <= 0;  // clear on CPU read
        end
    end
    always_comb begin
        nmi = PPUSTATUS[7];
    
    end
    
    assign vram_addr_ppu = v_reg[13:0]; // for internal PPU reads
    logic [2:0] fine_y;
    assign fine_y = v_reg[14:12];
   always_comb begin
        // Default values
        chr_addr0 = 13'd0;
        vram_en   = 1'b0;
        rendering_enabled = PPUMASK[3] || PPUMASK[4];
        ppu_access = rendering_enabled;
        // CPU-initiated access
        if(rendering_enabled) begin
            case (sx % 8)
            5: begin // pattern_low fetch
                chr_addr0 = {
                    PPUCTRL[4],        // Pattern table select: 0=$0000, 1=$1000
                    tile_id,           // Tile index from nametable
                    fine_y             // Row within the tile
                };
            end
            7: begin // pattern_high fetch
                chr_addr0 = {
                    PPUCTRL[4],        // Pattern table select
                    tile_id,
                    fine_y
                } + 8; // High byte is 8 bytes after the low byte
            end
            default: begin
                chr_addr0 = 0; // idle
            end
        endcase
        
            
        end
        else begin
            if (addr_final <= 16'h1FFF) begin
                chr_addr0 = addr_final[12:0]; // Pattern table access from CPU
            end else if (addr_final >= 16'h2000 && addr_final <= 16'h3EFF) begin
                vram_en = ppu_wren; // CPU write to name tables
            end
        end
        // PPU rendering logic will use v_reg separately for fetches
    end
    
    
    always_ff @(clk) begin //read/write from internal memory chr/vram
        if (16'h000 <= addr_final && addr_final <= 16'h1FFF) begin
            
		  ppu_bus <= chr_data;
		  
	       end 
	       else if (16'h2000 <= addr_final && addr_final <= 16'h3EFF) begin
	           ppu_bus <= vram_read;
	       
	       
	       end
    end
    
    logic [7:0] attribute_byte;
    logic [7:0] pattern_low, pattern_high;
    logic [15:0] bg_shift_pattern_low, bg_shift_pattern_high;
    
    
    always_ff @(posedge clk) begin
        if (rendering_enabled  && sx < 256 && sy < 240) begin
        bg_shift_pattern_low  <= {bg_shift_pattern_low[14:0], 1'b0};
        bg_shift_pattern_high <= {bg_shift_pattern_high[14:0], 1'b0};
    end
        if (rendering_enabled && (sx % 8) == 1 && sy < 240) begin
        // Compute address of nametable entry from v_reg
        tile_id <= vram_read;
        end else if ((sx % 8) == 3 && sy < 240) begin
        // Attribute table fetch
        attribute_byte <= vram_read;
        end else if (rendering_enabled && (sx % 8) == 5 && sy < 240) begin
        // Pattern low byte fetch
        pattern_low <= chr_data;
        end else if (rendering_enabled && (sx % 8) == 7 && sy < 240) begin
        // Pattern high byte fetch and reload shift registers
        pattern_high <= chr_data;
        bg_shift_pattern_low <= {bg_shift_pattern_low[7:0], pattern_low};
        bg_shift_pattern_high <= {bg_shift_pattern_high[7:0], pattern_high};
        end
        if (rendering_enabled && (sx % 8 == 0)) begin
            increment_horizontal();
end
   if (rendering_enabled && sx == 256 && sy < 240) begin
    increment_vertical();
end
    
    if (sy == 261 && sx == 304) begin
    v_reg <= t_reg;
end
    end
    task automatic increment_horizontal(); //increments on every 8th dot
        if (v_reg[4:0] == 5'd31) begin
            v_reg[4:0]  <= 5'd0;
            v_reg[10]   <= ~v_reg[10];
        end else begin
            v_reg[4:0]  <= v_reg[4:0] + 1;
    end
endtask

task automatic increment_vertical(); //happends on dot 256 
        if (v_reg[14:12] != 3'b111) begin
            
            v_reg[14:12]   <= v_reg[14:12] + 1;
        end else begin
            
            if(v_reg[9:5] == 5'd29) begin
                v_reg[9:5] <= 5'b00000;
                v_reg[11]  <= ~v_reg[11];
            
            end
            else if(v_reg[9:5] == 5'd31)begin
                v_reg[9:5] <= 5'b00000;
            end
            else begin
                 v_reg[9:5] <=  v_reg[9:5] + 1;
            end
            
    end
endtask




assign pixel = {bg_shift_pattern_high[15], bg_shift_pattern_low[15]};
endmodule
