`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/11/2025 08:26:23 PM
// Design Name: 
// Module Name: vram
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


module cpu_ram(
        input logic clk,
        input logic rst,
        input logic [10:0] addr,
        input logic [7:0] data_in,
        input logic we,
        
        output logic [7:0] data_out
        
    );
    
     logic [7:0] mem [2047:0];
     
    
     
     
     always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
        data_out <= mem[addr];
    end

    
endmodule
