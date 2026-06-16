#include <stdint.h>

// reg addr
#define UART_BASE       0x20000000
#define UART_TX_DATA    (*(volatile uint32_t*)(UART_BASE + 0x000))
#define UART_STATUS     (*(volatile uint32_t*)(UART_BASE + 0x004))

#define TIMER_BASE      0x20001000
#define TIMER_CTRL      (*(volatile uint32_t*)(TIMER_BASE + 0x000))
#define TIMER_COUNT     (*(volatile uint32_t*)(TIMER_BASE + 0x004))
#define TIMER_TIMEOUT   (*(volatile uint32_t*)(TIMER_BASE + 0x008))

#define FIR_BASE        0x20004000
#define FIR_DATA_IN     (*(volatile uint32_t*)(FIR_BASE + 0x000))
#define FIR_DATA_OUT    (*(volatile uint32_t*)(FIR_BASE + 0x004))
#define FIR_STATUS      (*(volatile uint32_t*)(FIR_BASE + 0x008))
#define FIR_CTRL        (*(volatile uint32_t*)(FIR_BASE + 0x00C))

#define TAPS 8
static const int16_t h[TAPS] = { -53, 0, 1995, 4096, 4096, 1995, 0, -53 };

#define N 64 // samples to filter 

static void uart_putc(char c) {
    while (UART_STATUS & 1);   // wait while tx_busy
    UART_TX_DATA = (uint32_t)(uint8_t)c;
}
static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

// printf (unsigned 32 bit decimal)
static void uart_putu32(uint32_t v) {
    char buf[11];
    int  i = 10;
    buf[i] = '\0';
    if (v == 0) { uart_putc('0'); return; }
    while (v && i > 0) {
        buf[--i] = '0' + (v % 10);
        v /= 10;
    }
    uart_puts(&buf[i]);
}
// printf (signed 32bit decimal)
static void uart_puts32(int32_t v) {
    if (v < 0) { uart_putc('-'); uart_putu32((uint32_t)(-v)); }
    else        uart_putu32((uint32_t)v);
}

static void timer_start(void) {
    TIMER_TIMEOUT = 0xFFFFFFFF;   
    TIMER_CTRL    = 1;
}

static uint32_t timer_stop(void) {
    uint32_t t = TIMER_COUNT;
    TIMER_CTRL = 0;
    return t;
}


// CPU-only FIR
static void fir_cpu(const int16_t *in, int16_t *out, int n) {
    /*
    Input   : Q1.15 (16-bit)
    Compute : wider accumulator (32-bit)
    Output  : Q1.15 (16-bit)
    */
    int16_t delay[TAPS] = {0};

    for (int i = 0; i < n; i++) {
        // Shift delay line
        for (int k = TAPS - 1; k > 0; k--)
            delay[k] = delay[k-1];
        delay[0] = in[i];

        // MAC
        int32_t acc = 0;
        for (int k = 0; k < TAPS; k++)
            acc += (int32_t)h[k] * (int32_t)delay[k];

        // Q1.15 truncation with saturation
        acc >>= 15;
        if      (acc >  32767) acc =  32767;
        else if (acc < -32768) acc = -32768;
        out[i] = (int16_t)acc;
    }
}


// Hardware-accelerated FIR
static void fir_hw(const int16_t *in, int16_t *out, int n) {
    FIR_CTRL = 1;
    FIR_CTRL = 0;

    for (int i = 0; i < n; i++) {
        FIR_DATA_IN = (uint32_t)(uint16_t)in[i];
        while (!(FIR_STATUS & 1));
        out[i] = (int16_t)(FIR_DATA_OUT & 0xFFFF);
    }
}


static void make_test_signal(int16_t *buf, int n) {
    int16_t v = 0;
    for (int i = 0; i < n; i++) {
        buf[i] = v; // test input signal for the FIR
        v += 1024;
        // wrap in Q1.15 (-32768 ... +32767)
    }
}

static int check_outputs(const int16_t *cpu, const int16_t *hw, int n) {
    int mismatches = 0;
    for (int i = 0; i < n; i++) {
        int32_t diff = (int32_t)cpu[i] - (int32_t)hw[i]; // **
        if (diff < -1 || diff > 1) {   // If the difference is larger than ±1:
            uart_puts("  MISMATCH [");
            uart_putu32(i);
            uart_puts("]: cpu=");
            uart_puts32(cpu[i]);
            uart_puts(" hw=");
            uart_puts32(hw[i]);
            uart_puts("\r\n");
            mismatches++;
        }
    }
    return mismatches;
}

int main(void) {
    int16_t input[N];
    int16_t out_cpu[N];
    int16_t out_hw[N];
    uint32_t cycles_cpu, cycles_hw;

    uart_puts("\r\n=== FIR Benchmark ===\r\n");
    uart_puts("Samples : ");
    uart_putu32(N);
    uart_puts(", Taps : ");
    uart_putu32(TAPS);
    uart_puts("\r\n");

    make_test_signal(input, N); // Generate test data


    timer_start();
    fir_cpu(input, out_cpu, N);
    cycles_cpu = timer_stop();

    uart_puts("CPU-only  cycles : ");
    uart_putu32(cycles_cpu);
    uart_puts("\r\n");


    timer_start();
    fir_hw(input, out_hw, N);
    cycles_hw = timer_stop();

    uart_puts("HW accel  cycles : ");
    uart_putu32(cycles_hw);
    uart_puts("\r\n");

    // ---- Speedup ----
    uart_puts("Speedup   ~");
    if (cycles_hw > 0) {
        uart_putu32(cycles_cpu / cycles_hw);
        uart_puts(".");
        uart_putu32((cycles_cpu % cycles_hw) * 10 / cycles_hw);
        uart_puts("x\r\n");
    } else {
        uart_puts("inf\r\n");
    }

    uart_puts("Correctness check...\r\n");
    int mismatches = check_outputs(out_cpu, out_hw, N);
    if (mismatches == 0)
        uart_puts("PASS — outputs match\r\n");
    else {
        uart_puts("FAIL — ");
        uart_putu32(mismatches);
        uart_puts(" mismatch(es)\r\n");
    }

    uart_puts("=== Done ===\r\n");
    return 0;
}