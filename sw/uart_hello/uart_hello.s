# uart_hello.s
# Sends "Hello FPGA!\r\n" over UART at 0x2000_0000
# Strategy: poll STATUS (0x2000_0004) bit[0] before each write
# so we never drop a character if the UART is still busy.

.section .text
.global _start

_start:
    li   a0, 0x20000000     # UART TX_DATA address
    la   a1, msg            # pointer to message
    li   a2, 13             # message length

send_loop:
    beqz a2, done           # if counter == 0, finished
    lbu  t0, 0(a1)          # load next byte

poll:
    lw   t1, 4(a0)          # read UART STATUS (offset +4)
    andi t1, t1, 1          # isolate tx_busy bit
    bnez t1, poll           # loop while busy

    sw   t0, 0(a0)          # write byte to TX_DATA
    addi a1, a1, 1          # advance pointer
    addi a2, a2, -1         # decrement counter
    j    send_loop

done:
    j    done               # halt

.section .rodata
msg:
    .byte 'H','e','l','l','o',' ','F','P','G','A','!',13,10