# sw/uart_hello/convert_memh.py
# Converts objcopy verilog hex to word-per-line format for $readmemh
import sys, re

words = {}
current_addr = 0

with open("uart_hello.memh") as f:
    for line in f:
        line = line.strip()
        if line.startswith("@"):
            current_addr = int(line[1:], 16)
        elif line:
            for byte in line.split():
                word_addr = current_addr >> 2
                byte_lane = current_addr & 3
                if word_addr not in words:
                    words[word_addr] = [0, 0, 0, 0]
                words[word_addr][byte_lane] = int(byte, 16)
                current_addr += 1

max_addr = max(words.keys()) if words else 0
with open("uart_hello_words.memh", "w") as f:
    for i in range(128):  # WORDS=128
        if i in words:
            b = words[i]
            # little-endian: byte0 is LSB
            word = b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)
            f.write(f"{word:08x}\n")
        else:
            f.write("00000000\n")

print(f"Written {max_addr+1} words")