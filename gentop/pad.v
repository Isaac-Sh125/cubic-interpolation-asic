// ==============================================================================
// TSMC 28nm Simulation Pad Model Definitions (Empty Functional Shells)
// File: innovus/datain/pads.v
// ==============================================================================

// Input Pad Functional Model Shell
module PDB22DG (PAD, I, O, OEN, REN);
    inout PAD;
    input O;
    input OEN;
    input REN;
    output I;
endmodule

// Core Power Pad Module
module VDDC ();
endmodule

// Core Ground Pad Module
module VSSC ();
endmodule

// Pad Ring Power Pad Module
module VDDP ();
endmodule

// Pad Ring Ground Pad Module
module VSSP ();
endmodule

// Analog Bias Supply Pad Module
module PBIAS ();
endmodule
