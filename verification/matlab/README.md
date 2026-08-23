# MATLAB Fixed-Point Verification Model

`cubic_hardware.m` is the consolidated MATLAB fixed-point verification model
used for interpolation factors L = 2, 3, 4, and 5.

The original verification data was generated using four per-L script copies.
A direct comparison showed that those copies differed only in:

- the selected interpolation factor L;
- the PRE-LPF output filename;
- the POST-LPF output filename.

The interpolation, edge handling, fixed-point arithmetic, polynomial
coefficients and FIR implementation were otherwise identical.

The project-facing version therefore accepts L as an argument:

    cubic_hardware(L, output_dir)

Supported values are:

    L = 2, 3, 4, 5

The model uses:

- 60 MS/s input sampling rate;
- 64-QAM stimulus generated with IQTools;
- Root Raised Cosine shaping with alpha = 0.15;
- 10,000 input samples for the preserved verification run;
- signed 16-bit fixed-point signal representation with 14 fractional bits;
- Catmull-Rom cubic interpolation for interior samples;
- quadratic edge handling;
- 64-tap MATLAB FIR with normalized cutoff 1/L.

The MATLAB 64-tap FIR is an algorithmic reference implementation. The final
RTL uses a different hardware-oriented 10-tap symmetric FIR with an
L-dependent coefficient bank. MATLAB and RTL post-filter outputs are therefore
evaluated as complete signal-processing chains rather than as bit-exact
equivalent signals.

The arithmetic/local-function region of this consolidated script was compared
against the original L=5 script after ignoring whitespace differences. The
normalized algorithm SHA-256 was identical:

    788bf41b224c3f2b67647665a0ad63f20739cd0a950f40678632dd53f2e61e20

The preserved verification outputs are stored under:

    results/verification/matlab_results/

The common 60 MS/s stimulus is stored once at:

    results/verification/matlab_results/iqdata_60M_use.txt

The original per-L stimulus copies were verified byte-for-byte identical before
consolidation.

The Keysight VSA screenshots generated from the MATLAB results are stored under:

    results/verification/matlab/pre_filter/
    results/verification/matlab/post_filter/
