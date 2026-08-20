# RTL Architecture

## 1. Purpose and Design Organization

The RTL implements the synthesizable digital signal-processing core of the
CUBIC Interpolation ASIC.

The design accepts serial complex I/Q input samples, reconstructs signed input
words, performs configurable cubic interpolation, schedules the interpolated
values into a serial sample stream, and applies an L-dependent low-pass FIR
filter.

The supported interpolation factors are:

- L = 2
- L = 3
- L = 4
- L = 5

The RTL uses a single system clock and contains one common control unit together
with two identical processing datapaths, one for the In-Phase component and one
for the Quadrature component.

The complete synthesizable RTL hierarchy is:

    ASIC_Top
    |
    +-- Control_Unit
    |
    +-- MinAJ2_Datapath  [I channel]
    |   |
    |   +-- SIPO
    |   +-- Interpolator
    |   +-- P2S_Interpolator
    |   +-- FIR_LPF_TRANSPOSED
    |
    +-- MinAJ2_Datapath  [Q channel]
        |
        +-- SIPO
        +-- Interpolator
        +-- P2S_Interpolator
        +-- FIR_LPF_TRANSPOSED

The same control signals are distributed to both datapaths. This guarantees
that the I and Q channels use the same interpolation factor, serial word mode
and sample timing.


## 2. Top-Level Module: ASIC_Top

The top-level module is implemented in `RTL/ASIC_top.v`.

Its main responsibilities are:

1. instantiate the global control unit;
2. instantiate identical I and Q datapaths;
3. distribute common timing and configuration information;
4. combine the two datapath valid signals;
5. expose the final signed I/Q outputs.

The main functional input interface is:

| Signal | Width | Description |
|---|---:|---|
| `clk` | 1 | System clock |
| `rst_n` | 1 | Active-low asynchronous reset |
| `serial_in_I` | 1 | Serial I-channel input |
| `serial_in_Q` | 1 | Serial Q-channel input |

The main output interface is:

| Signal | Width | Description |
|---|---:|---|
| `I_out` | 16 | Signed filtered I output |
| `Q_out` | 16 | Signed filtered Q output |
| `output_valid` | 1 | Valid indication for aligned I/Q output |
| `pll_active_960` | 1 | Indicates the selected 960 MHz interface mode |

The final data outputs are direct connections to the two FIR datapaths:

    I_out = I_filt
    Q_out = Q_filt

The final valid signal is:

    output_valid = I_valid & Q_valid

Therefore, an output complex sample is considered valid only when both
components are simultaneously valid.


## 3. Configuration Protocol

System configuration is performed before normal sample streaming begins.

The configuration is transferred through `serial_in_I` using a four-bit header.
The RTL testbench constructs the header as:

    cfg_word = {1'b1, L_VALUE[2:0]}

Therefore:

| Configuration Bit | Function |
|---|---|
| bit 3 | Configuration enable/start bit |
| bits 2:0 | Interpolation factor L |

The header is transmitted MSB-first.

The supported encoded interpolation factors are 2, 3, 4 and 5. The
`Control_Unit` explicitly identifies values outside this range as illegal and
does not enable normal data acquisition for an illegal configuration.

After a valid configuration has been captured, the control unit stores `L_val`,
selects the serial word mode and asserts `run_en`.

The configuration remains stable throughout normal packet processing.


## 4. Clock and Serial Word Modes

The serial input format depends on the selected interpolation factor.

Two modes are implemented:

| L | Input Word Length | Nominal System Clock |
|---|---:|---:|
| 2 | 16 bits | 960 MHz |
| 3 | 15 bits | 900 MHz |
| 4 | 16 bits | 960 MHz |
| 5 | 15 bits | 900 MHz |

For L=2 and L=4:

    mode_15bit = 0
    pll_req_960 = 1

For L=3 and L=5:

    mode_15bit = 1
    pll_req_960 = 0

The relationship between word length and clock frequency maintains an input
sample rate of approximately 60 MS/s.

For 16-bit operation:

    960 MHz / 16 = 60 MS/s

For 15-bit operation:

    900 MHz / 15 = 60 MS/s

The synthesizable RTL does not generate these clock frequencies internally.
Clock generation is external to the digital core, while `pll_req_960` exposes
the selected operating mode.

For ASIC implementation and timing signoff, the complete design is constrained
against a 1.04 ns system-clock period.


## 5. Control Unit

The `Control_Unit` module is implemented in `RTL/Control_Unit.v`.

It performs three primary tasks:

- configuration capture and decoding;
- generation of the serial-word phase counter;
- generation of the reconstructed-sample timing event.

### 5.1 Configuration State

The configuration state consists primarily of:

    cfg_reg
    cfg_valid
    L_val
    mode_15bit
    pll_req_960
    run_en

Before `cfg_valid` is asserted, incoming configuration bits are shifted into
`cfg_reg`.

Once the configuration has been recognized, the selected interpolation factor
is stored in `L_val`.

The design then derives `mode_15bit` and `pll_req_960` from L and asserts
`run_en` when the configuration is valid.


## 6. Global Phase Counter

After configuration, `sub_count` tracks the current clock position within a
serial input word.

The terminal count depends on the selected serial word length:

    max_count = 14   for 15-bit mode
    max_count = 15   for 16-bit mode

Therefore, `sub_count` cycles through:

    0 ... 14   for L=3 and L=5

or:

    0 ... 15   for L=2 and L=4

When `run_en` is inactive, `sub_count` is held at zero.


## 7. Reconstructed-Sample Tick

A complete serial input word becomes available at the end of each `sub_count`
cycle.

The control unit generates `tick_60M` as a registered pulse derived from the
terminal-count condition.

Conceptually:

    serial bits shift into SIPO
              |
              v
      final serial bit captured
              |
              v
      terminal count detected
              |
              v
      registered tick_60M pulse
              |
              v
      interpolator captures SIPO word

The extra registered timing step ensures that the SIPO has already captured the
final serial bit before the reconstructed sample is transferred into the cubic
interpolation window.

The resulting `tick_60M` event occurs at the reconstructed input-sample rate,
approximately 60 MHz.


## 8. Per-Channel Datapath

`MinAJ2_Datapath` encapsulates the signal-processing chain for one signal
component.

The module contains:

    SIPO
      |
      v
    Interpolator
      |
      v
    P2S_Interpolator
      |
      v
    FIR_LPF_TRANSPOSED

The same module is instantiated twice in `ASIC_Top`.

The I-channel instance receives `serial_in_I`, while the Q-channel instance
receives `serial_in_Q`.

Both receive identical:

    clk
    rst_n
    run_en
    tick_60M
    sub_count
    L_val
    mode_15bit

This creates structurally symmetric I and Q processing paths.


## 9. SIPO Input Reconstruction

The `SIPO` module is implemented in `RTL/SIPO.v`.

A single 16-bit shift register is used for both supported word modes.

While `enable` is asserted, the shift operation is:

    shift_reg <= {shift_reg[14:0], serial_in}

The testbench transmits each input word MSB-first.

### 9.1 16-Bit Mode

For L=2 and L=4, all sixteen bits are valid:

    data_out = shift_reg[15:0]

The sample is interpreted as a signed 16-bit value.

### 9.2 15-Bit Mode

For L=3 and L=5, the valid word occupies bits `[14:0]`.

The RTL converts it into the internal signed 16-bit representation by sign
extension:

    data_out = {shift_reg[14], shift_reg[14:0]}

As a result, the downstream interpolation hardware always operates on a common
signed 16-bit sample representation regardless of the serial word mode.


## 10. Cubic Interpolation Window

The `Interpolator` module is implemented in `RTL/Interpolator.v`.

The interpolation engine maintains a four-sample sliding window:

    p0
    p1
    p2
    p3

At every `tick_60M` event, the state advances according to:

    p0 <= p1
    p1 <= p2
    p2 <= p3
    p3 <= sipo_data

This creates a continuously updated four-point neighborhood for cubic
interpolation.

A local `sample_cnt` tracks the number of reconstructed input samples that have
entered the interpolation engine.


## 11. Window Priming and Valid Control

Immediately after reset, the four-sample interpolation window does not yet
contain a complete neighborhood.

The RTL therefore delays assertion of `interp_valid` until the window has been
primed.

The implemented start condition is associated with:

    sample_cnt == 3

At this point the active window contains the samples required to begin producing
valid interpolation output.

The interpolator also tracks the end of the configured packet so that the final
boundary region can be processed before `interp_valid` is deasserted.

The current top-level design is configured for:

    PACKET_LEN = 10000

input samples.


## 12. Fixed-Point Representation

The cubic interpolation kernel uses signed 16-bit fixed-point arithmetic.

The interpolation phase `u` and the interpolation polynomial coefficients use
Q3.13 representation.

This means that the numerical value represented by a 16-bit fixed-point word is:

    real_value = signed_integer / 2^13

Examples are:

| Hexadecimal | Q3.13 Value |
|---|---:|
| `0x0800` | 0.25 |
| `0x1000` | 0.50 |
| `0x1800` | 0.75 |
| `0x2000` | 1.00 |

Signed hexadecimal values are interpreted using two's-complement arithmetic.


## 13. Interpolation Phase Values

For each interpolation factor, the RTL selects fixed-point values representing
the required fractional positions between consecutive original samples.

### L = 2

One intermediate point is evaluated:

| Point | Hex | Approximate u |
|---|---:|---:|
| u1 | `0x1000` | 0.5 |

Together with the original point, this produces two output samples per input
interval.

### L = 3

Two intermediate points are evaluated:

| Point | Hex | Approximate u |
|---|---:|---:|
| u1 | `0x0AAB` | 0.33337 |
| u2 | `0x1555` | 0.66663 |

### L = 4

Three intermediate points are evaluated:

| Point | Hex | Approximate u |
|---|---:|---:|
| u1 | `0x0800` | 0.25 |
| u2 | `0x1000` | 0.50 |
| u3 | `0x1800` | 0.75 |

### L = 5

Four intermediate points are evaluated:

| Point | Hex | Approximate u |
|---|---:|---:|
| u1 | `0x0666` | 0.19995 |
| u2 | `0x0CCD` | 0.40002 |
| u3 | `0x1333` | 0.59998 |
| u4 | `0x199A` | 0.80005 |

These values are the Q3.13 representations used by the actual hardware and
therefore define the bit-true interpolation phase positions.


## 14. Cubic Basis

For normal interior samples, the four interpolation weights implemented by
`compute_lane` correspond to the cubic Catmull-Rom basis.

Using normalized phase `u`, the interior weights are:

    w0(u) = -0.5*u^3 + 1.0*u^2 - 0.5*u

    w1(u) =  1.5*u^3 - 2.5*u^2 + 1.0

    w2(u) = -1.5*u^3 + 2.0*u^2 + 0.5*u

    w3(u) =  0.5*u^3 - 0.5*u^2

The interpolated output is formed as:

    y(u) = p0*w0(u)
         + p1*w1(u)
         + p2*w2(u)
         + p3*w3(u)

The RTL stores the polynomial coefficients directly in Q3.13 hexadecimal form.

For example, the normal `w0` polynomial uses:

    c3 = 0xF000  = -0.5
    c2 = 0x2000  =  1.0
    c1 = 0xF000  = -0.5
    c0 = 0x0000  =  0.0

This avoids floating-point arithmetic and provides deterministic synthesizable
fixed-point behavior.


## 15. Horner Polynomial Evaluation

Each cubic basis polynomial is evaluated using Horner form.

A polynomial:

    c3*u^3 + c2*u^2 + c1*u + c0

is evaluated as:

    ((c3*u + c2)*u + c1)*u + c0

The RTL function `eval_poly` implements this sequence using three
multiplications.

This structure avoids explicit computation of `u^2` and `u^3` and creates a
regular multiply-add datapath suitable for hardware synthesis.


## 16. Fixed-Point Product Rounding

Inside `eval_poly`, multiplication of two Q3.13 operands produces a wider
product containing 26 fractional bits.

The `slice_round` function rescales the intermediate result back to the
16-bit representation used by the interpolation arithmetic.

The implemented operation is:

    rounded = val + 4096
    result  = rounded >>> 13

Since:

    4096 = 2^12

the added value provides the half-LSB bias used by the project's bit-true
fixed-point rounding convention before the 13-bit arithmetic right shift.

The same rescaling operation is also applied to the final sample-weight
products. In that stage, each signed input sample is multiplied by a Q3.13
interpolation weight and the product is divided by 2^13 before summation.

This keeps the interpolation result in the signed 16-bit sample domain.


## 17. Lane Computation

The `compute_lane` function performs one complete interpolation evaluation for a
selected value of `u`.

The computation can be summarized as:

    u
    |
    +--> evaluate w0
    +--> evaluate w1
    +--> evaluate w2
    +--> evaluate w3
             |
             v
    p0*w0, p1*w1, p2*w2, p3*w3
             |
             v
       fixed-point rescaling
             |
             v
           summation
             |
             v
        16-bit output

Up to four intermediate lanes are evaluated in parallel:

    w_y1
    w_y2
    w_y3
    w_y4

The number of active lanes is determined by `L_val`.


## 18. Boundary Handling

The first and last interpolation neighborhoods require dedicated behavior
because a complete four-sample neighborhood does not exist beyond the finite
packet boundaries.

The RTL therefore selects separate polynomial coefficient sets for:

    start_flag
    normal interior operation
    end_flag

For the first active interpolation region, the unavailable outer contribution
is explicitly suppressed and a dedicated start coefficient set is used.

For the final region, the phase is mirrored using:

    u_use = 1 - u

and a corresponding end coefficient set is selected.

This provides deterministic handling of the finite packet edges within the
same fixed-point interpolation datapath.


## 19. Parallel Interpolator Outputs

At every reconstructed input-sample event, the interpolator latches the original
sample and the computed intermediate points.

The output registers are:

    y0
    y1
    y2
    y3
    y4

The first output is:

    y0 <= p1

The remaining outputs are selected from the computed interpolation lanes.

The number of meaningful outputs depends on L:

| L | Valid Parallel Outputs |
|---|---|
| 2 | y0, y1 |
| 3 | y0, y1, y2 |
| 4 | y0, y1, y2, y3 |
| 5 | y0, y1, y2, y3, y4 |


## 20. P2S Interpolation Scheduler

The `P2S_Interpolator` module converts the parallel interpolator outputs into a
uniformly scheduled serial sample stream.

The module uses the shared `sub_count` value to select one of the parallel
interpolator results at the appropriate system-clock cycle.

The exact schedule is:

| L | Output | sub_count |
|---|---|---:|
| 2 | y0 | 7 |
| 2 | y1 | 15 |
| 3 | y0 | 4 |
| 3 | y1 | 9 |
| 3 | y2 | 14 |
| 4 | y0 | 3 |
| 4 | y1 | 7 |
| 4 | y2 | 11 |
| 4 | y3 | 15 |
| 5 | y0 | 2 |
| 5 | y1 | 5 |
| 5 | y2 | 8 |
| 5 | y3 | 11 |
| 5 | y4 | 14 |

Whenever one of these scheduled positions is reached:

    stream_out   <= selected interpolation value
    stream_valid <= 1

At other clock positions:

    stream_valid <= 0

The entire scheduler is additionally gated by `interp_valid`, preventing output
generation before the interpolation window is ready.


## 21. Effective Output Rate

The P2S schedule produces exactly L valid output samples for each reconstructed
60 MS/s input interval.

Therefore:

    Fout = L * 60 MS/s

which gives:

| L | Output Sample Rate |
|---|---:|
| 2 | 120 MS/s |
| 3 | 180 MS/s |
| 4 | 240 MS/s |
| 5 | 300 MS/s |

The L=5 mode produces the highest output-event density.

In this mode, valid interpolated values occur every three 900 MHz system-clock
cycles:

    sub_count 2 -> 5 -> 8 -> 11 -> 14

This valid-event cadence is important to the downstream FIR architecture and
its implementation timing constraints.


## 22. FIR Low-Pass Filter

The final stage of each datapath is `FIR_LPF_TRANSPOSED`, implemented in
`RTL/FIR_LPF_TRANSPOSED.v`.

The filter has:

    NTAPS = 10
    fractional length = 14 bits

The input and output sample representation is Q1.14.

The FIR uses four fixed coefficient banks, one for each supported interpolation
factor.


## 23. FIR Coefficient Banks

The ten coefficients are symmetric around the center of the filter.

### L = 2

    h0 = h9 =   146
    h1 = h8 =   -63
    h2 = h7 = -1190
    h3 = h6 =  1525
    h4 = h5 =  7773

### L = 3

    h0 = h9 =   219
    h1 = h8 = -1104
    h2 = h7 =    -5
    h3 = h6 =  3030
    h4 = h5 =  6052

### L = 4

    h0 = h9 =  -592
    h1 = h8 =  -697
    h2 = h7 =  1682
    h3 = h6 =  3097
    h4 = h5 =  4703

### L = 5

    h0 = h9 = -1740
    h1 = h8 =  1152
    h2 = h7 =  2038
    h3 = h6 =  3046
    h4 = h5 =  3696

The coefficients are stored as signed 16-bit fixed-point integers representing
Q1.14 values.


## 24. Symmetry Optimization

A direct ten-tap implementation could require ten coefficient multiplications.

Because the coefficients are symmetric:

    h[k] = h[9-k]

only five unique products are required for each incoming sample.

The RTL therefore generates:

    prod[0]
    prod[1]
    prod[2]
    prod[3]
    prod[4]

where:

    prod[g] = x_in * coeff(g, L_val)

The same five products are reused by the second half of the accumulator chain.

This reduces the number of unique multiplier operations associated with the
symmetric filter coefficients.


## 25. Transposed Accumulator Structure

The FIR uses ten signed 36-bit accumulator stages:

    acc_stage[0] ... acc_stage[9]

For the first half:

    acc_stage[0] <= prod[0]

    acc_stage[1] <= acc_stage[0] + prod[1]
    acc_stage[2] <= acc_stage[1] + prod[2]
    acc_stage[3] <= acc_stage[2] + prod[3]
    acc_stage[4] <= acc_stage[3] + prod[4]

For the second half, the symmetric products are reused:

    acc_stage[5] <= acc_stage[4] + prod[4]
    acc_stage[6] <= acc_stage[5] + prod[3]
    acc_stage[7] <= acc_stage[6] + prod[2]
    acc_stage[8] <= acc_stage[7] + prod[1]
    acc_stage[9] <= acc_stage[8] + prod[0]

The FIR state advances only when `x_valid` is asserted.

Therefore, inactive system-clock cycles do not advance the filter sample state.

Because the accumulator stages are updated with nonblocking assignments,
`y_out` is formed from the previously completed `acc_stage[9]` value at each
valid event. This introduces one valid-sample registered output latency while
preserving a throughput of one filtered result for each subsequent `x_valid`
event.


## 26. FIR Output Scaling

The FIR input and coefficients are represented using 14 fractional bits.

Before generating the final 16-bit output, the accumulator is rescaled by:

    final_acc = acc_stage[9] >>> 14

This removes the coefficient fractional scaling from the accumulated result.


## 27. FIR Saturation

After fixed-point rescaling, the result is limited to the signed 16-bit output
range.

The implemented limits are:

    maximum =  32767
    minimum = -32768

If the accumulator exceeds the positive limit, the output is saturated to:

    0x7FFF

If it falls below the negative limit, the output is saturated to:

    0x8000

Otherwise, the lower signed 16-bit result is transferred to `y_out`.

This prevents arithmetic overflow from wrapping around at the final interface.


## 28. FIR Valid Behavior

The FIR is driven by the P2S `stream_valid` signal.

When `x_valid` is low:

    y_valid = 0

and the filter accumulator state does not advance.

When `x_valid` is high, the FIR performs the valid-driven accumulator update and
asserts `y_valid`.

The filter remains physically clocked by the common high-frequency system
clock. Its sample-processing state, however, advances only on valid interpolated
sample events.

For L=5, the maximum event rate is one sample every three system-clock cycles,
corresponding to an effective sample rate of approximately 300 MS/s.


## 29. Valid-Signal Chain

The complete data-valid chain is:

    interpolator window ready
              |
              v
         interp_valid
              |
              v
      P2S scheduled point
              |
              v
         stream_valid
              |
              v
         FIR x_valid
              |
              v
          FIR y_valid
              |
              v
        I_valid / Q_valid
              |
              v
       output_valid

The top-level valid signal is the logical AND of the two channel-valid signals,
maintaining I/Q sample alignment at the external output.


## 30. Reset Strategy

The synthesizable state elements use an active-low asynchronous reset.

The common reset input is:

    rst_n

and appears in sequential processes in the form:

    always @(posedge clk or negedge rst_n)

Reset initializes the major state elements including:

- configuration state;
- phase counters;
- SIPO registers;
- interpolation window registers;
- interpolation valid state;
- P2S output state;
- FIR accumulators and outputs;
- top-level registered sanity path.

Normal operation begins after reset is released and the configuration header has
been accepted.


## 31. Functional Verification Interface

The RTL testbench is implemented in `RTL/tb_asic.sv`.

It performs the following high-level sequence:

    assert reset
          |
          v
    release reset
          |
          v
    transmit 4-bit configuration
          |
          v
    wait for run_en
          |
          v
    stream I/Q input samples MSB-first
          |
          v
    monitor output_valid
          |
          v
    write valid I/Q outputs to file

For the standard L=5 configuration, the testbench reads:

    input_hex_60M_L_5.txt

and writes:

    rtl_output_POST_LPF_L_5.txt

The same testbench structure supports L=2 through L=5 by selecting `L_VALUE`,
the corresponding input file and the corresponding clock mode.


## 32. Timing-Aware RTL Structure

The RTL intentionally contains datapath state that does not require a new
functional result on every system-clock edge.

The cubic interpolation output registers update at the reconstructed input
sample cadence, controlled by `tick_60M`.

The FIR accumulator state updates only when a valid interpolated sample arrives.

These architectural properties are represented in the implementation
constraints using multicycle timing paths.

The main implementation constraints associated with these structures are:

| Functional Structure | Setup Multicycle | Hold Multicycle |
|---|---:|---:|
| Interpolator output registers | 14 | 13 |
| FIR registers | 3 | 2 |

These constraints retain timing analysis on the paths while matching the
functional update cadence of the corresponding state elements.

Detailed synthesis and signoff constraint methodology is documented separately
in the synthesis and static-timing-analysis documentation.


## 33. RTL File Map

| File | Main Responsibility |
|---|---|
| `RTL/ASIC_top.v` | Top-level integration and I/Q synchronization |
| `RTL/Control_Unit.v` | Configuration, word-mode selection and sample timing |
| `RTL/MinAJ2_Datapath.v` | Per-channel DSP hierarchy |
| `RTL/SIPO.v` | Serial-to-parallel signed sample reconstruction |
| `RTL/Interpolator.v` | Four-sample fixed-point cubic interpolation |
| `RTL/P2S_Interpolator.v` | Time scheduling of parallel interpolation results |
| `RTL/FIR_LPF_TRANSPOSED.v` | Configurable ten-tap FIR low-pass filter |
| `RTL/tb_asic.sv` | RTL simulation stimulus and output capture |


## 34. Architectural Summary

The RTL architecture combines a high-rate serial interface with a lower-rate
sample-processing pipeline.

Configuration determines the interpolation factor, input word length and
clocking mode.

Each 60 MS/s input sample is reconstructed from the serial interface and inserted
into a four-sample cubic interpolation window.

The interpolator generates the required fractional samples in fixed-point
arithmetic, while the P2S scheduler distributes the results at the required
L-times output rate.

A configurable symmetric ten-tap FIR filter then performs the final low-pass
filtering stage.

The two identical I/Q datapaths share timing and configuration control,
resulting in a synchronized dual-channel implementation suitable for logic
synthesis, physical design and static timing signoff.
