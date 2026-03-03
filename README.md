# CPU and Memory Monitoring Scripts

This directory contains scripts for monitoring CPU and memory performance metrics on Linux systems using Intel Processor Counter Monitor (PCM).

## Scripts

### 1. monitor-cpu.sh

Comprehensive CPU and memory monitoring script that tracks:
- CPU utilization (usage percentage)
- IPC (Instructions Per Cycle)
- Core frequency (GHz)
- L2/L3 cache miss counts
- L2/L3 cache hit ratios
- Local Memory Bandwidth (LMB) - MB/s
- Remote Memory Bandwidth (RMB) - MB/s
- I/O wait percentage

#### Usage

```bash
./monitor-cpu.sh [cores] [interval] [duration]

Arguments:
  cores    - Comma-separated list of cores (e.g., "0-7" or "0,1,2,3")
  interval - Sampling interval in seconds (default: 1)
  duration - Monitoring duration in seconds (default: 60)
```

#### examples

```bash
# Monitor cores 0-7 for 60 seconds (default interval: 1s)
./monitor-cpu.sh "0-7"

# Monitor specific cores with custom interval
./monitor-cpu.sh "0,1,2,3" 0.5 120

# Monitor multiple core ranges
./monitor-cpu.sh "0-7,16-23" 1 60
```

#### Output Format

```
========================================
CPU & Memory Monitor
========================================
Monitoring cores: 0,1,2,3,4,5,6,7
Sockets: 0
Monitoring duration: 60s
Collection interval: 1s
Output file: ./output/cpu-monitor-20260303-093921.log

Timestamp           | CPU |  UTIL% |   IPC | Freq(GHz) |     L2Miss |     L3Miss |   L2Hit% |   L3Hit% |  LMB(MB/s) |  RMB(MB/s) |    IOwait%
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
2026-03-03 09:40:21 |   0 |   5.12 |  0.89 |      3.62 |        120 |       9421 |    0.54  |    0.78  |        8.3 |        2.1 |       0.8%
2026-03-03 09:40:21 |   1 |   4.77 |  0.85 |      3.60 |        110 |       9010 |    0.55  |    0.77  |        7.9 |        2.0 |       0.8%
...

When run interactively, the terminal display is refreshed like `top` and always shows only the latest frame (one line per CPU).
The log file always appends every sampling frame (multi-line per frame: one line per CPU) for later analysis.
```

#### Output Columns

| Column | Description |
|--------|-------------|
| Timestamp | DateTime of sample |
| CPU | Core number being monitored |
| UTIL% | CPU utilization (0-100%) |
| IPC | Instructions per cycle |
| Freq(GHz) | Current core frequency |
| L2Miss | L2 cache miss count |
| L3Miss | L3 cache miss count |
| L2Hit% | L2 cache hit ratio (0.00-1.00) |
| L3Hit% | L3 cache hit ratio (0.00-1.00) |
| LMB(MB/s) | Local memory bandwidth (MB/s) |
| RMB(MB/s) | Remote memory bandwidth (MB/s) |
| IOwait% | I/O wait percentage |

### 2. monitor-cores-0-7-memory.sh

Simple memory bandwidth monitoring script specifically for cores 0-7.

#### Usage

```bash
./monitor-cores-0-7-memory.sh [interval] [duration]
```

## Requirements

- Intel PCM (Processor Counter Monitor) tools installed
- Root privileges required (for accessing hardware performance counters)
- Linux kernel with perf_event_paranoid set appropriately

## Installation of PCM

PCM is typically pre-installed on systems with Intel Xeon processors:

```bash
# Check if PCM is available
/usr/local/sbin/pcm --help
```

## Notes

- Results are saved to `/nvme4/xtang/scripts/cpu-monitor-<timestamp>.log`
- The socket mapping is automatically determined from `lscpu -p`
- Memory bandwidth values represent bandwidth satisfied from local/remote memory controllers
- Lower IPC or higher cache misses may indicate performance bottlenecks
