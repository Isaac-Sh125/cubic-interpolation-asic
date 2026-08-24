# Pre-RTL MATLAB Fixed-Point Feasibility Model

`cubic_hardware.m` is the consolidated hardware-oriented MATLAB fixed-point
model used before the synthesizable RTL implementation of the CUBIC
Interpolation DSP ASIC.

## Purpose

The MATLAB model was developed as a pre-RTL feasibility step.

Its purpose was to model the expected hardware behavior using finite-word-length
arithmetic and verify that the cubic interpolation algorithm could satisfy the
required 64-QAM signal quality before committing to an RTL implementation.

The actual development sequence was:

    Cubic interpolation concept
            |
            v
    Hardware-oriented fixed-point MATLAB model
            |
            v
    Keysight PathWave VSA validation
            |
            v
    RTL implementation
            |
            v
    Keysight PathWave VSA validation of RTL output

The MATLAB fixed-point outputs were evaluated in Keysight PathWave VSA using
the project-provided 64-QAM system reference/configuration.

After this pre-RTL feasibility stage produced acceptable signal-quality
results, the design was implemented in synthesizable RTL.

The later RTL outputs were then evaluated independently using the same
system-level Keysight VSA methodology.

The MATLAB and RTL results therefore represent two chronological validation
stages. They are not a direct sample-by-sample or bit-exact MATLAB-to-RTL
comparison.

## Supported Operating Modes

The consolidated model accepts:

    cubic_hardware(L, output_dir)

with:

    L = 2, 3, 4, 5

The model uses:

- 60 MS/s input sampling rate;
- 64-QAM stimulus generated with IQTools;
- Root Raised Cosine shaping with alpha = 0.15;
- 10,000 input samples for the preserved verification run;
- signed 16-bit fixed-point signal representation with 14 fractional bits;
- Catmull-Rom cubic interpolation for interior samples;
- quadratic edge handling;
- a 64-tap fixed-point MATLAB FIR with normalized cutoff 1/L.

## MATLAB FIR and Final RTL FIR

The pre-RTL MATLAB model uses a 64-tap FIR.

The final RTL implementation uses a different hardware-oriented 10-tap
symmetric FIR with a dedicated coefficient bank for each interpolation factor.

For this reason, the MATLAB post-FIR and RTL post-FIR sequences are not expected
to be bit-exact equivalents.

The relevant project requirement is instead verified independently at the
system level using Keysight VSA.

## Keysight VSA Results

Representative captured MATLAB EVM values are:

| L | MATLAB pre-FIR | MATLAB post-FIR |
|---:|---:|---:|
| 2 | 223.44 m%rms | 215.39 m%rms |
| 3 | 192.98 m%rms | 196.82 m%rms |
| 4 | 201.39 m%rms | 227.29 m%rms |
| 5 | 221.91 m%rms | 228.30 m%rms |

The project signal-quality requirement is:

    EVM < 350 m%rms

The preserved MATLAB measurements therefore demonstrated acceptable
fixed-point signal quality before RTL development.

## Reference Terminology

Two different references appear in the project and must not be confused.

### Keysight System Reference

The pre-RTL MATLAB output, and later the RTL output, were evaluated in Keysight
VSA using the project-provided 64-QAM system reference/configuration.

This is the system-level reference used for EVM evaluation.

### RTL-Derived Digital Regression Baseline

The later file:

    out/output_golden.txt

is different.

Despite its historical filename, this file is the preserved validated L=5 RTL
output sequence.

It is byte-identical to:

    results/verification/rtl_output_post_LPF/rtl_output_POST_LPF_L_5.txt

and is used as a digital regression baseline to verify that later RTL reruns,
synthesized gate-level simulation and pad-level simulation preserve the already
validated RTL behavior.

It is not the external system reference used during the pre-RTL MATLAB
feasibility verification.

## Preserved MATLAB Evidence

Numeric MATLAB results are stored under:

    results/verification/matlab_results/

For every supported interpolation factor, the preserved files include:

    float_reference_cubic.txt
    cubic_fixed16_strict_output_PRE_LPF_L_<L>.txt
    cubic_fixed16_strict_output_POST_LPF_L_<L>.txt

The common 60 MS/s stimulus is stored at:

    results/verification/matlab_results/iqdata_60M_use.txt

Keysight VSA screenshots generated from the MATLAB fixed-point results are
stored under:

    results/verification/matlab/pre_filter/
    results/verification/matlab/post_filter/
