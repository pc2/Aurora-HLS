/*
 * Copyright 2026 Gerrit Pape (gerrit.pape@uni-paderborn.de)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <svdpi.h>

#define MAX_INSTANCES 2
#define DATA_BYTES 32
#define KEEP_BYTES 4
#define RECORD_BYTES (DATA_BYTES + KEEP_BYTES + 4)

static int tx_fds[MAX_INSTANCES] = {-1, -1};
static int rx_fds[MAX_INSTANCES] = {-1, -1};
static int debug_enabled = -1;

static int aurora_dpi_debug_enabled() {
    if (debug_enabled < 0) {
        const char *value = getenv("AURORA_DPI_DEBUG");
        debug_enabled = value && value[0] != '\0' && strcmp(value, "0") != 0;
    }
    return debug_enabled;
}

static int get_rank() {
    const char *rank_str = getenv("OMPI_COMM_WORLD_RANK");
    if (!rank_str) rank_str = getenv("PMIX_RANK");
    return rank_str ? atoi(rank_str) : 0;
}

void aurora_dpi_open_all() {
    char path[256];
    const char *dir = getenv("AURORA_PIPE_DIR");
    int rank = get_rank();

    // Phase 1: open all RX fds (O_RDONLY|O_NONBLOCK succeeds immediately)
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (dir) {
            snprintf(path, sizeof(path), "%s/rank%d/link_i%d_rx",
                     dir, rank, i);
        } else {
            snprintf(path, sizeof(path), "./link_i%d_rx", i);
        }
        rx_fds[i] = open(path, O_RDONLY | O_NONBLOCK);
        printf("aurora_dpi[r%d_i%d]: open RX %s = %d %s\n", rank, i, path,
               rx_fds[i], rx_fds[i] < 0 ? strerror(errno) : "ok");
        fflush(stdout);
    }

    // Phase 2: open all TX fds (readers now exist from phase 1)
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (dir) {
            snprintf(path, sizeof(path), "%s/rank%d/link_i%d_tx",
                     dir, rank, i);
        } else {
            snprintf(path, sizeof(path), "./link_i%d_tx", i);
        }
        int retries = 0;
        tx_fds[i] = open(path, O_WRONLY | O_NONBLOCK);
        while (tx_fds[i] < 0 && errno == ENXIO && retries < 10000) {
            usleep(1000);
            tx_fds[i] = open(path, O_WRONLY | O_NONBLOCK);
            retries++;
        }
        printf("aurora_dpi[r%d_i%d]: open TX %s = %d %s (retries=%d)\n", rank, i, path,
               tx_fds[i], tx_fds[i] < 0 ? strerror(errno) : "ok", retries);
        fflush(stdout);

#ifdef F_SETPIPE_SZ
        if (tx_fds[i] >= 0) {
            int actual = fcntl(tx_fds[i], F_SETPIPE_SZ, RECORD_BYTES);
            printf("aurora_dpi[r%d_i%d]: pipe buffer %d bytes\n", rank, i, actual);
            fflush(stdout);
        }
#endif
    }
}

int aurora_dpi_write(int instance, const svBitVecVal *data,
                     const svBitVecVal *keep, svBit last) {
    if (instance < 0 || instance >= MAX_INSTANCES || tx_fds[instance] < 0) return 0;
    unsigned char record[RECORD_BYTES];
    uint32_t flags = last ? 1u : 0u;
    memcpy(record, data, DATA_BYTES);
    memcpy(record + DATA_BYTES, keep, KEEP_BYTES);
    memcpy(record + DATA_BYTES + KEEP_BYTES, &flags, sizeof(flags));
    ssize_t n = write(tx_fds[instance], record, RECORD_BYTES);
    if (n == RECORD_BYTES) {
        if (aurora_dpi_debug_enabled()) {
            printf("aurora_dpi[%d]: wrote keep=0x%08x last=%u\n",
                   instance, keep[0], (unsigned int)last);
            fflush(stdout);
        }
        return 1;
    }
    if (aurora_dpi_debug_enabled()) {
        printf("aurora_dpi[%d]: write blocked n=%zd errno=%d\n",
               instance, n, errno);
        fflush(stdout);
    }
    return 0;
}

int aurora_dpi_read(int instance, svBitVecVal *data, svBitVecVal *keep,
                    svBit *last) {
    if (instance < 0 || instance >= MAX_INSTANCES || rx_fds[instance] < 0) return 0;
    unsigned char record[RECORD_BYTES];
    ssize_t total = 0;
    while (total < RECORD_BYTES) {
        ssize_t n = read(rx_fds[instance], record + total, RECORD_BYTES - total);
        if (n > 0) {
            total += n;
        } else if (n == 0) {
            return 0;
        } else if (errno == EAGAIN || errno == EWOULDBLOCK) {
            if (total == 0) return 0;
            usleep(1);
        } else {
            return 0;
        }
    }
    uint32_t flags;
    memcpy(data, record, DATA_BYTES);
    memcpy(keep, record + DATA_BYTES, KEEP_BYTES);
    memcpy(&flags, record + DATA_BYTES + KEEP_BYTES, sizeof(flags));
    *last = (flags & 1u) ? 1 : 0;
    if (aurora_dpi_debug_enabled()) {
        printf("aurora_dpi[%d]: read keep=0x%08x last=%u\n",
               instance, keep[0], (unsigned int)*last);
        fflush(stdout);
    }
    return 1;
}

void aurora_dpi_close(int instance) {
    if (instance < 0 || instance >= MAX_INSTANCES) return;
    if (tx_fds[instance] >= 0) { close(tx_fds[instance]); tx_fds[instance] = -1; }
    if (rx_fds[instance] >= 0) { close(rx_fds[instance]); rx_fds[instance] = -1; }
    printf("aurora_dpi[%d]: closed\n", instance);
    fflush(stdout);
}
