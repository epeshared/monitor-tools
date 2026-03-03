#!/bin/bash
# Monitor memory bandwidth for cores 0-7 (Socket 0)
# Run: ./monitor-cores-0-7-memory.sh [interval_seconds] [duration_seconds]

INTERVAL=${1:-1}
DURATION=${2:-60}

OUTPUT_DIR="/nvme4/xtang/scripts"
OUTPUT_FILE="${OUTPUT_DIR}/memory-bandwidth-$(date +%Y%m%d-%H%M%S).log"

# Header
echo "========================================" | tee "$OUTPUT_FILE"
echo "Memory Bandwidth Monitor for Cores 0-7" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "Monitoring duration: ${DURATION}s" | tee -a "$OUTPUT_FILE"
echo "Collection interval: ${INTERVAL}s" | tee -a "$OUTPUT_FILE"
echo "Output file: ${OUTPUT_FILE}" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "Timestamp          | Socket | LMB (MB/s) | RMB (MB/s) | Total (MB/s) | UTIL" | tee -a "$OUTPUT_FILE"
echo "--------------------------------------------------------------------------------" | tee -a "$OUTPUT_FILE"

END_TIME=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $END_TIME ]; do
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Get pcm output
    PCM_OUTPUT=$(/usr/local/sbin/pcm $INTERVAL -silent 2>/dev/null | grep -A 2 "Core (SKT)" | grep "SKT    0" | head -1)

    if [ -n "$PCM_OUTPUT" ]; then
        # Extract values (LMB and RMB are in columns after L3OCC)
        LMB=$(echo "$PCM_OUTPUT" | awk '{print $(NF-2)}')
        RMB=$(echo "$PCM_OUTPUT" | awk '{print $(NF-1)}')
        UTIL=$(echo "$PCM_OUTPUT" | awk '{print $2}')

        # Convert to numeric and calculate total
        LMB_NUM=$(echo "$LMB" | sed 's/[^0-9.]//g')
        RMB_NUM=$(echo "$RMB" | sed 's/[^0-9.]//g')
        TOTAL=$(echo "$LMB_NUM + $RMB_NUM" | bc 2>/dev/null || echo "N/A")

        printf "%s | %6s | %10s | %10s | %12s | %s\n" "$TIMESTAMP" "0" "$LMB" "$RMB" "$TOTAL" "$UTIL" | tee -a "$OUTPUT_FILE"
    fi

    sleep $INTERVAL
done

echo "" | tee -a "$OUTPUT_FILE"
echo "Monitoring complete. Results saved to: ${OUTPUT_FILE}" | tee -a "$OUTPUT_FILE"
