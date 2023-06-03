//!
//! Copyright 2019 Sergey Khabarov, sergeykhbr@gmail.com
//!
//! Licensed under the Apache License, Version 2.0 (the "License");
//! you may not use this file except in compliance with the License.
//! You may obtain a copy of the License at
//!
//!     http://www.apache.org/licenses/LICENSE-2.0
//!
//! Unless required by applicable law or agreed to in writing, software
//! distributed under the License is distributed on an "AS IS" BASIS,
//! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//! See the License for the specific language governing permissions and
//! limitations under the License.
//!

module axi4_sram
#(
    parameter int async_reset = 0,
    parameter int abits = 17,
    parameter init_file = ""
)
(
    input clk,
    input nrst,
    input types_amba_pkg::mapinfo_type i_mapinfo,
    output types_amba_pkg::dev_config_type cfg,
    input types_amba_pkg::axi4_slave_in_type i,
    output types_amba_pkg::axi4_slave_out_type o,
    output [0:abits-1] w_req_addr,              //added test signals
    output [63:0] r_data,                       //added test signals
    output w_req,                               //added test signals
    output [7:0] w_wstrb,                       //added test signals
    output [63:0] w_data                        //added test signals
);

import types_amba_pkg::*;

logic w_req_valid;
logic [CFG_SYSBUS_ADDR_BITS-1:0] wb_req_addr;         //48 bits
logic [7:0] wb_req_size;
logic w_req_write; 
logic [CFG_SYSBUS_DATA_BITS-1:0] wb_req_wdata;       //64 bits
logic [CFG_SYSBUS_DATA_BYTES-1:0] wb_req_wstrb;      //8 bits
logic w_req_last;
logic [CFG_SYSBUS_DATA_BITS-1:0] wb_rdata;           //64 bits
assign w_req_addr = wb_req_addr;            //assign test signals
assign r_data = wb_rdata;                   //assign test signals
assign w_req = w_req_write;                 //assign test signals
assign w_wstrb = wb_req_wstrb;              //assign test signals
assign w_data = wb_req_wdata;               //assign test signals

axi_slv #(
    .async_reset(async_reset),
    .vid(VENDOR_OPTIMITECH),
    .did(OPTIMITECH_SRAM)
) axi0 (
    .i_clk(clk),
    .i_nrst(nrst),
    .i_mapinfo(i_mapinfo),
    .o_cfg(cfg),
    .i_xslvi(i),
    .o_xslvo(o),
    .o_req_valid(w_req_valid),
    .o_req_addr(wb_req_addr),
    .o_req_size(wb_req_size),
    .o_req_write(w_req_write),
    .o_req_wdata(wb_req_wdata),
    .o_req_wstrb(wb_req_wstrb),
    .o_req_last(w_req_last),
    .i_req_ready(1'b1),
    .i_resp_valid(1'b1),
    .i_resp_rdata(wb_rdata),
    .i_resp_err(1'd0)
);


srambytes_tech #(
    .abits(abits),             // abits = 18
    .log2_dbytes(CFG_LOG2_SYSBUS_DATA_BYTES), //log2_dbytes = 3
    .init_file(init_file)
) tech0 (
    .clk(clk),
    .addr(wb_req_addr[abits-1:0]),     
    .rdata(wb_rdata),
    .we(w_req_write),
    .wstrb(wb_req_wstrb),
    .wdata(wb_req_wdata)
);

endmodule
