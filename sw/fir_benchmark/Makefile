TARGET   = fir_benchmark
XVITIS   = /opt/Xilinx/2025.1/Vitis/gnu/riscv/lin/riscv64-unknown-elf/bin
CC       = $(XVITIS)/riscv64-unknown-elf-gcc
AS       = $(XVITIS)/riscv64-unknown-elf-gcc
LD       = $(XVITIS)/riscv64-unknown-elf-gcc
OBJCOPY  = $(XVITIS)/riscv64-unknown-elf-objcopy
OBJDUMP  = $(XVITIS)/riscv64-unknown-elf-objdump

ARCH_FLAGS = -march=rv32im -mabi=ilp32
CFLAGS     = $(ARCH_FLAGS) -O2 -nostdlib -nostartfiles -ffreestanding \
             -fno-builtin -Wall -Wextra
LDFLAGS    = $(ARCH_FLAGS) -nostdlib -T link.ld

SRCS_C = fir_benchmark.c
SRCS_S = start.S
OBJS   = start.o fir_benchmark.o

all: $(TARGET)_words.memh $(TARGET).dump

start.o: start.S
	$(AS) $(ARCH_FLAGS) -c -o $@ $<

fir_benchmark.o: fir_benchmark.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET).elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

# Flat word file for $readmemh
$(TARGET)_words.memh: $(TARGET).elf
	$(OBJCOPY) -O binary --only-section=.text $< $(TARGET)_imem.bin
	python3 bin2memh.py $(TARGET)_imem.bin $(TARGET)_words.memh

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f *.o *.elf *.bin *.memh *.dump