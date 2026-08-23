// ==============================================================================
// LEGACY ONLY: unused by the canonical padded GLS build
// Canonical build_top.cud uses the real TSMC 28 nm I/O model instead.
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
