function t = ltf_ref()
% Known 64-sample long training pattern (IEEE 802.11-2016, Sec 17.3.3).
% Extracted once and frozen — in the FPGA these become 64 ROM constants.

S = load('ltf_ref.mat');
t = S.LTF_REF;
end