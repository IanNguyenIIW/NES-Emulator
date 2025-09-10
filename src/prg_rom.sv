`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: prg_rom
// Description: Donkey Kong 16 KiB PRG-ROM with $C000-$FFFF mirroring
//////////////////////////////////////////////////////////////////////////////////

module prg_rom (
    input  logic        clk,
    input  logic        ena,
    input  logic [14:0] addr,     // 0x0000-0x7FFF for mapped $8000-$FFFF
    output logic [7:0]  data
);

    // 16 KiB PRG-ROM = 2^14 = 16384
    logic [7:0] mem [0:16383];    // 16 KiB
    logic [13:0] rom_addr;

    // Mirror $C000-$FFFF to $8000-$BFFF
    always_comb begin
        // Only 16 KiB => mask to 14 bits
        rom_addr = addr[13:0];  // mask off upper bit
    end

    initial $readmemh("prg_rom.hex", mem);

    always_ff @(posedge clk) begin
        if (ena)
            data <= mem[rom_addr];
    end

endmodule
