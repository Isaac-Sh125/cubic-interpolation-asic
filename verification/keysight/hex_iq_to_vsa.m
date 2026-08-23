function hex_iq_to_vsa(fname, L, out_mat)
% HEX_IQ_TO_VSA
% Convert two-column signed 16-bit hexadecimal RTL I/Q output into a
% MAT file compatible with Keysight Vector Signal Analysis.
%
% The final RTL FIR output uses:
%
%   Word length       = 16 bits
%   Fractional bits   = 14 bits
%
% Output sampling rate:
%
%   fs_out = L * 60 MS/s
%
% Usage example:
%
%   hex_iq_to_vsa( ...
%       'rtl_output_POST_LPF_L_5.txt', ...
%       5, ...
%       'rtl_L5.mat');
%
% Input text format:
%
%   I_hex   Q_hex
%
% MAT output variables:
%
%   Y          complex I/Q sample vector
%   XDelta     sample interval [s]
%   InputZoom  Keysight VSA amplitude scaling
%   XStart     start time [s]

    if nargin ~= 3
        error('Usage: hex_iq_to_vsa(fname, L, out_mat)');
    end

    if ~ismember(L, [2 3 4 5])
        error('Supported interpolation factors are L = 2, 3, 4, 5.');
    end

    WL   = 16;
    FRAC = 14;

    fs_in  = 60e6;
    fs_out = L * fs_in;

    fid = fopen(fname, 'r');

    if fid <= 0
        error('Cannot open input file: %s', fname);
    end

    C = textscan( ...
        fid, ...
        '%s %s', ...
        'Delimiter', ' \t', ...
        'MultipleDelimsAsOne', true, ...
        'CollectOutput', true);

    fclose(fid);

    hexPairs = C{1};

    if isempty(hexPairs)
        error('No I/Q samples were parsed from %s', fname);
    end

    hexI = string(hexPairs(:,1));
    hexQ = string(hexPairs(:,2));

    % ---------------------------------------------------------
    % Hexadecimal -> unsigned integer representation
    % ---------------------------------------------------------

    uI = uint32(hex2dec(hexI));
    uQ = uint32(hex2dec(hexQ));

    signMask = bitshift(uint32(1), WL - 1);
    fullMod  = bitshift(uint32(1), WL);

    I_int = double(uI);
    Q_int = double(uQ);

    % ---------------------------------------------------------
    % Two's-complement conversion
    % ---------------------------------------------------------

    negI = bitand(uI, signMask) ~= 0;
    negQ = bitand(uQ, signMask) ~= 0;

    I_int(negI) = I_int(negI) - double(fullMod);
    Q_int(negQ) = Q_int(negQ) - double(fullMod);

    % ---------------------------------------------------------
    % Fixed-point Q format -> floating point
    % ---------------------------------------------------------

    I = I_int / (2^FRAC);
    Q = Q_int / (2^FRAC);

    Y = complex(I, Q);
    Y = Y(:);

    % ---------------------------------------------------------
    % Exact output-limit diagnostic
    % ---------------------------------------------------------

    maxCode = double(2^(WL - 1) - 1);
    minCode = -double(2^(WL - 1));

    nLimit = sum( ...
        I_int == maxCode | ...
        I_int == minCode | ...
        Q_int == maxCode | ...
        Q_int == minCode);

    % ---------------------------------------------------------
    % Keysight VSA metadata
    % ---------------------------------------------------------

    XDelta    = 1 / fs_out;
    InputZoom = 1;
    XStart    = 0;

    save(out_mat, 'Y', 'XDelta', 'InputZoom', 'XStart');

    fprintf( ...
        'Saved %d RTL I/Q samples to %s\n', ...
        numel(Y), out_mat);

    fprintf( ...
        'Format: signed %d-bit, %d fractional bits\n', ...
        WL, FRAC);

    fprintf( ...
        'Sampling rate: %.0f MS/s (L=%d)\n', ...
        fs_out / 1e6, L);

    fprintf( ...
        '|Y|max = %.6f, RMS = %.6f\n', ...
        max(abs(Y)), rms(Y));

    fprintf( ...
        'Samples containing exact positive/negative full-scale codes: %d\n', ...
        nLimit);
end
