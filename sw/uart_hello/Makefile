all:
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 uart_hello.s -o uart_hello.o
	riscv64-unknown-elf-ld -Ttext=0x0 -Tdata=0x10000000 -nostdlib uart_hello.o -o uart_hello.elf
	riscv64-unknown-elf-objcopy -O verilog uart_hello.elf uart_hello.memh
	python3 convert_memh.py
	python3 gen_coe.py

clean:
	rm -f uart_hello.o uart_hello.elf uart_hello.memh uart_hello_words.memh uart_hello.coe
