# Parameterizable Portable Microchip CoreFIFO (`COREFIFO_MCHP`)

A portable, programmatically parameterizable RTL wrapper around Microchip's `COREFIFO` dual-clock FIFO controller. This repository decouples Microchip's CDC pointer and flag control logic from Libero SoC's static, GUI-generated hard memory wrappers by introducing generic behavioral dual-port RAM models (`dpram`, `asymmetric_ram`, `asymmetric_ram_type2`).

---

## Motivation

In Microchip Libero SoC, the standard `COREFIFO` IP configurator generates rigid, non-parameterizable RTL wrappers hardcoded to fixed data widths, depths, and device-specific memory primitives (e.g., `RAM1K20`, `RAM64x12`, `RAM1K18`). In parameterized RTL designs—such as multi-pixel-per-clock video pipelines, AXI4-Stream width converters, or variable-aspect-ratio DMA buffers—this creates several bottlenecks:

1. **No Programmatic Parameterization:** Changing a bus width, FIFO depth, pipeline latency, or almost-full threshold requires re-opening the Libero GUI configurator, regenerating a new IP variant, and maintaining multiple static wrappers.
2. **Vendor Primitive Lock-In:** Hardcoded device RAM primitives tie RTL simulation and linting to Microchip-specific simulation libraries, complicating standalone testbenches and cross-platform portability.
3. **Rigid Memory Mapping:** Switching between Large SRAM (`lsram`), Micro SRAM (`uram`), or fabric registers requires regenerating the core rather than passing a parameter.

`COREFIFO_MCHP` solves this by pairing Microchip's proven CDC control logic (`corefifo_async`, Gray-code pointer synchronizers, and `corefifo_fwft`) with clean behavioral memory models driven by `(* syn_ramstyle *)` synthesis attributes:

* **Full Compile-Time Parameterization:** Configure `WWIDTH`, `RWIDTH`, `WDEPTH`, `RDEPTH`, `PIPE`, `FWFT`, and thresholds directly at instantiation.
* **Tool-Guided Memory Inference:** Passes `RamStyle` (`"lsram"`, `"uram"`, or `"registers"`) to Synplify Pro so Microchip PolarFire and SmartFusion2 targets infer optimal block/micro RAM resources automatically.
* **Simulator & Vendor Portability:** Pure behavioral memory arrays elaborate cleanly in Questa Sim, Verilator, Icarus Verilog, and VCS without requiring pre-compiled vendor primitive libraries.

---

## Repository Structure

| File | Role |
| :--- | :--- |
| `AC_CoreFIFO_MCHP.v` | Top-level parameterizable wrapper (`COREFIFO_MCHP`) selecting symmetric or asymmetric RAM instances and routing control/status signals. |
| `corefifo_async.v` | Dual-clock asynchronous FIFO controller handling Gray-code CDC, variable aspect-ratio pointer shifting, flags, and counters. |
| `corefifo_fwft.v` | First-Word Fall-Through (FWFT) and prefetch output staging logic (`PIPE = 1`, symmetric depth). |
| `corefifo_nstagessync.v` | Parameterizable multi-stage synchronizer for Gray-coded read/write pointers. |
| `corefifo_graytobinconv.v` | Combinational Gray-to-binary pointer converter. |
| `dpram` *(external/lib)* | Behavioral true/simple dual-port RAM for symmetric configurations (`WDEPTH == RDEPTH`). |
| `asymmetric_ram` *(external/lib)* | Behavioral asymmetric dual-port RAM for down-sizing (`WDEPTH > RDEPTH`, `WWIDTH < RWIDTH`). |
| `asymmetric_ram_type2.v` | Behavioral asymmetric dual-port RAM for up-sizing (`WDEPTH < RDEPTH`, `WWIDTH > RWIDTH`) with 1- or 2-cycle read latency. |

---

## Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `RamStyle` | `"lsram"` | Synplify Pro RAM inference directive: `"lsram"`, `"uram"`, or `"registers"`. |
| `PIPE` | `1` | Memory read latency in `RCLOCK` cycles (`1` = non-pipelined output, `2` = pipelined output). |
| `WWIDTH` / `RWIDTH` | `18` | Write and read data bus widths (bits). |
| `WDEPTH` / `RDEPTH` | `1024` | Write and read depths (words). Must satisfy `WDEPTH * WWIDTH == RDEPTH * RWIDTH` with a power-of-2 ratio. |
| `FWFT` | `0` | First-Word Fall-Through mode (`1` = enabled, `0` = standard read latency). Supported when `PIPE == 1` and `WDEPTH == RDEPTH`. |
| `PREFETCH` | `0` | Read data prefetching (`1` = enabled, `0` = disabled). Supported when `PIPE == 1` and `WDEPTH == RDEPTH`. |
| `ESTOP` / `FSTOP` | `1` | `1` = block pointer increment on empty read / full write; `0` = allow wrap-around. |
| `AE_STATIC_EN` / `AF_STATIC_EN` | `0` | Enable static `AEVAL` / `AFVAL` thresholds for `AEMPTY` / `AFULL` flags. |
| `AEVAL` / `AFVAL` | `4` / `1020` | Almost-empty and almost-full threshold values. |
| `READ_DVALID` / `WRITE_ACK` | `0` | Enable `DVLD` read valid and `WACK` write acknowledge strobes. |
| `OVERFLOW_EN` / `UNDERFLOW_EN` | `0` | Enable `OVERFLOW` and `UNDERFLOW` error flags. |
| `WRCNT_EN` / `RDCNT_EN` | `0` | Enable write-domain (`WRCNT`) and read-domain (`RDCNT`) occupancy counters. |

---

## Instantiation Example

```verilog
COREFIFO_MCHP #(
    .RamStyle     ("lsram"),
    .PIPE         (1),
    .WWIDTH       (32),
    .WDEPTH       (512),
    .RWIDTH       (128),
    .RDEPTH       (128),
    .FWFT         (0),
    .PREFETCH     (0),
    .ESTOP        (1),
    .FSTOP        (1),
    .AF_STATIC_EN (1),
    .AFVAL        (480),
    .AE_STATIC_EN (1),
    .AEVAL        (8),
    .READ_DVALID  (1),
    .WRCNT_EN     (1),
    .RDCNT_EN     (1)
) u_async_fifo (
    .WCLOCK    (wclk),
    .RCLOCK    (rclk),
    .WRESET_N  (wrst_n),
    .RRESET_N  (rrst_n),
    .DATA      (wdata),
    .WE        (wen),
    .RE        (ren),
    .Q         (rdata),
    .FULL      (full),
    .EMPTY     (empty),
    .AFULL     (afull),
    .AEMPTY    (aempty),
    .OVERFLOW  (),
    .UNDERFLOW (),
    .WACK      (),
    .DVLD      (dvld),
    .WRCNT     (wrcnt),
    .RDCNT     (rdcnt)
);