// Copyright (c) 2023-2025 Rishiyur S. Nikhil.  All Rights Reserved.

package Accel_IFC;

// ****************************************************************
// Imports from libraries

// none

// ----------------
// Imports from 'vendor' libs

import Semi_FIFOF :: *;

// ----------------
// Local imports

import Mem_Req_Rsp :: *;

// ****************************************************************

interface Accel_IFC;
   // Server interface to control and config the accelerator
   interface Server_Semi_FIFOF #(Mem_Req, Mem_Rsp) server;

   // Client interface for the accelerator to access memory
   interface Client_Semi_FIFOF #(Mem_Req, Mem_Rsp) client;
endinterface

// ****************************************************************

endpackage
