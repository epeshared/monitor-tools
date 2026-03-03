#!/bin/bash
# Comprehensive CPU and Memory Monitor
# Usage: ./monitor-cpu.sh [cores] [interval] [duration]

CORES=${1:-"0-7"}
INTERVAL=${2:-1}
DURATION=${3:-60}

OUTPUT_DIR="./output"
OUTPUT_FILE="${OUTPUT_DIR}/cpu-monitor-$(date +%Y%m%d-%H%M%S).log"

# Ensure output directory exists (avoid tee errors)
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

# Create temp file for core list
CORES_FILE=$(mktemp)
for item in $(echo "$CORES" | tr ',' ' '); do
    if [[ "$item" == *-* ]]; then
        start=$(echo "$item" | cut -d- -f1)
        end=$(echo "$item" | cut -d- -f2)
        seq $start $end
    else
        echo "$item"
    fi
done | sort -n | uniq > "$CORES_FILE"

CORES_SORTED=$(cat "$CORES_FILE" | tr '\n' ',' | sed 's/,$//')

# Get socket mapping
declare -A CORE_SOCKET
while IFS=',' read -r cpu core socket rest; do
    [[ "$cpu" == "#" ]] && continue
    CORE_SOCKET[$cpu]=$socket
done < <(lscpu -p 2>/dev/null)
SOCKETS_USED=$(for c in $(cat "$CORES_FILE"); do echo "${CORE_SOCKET[$c]:-0}"; done | sort -u | tr '\n' ' ' | tr -d '\n')

print_table_header() {
    echo "========================================"
    echo "CPU & Memory Monitor"
    echo "========================================"
    echo "Monitoring cores: $CORES_SORTED"
    echo "Sockets: $SOCKETS_USED"
    echo "Monitoring duration: ${DURATION}s"
    echo "Collection interval: ${INTERVAL}s"
    echo "Output file: ${OUTPUT_FILE}"
    echo ""
    printf "%-19s | %-3s | %6s | %5s | %9s | %10s | %10s | %8s | %8s | %10s | %10s | %10s\n" \
        "Timestamp" "CPU" "UTIL%" "IPC" "Freq(GHz)" "L2Miss" "L3Miss" "L2Hit%" "L3Hit%" "LMB(MB/s)" "RMB(MB/s)" "IOwait%"
    echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
}

# Write log header once (log keeps every sampling frame for analysis)
print_table_header | tee "$OUTPUT_FILE" >/dev/null

SAMPLES=$(awk -v d="$DURATION" -v i="$INTERVAL" 'BEGIN{ if(i<=0){print 0; exit} v=d/i; if(v<1) v=1; printf "%d", int(v + 0.999999) }')
TIMEOUT=$(awk -v i="$INTERVAL" 'BEGIN{ t=i+5; if(t<5) t=5; printf "%d", int(t+0.5) }')

cleanup() {
    rm -f "$CORES_FILE"
}
trap cleanup EXIT

IS_TTY=0
if [ -t 1 ]; then
    IS_TTY=1
fi

for ((sample=1; sample<=SAMPLES; sample++)); do
    # Capture CPU time counters before/after the pcm interval to compute iowait% without extra sleep.
    STAT_BEFORE=$(awk '/^cpu /{for(i=2;i<=11;i++)printf $i" ";print ""; exit}' /proc/stat)

    # Get PCM output and clean ANSI codes, then remove K suffix from L2MISS
    PCM=$(timeout "$TIMEOUT" /usr/local/sbin/pcm "$INTERVAL" -silent -i=1 -f 2>/dev/null | sed 's/\x1b\[[0-9;]*[mG]//g' | sed 's/ \([0-9]*\)K/\1/g' || true)

    STAT_AFTER=$(awk '/^cpu /{for(i=2;i<=11;i++)printf $i" ";print ""; exit}' /proc/stat)
    IOWAIT=$(awk -v b="$STAT_BEFORE" -v a="$STAT_AFTER" '
        BEGIN {
            split(b, bb, " ");
            split(a, aa, " ");
            tb=0; ta=0;
            for(i=1;i<=10;i++){ tb+=bb[i]; ta+=aa[i]; }
            dt=ta-tb;
            di=aa[5]-bb[5];
            if(dt>0) printf "%.1f", (100*di/dt); else printf "0.0";
        }')

    [ -z "$PCM" ] && continue

    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    FRAME=$(echo "$PCM" | awk -v cores_file="$CORES_FILE" -v ts="$TIMESTAMP" -v iowait="$IOWAIT" '
        BEGIN {
            while ((getline line < cores_file) > 0) {
                cores[line] = 1
            }
            close(cores_file)
        }
        /^[[:space:]]*[0-9]+[[:space:]]+0[[:space:]]+[0-9]/ {
            core = $1
            if (core in cores) {
                util = $3
                ipc = $4
                freq = $5
                l3miss = $6
                l2miss = $7
                l3hit = $8
                l2hit = $9
                lmb = $13
                rmb = $14

                printf "%-19s | %-3s | %6s | %5s | %9s | %10s | %10s | %8s | %8s | %10s | %10s | %9.1f%%\n",
                    ts, core, util, ipc, freq, l2miss, l3miss, l2hit, l3hit, lmb, rmb, iowait
            }
        }
    ' | sort -t'|' -k2 -n)

    # Append this sampling frame to log (multi-line per frame).
    if [ -n "$FRAME" ]; then
        printf "%s\n" "$FRAME" >> "$OUTPUT_FILE"
    fi

    # Live screen: only keep one line per CPU by re-drawing the latest frame.
    if [ "$IS_TTY" -eq 1 ]; then
        printf "\033[H\033[J"
        print_table_header
        printf "%s\n" "$FRAME"
    else
        # Non-interactive output: stream frames to stdout
        printf "%s\n" "$FRAME"
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "Monitoring complete. Results saved to: ${OUTPUT_FILE}" | tee -a "$OUTPUT_FILE"
