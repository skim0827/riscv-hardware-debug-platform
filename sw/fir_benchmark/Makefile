# Produces fir_benchmark.hex (raw 32-bit instruction words) for loading

TARGET   = fir_benchmark
CC       = riscv32-unknown-elf-gcc
OBJCOPY  = riscv32-unknown-elf-objcopy
OBJDUMP  = riscv32-unknown-elf-objdump


# Match Arty A7 IMEM: 128 words × 4 bytes = 512 bytes
LDSCRIPT = ../uart_hello/link.ld


CFLAGS = -march=rv32i -mabi=ilp32 -O2 -nostdlib -nostartfiles \
         -fno-builtin -Wall -Wextra



SRCS = fir_benchmark.c ../uart_hello/start.S
 
all: $(TARGET).hex $(TARGET).dump
 
$(TARGET).elf: $(SRCS) $(LDSCRIPT)
	$(CC) $(CFLAGS) -T$(LDSCRIPT) -o $@ $(SRCS)
 
$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O verilog $< $@
 
# Flat 32-bit word file for $readmemh (same format as uart_hello_words.memh)
$(TARGET)_words.memh: $(TARGET).elf
	$(OBJCOPY) -O binary $< $(TARGET).bin
	python3 bin2memh.py $(TARGET).bin $(TARGET)_words.memh
 
$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d $< > $@
 
clean:
	rm -f *.elf *.hex *.bin *.memh *.dump
