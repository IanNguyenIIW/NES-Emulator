`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/05/2025 03:51:54 AM
// Design Name: 
// Module Name: chr_rom
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module chr_rom(
 input logic clk,
   
     input logic ena,
     input logic [12:0] addr,
     output logic [7:0] data
    );
    
    logic [7:0] mem [0:8191];
    
    
     initial $readmemh("chr_rom.hex", mem);
     
     always_ff @(posedge clk) begin
        if (ena)
            data <= mem[addr];
    end
endmodule
