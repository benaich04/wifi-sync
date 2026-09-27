src  = fileread('../sync/sync_step.m');
BETA = str2double(regexp(src, 'BETA\s*=\s*([\d.]+)', 'tokens', 'once'));
TH   = str2double(regexp(src, 'TH\s*=\s*([\d.]+)',   'tokens', 'once'));

%load('../data/wave_clean.mat');   % clean waveform
%load('../data/wave_noisy.mat');  % noisy, 5 dB
%load('../data/wave_cfo.mat');    % clean, 20 kHz CFO
load('../data/wave_3pkt.mat');   % clean, no cfo, 3 packets

addpath('../sync');

N  = length(rx);
s  = zeros(N,1);
a  = false(N,1);
pe = zeros(N,1);
pk = zeros(N,1);
cf = zeros(N,1);

sync_step(0, true);   % reset

for k = 1:N
    [s(k), a(k), pe(k), pk(k), cf(k)] = sync_step(rx(k), false);
end

% ---------------- results ----------------
ends = find(pe);
arms = find(a);

fprintf('\npackets found : %d\n', numel(ends));
fprintf('BETA = %.2f   TH = %.2f\n\n', BETA, TH);

if isempty(ends)
    fprintf('*** nothing detected ***\n');
else
    fprintf(' #   armed    end    arm->end   CFO (kHz)\n');
    for i = 1:numel(ends)
        j = find(arms < ends(i), 1, 'last');       % the arm that led to this end
        fprintf('%2d  %6d  %6d  %8d  %9.2f\n', ...
                i, arms(j), ends(i), ends(i)-arms(j), cf(ends(i))/1e3);
    end

    if numel(ends) > 1
        fprintf('\ngaps between ends: %s\n', mat2str(diff(ends).'));
    end

    % ---------------- truth vs detected (packet 1 only) ----------------
    truth = preamble_end - 1;   % .mat holds first payload sample; we report last preamble sample
    fprintf('\npreamble end  truth %d   detected %d   error %+d samples\n', ...
            truth, ends(1), ends(1)-truth);
    fprintf('CFO           truth %.2f kHz   detected %.2f kHz   error %+.2f kHz\n', ...
            cfo_Hz/1e3, cf(ends(1))/1e3, (cf(ends(1))-cfo_Hz)/1e3);
end

fprintf('\nmax STF score : %.3f\n', max(s));
fprintf('max LTF peak  : %.3f\n', max(pk));

% ---------------- plots ----------------
figure

subplot(2,1,1)
plot(s); grid on; ylim([0 1.2])
yline(BETA,'m--')
if ~isempty(arms), xline(arms,'r'); end
title(sprintf('STF score   (BETA = %.2f, peak = %.2f)', BETA, max(s)))
ylabel('|P|^2/R^2')

subplot(2,1,2)
plot(pk); grid on; ylim([0 1.2])
yline(TH,'m--')
if ~isempty(ends), xline(ends,'g'); end
title(sprintf('LTF peak   (TH = %.2f, peak = %.2f)', TH, max(pk)))
ylabel('normalised'); xlabel('sample')