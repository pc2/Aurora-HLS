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

#include <hls_stream.h>
#include <ap_int.h>
#include <ap_axi_sdata.h>

#ifndef __SYNTHESIS__
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cerrno>
#include <cstring>
#include <thread>
#endif

#ifndef DATA_WIDTH_BYTES
#define DATA_WIDTH_BYTES 64
#endif

#ifndef USE_FRAMING
#define USE_FRAMING 0
#endif

#define DATA_WIDTH (DATA_WIDTH_BYTES * 8)

#define CONFIGURATION_READY (1u << 31)
#define CONFIGURATION_HAS_TKEEP (1u << 0)
#define CONFIGURATION_HAS_TLAST (1u << 1)
#define CONFIGURATION_FIFO_WIDTH_SHIFT 2

using axis_packet = ap_axiu<DATA_WIDTH, 0, 0, 0>;

#ifndef __SYNTHESIS__
// Pipe format matches hw_emu: data, tkeep, then a tlast flag.
static constexpr size_t KEEP_BYTES = DATA_WIDTH_BYTES / 8;
static constexpr size_t RECORD_BYTES = DATA_WIDTH_BYTES + KEEP_BYTES + sizeof(uint32_t);
static_assert(DATA_WIDTH_BYTES == 32 || DATA_WIDTH_BYTES == 64,
              "AuroraFlow sw_emu supports 32- and 64-byte streams");
static_assert(RECORD_BYTES <= 4096,
              "AuroraFlow sw_emu records must fit in a POSIX atomic pipe write");

static bool write_packet(int fd, const axis_packet &pkt) {
    unsigned char record[RECORD_BYTES];
    uint64_t keep = pkt.keep.to_uint64();
    uint32_t flags = pkt.last ? 1u : 0u;

    memcpy(record, &pkt.data, DATA_WIDTH_BYTES);
    memcpy(record + DATA_WIDTH_BYTES, &keep, KEEP_BYTES);
    memcpy(record + DATA_WIDTH_BYTES + KEEP_BYTES, &flags, sizeof(flags));

    return write(fd, record, sizeof(record)) == static_cast<ssize_t>(sizeof(record));
}

static bool read_full(int fd, void *buf, size_t count) {
    size_t total = 0;
    while (total < count) {
        ssize_t n = read(fd, (char *)buf + total, count - total);
        if (n <= 0) return false;
        total += n;
    }
    return true;
}

static bool read_packet(int fd, axis_packet &pkt) {
    unsigned char record[RECORD_BYTES];
    uint64_t keep = 0;
    uint32_t flags = 0;

    if (!read_full(fd, record, sizeof(record))) return false;

    memcpy(&pkt.data, record, DATA_WIDTH_BYTES);
    memcpy(&keep, record + DATA_WIDTH_BYTES, KEEP_BYTES);
    memcpy(&flags, record + DATA_WIDTH_BYTES + KEEP_BYTES, sizeof(flags));
    pkt.keep = keep;
    pkt.last = flags & 1u;
    return true;
}
#endif

extern "C" {

void aurora_flow_sw_emu(
    hls::stream<axis_packet> &tx_axis,
    hls::stream<axis_packet> &rx_axis,
    unsigned int pipe_id,
    volatile unsigned int *control,
    volatile unsigned int *configuration
) {
    *configuration = CONFIGURATION_READY
        | (DATA_WIDTH_BYTES << CONFIGURATION_FIFO_WIDTH_SHIFT)
        | (USE_FRAMING ? CONFIGURATION_HAS_TKEEP | CONFIGURATION_HAS_TLAST : 0);

#ifdef __SYNTHESIS__
    axis_packet pkt = tx_axis.read();
    rx_axis.write(pkt);
    *control = 0;
#else
    signal(SIGPIPE, SIG_IGN);

    const char *pipe_dir = getenv("AURORA_PIPE_DIR");
    const char *rank_str = getenv("OMPI_COMM_WORLD_RANK");
    if (!rank_str) rank_str = getenv("PMIX_RANK");
    int rank = rank_str ? atoi(rank_str) : 0;

    char tx_path[256], rx_path[256];
    if (pipe_dir) {
        snprintf(tx_path, sizeof(tx_path), "%s/rank%d/link_i%u_tx",
                 pipe_dir, rank, pipe_id);
        snprintf(rx_path, sizeof(rx_path), "%s/rank%d/link_i%u_rx",
                 pipe_dir, rank, pipe_id);
    } else {
        snprintf(tx_path, sizeof(tx_path), "./link_i%u_tx", pipe_id);
        snprintf(rx_path, sizeof(rx_path), "./link_i%u_rx", pipe_id);
    }

    int tx_fd = -1, rx_fd = -1;
    std::thread tx_opener([&tx_fd, &tx_path]() {
        tx_fd = open(tx_path, O_WRONLY);
    });
    rx_fd = open(rx_path, O_RDONLY);
    tx_opener.join();

    if (tx_fd < 0 || rx_fd < 0) {
        fprintf(stderr,
                "aurora_flow_sw_emu[%u]: pipe open failed: %s\n",
                pipe_id, strerror(errno));
        if (tx_fd >= 0) close(tx_fd);
        if (rx_fd >= 0) close(rx_fd);
        return;
    }

    fprintf(stderr, "aurora_flow_sw_emu[%u]: pipes connected\n", pipe_id);

    std::thread tx_thread([&tx_axis, tx_fd, control]() {
        while (*control == 0) {
            if (tx_axis.empty()) {
                usleep(1000);
                continue;
            }
            axis_packet pkt = tx_axis.read();
            if (!write_packet(tx_fd, pkt)) break;
        }
        close(tx_fd);
    });

    struct pollfd pfd = {rx_fd, POLLIN, 0};
    while (*control == 0) {
        int ret = poll(&pfd, 1, 100);
        if (ret > 0 && (pfd.revents & POLLIN)) {
            axis_packet pkt;
            if (!read_packet(rx_fd, pkt)) break;
            rx_axis.write(pkt);
        } else if (ret > 0 && (pfd.revents & (POLLHUP | POLLERR))) {
            break;
        }
    }
    close(rx_fd);
    tx_thread.join();

    fprintf(stderr, "aurora_flow_sw_emu[%u]: shutdown\n", pipe_id);
#endif
}

}
