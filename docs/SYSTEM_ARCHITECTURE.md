# System Architecture

## 1. Overview

The CUBIC Interpolation DSP ASIC implements a dual-channel digital interpolation
pipeline for complex I/Q signals.

The design receives serial In-Phase (I) and Quadrature (Q) sample streams,
reconstructs signed input samples, performs configurable cubic interpolation,
serializes the generated interpolation points into a uniformly timed output
stream, and applies a low-pass FIR filter.

The interpolation factor is configurable for:

- L = 2
- L = 3
- L = 4
- L = 5

The I and Q channels use identical datapaths and operate from a common control
unit, ensuring synchronized processing of both components of the complex signal.

The synthesizable top-level RTL is implemented in `RTL/ASIC_top.v`.


## 2. Top-Level Architecture

The system consists of one shared control unit and two identical signal-processing
datapaths.

Functional hierarchy:

    ASIC_Top
    |
    +-- Control_Unit
    |
    +-- MinAJ2_Datapath (I channel)
    |   |
    |   +-- SIPO
    |   +-- Interpolator
    |   +-- P2S_Interpolator
    |   +-- FIR_LPF_TRANSPOSED
    |
    +-- MinAJ2_Datapath (Q channel)
        |
        +-- SIPO
        +-- Interpolator
        +-- P2S_Interpolator
        +-- FIR_LPF_TRANSPOSED

The shared control architecture guarantees that both signal components use the
same interpolation factor, sample timing and output schedule.


## 3. Top-Level Interfaces

The main functional inputs are:

| Signal | Description |
|---|---|
| `clk` | System clock |
| `rst_n` | Active-low asynchronous reset |
| `serial_in_I` | Serial I-channel input and configuration source |
| `serial_in_Q` | Serial Q-channel input |

The main functional outputs are:

| Signal | Description |
|---|---|
| `I_out[15:0]` | Signed filtered I-channel output |
| `Q_out[15:0]` | Signed filtered Q-channel output |
| `output_valid` | Indicates a synchronized valid I/Q output sample |
| `pll_active_960` | Reports the selected external clocking mode |

`output_valid` is asserted only when both I and Q datapaths independently
assert their valid outputs. This preserves alignment between the two components
of the complex sample.

The top level also contains simple combinational and registered sanity-check
paths used for implementation-level observability.


## 4. Shared Control Architecture

`Control_Unit` is responsible for configuration decoding and global sample
timing.

The control unit extracts the interpolation factor `L_val` and derives the
corresponding serial word mode.

Two serial word lengths are supported:

| Interpolation Factor | Serial Word Mode |
|---|---|
| L = 2 | 16 bit |
| L = 3 | 15 bit |
| L = 4 | 16 bit |
| L = 5 | 15 bit |

For the 15-bit operating mode, the reconstructed sample is sign-extended to the
internal 16-bit representation.

The control unit generates the following global signals:

| Signal | Function |
|---|---|
| `run_en` | Enables sample acquisition |
| `L_val` | Selects interpolation factor |
| `mode_15bit` | Selects 15-bit or 16-bit input reconstruction |
| `sub_count` | Tracks the serial/sample phase within an input word |
| `tick_60M` | Indicates completion of a reconstructed input sample |

The `tick_60M` event is registered so that the SIPO shift register has completed
the current input word before the interpolation window captures the reconstructed
sample.

Clock generation is external to the RTL. The design exposes the selected
clocking mode through `pll_active_960`.

### 4.1 Clock Mode and Sample-Rate Relationship

The serial word length and system clock mode are selected together so that one
complete input sample is reconstructed approximately every 16.67 ns, corresponding to 60 MS/s.

For 16-bit operation, 16 clock cycles are required per input sample and the
corresponding system clock mode is 960 MHz.

For 15-bit operation, 15 clock cycles are required per input sample and the
corresponding system clock mode is 900 MHz.

This maintains a constant reconstructed input-sample rate of 60 MS/s while
supporting both serial word formats.

| L | Serial Word Length | System Clock Mode | Input Sample Rate | Interpolated Sample Rate |
|---|---:|---:|---:|---:|
| 2 | 16 bit | 960 MHz | 60 MS/s | 120 MS/s |
| 3 | 15 bit | 900 MHz | 60 MS/s | 180 MS/s |
| 4 | 16 bit | 960 MHz | 60 MS/s | 240 MS/s |
| 5 | 15 bit | 900 MHz | 60 MS/s | 300 MS/s |

The interpolated sample rate is `L` times the reconstructed input-sample rate.

### 4.2 ASIC Implementation Timing Target

The 900 MHz and 960 MHz values describe the functional system clock modes used
by the serial interface.

For logic synthesis, physical implementation and final static timing analysis,
the ASIC is constrained using a 1.04 ns clock period, corresponding to
approximately 961.5 MHz.

This implementation target covers the highest-frequency 960 MHz operating mode
and provides a single timing reference for synthesis, place-and-route and
signoff analysis.

The implementation constraints also use 50 ps clock uncertainty and 50 ps
clock transition margins.


## 5. I/Q Processing Datapath

Both channels use the same `MinAJ2_Datapath` module.

The functional processing sequence is:

    Serial Input
        |
        v
      SIPO
        |
        v
    Cubic Interpolator
        |
        v
    Parallel-to-Stream Scheduler
        |
        v
    10-Tap FIR Low-Pass Filter
        |
        v
    Filtered 16-bit Output

Using identical hardware structures for the I and Q paths provides a symmetric
implementation and preserves matched latency between both channels.


## 6. Serial-to-Parallel Input Reconstruction

The `SIPO` module converts each serial input stream into a signed 16-bit internal
sample.

A 16-bit shift register is used for both operating modes.

In 16-bit mode, the complete shift register is interpreted directly as the
sample.

In 15-bit mode, bits `[14:0]` contain the valid sample and bit 14 is replicated
into bit 15 to perform signed extension.

The SIPO shifts only while `run_en` is active.


## 7. Cubic Interpolator

The interpolation engine operates on a four-sample sliding window:

    p0, p1, p2, p3

At each reconstructed input-sample event, the window advances and the newest
sample is inserted into `p3`.

The cubic interpolation kernel is implemented using fixed-point polynomial
evaluation. Polynomial evaluation uses Horner form in order to construct the
interpolation weights from a sequence of multiply-and-accumulate operations.

The interpolation phase is represented in Q3.13 fixed-point format.

For each input interval, the hardware generates one original sample together
with the required intermediate interpolation points.

| L | Generated Outputs |
|---|---|
| 2 | `y0`, `y1` |
| 3 | `y0`, `y1`, `y2` |
| 4 | `y0`, `y1`, `y2`, `y3` |
| 5 | `y0`, `y1`, `y2`, `y3`, `y4` |

`y0` corresponds to the original sample represented by the active interpolation
window. The remaining outputs are cubic interpolation points evaluated at
fractional positions determined by `L`.

The fixed-point phase locations are selected to represent the uniformly spaced
positions required by each interpolation factor.

The current top-level implementation is configured for packets of 10,000
input samples.

The interpolator includes dedicated start- and end-of-packet coefficient
handling so that the finite input sequence is processed with explicit boundary
behavior and without emitting uninitialized startup samples.


## 8. Bit-True Fixed-Point Evaluation

The cubic interpolation arithmetic uses signed fixed-point operations.

Interpolation coefficients and fractional positions use Q3.13 representation.

Each polynomial multiplication produces a wider intermediate result. Before the
result returns to the 16-bit Q3.13 representation, the implementation applies
the project's bit-true rounding operation by adding a half-LSB before removing
the 13 fractional product bits.

The interpolation output is computed as the sum of four weighted samples:

    y = p0*w0 + p1*w1 + p2*w2 + p3*w3

The four weighted products are rounded before the final summation.

This architecture preserves deterministic fixed-point behavior between the
reference model and the synthesizable hardware implementation.


## 9. Parallel-to-Stream Scheduling

The cubic interpolator produces up to five values in parallel. The
`P2S_Interpolator` module converts these values into a time-ordered output
stream.

The common `sub_count` generated by the control unit determines when each
interpolated point is transmitted.

Output positions are:

| L | Active `sub_count` Values |
|---|---|
| 2 | 7, 15 |
| 3 | 4, 9, 14 |
| 4 | 3, 7, 11, 15 |
| 5 | 2, 5, 8, 11, 14 |

This scheduling distributes the L output samples uniformly across the available
clock cycles associated with each reconstructed input interval.

The scheduler asserts `stream_valid` only when a valid interpolated output is
being transmitted.


## 10. FIR Low-Pass Filter

Each datapath contains a dedicated `FIR_LPF_TRANSPOSED` module.

The MATLAB algorithmic reference uses a 64-tap FIR low-pass filter. The RTL
implementation deliberately replaces this filter with a 10-tap symmetric,
L-dependent hardware FIR. This is a hardware-complexity tradeoff rather than a
coefficient-identical implementation of the MATLAB filter; system-level signal
quality is therefore evaluated for the complete MATLAB and RTL processing
chains.

The hardware FIR contains 10 taps and uses one of four fixed coefficient banks,
selected by the interpolation factor.

Each coefficient bank is symmetric. Therefore, only five unique multiplier
results are required to implement the ten-tap filter response.

Main implementation characteristics are:

- 10 FIR taps
- 5 unique symmetric coefficient products
- Four fixed coefficient banks selected by the interpolation factor
- Q1.14 input and output representation
- 36-bit internal accumulator stages
- Saturation to the signed 16-bit output range
- Valid-driven state updates

The FIR is implemented using a transposed accumulator structure, providing a
regular pipelined datapath suitable for synthesis and physical implementation.


## 11. I/Q Output Synchronization

The two datapaths independently generate `I_valid` and `Q_valid`.

The top-level output valid signal is defined as:

    output_valid = I_valid AND Q_valid

Because both paths share the same configuration and timing controls and contain
the same processing structure, their generated output samples remain aligned.

The final interface therefore provides synchronized filtered complex samples:

    (I_out, Q_out, output_valid)


## 12. RTL Source Map

| File | Function |
|---|---|
| `RTL/ASIC_top.v` | Top-level integration |
| `RTL/Control_Unit.v` | Configuration and global timing |
| `RTL/MinAJ2_Datapath.v` | Per-channel processing hierarchy |
| `RTL/SIPO.v` | Serial-to-parallel sample reconstruction |
| `RTL/Interpolator.v` | Fixed-point cubic interpolation |
| `RTL/P2S_Interpolator.v` | Interpolation output scheduling |
| `RTL/FIR_LPF_TRANSPOSED.v` | 10-tap configurable FIR low-pass filter |


## 13. Implementation Flow Context

The RTL architecture forms the functional core of the complete ASIC
implementation flow.

The project repository contains the complete implementation path through final
static timing analysis:

    RTL
     |
     v
    Functional Simulation
     |
     v
    Logic Synthesis
     |
     v
    Gate-Level Verification and Equivalence Checking
     |
     v
    Pad Integration
     |
     v
    Physical Design
     |
     v
    Post-Route ECO and Physical Verification
     |
     v
    Parasitic Extraction
     |
     v
    PrimeTime Static Timing Analysis

Detailed descriptions of the individual implementation stages are provided in
the remaining documents under the `docs/` directory.
