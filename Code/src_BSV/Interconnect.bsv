// Copyright (c) 2026 Rishiyur S. Nikhil.  All Rights Reserved.

package Interconnect;

// ****************************************************************
// Common top-level for various versions of VAdd

// ****************************************************************
// Imports from libraries

import Vector       :: *;

import FIFOF        :: *;
import GetPut       :: *;
import ClientServer :: *;
import Connectable  :: *;
import StmtFSM      :: *;

// ----------------
// Imports from 'vendor' libs

import Cur_Cycle :: *;
import Semi_FIFOF :: *;

// ----------------
// Local imports

import Mem_Req_Rsp :: *;

// ****************************************************************

Integer verbosity = 0;

// ****************************************************************

interface Interconnect_IFC #(numeric type nClients_t, numeric type nServers_t);
   // base-address and size serviced by each server
   method Action init (Vector #(nServers_t,
				Tuple2 #(Bit #(64), Bit #(64))) v_addr_map);
endinterface

// ****************************************************************
// Returns the port number of the server servicing a given address (-1 if none)

function Integer destination_port (Vector #(nServers_t,
					      Tuple2 #(Bit #(64), Bit #(64))) v_addr_map,
				     Bit #(64) addr);
   Integer nServers = valueOf (nServers_t);
   Integer result = -1;
   for (Integer j = 0; j < nServers; j = j + 1) begin
      match { .base, .size} = v_addr_map [j];
      if ((base <= addr) && (addr <= base + size))
	 result = j;
   end
   return result;
endfunction

// ****************************************************************

module mkInterconnect #(Vector #(nClients_t, Client_Semi_FIFOF #(Mem_Req, Mem_Rsp)) v_clients,
			Vector #(nServers_t, Server_Semi_FIFOF #(Mem_Req, Mem_Rsp)) v_servers)
                      (Interconnect_IFC #(nClients_t, nServers_t));

   Integer nClients = valueOf (nClients_t);
   Integer nServers = valueOf (nServers_t);

   // FIFOFs of ``return ports''
   // For each req delivered from client c to server s, this FIFO
   // associated with server s remembers c, so we know where to send
   // the response.

   // FUTURE: actually the return port should be carried on the
   // mem_req and mem_rsp, to accommodate out-of-order responses.
   // For this, we need to add field for return-port on mem_reqs and mem_rsps.
   // Further, this field on a mem_req gets wider as it flows towards its destination,
   // and this field on a mem_rsp gets narrower as it flows back to its source.

   Vector #(nServers_t, FIFOF #(Bit #(TLog #(nClients_t))))  vf_return_clients
   <- replicateM (mkSizedFIFOF (16));

   Reg #(Vector #(nServers_t, Tuple2 #(Bit #(64), Bit #(64)))) rg_v_addr_map <- mkRegU;

   // WARNING: When requests go to different destinations,
   // WARNING: responses may not be in order! Clients should deal with this.

   // Forward request from clients to servers
   for (Integer c = 0; c < nClients; c = c + 1) begin
      let req    = v_clients [c].request.first;
      let dest_s = destination_port (rg_v_addr_map, req.addr);

      rule rl_req_err (dest_s == -1);
	 $display ("ERROR: Interconnect client %0d: wild req addr", c, fshow (req));

	 let err_rsp = Mem_Rsp {rsp_type: MEM_RSP_ERR,
				data:     req.data,
				req_type: req.req_type,
				size:     req.size,
				addr:     req.addr,
				xtra:     Mem_Rsp_Xtra {inum:  req.xtra.inum,
							pc:    req.xtra.pc,
							instr: req.xtra.instr}};
	 v_clients [c].response.enq (err_rsp);
      endrule

      for (Integer s = 0; s < nServers; s = s + 1)
	 rule rl_req (dest_s == fromInteger (s));
	    v_clients [c].request.deq;
	    v_servers [s].request.enq (req);
	    vf_return_clients [s].enq (fromInteger (c));

	    if (verbosity != 0) begin
	       $display ("%0d: Interconnect: [%0d] ==> [%0d]", cur_cycle, c, s);
	       $display (fshow_Mem_Req (req));
	    end
	 endrule
   end

   // Forward response from servers to clients
   for (Integer s = 0; s < nServers; s = s + 1) begin
      let rsp    = v_servers [s].response.first;
      let dest_c = vf_return_clients [s].first;

      for (Integer c = 0; c < nClients; c = c + 1)
	 rule rl_rsp (dest_c == fromInteger (c));
	    v_servers [s].response.deq;
	    vf_return_clients [s].deq;
	    v_clients [c].response.enq (rsp);

	    if (verbosity != 0) begin
	       $display ("%0d: Interconnect: [%0d] <== [%0d]", cur_cycle, c, s);
	       $display (fshow_Mem_Rsp (rsp, True));
	    end
	 endrule
   end

   // ****************************************************************
   // INTERFACE

   method Action init (Vector #(nServers_t, Tuple2 #(Bit #(64), Bit #(64))) v_addr_map);
      action
	 rg_v_addr_map <= v_addr_map;

	 $display ("%0d: Interconnect: addr map", cur_cycle);
	 for (Integer j = 0; j < valueOf (nServers_t); j = j + 1) begin
	    match { .base, .size } = v_addr_map [j];
	    $display ("    %0d:  %08x  %08x", j, base, size);
	 end
      endaction
   endmethod

endmodule

// ****************************************************************

endpackage
