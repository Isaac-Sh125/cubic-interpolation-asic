function float_iq_to_vsa(fname, fs_hz, out_mat)
% FLOAT_IQ_TO_VSA
% Convert a two-column floating-point I/Q text file into a MAT file
% compatible with Keysight Vector Signal Analysis.
%
% Usage example:
%
%   float_iq_to_vsa( ...
%       'cubic_fixed16_strict_output_POST_LPF_L_5.txt', ...
%       300e6, ...
%       'matlab_post_filter_L5.mat');
%
% Input text format:
%
%   I(float)   Q(float)
%
% MAT output variables:
%
%   Y          complex I/Q sample vector
%   XDelta     sample interval [s]
%   InputZoom  Keysight VSA amplitude scaling
%   XStart     start time [s]

    if nargin ~= 3
        error(['Usage: float_iq_to_vsa(fname, fs_hz, out_mat)']);
    end

    if fs_hz <= 0
        error('Sampling frequency must be positive.');
    end

    fid = fopen(fname, 'r');

    if fid <= 0
        error('Cannot open input file: %s', fname);
    end

    iq = textscan( ...
        fid, ...
        '%f %f', ...
        'Delimiter', ' \t', ...
        'MultipleDelimsAsOne', true);

    fclose(fid);

    I = iq{1};
    Q = iq{2};

    if isempty(I) || isempty(Q)
        error('No I/Q samples were parsed from %s', fname);
    end

    if numel(I) ~= numel(Q)
        error('I/Q vector lengths do not match.');
    end

    Y = complex(I, Q);
    Y = Y(:);

    XDelta    = 1 / fs_hz;
    InputZoom = 1;
    XStart    = 0;

    save(out_mat, 'Y', 'XDelta', 'InputZoom', 'XStart');

    fprintf( ...
        'Saved %d floating-point I/Q samples to %s at %.3f MS/s\n', ...
        numel(Y), out_mat, fs_hz / 1e6);
end
