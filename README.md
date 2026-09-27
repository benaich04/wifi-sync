# wifi-sync-fpga

Real-time 802.11a/g preamble synchronisation for a USRP X410 FPGA.

This repo holds the **MATLAB reference model** (Phase 2). It is written to be
rewritten in VHDL, not to be fast in MATLAB: one sample per call, persistent
state, no vectorised tricks, no toolbox inside the algorithm.

## Diagrams

Both live in one FigJam board:
**https://www.figma.com/board/sjSYdkb3xudl45MJkWf8mF**

1. **sync_step.m — per-sample logic and state machine** — every branch of the
   detector, IDLE and ARMED.
2. **File interaction** — which file calls which, and what to run first.

## How it works

Two stages, because they cost very different amounts of silicon.

**Stage 1 — STF (always on, ~4 DSP).** The short training field repeats every
16 samples. Multiply each sample by the conjugate of the one 16 back: if the
signal repeats, every product points the same way and they stack up; noise
cancels. Cheap, needs no stored reference, but only says *roughly* here.

**Stage 2 — LTF (gated, expensive).** Slide the known 64-sample LTS against the
signal. It matches at exactly one position, so the peak is sample-exact. Two
peaks 64 apart (LTS1, LTS2) confirm the packet and mark the end of the preamble.

The STF arms the LTF. The LTF never runs on noise.

**CFO** falls out for free: `angle(P)` is the phase the signal drifted over 16
samples, so `f = angle(P) * FS / (2*pi*D)`. Latched 48 samples after arming, once
the correlation window is fully inside the STF.

## Parameters

All of these live at the top of `sync_step.m`.

| Name | Value | What it is |
|---|---|---|
| `D` | 16 | STF repeat period. **Fixed by the standard** — not tunable. Also sets the CFO range to ±625 kHz. |
| `FS` | 20e6 | Sample rate. Only used to print CFO in Hz. The FPGA never needs it — its NCO wants `angle(P)/D` radians per sample. |
| `L` | 48 | How many pairs to average into `P` and `R`. More averaging, less noise, slower response. 48 pairs span 64 samples. |
| `BETA` | 0.4 | Pass mark for the STF score. **Sets the minimum usable SNR**: the score ceiling is `SNR/(1+SNR)`, so 0.4 works down to ~5 dB, 0.6 does not. Becomes a writable FPGA register. |
| `NH` | 8 | Consecutive passes required before arming. Rejects single-sample noise spikes. |
| `TH` | 0.5 | Pass mark for the LTF peak. Noise floor sits ~0.1 and the GI2 partial match ~0.25, so 0.5 clears both with margin. |
| `NLTS` | 64 | Length of one long training symbol. Fixed by the standard. |
| `TMAX` | 400 | Give up hunting for the LTF after this many samples. Measured arm-to-confirm is ~300, so this leaves ~100 spare. |
| `IDLE` / `ARMED` | 0 / 1 | State encoding. |

`BETA` and `TH` are the two you tune empirically on real captures.

## Running it

```matlab
cd matlab/gen
make_waveform(20, 0, '../data/wave_clean.mat')   % snr_dB, cfo_Hz, outfile
cd ../test
run_sync
```

Edit the `load` line in `run_sync.m` to pick a waveform. It prints a table and
draws the STF and LTF traces with the thresholds marked.

## Results

Timing error is zero samples in all four cases.

| Waveform | Packets | Preamble end | CFO truth | CFO measured | LTF peak |
|---|---|---|---|---|---|
| clean, 20 dB | 1 | 2320 ✓ | 0 | −2.00 kHz | 0.991 |
| noisy, 5 dB | 1 | 2320 ✓ | 0 | −3.14 kHz | 0.757 |
| 20 kHz CFO | 1 | 2320 ✓ | 20.00 kHz | 20.57 kHz | 0.976 |
| 3 packets | 3 | 2320 / 5920 / 9520 ✓ | 0 | −3.03 / +0.47 / +2.90 kHz | 0.993 |

CFO scatter is the estimator's noise floor, `σ ≈ 1/sqrt(2*L*SNR)` ≈ 2 kHz at
20 dB. The three-packet run averages to +0.11 kHz — zero-mean, so noise and not
bias. Packet gaps came out 3600 / 3600, matching 320 preamble + 80 SIGNAL +
35×80 data + 400 idle exactly.

## Layout

```
matlab/
  gen/     WLAN Toolbox allowed HERE ONLY - test stimulus
  sync/    no toolbox - this is what becomes VHDL
  test/    harness and plots
  data/    generated waveforms
```

The split is the point. `sync/` must stay toolbox-free or it cannot be ported.

## Known gaps

- If a second LTF peak lands at a gap other than 64, nothing fires and
  `firstPk` stays stale until `TMAX`. Never hit in testing.
- `score` is debug-only and exceeds 1 at the packet edge, where `R` is still
  measuring silence. Harmless — the real test is the multiply `Pmag2 > BETA*R^2`
  — but do not size a fixed-point word for a 0–1 range.
- `P` and `R` are full 48-term loops. They should become add-one/subtract-one
  sliding sums before synthesis.
- HDL cleanup pending: drop the debug division, split complex persistents into
  real/imag, convert to `fi`.
