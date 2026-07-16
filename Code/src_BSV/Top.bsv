// Copyright (c) 2023-2025 Rishiyur S. Nikhil.  All Rights Reserved.

package Top;

// ****************************************************************
// Imports from libraries

import Vector      :: *;
import FIFOF       :: *;
import Connectable :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle :: *;
import Semi_FIFOF :: *;

// ----------------
// Local imports

import Arch        :: *;
import Utils       :: *;
import Mem_Req_Rsp :: *;
import CPU_IFC     :: *;
import CPU         :: *;

import Accel_IFC :: *;
import Accel     :: *;

import Interconnect :: *;

import Mems_Devices :: *;

// ****************************************************************
// Global address map

Bit #(XLEN) pc_reset_value = 'h_8000_0000;

Bit #(64) addr_base_mem = 'h_8000_0000;
Bit #(64) size_B_mem    = 'h_1000_0000;

Bit #(64) addr_base_accel = 'h_C000_0000;
Bit #(64) size_B_accel    = 'h_0000_0100;

// ****************************************************************

(* synthesize *)
module mkTop (Empty);
   Reg #(File) rg_logfile <- mkReg (InvalidFile);

   // Instantiate the CPU
   CPU_IFC cpu <- mkCPU;

   // Instantiate an accelerator
   Accel_IFC accel <- mkAccel;

   // ----------------
   // Instantiate an interconnect

   // Vector of clients for interconnect
   Vector #(2, Client_Semi_FIFOF #(Mem_Req, Mem_Rsp)) v_interconnect_clients;
   v_interconnect_clients [0] = interface Client_Semi_FIFOF;
				   interface request  = cpu.fo_DMem_req;
				   interface response = cpu.fi_DMem_rsp;
				endinterface;
   v_interconnect_clients [1] = accel.client;

   // Vector of buffers for interconnect server-side
   Vector #(2, FIFOF #(Mem_Req)) vf_buf_reqs <- replicateM (mkFIFOF);
   Vector #(2, FIFOF #(Mem_Rsp)) vf_buf_rsps <- replicateM (mkFIFOF);

   // Vector of servers for interconnect
   Vector #(2, Server_Semi_FIFOF #(Mem_Req, Mem_Rsp)) v_interconnect_servers;
   for (Integer j = 0; j < 2; j = j + 1)
      v_interconnect_servers [j] = fifofs_to_Server_Semi_FIFOF (vf_buf_reqs [j],
								vf_buf_rsps [j]);

   // The interconnect
   Interconnect_IFC #(2, 2) interconnect <- mkInterconnect (v_interconnect_clients,
							    v_interconnect_servers);

   // ----------------
   // Instantiate the memory model
   Mems_Devices_IFC mems_devices <- mkMems_Devices (cpu.fo_IMem_req,
						    cpu.fi_IMem_rsp,
						    cpu.fo_DMem_S_req,
						    cpu.fi_DMem_S_rsp,
						    cpu.fo_DMem_S_commit,

						    to_FIFOF_O (vf_buf_reqs [0]),
						    to_FIFOF_I (vf_buf_rsps [0]),

						    dummy_FIFOF_O,
						    dummy_FIFOF_I);

   // ----------------
   // Connect the accelerator
   mkConnection (to_FIFOF_O (vf_buf_reqs [1]), accel.server.request);
   mkConnection (accel.server.response, to_FIFOF_I (vf_buf_rsps [1]));

   // ----------------

   Reg #(int) rg_top_step <- mkReg (0);    // Sequences startup steps

   // ****************************************************************
   // BEHAVIOR

   // ================================================================
   // Startup sequence

   // Show banner and open logfile
   rule rl_step0 (rg_top_step == 0);
      $display ("================================================================");
      $display ("Simulation top-level.  Command-line options:");
      $display ("  +log      Generate log (trace) file (can become large!)");

      let log <- $test$plusargs ("log");
      File f = InvalidFile;
      if (log) begin
	 $display ("INFO: Logfile is: log.txt");
	 f <- $fopen ("log.txt", "w");
      end
      else
	 $display ("INFO: No logfile");
      rg_logfile  <= f;


      rg_top_step <= 1;
   endrule


   // Initialize modules
   rule rl_step1 (rg_top_step == 1);
      let init_params = Initial_Params {pc_reset_value:    pc_reset_value,
					addr_base_mem:     addr_base_mem,
					size_B_mem:        size_B_mem,

					flog:              rg_logfile,
					dbg_listen_socket: 0};

      cpu.init (init_params);
      mems_devices.init (init_params);

      Vector #(2, Tuple2 #(Bit #(64), Bit #(64))) v_addr_map = ?;
      v_addr_map [0] = tuple2 ('h_0000_0000, addr_base_mem+size_B_mem); // Mem/CLINT/UART/...
      v_addr_map [1] = tuple2 (addr_base_accel, size_B_accel);
      interconnect.init (v_addr_map);

      rg_top_step <= 2;
   endrule

   // Get ready to run
   rule rl_step2 (rg_top_step == 2);
      $display ("================================================================");
      rg_top_step <= 3;
   endrule

   // ... system running

   Integer cycle_limit = 0;    // Use 0 for no-limit

   rule rg_step3 (rg_top_step == 3);
      // Quit if reached cycle-limit
      let x <- cur_cycle;
      if ((cycle_limit > 0) && (x > fromInteger (cycle_limit))) begin
	 $display ("================================================================");
         $display ("Quit (reached cycle_limit %0d)", cycle_limit);
	 rg_top_step <= 4;
      end
   endrule

   rule rl_step4 (rg_top_step == 4);
      $finish (0);
   endrule

   // ================================================================
   // Relay MTIME to CPU's CSRs module

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_relay_MTIME;
      let t <- mems_devices.rd_MTIME;
      cpu.set_TIME (t);
   endrule

   // ================================================================
   // Relay MTIP to CPU's CSRs module

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_relay_MTIP;
      let t = mems_devices.mv_MTIP;
      cpu.set_MIP_MTIP (t);
   endrule

   // ================================================================
   // Drain RVFI packets

   rule rl_drain_RVFI;
      let t <- pop_o (cpu.fo_rvfi_reports);
   endrule

   // ================================================================
   // INTERFACE

   // Empty
endmodule

// ****************************************************************

endpackage
