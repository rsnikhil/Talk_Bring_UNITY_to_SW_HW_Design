// Copyright (c) 2023-2025 Rishiyur S. Nikhil.  All Rights Reserved.

package Accel;

// ****************************************************************
// Imports from libraries

import FIFOF   :: *;
import StmtFSM :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;
import GetPut_Aux :: *;

// ----------------
// Local imports

import Instr_Bits  :: *;
import Mem_Req_Rsp :: *;
import Accel_IFC   :: *;

// ****************************************************************

typedef enum { STATE_IDLE, STATE_RUNNING } State
deriving (Bits, Eq, FShow);

typedef enum { VA, VB, VC } Vector_Id
deriving (Bits, Eq, FShow);

Integer verbosity = 0;

// ****************************************************************

(* synthesize *)
module mkAccel (Accel_IFC);
   // Control and config this accelerator
   FIFOF #(Mem_Req) f_ctrl_reqs <- mkFIFOF;
   FIFOF #(Mem_Rsp) f_ctrl_rsps <- mkFIFOF;

   // Access to memory from this accelerator
   FIFOF #(Mem_Req) f_mem_reqs <- mkFIFOF;
   FIFOF #(Mem_Rsp) f_mem_rsps <- mkFIFOF;

   Reg #(State) rg_state <- mkReg (STATE_IDLE);

   // ****************************************************************

   function Bit #(64) fn_base_addr (Vector_Id vid);
      return case (vid)
		VA: 'h_8000_1000;
		VB: 'h_8000_2000;
		VC: 'h_8000_3000;
		default: 'h_AAAA_AAAA;
	     endcase;
   endfunction

   function Fmt fshow_vector_and_index (Vector_Id vid, int index);
      return $format (fshow (vid), "[%0d]", index);
   endfunction

   // ****************************************************************
   // Packaging read requests and responses

   function Action read_req (Vector_Id vid, int index);
      action
	 let addr = fn_base_addr (vid) + zeroExtend (pack (index) << 2);
         let req = Mem_Req {req_type: funct5_LOAD,
			    size:     MEM_4B,
			    addr:     addr,
			    data:     ?,
			    epoch:    ?,
			    xtra:     ?};
         f_mem_reqs.enq (req);
	 if (verbosity != 0) begin
            $display ("  read_req ", fshow_vector_and_index (vid, index));
	    $display ("    ", fshow_Mem_Req (req));
	 end
      endaction
   endfunction

   function Action read_rsp (Vector_Id vid, int index, Reg #(int) rg);
      action
         let rsp <- pop (f_mem_rsps);
         if (rsp.rsp_type != MEM_RSP_OK) begin
            $display ("ERROR: read_rsp ", fshow_vector_and_index (vid, index));
            $finish (1);
         end
	 if (verbosity != 0) begin
            $display ("  read_rsp ", fshow_vector_and_index (vid, index));
	    $display ("    ", fshow_Mem_Rsp (rsp, False));
	 end
	 rg <= unpack (truncate (rsp.data));
      endaction
   endfunction

   function Stmt read_req_rsp (Vector_Id vid, int index, Reg #(int) rg);
      return seq
		read_req (vid, index);
		read_rsp (vid, index, rg);
	     endseq;
   endfunction

   // ****************************************************************
   // Packaging write requests and responses

   function Action write_req (Vector_Id vid, int index, int wdata);
      action
	 let addr = fn_base_addr (vid) + zeroExtend (pack (index) << 2);
         let req = Mem_Req {req_type: funct5_STORE,
			    size:     MEM_4B,
			    addr:     addr,
			    data:     zeroExtend (pack (wdata)),
			    epoch:    ?,
			    xtra:     ?};
         f_mem_reqs.enq (req);
	 if (verbosity != 0) begin
            $display ("  Write req ", fshow_vector_and_index (vid, index));
	    $display ("    ", fshow_Mem_Req (req));
	 end
      endaction
   endfunction

   function Action write_rsp (Vector_Id vid, int index);
      action
         let rsp <- pop (f_mem_rsps);
         if (rsp.rsp_type != MEM_RSP_OK) begin
            $display ("ERROR: write_rsp ", fshow_vector_and_index (vid, index));
            $finish (1);
         end
	 if (verbosity != 0) begin
            $display ("  write_rsp ", fshow_vector_and_index (vid, index));
	    $display ("    ", fshow_Mem_Rsp (rsp, False));
	 end
      endaction
   endfunction

   function Stmt write_req_rsp (Vector_Id vid, int index, int wdata);
      return seq
		write_req (vid, index, wdata);
		write_rsp (vid, index);
	     endseq;
   endfunction


   // ****************************************************************
   // VAdd accel version vNull    (for measuring accel setup overhead)

   Stmt stmt_vNull =
   seq
      noAction;
   endseq;

   // ****************************************************************
   // VAdd accel versions v1a    (transliteration of trad. C program)

   Reg #(int) rg_vsize <- mkReg (100);

   Reg #(int) rg_j  <- mkRegU;
   Reg #(int) rg_aj <- mkRegU;
   Reg #(int) rg_bj <- mkRegU;
   Reg #(int) rg_cj <- mkRegU;

   Stmt stmt_v1a =
   seq
      for (rg_j <= 0; rg_j < rg_vsize; rg_j <= rg_j + 1) seq
	 read_req_rsp  (VA, rg_j, rg_aj);
	 read_req_rsp  (VB, rg_j, rg_bj);
	 write_req_rsp (VC, rg_j, rg_aj + rg_bj);
      endseq
   endseq;

   // ... and expliclty split-phasing the loads

   Stmt stmt_v1b =
   seq
      for (rg_j <= 0; rg_j < rg_vsize; rg_j <= rg_j + 1) seq
	 read_req (VA, rg_j);
	 read_rsp (VA, rg_j, rg_aj);

	 read_req (VB, rg_j);
	 read_rsp (VB, rg_j, rg_bj);

	 write_req_rsp (VC, rg_j, rg_aj + rg_bj);
      endseq
   endseq;

   // ****************************************************************
   // VAdd accel versions v2    (concurrent loads for A[j] and B[j]

   Stmt stmt_v2 =
   seq
      for (rg_j <= 0; rg_j < rg_vsize; rg_j <= rg_j + 1) seq
	 read_req (VA, rg_j);
	 read_req (VB, rg_j);

	 read_rsp (VA, rg_j, rg_aj);
	 read_rsp (VB, rg_j, rg_bj);

	 write_req_rsp (VC, rg_j, rg_aj + rg_bj);
      endseq
   endseq;

   // ****************************************************************
   // VAdd accel versions v3    (loop unroll once)

   Stmt stmt_v3 =
   seq
      for (rg_j <= 0; rg_j < rg_vsize; rg_j <= rg_j + 2) seq
	 read_req (VA, rg_j);
	 read_req (VB, rg_j);
	 read_req (VA, rg_j+1);
	 read_req (VB, rg_j+1);

	 read_rsp  (VA, rg_j, rg_aj);
	 read_rsp  (VB, rg_j, rg_bj);
	 write_req (VC, rg_j, rg_aj + rg_bj);

	 read_rsp  (VA, rg_j+1, rg_aj);
	 read_rsp  (VB, rg_j+1, rg_bj);
	 write_req (VC, rg_j+1, rg_aj + rg_bj);

	 write_rsp (VC, rg_j);
	 write_rsp (VC, rg_j+1);
      endseq
   endseq;

   // ****************************************************************
   // VAdd accel versions v4    (3 concurrent engines: load, compute-store, store-rsp)

   Reg #(int) rg_j2 <- mkRegU;
   Reg #(int) rg_j3 <- mkRegU;

   // This version will deadlock due to head-of-line blocking
   Stmt stmt_v4a =
   par
      for (rg_j <= 0; rg_j < rg_vsize; rg_j <= rg_j + 1) seq
	 read_req (VA, rg_j);
	 read_req (VB, rg_j);
      endseq
      
      for (rg_j2 <= 0; rg_j2 < rg_vsize; rg_j2 <= rg_j2 + 1) seq
	 read_rsp  (VA, rg_j, rg_aj);
	 read_rsp  (VB, rg_j, rg_bj);
	 write_req (VC, rg_j, rg_aj + rg_bj);
      endseq
      
      for (rg_j3 <= 0; rg_j3 < rg_vsize; rg_j3 <= rg_j3 + 1)
	 write_rsp (VC, rg_j);
   endpar;

   // ----------------
   // This version avoids deadlock due to head-of-line blocking

   FIFOF #(Mem_Rsp) f_W_mem_rsps <- mkSizedFIFOF (10);

   function Action write_rsp2 (Vector_Id vid, int index);
      action
         let rsp <- pop (f_W_mem_rsps);
         if (rsp.rsp_type != MEM_RSP_OK) begin
            $display ("ERROR: write_rsp ", fshow_vector_and_index (vid, index));
            $finish (1);
         end
	 if (verbosity != 0) begin
            $display ("  write_rsp ", fshow_vector_and_index (vid, index));
	    $display ("    ", fshow_Mem_Rsp (rsp, False));
	 end
      endaction
   endfunction

   Stmt stmt_v4b =
   par
      for (rg_j <= 0; rg_j < rg_vsize; rg_j <= rg_j + 1) seq
	 read_req (VA, rg_j);
	 read_req (VB, rg_j);
      endseq
      
      for (rg_j2 <= 0; rg_j2 < rg_vsize; rg_j2 <= rg_j2 + 1) seq
	 read_rsp  (VA, rg_j, rg_aj);
	 read_rsp  (VB, rg_j, rg_bj);
	 write_req (VC, rg_j, rg_aj + rg_bj);
      endseq
      
      for (rg_j3 <= 0; rg_j3 < rg_vsize; rg_j3 <= rg_j3 + 1)
	 write_rsp2 (VC, rg_j);
   endpar;

   // ****************************************************************
   // Control: Any STORE request is treated as a "START" signal

   // FSM fsm <- mkFSM (stmt_vNull);
   FSM fsm_v1a <- mkFSM (stmt_v1a);
   FSM fsm_v1b <- mkFSM (stmt_v1b);
   FSM fsm_v2  <- mkFSM (stmt_v2);
   FSM fsm_v3  <- mkFSM (stmt_v3);
   FSM fsm_v4a <- mkFSM (stmt_v4a);
   FSM fsm_v4b <- mkFSM (stmt_v4b);

   Reg #(Bool) rg_separate_R_and_W_rsps <- mkReg (False);

   rule rl_separate_R_and_W_rsps (rg_separate_R_and_W_rsps
				  && (f_mem_rsps.first.req_type == funct5_STORE));
      let rsp <- pop (f_mem_rsps);
      f_W_mem_rsps.enq (rsp);
   endrule

   // ================================================================

   function ActionValue #(FSM) fav_select_fsm ();
      actionvalue
	 let v2  <- $test$plusargs ("accel_v2");
	 let v3  <- $test$plusargs ("accel_v3");
	 let v4  <- $test$plusargs ("accel_v4");
	 let fsm = (v4 ? fsm_v4b
		    : (v3 ? fsm_v3
		       : (v2 ? fsm_v2 : fsm_v1a)));
	 rg_separate_R_and_W_rsps <= v4;
	 return fsm;
      endactionvalue
   endfunction

   let ctrl_status_req = f_ctrl_reqs.first;

   rule rl_ctrl_cmd (ctrl_status_req.req_type == funct5_STORE);
      let fsm <- fav_select_fsm ();
      if (fsm.done) begin
	 f_ctrl_reqs.deq;
	 let rsp = Mem_Rsp {rsp_type: MEM_RSP_OK,
			    data    : ?,
			    req_type: ctrl_status_req.req_type,
			    size    : ctrl_status_req.size,
			    addr    : ctrl_status_req.addr,
			    xtra    : Mem_Rsp_Xtra {inum  : ctrl_status_req.xtra.inum,
						    pc   : ctrl_status_req.xtra.pc,
						    instr: ctrl_status_req.xtra.instr}};
	 f_ctrl_rsps.enq (rsp);

	 fsm.start;
	 $display ("%0d: Accel: rec'd START command", cur_cycle);
      end
   endrule

   // Control: Any LOAD request is treated as a "FINISHED" query.
   // We don't return a response until the accel computation is finished.
   rule rl_ctrl_status (ctrl_status_req.req_type == funct5_LOAD);
      let fsm <- fav_select_fsm ();
      if (fsm.done) begin
	 f_ctrl_reqs.deq;
	 let rsp = Mem_Rsp {rsp_type: MEM_RSP_OK,
			    data    : ?,
			    req_type: ctrl_status_req.req_type,
			    size    : ctrl_status_req.size,
			    addr    : ctrl_status_req.addr,
			    xtra    : Mem_Rsp_Xtra {inum  : ctrl_status_req.xtra.inum,
						    pc   : ctrl_status_req.xtra.pc,
						    instr: ctrl_status_req.xtra.instr}};
	 f_ctrl_rsps.enq (rsp);
	 $display ("%0d: Accel: sent FINISHED response", cur_cycle);
      end
   endrule

   // ****************************************************************
   // INTERFACE

   // Memory data read/write
   interface client = fifofs_to_Client_Semi_FIFOF (f_mem_reqs, f_mem_rsps);

   // CPU control and status
   interface server = fifofs_to_Server_Semi_FIFOF (f_ctrl_reqs, f_ctrl_rsps);
endmodule

// ****************************************************************

endpackage
