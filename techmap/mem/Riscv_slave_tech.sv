`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Karlsruhe institute for technology
// Engineer: Mina Nakhla
// Create Date: 05/18/2023 10:10:34 PM
// Design Name: Riscv slave technology
// Module Name: Riscv_slave_tech
// Target Devices: VC707
// Tool Versions: Vivado 2022
//////////////////////////////////////////////////////////////////////////////////

module Riscv_slave_tech #(
    //parameter integer abits = 3,      // for first implementation
    parameter integer abits = 4,      
    parameter integer log2_dbytes = 3,  // 2^log2_dbytes = number of bytes on data bus
    parameter init_file = ""
    )
    (
    input clk,
    input logic [abits-1 : 0] addr,                 //input address 2 bits
    output logic [8*(2**log2_dbytes)-1 : 0] rdata,  //output read data 64 bits through the data bus
    input w_enable,                                 //input write enable
    input [(2**log2_dbytes)-1 : 0] wstrb,           //wstrb stands for write-strobe if any bit of wstrb is 1 it means that it is write not read
    input [8*(2**log2_dbytes)-1 : 0] wdata          //input data 64 bits to be written in the sram.
    //output [abits-1:0] o_address
);
    import config_target_pkg::*;
    localparam integer dbytes = (2**log2_dbytes);
    localparam integer dbits = 8*dbytes;
    logic [dbytes-1 : 0] wr_ena;
    logic write_enable;

//   My first implementation    
//   generate if (init_file == "") begin : i2
//      for (genvar n = 0; n <= dbytes-1; n++) begin : rx
//        assign wr_ena[n] = w_enable & wstrb[n];
                 
//      Riscv_slave #(
//          //.abits(abits-log2_dbytes),  // address bits = 3
//          .abits(abits),
//          .log2_dbytes(0), //1 byte in each cell of the new slave peripheral
//          .init_file(init_file)
//      ) new_slave (
//          .clk(clk), 
//          //.address(addr[abits-1:log2_dbytes]), // the memory architecture for a big memory "columns" of bytes. 
//          .address(addr),          
//          .r_data(rdata[8*n+:8]), //take slices of rdata vector which is input from the bus 64 bits of data and each slice is 8 bits.
//          .w_enable(wr_ena[n]),
//          .w_data(wdata[8*n+:8])
//         // .o_address(o_address)
          
//      );
//   end : rx
//  end : i2
//endgenerate

// My second implementation 1 register 64 bits 
     for(genvar n = 0 ; n<= dbytes-1;n++) begin : assigning_wenable_of_slave
        assign wr_ena[n] = w_enable & wstrb[n];
     end
     
     always_comb begin
      integer i;
      for(i = 0 ; i<= dbytes-1; i++) begin
            if(wr_ena[i] == 0) begin
                write_enable = 1'b0;
                break;
            end else begin
                write_enable = 1'b1;
            end               
      end 
     end
     //assign write_en = write_enable;
     
      Riscv_slave #(          
          .abits(abits),
          .log2_dbytes(log2_dbytes), 
          .init_file(init_file)
      ) new_slave (
          .clk(clk), 
          .address(addr),  
          .r_data(rdata), 
          .w_enable(write_enable),
          .w_data(wdata)
        );

//Third implmentation same as sram
//module Riscv_slave_tech #(    
//    parameter integer abits = 4,
//    parameter integer log2_dbytes = 3,  // 2^log2_dbytes = number of bytes on data bus
//    parameter init_file = ""
//)
//(
//    input clk,
//    input logic [abits-1 : 0] addr,                 //input address 18 bits
//    output logic [8*(2**log2_dbytes)-1 : 0] rdata,  //output read data 64 bits through the data bus
//    input we,                                       //input write enable
//    input [(2**log2_dbytes)-1 : 0] wstrb,           //wstrb stands for write-strobe if any bit of wstrb is 1 it means that it is write not read
//    input [8*(2**log2_dbytes)-1 : 0] wdata          //input data 64 bits to be written in the sram.
//);

//import config_target_pkg::*;

//! reduced name of configuration constant:

//localparam integer dbytes = (2**log2_dbytes);
//localparam integer dbits = 8*dbytes;

//logic [dbytes-1 : 0] wr_ena;

//generate if (init_file == "") begin : i1
//   for (genvar n = 0; n <= dbytes-1; n++) begin : rx
//      assign wr_ena[n] = we & wstrb[n];
                  
//      ram_tech #(
//          .abits(abits-log2_dbytes),
//          .dbits(8)
//      ) new_slave (
//          .i_clk(clk), 
//          .i_addr(addr[abits-1:log2_dbytes]),
//          .o_rdata(rdata[8*n+:8]),
//          .i_wena(wr_ena[n]), 
//          .i_wdata(wdata[8*n+:8])
//      );
//   end : rx
//  end : i1
//endgenerate    

//fourth implementation 
//generate if (init_file != "") begin : i2
//   for (genvar n = 0; n <= dbytes-1; n++) begin : rx
//      assign wr_ena[n] = we & wstrb[n];
                  
//      Riscv_slave #(
//          .abits(abits-log2_dbytes),
//          .byte_idx(n),
//          .init_file(init_file)
//      ) x0 (
//          .clk(clk), 
//          .address(addr[abits-1:log2_dbytes]), //configure a memory of 64 bits splitted in 8 bits each 8 bits have the same MSBS but different 
//                                               //LSBS,so he is ignoring the last 3 bits to store the 64 bits in the same address and by using 
//                                               //a multiplexer you can use the last 3 bits to read a byte/2 bytes/word/doubleword 
//          .rdata(rdata[8*n+:8]),
//          .we(wr_ena[n]),
//          .wdata(wdata[8*n+:8])
//      );
//   end : rx
//  end : i2
//endgenerate
endmodule