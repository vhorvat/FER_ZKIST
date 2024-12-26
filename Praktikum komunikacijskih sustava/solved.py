# ------------------------- COPYRIGHT -------------------------
# Some parts of this code are sourced from PySDR blog 
# by Dr. Marc Lichtman - pysdr@vt.edu
# Big thanks to professor Lichtman for providing us with code, 
# examples and SDR programming knowlegde
# https://pysdr.org/
# -------------------------------------------------------------

import numpy as np
import pandas as pd
import commpy as cp
import matplotlib.pyplot as plt
from PIL import Image

# ------ GLOBAL CONSTANTS
sample_rate = 1e6
samples_per_symbol = 8

def plot_iq_graph(data, title):
    I = np.real(data)[::5]
    Q = np.imag(data)[::5]

    plt.figure(figsize=(6, 6))
    plt.scatter(I, Q, color='orange')
    plt.title(title)
    plt.xlabel('I')
    plt.ylabel('Q')
    plt.grid(True)
    plt.show()
    return

def phase_detector_4(sample):
    a = 1.0 if sample.real > 0 else -1.0
    b = 1.0 if sample.imag > 0 else -1.0
    return a * sample.imag - b * sample.real

def bit_array_to_image(bit_array, width, height):
    binary_string = ''.join(str(bit) for bit in bit_array)
    pixel_values = [int(binary_string[i:i+8], 2) for i in range(0, len(binary_string), 8)]
    img = Image.new('L', (width, height))
    img.putdata(pixel_values)
    return img

def main():
#--------------------- STEP 0: LOADING DATA 
    data_path = 'Lab_1_signal.csv' 
    data = pd.read_csv(data_path, header=None)
    data_complex = data[0].apply(lambda x: eval(x))

    plot_iq_graph(data_complex, "I-Q graph, initial data")

#--------------------- STEP 1: RRCOS FILTER
    t_rc, h_rc = cp.rrcosfilter(N=100, alpha=0.2, Ts = samples_per_symbol/sample_rate, Fs = sample_rate)

    filtered_data = np.convolve(data_complex, h_rc, mode='full')
    filtered_data = filtered_data * 1/10

    plt.figure(figsize=(9,6), dpi=70)
    plt.plot(t_rc, h_rc, '.-', markersize=10)
    plt.title("Odziv rrcos filtera")
    plt.xlabel('t/Ts')
    plt.ylabel('h(t)')
    plt.grid(True)
    plt.show()

#--------------------- STEP 2: COARSE FREQ. SYNC
    filtered_data_power4 = filtered_data**4
    psd = np.fft.fftshift(np.abs(np.fft.fft(filtered_data_power4)))
    f = np.linspace(-sample_rate/2.0, sample_rate/2.0, len(psd))
    max_freq = f[np.argmax(psd)]
    
    Ts = 1/sample_rate 
    t = np.arange(0, Ts*len(filtered_data_power4), Ts) 
    
    frequency_synced = filtered_data * np.exp(-1j*2*np.pi*max_freq*t/4.0)

    plot_iq_graph(frequency_synced, "I-Q graph, after coarse frequency sync")

#--------------------- STEP 3: TIME SYNC
    samples = frequency_synced
    mu = 0 
    out = np.zeros(len(samples) + 10, dtype=np.complex64)
    out_rail = np.zeros(len(samples) + 10, dtype=np.complex64) 
    i_in = 0 
    i_out = 2 
    while i_out < len(samples) and i_in+16 < len(samples):
        out[i_out] = samples[i_in] 
        out_rail[i_out] = int(np.real(out[i_out]) > 0) + 1j*int(np.imag(out[i_out]) > 0)
        x = (out_rail[i_out] - out_rail[i_out-2]) * np.conj(out[i_out-1])
        y = (out[i_out] - out[i_out-2]) * np.conj(out_rail[i_out-1])
        mm_val = np.real(y - x)
        mu += samples_per_symbol + 0.7*mm_val
        i_in += int(np.floor(mu)) 
        mu = mu - np.floor(mu) 
        i_out += 1 
    out = out[2:i_out] 
    time_synced = out 

    plot_iq_graph(time_synced, "I-Q graph, after time sync")

#--------------------- STEP 4: FINE FREQ. SYNC
    N = len(time_synced)
    phase = 0
    freq = 0

    alpha = 0.01
    beta = 0.0001

    out = np.zeros(N, dtype=np.complex64)
    freq_log = []
    for i in range(N):
        out[i] = time_synced[i] * np.exp(-1j*phase) 
        error = np.sign(np.real(out[i])) * np.imag(out[i]) - np.sign(np.imag(out[i])) * np.real(out[i])

        freq += (beta * phase_detector_4(time_synced[i] * np.exp(-1j*phase)))
        freq_log.append(freq * sample_rate / (2*np.pi))
        phase += freq + (alpha * phase_detector_4(time_synced[i] * np.exp(-1j*phase)))

        while phase >= 2*np.pi:
           phase -= 2*np.pi
        while phase < 0:
            phase += 2*np.pi

    fine_frequency_synced = out
    plot_iq_graph(fine_frequency_synced, "I-Q graph, after fine frequency sync")

#--------------------- STEP 5: DEMODULATE DATA
    modulation_fake_QPSK = cp.modulation.QAMModem(4)
    demodulated = modulation_fake_QPSK.demodulate(input_symbols = fine_frequency_synced, demod_type='hard')

#--------------------- STEP 5.1: EXTRACT PICTURE
    preamble = np.concatenate((np.tile([1, 0, 0, 1], 50), np.tile([0, 0], 50)))

    correlation = np.correlate(demodulated, preamble, mode='full')
    start_index = np.argmax(correlation) - len(preamble) + 1

    if start_index + len(preamble) + 1840 <= len(demodulated):
        extracted_bits = demodulated[start_index + len(preamble) - 2 : start_index + len(preamble) - 2 + 14720]

    image = bit_array_to_image(extracted_bits, 40, 46)
    image.show()

main()