/*
 * Copyright 2023-2024 Gerrit Pape (papeg@mail.upb.de)
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

#pragma once

#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"
#include <cmath>
#include <bitset>

double get_wtime()
{
    struct timespec time;
    clock_gettime(CLOCK_REALTIME, &time);                                                                            
    return time.tv_sec + (double)time.tv_nsec / 1e9;
}

// control s axi addresses
static const uint32_t CORE_STATUS_ADDRESS        = 0x00000010;
static const uint32_t FIFO_STATUS_ADDRESS        = 0x00000014;
static const uint32_t CONFIGURATION_ADDRESS      = 0x00000018;
static const uint32_t FIFO_THRESHOLDS_ADDRESS    = 0x0000001c;
static const uint32_t FRAMES_RECEIVED_ADDRESS    = 0x00000020;
static const uint32_t FRAMES_WITH_ERRORS_ADDRESS = 0x00000024;
static const uint32_t SW_RESET_ADDRESS           = 0x00000028;

// masks for core status bits
static const uint32_t GT_POWERGOOD        = 0x0000000f;
static const uint32_t LINE_UP             = 0x000000f0;
static const uint32_t GT_PLL_LOCK         = 0x00000100;
static const uint32_t MMCM_NOT_LOCKED_OUT = 0x00000200;
static const uint32_t HARD_ERR            = 0x00000400;
static const uint32_t SOFT_ERR            = 0x00000800;
static const uint32_t CHANNEL_UP          = 0x00001000;

static const uint32_t CORE_STATUS_OK = GT_POWERGOOD | LINE_UP | GT_PLL_LOCK | CHANNEL_UP;

// masks for fifo status bits
static const uint32_t FIFO_TX_PROG_EMPTY   = 0x00000001;
static const uint32_t FIFO_TX_ALMOST_EMPTY = 0x00000002;
static const uint32_t FIFO_TX_PROG_FULL    = 0x00000004;
static const uint32_t FIFO_TX_ALMOST_FULL  = 0x00000008;
static const uint32_t FIFO_RX_PROG_EMPTY   = 0x00000010;
static const uint32_t FIFO_RX_ALMOST_EMPTY = 0x00000020;
static const uint32_t FIFO_RX_PROG_FULL    = 0x00000040;
static const uint32_t FIFO_RX_ALMOST_FULL  = 0x00000080;
static const char *fifo_status_name[8] = {
    "FIFO tx prog empty",
    "FIFO tx almost empty",
    "FIFO tx prog full",
    "FIFO tx almost full",
    "FIFO rx prog empty",
    "FIFO rx almost empty",
    "FIFO rx prog full",
    "FIFO rx almost full",
};

// masks for configuration bits
static const uint32_t HAS_TKEEP         = 0x000001;
static const uint32_t HAS_TLAST         = 0x000002;
static const uint32_t FIFO_WIDTH        = 0x0007fc;
static const uint32_t FIFO_DEPTH        = 0x007800;
static const uint32_t RX_EQ_MODE_BINARY = 0x018000;
static const uint32_t INS_LOSS_NYQ      = 0x3e0000;
static const char *rx_eq_mode_names[4] = {
    "AUTO",
    "LPM",
    "DFE",
    ""
};

class Aurora
{
public:
    Aurora(xrt::ip ip) : ip(ip)
    {
        // read constant configuration information
        uint32_t configuration = ip.read_register(CONFIGURATION_ADDRESS);

        has_tkeep = (configuration & HAS_TKEEP);
        has_tlast = (configuration & HAS_TLAST) >> 1;
        fifo_width = (configuration & FIFO_WIDTH) >> 2;
        fifo_depth = pow(2, (configuration & FIFO_DEPTH) >> 11);
        rx_eq_mode = (configuration & RX_EQ_MODE_BINARY) >> 15; 
        ins_loss_nyq = (configuration & INS_LOSS_NYQ) >> 17;

        uint32_t fifo_thresholds = ip.read_register(FIFO_THRESHOLDS_ADDRESS);

        fifo_prog_full_threshold = (fifo_thresholds & 0xffff0000) >> 16;
        fifo_prog_empty_threshold = (fifo_thresholds & 0x0000ffff);
    }

    Aurora(std::string name, xrt::device &device, xrt::uuid &xclbin_uuid)
        : Aurora(xrt::ip(device, xclbin_uuid, name)) {}

    std::string create_name_from_instance(uint32_t instance)
    {
        char name[100];
        snprintf(name, 100, "aurora_hls_%u:{aurora_hls_%u}", instance, instance);
        return std::string(name);
    }

    Aurora(uint32_t instance, xrt::device &device, xrt::uuid &xclbin_uuid)
        : Aurora(create_name_from_instance(instance), device, xclbin_uuid) {}
 
    Aurora() {}

    bool has_framing()
    {
        return has_tlast;
    }

    const char *get_rx_eq_mode_name()
    {
        return rx_eq_mode_names[rx_eq_mode];
    }

    void print_configuration()
    {
        std::cout << "Aurora configuration: " << std::endl;
        std::cout << "has tlast: " << has_tlast << std::endl;  
        std::cout << "has tkeep: " << has_tkeep << std::endl;  
        std::cout << "FIFO width: " << fifo_width << std::endl;
        std::cout << "FIFO depth: " << fifo_depth << std::endl;
        std::cout << "FIFO full threshold: " << fifo_prog_full_threshold << std::endl;
        std::cout << "FIFO empty threshold: " << fifo_prog_empty_threshold << std::endl;
        std::cout << "Equalization mode: " << rx_eq_mode_names[rx_eq_mode] << std::endl;
        std::cout << "Nyquist loss: " << (uint16_t)ins_loss_nyq << std::endl;
    }

    uint32_t get_core_status()
    {
        return ip.read_register(CORE_STATUS_ADDRESS);
    }

    uint8_t gt_powergood()
    {
        return (get_core_status() & GT_POWERGOOD);
    }

    uint8_t line_up()
    {
        return (get_core_status() & LINE_UP) >> 4;
    }

    bool gt_pll_lock()
    {
        return (get_core_status() & GT_PLL_LOCK);
    }

    bool mmcm_not_locked_out()
    {
        return (get_core_status() & MMCM_NOT_LOCKED_OUT);
    }

    bool hard_err()
    {
        return (get_core_status() & HARD_ERR);
    }

    bool soft_err()
    {
        return (get_core_status() & SOFT_ERR);
    }

    bool channel_up()
    {
        return (get_core_status() & CHANNEL_UP);
    }

    void print_core_status()
    {
        uint32_t reg_read_data = get_core_status();
        std::cout << "GT Power good: " << std::bitset<4>(reg_read_data & GT_POWERGOOD) << std::endl;
        std::cout << "Lines up: " << std::bitset<4>((reg_read_data & LINE_UP) >> 4) << std::endl;
        if (reg_read_data & GT_PLL_LOCK)
        {
            std::cout << "GT PLL Lock" << std::endl;
        }
        if (reg_read_data & MMCM_NOT_LOCKED_OUT)
        {
            std::cout << "MMCM not locked out" << std::endl;
        }
        if (reg_read_data & HARD_ERR)
        {
            std::cout << "Hard error detected" << std::endl;
        }
        if (reg_read_data & SOFT_ERR)
        {
            std::cout << "Soft error detected" << std::endl;
        }
        if (reg_read_data & CHANNEL_UP)
        {
            std::cout << "Channel up" << std::endl;
        }
    }

    bool core_status_ok(size_t timeout_ms)
    {
        double timeout_start, timeout_finish;
        timeout_start = get_wtime();
        while (1) {
            uint32_t reg_read_data = get_core_status();
            if (reg_read_data == CORE_STATUS_OK) {
                return true;
            } else {
                timeout_finish = get_wtime();
                if (((timeout_finish - timeout_start) * 1000) > timeout_ms) {
                    return false;
                }
            }
        }
    }

    uint32_t get_fifo_status()
    {
        return ip.read_register(FIFO_STATUS_ADDRESS);
    }

    bool fifo_tx_is_prog_empty()
    {
        return (get_fifo_status() & FIFO_TX_PROG_EMPTY);
    }

    bool fifo_tx_is_almost_empty()
    {
        return (get_fifo_status() & FIFO_TX_ALMOST_EMPTY);
    }

    bool fifo_tx_is_prog_full()
    {
        return (get_fifo_status() & FIFO_TX_PROG_FULL);
    }

    bool fifo_tx_is_almost_full()
    {
        return (get_fifo_status() & FIFO_TX_ALMOST_FULL);
    }

    bool fifo_rx_is_prog_empty()
    {
        return (get_fifo_status() & FIFO_RX_PROG_EMPTY);
    }

    bool fifo_rx_is_almost_empty()
    {
        return (get_fifo_status() & FIFO_RX_ALMOST_EMPTY);
    }

    bool fifo_rx_is_prog_full()
    {
        return (get_fifo_status() & FIFO_RX_PROG_FULL);
    }

    bool fifo_rx_is_almost_full()
    {
        return (get_fifo_status() & FIFO_RX_ALMOST_FULL);
    }

    void print_fifo_status()
    {
        uint32_t fifo_status = get_fifo_status();
        for (uint32_t bit = 0; bit < 8; bit++) {
            if (fifo_status & (1 << bit)) {
                std::cout << fifo_status_name[bit] << std::endl;
            }
        }
    }

    uint32_t get_frames_received()
    {
        if (has_tlast) {
            return ip.read_register(FRAMES_RECEIVED_ADDRESS);
        } else {
            return -1;
        }
    }

    uint32_t get_frames_with_errors()
    {
        if (has_tlast) {
            return ip.read_register(FRAMES_WITH_ERRORS_ADDRESS);
        } else {
            return -1;
        }
    }

    void set_reset(bool active)
    {
        ip.write_register(SW_RESET_ADDRESS, active);
    }

    bool has_tkeep;
    bool has_tlast;
    uint16_t fifo_width;
    uint16_t fifo_depth;
    uint8_t rx_eq_mode;
    uint8_t ins_loss_nyq;
    uint16_t fifo_prog_full_threshold;
    uint16_t fifo_prog_empty_threshold;

private:
    xrt::ip ip;
};

