function make_waveform(snr_dB, cfo_Hz, outfile)

if nargin <1, snr_dB = 20;  end
if nargin <2, cfo_Hz = 0;   end
if nargin <3, outfile = '../data/wave_clean.mat';   end


fs = 20e6;  %sampling frequency = 20MHz
gap = 2000; %how many samples of silence to put on each side of the packet


% PART 1 :  Make the packet 
cfg = wlanNonHTConfig('MCS', 0, 'PSDULength', 100);   
bits = randi([0 1], cfg.PSDULength*8, 1);
%pkt = wlanWaveformGenerator(bits, cfg);

pkt = wlanWaveformGenerator(bits, cfg, 'NumPackets', 3, 'IdleTime', 20e-6);


% PART 2 : surround it with silence
rx = [zeros(gap, 1); pkt; zeros(gap,1)];

pkt_start = gap + 1;
preamble_end = gap + 320 + 1;


% PART 3 : frequency offset
n = (0:length(rx)-1).';
rx = rx .* exp(1j*2*pi*cfo_Hz*n/fs);


% PART 4 : noise
sig_pwr = mean(abs(pkt).^2);
noise_pwr = sig_pwr / 10^(snr_dB/10);
noise = sqrt(noise_pwr/2) * (randn(size(rx)) + 1j*randn(size(rx)));rx = rx + noise;


% PART 5 : save
save(outfile, 'rx', 'fs', 'pkt_start', 'preamble_end', 'snr_dB', 'cfo_Hz', 'pkt');

                                     
                                                    
                                                        