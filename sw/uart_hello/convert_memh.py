# sw/uart_hello/convert_memh.py
# Converts objcopy verilog hex to word-per-line format for $readmemh.
# Produces two files:
#   uart_hello_words.memh  — IMEM (word addresses 0..127, byte base 0x0000_0000)
#   uart_hello_dmem.memh   — DMEM (word addresses 0..127, byte base 0x1000_0000)

IMEM_WORDS = 128
DMEM_WORDS = 128
DMEM_BASE_WORD = 0x10000000 >> 2   # 0x400_0000

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

def write_region(filename, base_word, num_words):
    with open(filename, "w") as f:
        for i in range(num_words):
            key = base_word + i
            if key in words:
                b = words[key]
                word = b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)
                f.write(f"{word:08x}\n")
            else:
                f.write("00000000\n")
    print(f"Written {filename}")

write_region("uart_hello_words.memh", 0,              IMEM_WORDS)
write_region("uart_hello_dmem.memh",  DMEM_BASE_WORD, DMEM_WORDS)
