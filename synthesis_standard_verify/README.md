# Standard-Compile Verification Variant

This directory contains an isolated synthesis variant used only for
verification of synthesis-strategy equivalence.

It is not the physical-implementation source of truth.

The production implementation uses the canonical synthesis flow under:

    synthesis/

with:

    compile_ultra -gate_clock

This verification variant uses the same current RTL, constraints, technology
setup, clock-gating configuration and scan flow, but replaces the compilation
command with:

    compile -gate_clock

A direct script comparison confirms that this compile command is the only
functional difference between:

    synthesis/scripts/synthesis.tcl

and:

    synthesis_standard_verify/scripts/synthesis_standard.tcl

The resulting standard-compile gate-level netlist is preserved at:

    synthesis_standard_verify/dataout/ASIC_Top_netlist.v

It is used only as the Golden implementation in the standard-vs-ultra
gate-to-gate Conformal LEC comparison.

The corresponding LEC environment is:

    lec_standard_vs_ultra/

and the final result is documented in:

    results/lec/LEC_STANDARD_VS_ULTRA_SUMMARY.txt
