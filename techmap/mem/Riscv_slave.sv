`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Karlsruhe institute of technology
// Engineer: Mina Nakhla
// Create Date: 05/18/2023 03:49:04 PM
// Design Name: Riscv Slave Peripheral
// Module Name: Riscv_slave
// Target Devices: VC707
// Tool Versions: Vivado 2022
// Description: This is Riscv slave peripheral that takes input 64 bits data vectors until it is full. 
//////////////////////////////////////////////////////////////////////////////////
//First implementation
module Riscv_slave #(
    parameter integer abits = 4,
    parameter integer log2_dbytes = 3,  // 2^log2_dbytes = number of bytes on data bus
    parameter init_file = ""
)
(
    input clk,
    input [0:abits-1] address,
    input w_enable,
    input [0:8*(2**log2_dbytes)-1] w_data,
    output logic [0:(8*2**log2_dbytes)-1]  r_data        
);
    localparam data_bytes = 2**log2_dbytes;
    localparam data_bits = 8*data_bytes;
    localparam slave_peripheral_width = data_bits; 
    typedef logic [0:slave_peripheral_width-1] register [0:abits-1]; 
    register slave_peripheral;
    logic [0:data_bits-1] test_signal;
    always_ff @(posedge clk) begin
        if(w_enable == 1'b1) begin
            slave_peripheral[address] <= w_data;
            test_signal <= w_data;
        end else begin
            test_signal <= slave_peripheral[address];
        end
    end 
    assign r_data = test_signal; 
endmodule


//Second implementation same as internal ram
//(* dont_touch="true" *) module Riscv_slave
//#(
//    parameter abits = 4,
//    parameter dbits = 64
//)
//(
//    input                      i_clk,
//    input [abits - 1:0]        i_addr,
//    output logic [dbits - 1:0] o_rdata,
//    input                      i_wena,
//    input [dbits - 1:0]        i_wdata
//);
//logic [dbits - 1:0] r_data;
//(* ram_style="distributed" *) logic [dbits - 1:0] ram [0 : 2 ** abits - 1];
//always_ff @(posedge i_clk)
//begin: main_proc
//    if(i_wena == 1'b1) begin
//        ram[i_addr] <= i_wdata;
//        r_data <= i_wdata;
//    end else
//        r_data <= ram[i_addr];
//end: main_proc

//assign o_rdata = r_data;
//endmodule

//Third implementation as SRAM_8_inferred
//module Riscv_slave #(
//    parameter integer abits = 4,
//    parameter integer byte_idx = 0,
//    parameter init_file = ""
//)
//(
//    input clk,
//    input [abits-1 : 0] address,
//    output logic [7:0] rdata,
//    input we,
//    input [7:0] wdata
//);

//localparam integer slave_length = 2**abits;

// romimage only 256 KB, but SRAM is 512 KB so we initialize one
// half of sram = 32768 * 8 = 256 KB

//const integer FILE_IMAGE_LINES_TOTAL = 32768;

//typedef logic [7:0] ram_type [0 : slave_length-1];

//ram_type ram;
//logic [7 : 0] read_data;

//function init_ram(input file_name);
// logic [63:0] temp_mem [0 : slave_length-1];
// $readmemh(init_file, temp_mem);
// for (int i = 0; i < slave_length; i++)
//  case(byte_idx)
//   0: ram[i] = temp_mem[i][0  +: 8];
//   1: ram[i] = temp_mem[i][8  +: 8];
//   2: ram[i] = temp_mem[i][16 +: 8];
//   3: ram[i] = temp_mem[i][24 +: 8];
//   4: ram[i] = temp_mem[i][32 +: 8];
//   5: ram[i] = temp_mem[i][40 +: 8];
//   6: ram[i] = temp_mem[i][48 +: 8];
//   7: ram[i] = temp_mem[i][56 +: 8];
//   default: ram[i] = temp_mem[i][0 +: 8];
//  endcase
//endfunction

//! @warning SIMULATION INITIALIZATION
//initial begin
// void'(init_ram(init_file));
//end

//always_ff@(posedge clk)
//begin
//  if (we) begin
//    ram[address] <= wdata;
//    read_data <= wdata;
//  end else
//    read_data <= ram[address];

//end

//assign rdata = read_data;

//`ifdef DISPLAY_MEMORY_INSTANCE_INFORMATION
//initial begin 
//  $display("");
//  $display("****************************************************");
//  $display("sram8_inferred_init ********************************");
//  $display("unique_tag = sram8_inferred_init_W%0d_D%0d_C%0d", 8, 2**abits, (2**abits)*8);
//  $display("****************************************************");
//  $display("full path     =  %m");
//  $display("abits         =  %d",abits);
//  $display("Summary ********************************************");
//  $display("Width         =  %d",8);
//  $display("Depth         =  %d",2**abits);
//  $display("Capacity      =  %d bits",(2**abits)*8);  
//  $display("****************************************************");
//  $display("");
//end
//`endif

//endmodule