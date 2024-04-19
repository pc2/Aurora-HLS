/*
 * Copyright 2024 Gerrit Pape (papeg@mail.upb.de)
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

#include <mpi.h>
#include "Aurora.hpp"

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    int world_size , world_rank;
    MPI_Comm_size(MPI_COMM_WORLD , &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD , &world_rank);

    MPI_Comm node_comm;
    MPI_Comm_split_type(MPI_COMM_WORLD, OMPI_COMM_TYPE_NODE, 0, MPI_INFO_NULL, &node_comm);

    int node_rank, node_size;
    MPI_Comm_rank(node_comm, &node_rank);
    MPI_Comm_size(node_comm, &node_size);

    xrt::device device = xrt::device(node_rank);
    std::string xclbin_filepath;
    if (argc > 1) {
        xclbin_filepath = std::string(argv[1]);
    } else {
        xclbin_filepath = std::string("aurora_hls_hw_test.xclbin");
    }
    xrt::uuid xclbin_uuid = device.load_xclbin(xclbin_filepath);

    AuroraDuo aurora(device, xclbin_uuid);
    if (!aurora.check_core_status_global(3000, world_rank, world_size)) {
        if (world_rank == 0) {
            std::cout << "All cores ready" << std::endl;
        }
    }

    MPI_Finalize();
}
