// 
//  Copyright 2022 Sergey Khabarov, sergeykhbr@gmail.com
// 
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// 

`timescale 1ns/10ps

module axi_slv #(
    parameter bit async_reset = 1'b0,
    parameter int unsigned vid = 0,                         // Vendor ID
    parameter int unsigned did = 0                          // Device ID
)
(
    input logic i_clk,                                      // CPU clock
    input logic i_nrst,                                     // Reset: active LOW
    input types_amba_pkg::mapinfo_type i_mapinfo,           // Base address information from the interconnect port
    output types_amba_pkg::dev_config_type o_cfg,           // Slave config descriptor
    input types_amba_pkg::axi4_slave_in_type i_xslvi,       // AXI Slave input interface
    output types_amba_pkg::axi4_slave_out_type o_xslvo,     // AXI Slave output interface
    output logic o_req_valid,
    output logic [types_amba_pkg::CFG_SYSBUS_ADDR_BITS-1:0] o_req_addr,
    output logic [7:0] o_req_size,
    output logic o_req_write,
    output logic [types_amba_pkg::CFG_SYSBUS_DATA_BITS-1:0] o_req_wdata,
    output logic [types_amba_pkg::CFG_SYSBUS_DATA_BYTES-1:0] o_req_wstrb,
    output logic o_req_last,
    input logic i_req_ready,
    input logic i_resp_valid,
    input logic [types_amba_pkg::CFG_SYSBUS_DATA_BITS-1:0] i_resp_rdata,
    input logic i_resp_err
);

import types_amba_pkg::*;
import axi_slv_pkg::*;

axi_slv_registers r, rin;

always_comb
begin: comb_proc
    axi_slv_registers v;
    logic [11:0] vb_req_addr_next;
    logic v_req_last;
    dev_config_type vcfg;
    axi4_slave_out_type vxslvo;

    vb_req_addr_next = 0;
    v_req_last = 0;
    vcfg = dev_config_none;
    vxslvo = axi4_slave_out_none;

    v = r;

    vcfg.descrsize = PNP_CFG_DEV_DESCR_BYTES;
    vcfg.descrtype = PNP_CFG_TYPE_SLAVE;
    vcfg.addr_start = i_mapinfo.addr_start;
    vcfg.addr_end = i_mapinfo.addr_end;
    vcfg.vid = vid;
    vcfg.did = did;

    vb_req_addr_next = (r.req_addr[11: 0] + r.req_xsize);
    if (r.req_burst == AXI_BURST_FIXED) begin
        vb_req_addr_next = r.req_addr[11: 0];
    end else if (r.req_burst == AXI_BURST_WRAP) begin
        // Wrap suppported only 2, 4, 8 or 16 Bytes. See ARMDeveloper spec.
        if (r.req_xsize == 2) begin
            vb_req_addr_next[11: 1] = r.req_addr[11: 1];
        end else if (r.req_xsize == 4) begin
            vb_req_addr_next[11: 2] = r.req_addr[11: 2];
        end else if (r.req_xsize == 8) begin
            vb_req_addr_next[11: 3] = r.req_addr[11: 3];
        end else if (r.req_xsize == 16) begin
            vb_req_addr_next[11: 4] = r.req_addr[11: 4];
        end else if (r.req_xsize == 32) begin
            // Optional (not in ARM spec)
            vb_req_addr_next[11: 5] = r.req_addr[11: 5];
        end
    end

    v_req_last = (~(|r.req_len));
    v.req_last = v_req_last;

    case (r.state)
    State_Idle: begin
        v.req_valid = 1'b0;                                //initializing some signals in the v register
        v.req_write = 1'b0;
        v.resp_valid = 1'b0;
        v.resp_last = 1'b0;
        v.resp_err = 1'b0;
        vxslvo.aw_ready = 1'b1;
        vxslvo.w_ready = 1'b1;                              // No burst AXILite ready
        vxslvo.ar_ready = (~i_xslvi.aw_valid);              
        if (i_xslvi.aw_valid == 1'b1) begin                 //check if there is write address valid.
            v.req_addr = i_xslvi.aw_bits.addr;              // match the inputs to the interface to the v register.
            v.req_xsize = XSizeToBytes(i_xslvi.aw_bits.size);
            v.req_len = i_xslvi.aw_bits.len;
            v.req_burst = i_xslvi.aw_bits.burst;
            v.req_id = i_xslvi.aw_id;
            v.req_user = i_xslvi.aw_user;
            v.req_wdata = i_xslvi.w_data;                   // AXI Lite compatible
            v.req_wstrb = i_xslvi.w_strb;
            if (i_xslvi.w_valid == 1'b1) begin       //check if there is data valid to write which means that it is not a burst of data 
                // AXI Lite does not support burst transaction
                v.state = State_last_w;             //then go to last write state because it is only 64 bits of data not a stream of data
                v.req_valid = 1'b1;                        //update the status of the v register
                v.req_write = 1'b1;                        //update the status of the v register
            end else begin
                v.state = State_w;   //if the data is not valid,and I have a valid write address that means that the data is in burst 
            end                              //then go to State_W for writing bursts of data
        end else if (i_xslvi.ar_valid == 1'b1) begin  //check if I have a valid read address which means that I want to read now 
            v.req_valid = 1'b1;                       //enabling that there is valid address to be sent
            v.req_addr = i_xslvi.ar_bits.addr;        //matching input read signals to v register variable
            v.req_xsize = XSizeToBytes(i_xslvi.ar_bits.size);
            v.req_len = i_xslvi.ar_bits.len;
            v.req_burst = i_xslvi.ar_bits.burst;
            v.req_id = i_xslvi.ar_id;
            v.req_user = i_xslvi.ar_user;
            v.state = State_addr_r;          // then go to read address state 
        end
    end
    State_w: begin //this is the state reached if I have bursts of data 
        vxslvo.w_ready = 1'b1;       //enable the ready signal of the v variable waiting for valid signal for this transaction                   
        v.req_wdata = i_xslvi.w_data; // assign the input data transaction to the v variable write data 
        v.req_wstrb = i_xslvi.w_strb; //assign the input wstrb to the v variable wstrb
        if (i_xslvi.w_valid == 1'b1) begin //checking the assertion of the valid signal of the first transaction 
            v.req_valid = 1'b1;            //if input = 1 then valid signal in V = 1 (ready was = 1 waiting for valid)
            v.req_write = 1'b1;            //write request = 1 
            if ((|r.req_len) == 1'b1) begin //oring of the 8 bits in len = 1 means that there are more transactions in the burst
                v.state = State_burst_w;    //therfore go to write burst state 
            end else begin
                v.state = State_last_w;   //oring of the 8 bits of len = 0 means all transactions are written so go to last write state
            end
        end
    end
    State_burst_w: begin //this state is reached if I have bursts of data of more than one transaction I think
        v.req_valid = i_xslvi.w_valid;  //input valid signal matched to v valid signal for next transaction
        vxslvo.w_ready = i_resp_valid;  //I think if the previous transaction is written correctly so B response is 1 which consequently 
                                        //means that the slave is ready to the next transaction so ready signal in v is enabled.
        if ((i_xslvi.w_valid == 1'b1) && (i_resp_valid == 1'b1)) begin //check valid signal for this transaction and response 
                                                                       //of previous signal transaction(input to interface from slave).
                                                                       //if both signals are = 1 so start issuing next transaction
            v.req_addr = {r.req_addr[(CFG_SYSBUS_ADDR_BITS - 1): 12], vb_req_addr_next}; 
            v.req_wdata = i_xslvi.w_data; //input data to be written for the next transaction assigned to v variable data 
            v.req_wstrb = i_xslvi.w_strb; //input wstrb for the data in the next transaction assigned to v variable wstrb
            if ((|r.req_len) == 1'b1) begin //check the oring of the 8 bits of len signal
                v.req_len = (r.req_len - 1); //if the oring = 1 decrement the len in r and v meaning that transaction is issued
            end                                 
            if (r.req_len == 8'h01) begin //when the len reaches 1 meaning there is only 1 transaction remaining get out of this state 
                v.state = State_last_w;   // and go to the last write state but I think all the transactions have been sent because the
            end                           //the first transaction is issued in the write state before burst write state.
        end
    end
    State_last_w: begin  //last write state no transactions written in this state because as I said all first transaction is issued in 
                         //write state and len doesn't decrement there so when len = 1, all transactions are written 
        // Wait cycle: w_ready is zero on the last write because it is laready accepted
        if (i_resp_valid == 1'b1) begin //check the response of the slave to the previous transaction which was the last one
            v.req_valid = 1'b0;         //if the response is 1 meaning it was written, so disable the v valid signal, as there are not 
                                        //any remaining transactions to be written
            v.req_write = 1'b0;         //disable request write --> no more writes
            v.resp_err = i_resp_err;    //assign input error signal to error signal in v 
            v.state = State_b;          //go to the B response state to get the response for the whole burst.
        end
    end
    State_b: begin          //this state is reached after all the burst or single data item are sent and written by the slave
        vxslvo.b_valid = 1'b1; //at this point enable the b response valid signal meaning there is a B signal needs to be sent 
        if (i_xslvi.b_ready == 1'b1) begin //check for the B response ready signal to send the B response signal from slave to master
            v.state = State_Idle; //if the ready and valid signals of B response are enabled then return back to idle state, as the         
        end                       //written burst or data item are written and received by the slave.
    end
    State_addr_r: begin //this state is reached from the idle state when I have a valid read address.
        // Setup address:
        if (i_req_ready == 1'b1) begin //check the ready signal send by slave meaning that it is ready to recieve the address
            if ((|r.req_len) == 1'b1) begin //if master is ready check the oring of len to know if the master wants to read bursts of
                                            //data or only a single data item
                v.req_addr = {r.req_addr[(CFG_SYSBUS_ADDR_BITS - 1): 12], vb_req_addr_next};
                v.req_len = (r.req_len - 1); //decrementing the len signal in r and v as well
                v.state = State_addrdata_r; //go to state read data address for reading of bursts 
            end else begin //the master needs to read a single data item from the slave
                v.req_valid = 1'b0; //address is sent to the slave so disable the valid signal enabled in the idle state for the address
                v.state = State_data_r; //go to read data state to read single item of data 64 bits. 
            end
        end
    end
    State_addrdata_r: begin //this state is reached if you have a burst of data to be read from slave
        v.resp_valid = i_resp_valid; //I think this means that the current address is valid to read from or not depending on i/p value 
        v.resp_rdata = i_resp_rdata; //respond with the data to the master for this first valid address "first transaction"  
        v.resp_err = i_resp_err;     //respond with any errors
        if ((i_resp_valid == 1'b0) || ((|r.req_len) == 1'b0)) begin //if the address given to slave is not valid so it will response 
                                                                    //invalid address or burst is empty then 
            v.req_valid = 1'b0;                                     //disable valid signal from master to slave
            v.state = State_data_r;                                 //go to state read data waiting for valid signal from master to start sending the data
        end else if (i_xslvi.r_ready == 1'b0) begin                 //if master is not ready to accept the data
            // Bus is not ready to accept read data
            v.req_valid = 1'b0;                                     //disable valid signal from slave to master for valid data 
            v.state = State_out_r;                                  //go to state read out 
        end else if (i_req_ready == 1'b0) begin                     //    
            // Slave device is not ready to accept burst request
            v.state = State_addr_r;                                 //
        end else begin                                              //
            v.req_addr = {r.req_addr[(CFG_SYSBUS_ADDR_BITS - 1): 12], vb_req_addr_next}; //
            v.req_len = (r.req_len - 1);                                                 //
        end
    end
    State_data_r: begin //this state is reached when master needs to read single data item of 64 bits or single transaction in a burst
        if (i_resp_valid == 1'b1) begin //check the response valid address signal if it is enabled then 
            v.resp_valid = 1'b1;        //enable the response valid signal in v 
            v.resp_rdata = i_resp_rdata;//read the data from the valid address --> input to interface from slave 
            v.resp_err = i_resp_err; //error signal response 
            v.resp_last = (~(|r.req_len)); //the last transaction signal is simply the inverse of oring of len signal len = 0 means
                                           //last transaction is reached "last = 1" otherwise last = 0 when oring of len gives '1'  
            v.state = State_out_r; //go to state read out that make like a loop if I have a burst to check the next address or reach
        end                        //the idle state if I have a single data item or the burst is empty
    end
    State_out_r: begin  //this state is reached after reading a 64 bits of data 
        if (i_xslvi.r_ready == 1'b1) begin          //I think this i/p signal from  
            v.resp_valid = 1'b0;                    //
            v.resp_last = 1'b0;                     //
            if ((|r.req_len) == 1'b1) begin         //if the burst of address is not finished then
                v.req_valid = 1'b1;                 //enable read address valid signal to start sending the next address
                v.state = State_addr_r;             //go to read address state 
            end else begin                          //if the burst is finished so the oring of len signal gives 0 then 
                v.state = State_Idle;               //return to the idle state again
            end
        end
    end
    default: begin
    end
    endcase

    if (~async_reset && i_nrst == 1'b0) begin
        v = axi_slv_r_reset;
    end

    o_req_valid = r.req_valid;
    o_req_last = v_req_last;
    o_req_addr = r.req_addr;
    o_req_size = r.req_xsize;
    o_req_write = r.req_write;
    o_req_wdata = r.req_wdata;
    o_req_wstrb = r.req_wstrb;

    vxslvo.b_id = r.req_id;
    vxslvo.b_user = r.req_user;
    vxslvo.b_resp = {r.resp_err, 1'h0};
    vxslvo.r_valid = r.resp_valid;
    vxslvo.r_id = r.req_id;
    vxslvo.r_user = r.req_user;
    vxslvo.r_resp = {r.resp_err, 1'h0};
    vxslvo.r_data = r.resp_rdata;
    vxslvo.r_last = r.resp_last;
    o_xslvo = vxslvo;
    o_cfg = vcfg;

    rin = v;
end: comb_proc

generate
    if (async_reset) begin: async_rst_gen

        always_ff @(posedge i_clk, negedge i_nrst) begin: rg_proc
            if (i_nrst == 1'b0) begin
                r <= axi_slv_r_reset;
            end else begin
                r <= rin;
            end
        end: rg_proc


    end: async_rst_gen
    else begin: no_rst_gen

        always_ff @(posedge i_clk) begin: rg_proc
            r <= rin;
        end: rg_proc

    end: no_rst_gen
endgenerate

endmodule: axi_slv
