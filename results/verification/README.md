# Verification Evidence

This directory contains the preserved numerical and visual evidence for the
project verification flow.

The evidence belongs to three related but distinct verification stages.

## 1. Pre-RTL Fixed-Point Feasibility

Before RTL development, `verification/matlab/cubic_hardware.m` was used as a
hardware-oriented fixed-point MATLAB model.

Its outputs were evaluated in Keysight PathWave VSA using the
project-provided 64-QAM system reference.

Evidence:

    matlab/pre_filter/
    matlab/post_filter/
    matlab_results/

These measurements were used to establish fixed-point feasibility before RTL
implementation.

## 2. RTL Signal-Quality Validation

After RTL implementation, the post-FIR RTL output was evaluated using the same
system-level Keysight methodology and reference.

Evidence:

    rtl/
    rtl_output_post_LPF/

Representative captured RTL EVM:

    approximately 176-267 m%rms

Project requirement:

    EVM < 350 m%rms

All four supported RTL modes satisfy the requirement.

## 3. Downstream Digital Preservation

After the L=5 RTL output had been validated, the complete output sequence was
preserved as:

    ../../out/output_golden.txt

This is an RTL-derived regression baseline.

It is byte-identical to:

    rtl_output_post_LPF/rtl_output_POST_LPF_L_5.txt

Both contain 49,978 samples and share SHA-256:

    6c669c2771e14a7b7e9a83124db0354d2bdda95fd6f41fd549d216fbc017c693

This baseline is later used to verify preservation through:

- RTL regression;
- synthesized gate-level simulation;
- pad-level gate simulation.

Cadence Conformal LEC independently verifies RTL-to-gate logical equivalence.

## Important Reference Distinction

The project-provided 64-QAM system reference used by Keysight VSA is not the
same object as `out/output_golden.txt`.

The first is the system-level reference used for EVM verification.

The second is the later RTL-derived digital regression baseline.

## Summary Files

    keysight_vsa_summary.txt
    digital_verification_summary.txt
