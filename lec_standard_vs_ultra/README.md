# Standard-Compile vs Compile-Ultra LEC

This directory contains the Cadence Conformal gate-to-gate equivalence check
between two current-project synthesis implementations:

Golden:
    standard Design Compiler compile + clock gating + scan

Revised:
    Design Compiler compile_ultra + clock gating + scan

The two synthesis scripts differ only in the compilation command:

    compile -gate_clock

versus:

    compile_ultra -gate_clock

The comparison evaluates functional operation with scan disabled:

    scan_en  = 0
    scan_in1 = 0
    scan_in2 = 0
    scan_in3 = 0

The comparison uses:

    set analyze option -auto
    set compare effort high

Final result:

    Processed module pairs : 5 / 5
    Equivalent              : 5
    Non-equivalent          : 0
    Abort                   : 0
    Hierarchical result     : Equivalent

The curated summary and full final Conformal log are stored under:

    results/lec/LEC_STANDARD_VS_ULTRA_SUMMARY.txt
    results/lec/LEC_STANDARD_VS_ULTRA_FULL_LOG.txt
