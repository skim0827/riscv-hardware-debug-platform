# Memory Map

Constants are defined in `rtl/package/axi4_lite_pkg.sv`.

## Address Regions

| Region | Base | Description |
| --- | ---: | --- |
| IMEM | `0x0000_0000` | direct CPU instruction-fetch path |
| DMEM | `0x1000_0000` | data memory |
| UART | `0x2000_0000` | UART transmit peripheral |
| Timer/WDT | `0x2000_1000` | timer and watchdog |
| Health | `0x2000_2000` | fault telemetry block |
| DMA | `0x2000_3000` | DMA controller (CPU config slave) |
| FIR | `0x2000_4000` | FIR accelerator |

## UART Registers

Base: `0x2000_0000`

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `TX_DATA` | W | Write low byte to transmit |
| `0x004` | `STATUS` | R | Bit 0 is `tx_busy` |

## Timer / Watchdog Registers

Base: `0x2000_1000`

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `CTRL` | R/W | bit 0 timer enable, bit 1 WDT enable, bit 2 WDT kick |
| `0x004` | `COUNT` | R | Current counter value |
| `0x008` | `TIMEOUT` | R/W | Timer/watchdog threshold |
| `0x00C` | `STATUS` | R/W1C | bit 0 timer IRQ pending, bit 1 WDT fired |

## Health Monitor Registers

Base: `0x2000_2000`

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `ECC_CORR_CNT` | R | IMEM + DMEM correction count |
| `0x004` | `ECC_DET_CNT` | R | IMEM + DMEM detection count |
| `0x008` | `TMR_PC_CNT` | R | PC TMR disagreement count |
| `0x00C` | `TMR_FSM_CNT` | R | FSM TMR disagreement count |
| `0x010` | `TMR_RF_CNT` | R | register-file TMR disagreement count |
| `0x014` | `TMR_IR_CNT` | R | instruction-register TMR disagreement count |
| `0x018` | `STATUS` | R | Live fault signal snapshot |
| `0x01C` | `IRQ_MASK` | R/W | Enables events to assert `health_irq` |
| `0x020` | `IRQ_STATUS` | R/W1C | Latched event flags |
| `0x024` | `CTRL` | W | Bit 0 clears all counters |

`STATUS` and `IRQ_STATUS` use the same event bit layout:

| Bit | Event |
| ---: | --- |
| 0 | IMEM corrected |
| 1 | IMEM detected |
| 2 | DMEM corrected |
| 3 | DMEM detected |
| 4 | PC TMR disagreement |
| 5 | FSM TMR disagreement |
| 6 | register-file TMR disagreement |
| 7 | instruction-register TMR disagreement |

## DMA Controller Registers

Base: `0x2000_3000`

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x00` | `SRC_ADDR` | R/W | Source base address in DMEM |
| `0x04` | `DST_ADDR` | R/W | Destination base address in DMEM |
| `0x08` | `LEN` | R/W | Number of 32-bit words to transfer |
| `0x0C` | `CTRL` | R/W | `[0]` start (SC), `[1]` irq_en |
| `0x10` | `STATUS` | R/W1C | `[0]` busy, `[1]` done (W1C), `[2]` error (W1C) |

**SC** = self-clearing: hardware clears `CTRL[0]` immediately after transfer starts.  
**W1C**: write 1 to clear; used by the interrupt handler to acknowledge completion.

## FIR Accelerator Registers

Base: `0x2000_4000`

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `DATA_IN` | W | Write sample to push into FIR |
| `0x004` | `DATA_OUT` | R | bit[16] = valid flag, bits[15:0] = result |
| `0x008` | `STATUS` | R | bit[1] = busy, bit[0] = output valid |
| `0x00C` | `CTRL` | W | bit[0] = soft reset |
