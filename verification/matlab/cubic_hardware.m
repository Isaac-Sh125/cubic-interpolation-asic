function cubic_hardware(L, output_dir)
% CUBIC_HARDWARE
% Fixed-point MATLAB reference flow for the CUBIC interpolation ASIC.
%
% The same implementation is used for interpolation factors L = 2, 3, 4, 5.
%
% Usage:
%
%   cubic_hardware(2, 'results/verification/matlab_results/L=2');
%   cubic_hardware(3, 'results/verification/matlab_results/L=3');
%   cubic_hardware(4, 'results/verification/matlab_results/L=4');
%   cubic_hardware(5, 'results/verification/matlab_results/L=5');
%
% Flow:
%   1. Generate the 60 MS/s 64-QAM stimulus
%   2. Generate a floating-point cubic reference
%   3. Run the strict 16-bit fixed-point cubic interpolation model
%   4. Export the pre-FIR fixed-point signal
%   5. Apply the 64-tap MATLAB fixed-point FIR
%   6. Export the post-FIR fixed-point signal

if nargin < 1
    error('Usage: cubic_hardware(L [, output_dir])');
end

if ~ismember(L, [2 3 4 5])
    error('Supported interpolation factors are L = 2, 3, 4, 5.');
end

if nargin < 2 || isempty(output_dir)
    output_dir = pwd;
end

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

clc;
close all;
rng(0);

% IQTools must provide iqmod().
% Either add IQTools to the MATLAB path before running, or define the
% environment variable IQTOOLS_PATH.
if exist('iqmod', 'file') ~= 2
    IQTOOLS_PATH = getenv('IQTOOLS_PATH');

    if ~isempty(IQTOOLS_PATH) && exist(IQTOOLS_PATH, 'dir')
        addpath(genpath(IQTOOLS_PATH));
    end
end

if exist('iqmod', 'file') ~= 2
    error(['IQTools function iqmod() was not found. Add IQTools to the ' ...
           'MATLAB path or define the IQTOOLS_PATH environment variable.']);
end

%% Shared parameters
samplefactor   = L;
samplerate     = 3;
samplerate1    = samplerate * samplefactor;
alpha          = 0.15;
fs             = 60e6;
fs1            = fs * samplefactor;
number_symbols = 4000;
L              = samplefactor;
% LIMIT TO 10,000 SAMPLES TO PREVENT LONG RUNTIMES
maxSamples60   = 10000;
%% Fixed-point normalization knob
TARGET_PEAK = 0.8;
%% =========================
%  1. Generate signals
% =========================
fprintf('1. Generating Signal...\n');
[iqdata_60M, iqdata_300M, fs, fs1] = generateQAMSignals( ...
    samplerate, samplerate1, alpha, fs, fs1, number_symbols);

% --- CRITICAL: TRUNCATE INPUT ---
N60_full       = length(iqdata_60M);
N60_use        = min(maxSamples60, N60_full);
iqdata_60M_use = iqdata_60M(1:N60_use);
fprintf('   Using %d samples (Truncated from %d)\n', N60_use, N60_full);

%% Output files
input_file = fullfile(output_dir, 'iqdata_60M_use.txt');
float_file = fullfile(output_dir, 'float_reference_cubic.txt');
pre_file   = fullfile(output_dir, ...
    sprintf('cubic_fixed16_strict_output_PRE_LPF_L_%d.txt', L));
post_file  = fullfile(output_dir, ...
    sprintf('cubic_fixed16_strict_output_POST_LPF_L_%d.txt', L));

%% Export original input
save_complex_signal_to_txt(iqdata_60M_use, input_file);

%% =========================
%  2. FLOAT reference ('cubic')
% =========================
fprintf('2. Running Float Reference (interp1 cubic)...\n');
t_in = 0:N60_use-1;
t_out = 0 : 1/L : (N60_use-1);
% Transpose to column vector
x_cubic_builtin = interp1(t_in, iqdata_60M_use, t_out, 'cubic').';
save_complex_signal_to_txt(x_cubic_builtin, float_file);

%% =========================
%  3. FIXED-POINT CHAIN
% =========================
% --- A. Normalization ---
% We normalize based on the truncated segment to ensure consistent scaling for this run
[x_norm_use, x_rms, peak_norm, scale] = normalize_to_target_peak(iqdata_60M_use, TARGET_PEAK);

% Hardware Specs
HW_WL = 16;
HW_FL = 14;

% --- B. CUBIC ARITHMETIC Interpolation ---
fprintf('3. Running Strict 16-bit Cubic Arithmetic (This is slow in MATLAB)...\n');
% Process Real and Imag separately
fprintf('   Processing Real Component...\n');
yI_cubic = cubic_fixed_strict16(real(x_norm_use), L, HW_WL, HW_FL);
fprintf('   Processing Imag Component...\n');
yQ_cubic = cubic_fixed_strict16(imag(x_norm_use), L, HW_WL, HW_FL);

% >>> EXPORT 1: PRE-FILTER (Rescaled) <<<
iq_pre_lpf = complex(double(yI_cubic), double(yQ_cubic)) * (x_rms / scale);
save_complex_signal_to_txt(iq_pre_lpf, pre_file);

% --- C. LPF Filtering ---
fprintf('4. Running Strict 16-bit FIR LPF...\n');
% Design 64-tap FIR LPF (normalized cutoff = 1/L)
N_taps = 64;
b_float = fir1(N_taps-1, 1/L, 'low', hamming(N_taps));
% Quantize Coefficients to 16-bit (Q1.15)
b_fixed = fi(b_float, 1, 16, 15);

% Apply Filter
yI_filt = fir_fixed_strict16(yI_cubic, b_fixed, HW_WL, HW_FL);
yQ_filt = fir_fixed_strict16(yQ_cubic, b_fixed, HW_WL, HW_FL);

% >>> EXPORT 2: POST-FILTER (Rescaled) <<<
iq_post_lpf = complex(double(yI_filt), double(yQ_filt)) * (x_rms / scale);
save_complex_signal_to_txt(iq_post_lpf, post_file);

fprintf('\nDONE. Exported MATLAB verification data for L=%d:\n', L);
fprintf('  %s\n', input_file);
fprintf('  %s\n', float_file);
fprintf('  %s\n', pre_file);
fprintf('  %s\n', post_file);

end

%% =========================================================
%  LOCAL FUNCTIONS
% =========================================================

function y_out = cubic_fixed_strict16(x_in, L, wl, fl)
    % Strict 16-bit Arithmetic Implementation of:
    % 1. Catmull-Rom (Core)
    % 2. Quadratic Extrapolation (Edges)

    % Types
    T_sig  = numerictype(1, wl, fl);
    % Coefficients need range [-2.5, 2.5], so we use Q3.13 (1 sign, 2 int, 13 frac)
    T_coef = numerictype(1, 16, 13);

    F = fimath('RoundingMethod','Nearest', 'OverflowAction','Saturate', ...
               'ProductMode','FullPrecision', 'SumMode','FullPrecision');

    x_fi = fi(x_in, T_sig, F);
    N = length(x_fi);
    N_out = (N-1)*L + 1;
    y_out = fi(zeros(N_out, 1), T_sig, F);

    % --- POLYNOMIAL COEFFICIENTS ---
    % Core (Catmull-Rom alpha=-0.5) [u^3, u^2, u, 1]
    C_Core_M1 = fi([-0.5,  1.0, -0.5,  0.0], T_coef, F);
    C_Core_0  = fi([ 1.5, -2.5,  0.0,  1.0], T_coef, F);
    C_Core_1  = fi([-1.5,  2.0,  0.5,  0.0], T_coef, F);
    C_Core_2  = fi([ 0.5, -0.5,  0.0,  0.0], T_coef, F);

    % Start Edge (Quadratic)
    C_Start_1 = fi([0.0,  0.5, -1.5, 1.0], T_coef, F);
    C_Start_2 = fi([0.0, -1.0,  2.0, 0.0], T_coef, F);
    C_Start_3 = fi([0.0,  0.5, -0.5, 0.0], T_coef, F);

    idx = 1;

    % Progress reporting
    print_step = floor((N-1)/10);

    for k = 1:N-1
        if mod(k, print_step) == 0
            fprintf('      Progress: %d%%\n', round((k/(N-1))*100));
        end

        is_start = (k == 1);
        is_end   = (k == N-1);

        % Fetch Core Neighbors
        if k>1, p0=x_fi(k-1); else, p0=fi(0,T_sig,F); end
        p1 = x_fi(k);
        p2 = x_fi(k+1);
        if k+2<=N, p3=x_fi(k+2); else, p3=fi(0,T_sig,F); end

        % Fetch Edge Neighbors
        if is_start
            es1=x_fi(1); es2=x_fi(2); es3=x_fi(3);
        elseif is_end
            ee1=x_fi(N); ee2=x_fi(N-1); ee3=x_fi(N-2);
        end

        for i = 0:L-1
            u_dbl = i/L;
            u = fi(u_dbl, T_coef, F);

            val = fi(0, T_sig, F);

            if is_start
                % --- START SEGMENT ---
                w1 = poly_eval_fixed(C_Start_1, u, T_coef, F);
                w2 = poly_eval_fixed(C_Start_2, u, T_coef, F);
                w3 = poly_eval_fixed(C_Start_3, u, T_coef, F);

                term1 = fi(w1*es1, T_sig, F);
                term2 = fi(w2*es2, T_sig, F);
                term3 = fi(w3*es3, T_sig, F);
                val(:) = term1 + term2 + term3;

            elseif is_end
                % --- END SEGMENT ---
                u_rev = fi(1.0 - u_dbl, T_coef, F);

                w1 = poly_eval_fixed(C_Start_1, u_rev, T_coef, F);
                w2 = poly_eval_fixed(C_Start_2, u_rev, T_coef, F);
                w3 = poly_eval_fixed(C_Start_3, u_rev, T_coef, F);

                term1 = fi(w1*ee1, T_sig, F);
                term2 = fi(w2*ee2, T_sig, F);
                term3 = fi(w3*ee3, T_sig, F);
                val(:) = term1 + term2 + term3;

            else
                % --- CORE SEGMENT ---
                w0 = poly_eval_fixed(C_Core_M1, u, T_coef, F);
                w1 = poly_eval_fixed(C_Core_0,  u, T_coef, F);
                w2 = poly_eval_fixed(C_Core_1,  u, T_coef, F);
                w3 = poly_eval_fixed(C_Core_2,  u, T_coef, F);

                term0 = fi(w0*p0, T_sig, F);
                term1 = fi(w1*p1, T_sig, F);
                term2 = fi(w2*p2, T_sig, F);
                term3 = fi(w3*p3, T_sig, F);

                val(:) = term0 + term1 + term2 + term3;
            end

            y_out(idx) = val;
            idx = idx + 1;
        end
    end
    y_out(end) = x_fi(end);
end

% Horner's Method with strict casting
function res = poly_eval_fixed(C, u, T_type, F)
    % ((A*u + B)*u + C)*u + D
    acc = fi(C(1) * u, T_type, F);
    acc(:) = acc + C(2);
    acc(:) = acc * u;
    acc(:) = acc + C(3);
    acc(:) = acc * u;
    acc(:) = acc + C(4);
    res = acc;
end

function y_out = fir_fixed_strict16(x, b, wl, fl)
    T_store = numerictype(1, wl, fl);
    F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate', ...
               'ProductMode','FullPrecision','SumMode','FullPrecision');
    x = fi(x, T_store, F);
    b = fi(b, 1, 16, 15, F);

    y_temp = filter(b, 1, x);
    y_out = fi(y_temp, T_store, F);
end

function save_complex_signal_to_txt(sig, filename)
    if isfi(sig), sig = double(sig); end
    fid = fopen(filename,'w');
    if fid==-1, error('Cannot create %s', filename); end
    fprintf(fid,'%% Real_Part\tImag_Part\n');
    data = [real(sig(:)), imag(sig(:))];
    fprintf(fid,'%.17g\t%.17g\n', data.');
    fclose(fid);
    fprintf('[SAVED] %s\n', filename);
end

function [iqdata_60M, iqdata_300M, fs, fs1] = generateQAMSignals(samplerate, samplerate1, alpha, fs, fs1, number_symbols)
    [iqdata_60M, ~, ~, ~, ~] = iqmod('sampleRate', fs, 'numSymbols', number_symbols, 'data', 'random', ...
        'modType','QAM64', 'oversampling', samplerate, 'filterType', 'Root Raised Cosine', ...
        'filterNsym', 80, 'filterBeta', alpha, 'carrierOffset', 0, 'magnitude', 0, 'function', 'download');
    [iqdata_300M, ~, ~, ~, ~] = iqmod('sampleRate', fs1, 'numSymbols', number_symbols, 'data', 'random', ...
        'modType','QAM64', 'oversampling', samplerate1, 'filterType', 'Root Raised Cosine', ...
        'filterNsym', 80, 'filterBeta', alpha, 'carrierOffset', 0, 'magnitude', 0, 'function', 'download');
end

function [x_norm, x_rms, peak_norm, scale] = normalize_to_target_peak(x, target_peak)
    x = x(:); x_rms = rms(x); x_unit = x / x_rms;
    peak_norm = max(abs(x_unit)); scale = target_peak / peak_norm;
    x_norm = x_unit * scale;
end
