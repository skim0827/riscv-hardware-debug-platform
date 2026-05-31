# Memory Map

The SoC uses a simple 32-bit address map. Constants live in
`rtl/package/axi4_lite_pkg.sv`.

## Address Regions

| Region | Base | Notes |
| --- | ---: | --- |
| IMEM | `0x0000_0000` | Direct CPU instruction-fetch path |
| DMEM | `0x1000_0000` | AXI4-Lite data memory |
| UART | `0x2000_0000` | AXI4-Lite UART transmit peripheral |
| Timer/WDT | `0x2000_1000` | AXI4-Lite timer and watchdog |
| Health | `0x2000_2000` | AXI4-Lite fault telemetry block |

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
| `0x000` | `CTRL` | R/W | Bit 0 enables timer, bit 1 enables watchdog, bit 2 kicks watchdog |
| `0x004` | `COUNT` | R | Current counter value |
| `0x008` | `TIMEOUT` | R/W | Timer/watchdog threshold |
| `0x00C` | `STATUS` | R/W1C | Bit 0 timer IRQ pending, bit 1 watchdog fired |

## Health Monitor Registers

Base: `0x2000_2000`

| Offset | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x000` | `ECC_CORR_CNT` | R | IMEM + DMEM single-bit correction count |
| `0x004` | `ECC_DET_CNT` | R | IMEM + DMEM double-bit detection count |
| `0x008` | `TMR_PC_CNT` | R | PC TMR voter disagreement count |
| `0x00C` | `TMR_FSM_CNT` | R | FSM TMR voter disagreement count |
| `0x010` | `TMR_RF_CNT` | R | Register-file TMR voter disagreement count |
| `0x014` | `TMR_IR_CNT` | R | Instruction/control-path TMR disagreement count |
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
| 4 | TMR PC disagreement |
| 5 | TMR FSM disagreement |
| 6 | TMR register-file disagreement |
| 7 | TMR instruction/control-path disagreement |
