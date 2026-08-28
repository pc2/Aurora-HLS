#include <algorithm>
#include <cstdint>

static constexpr size_t MAX_STREAM_WORD_BYTES = 64;

static size_t transfer_buffer_size(size_t byte_size)
{
    return ((byte_size + MAX_STREAM_WORD_BYTES - 1) / MAX_STREAM_WORD_BYTES)
        * MAX_STREAM_WORD_BYTES;
}

class SendKernel
{
public:
    SendKernel(uint32_t instance, xrt::device &device, xrt::uuid &xclbin_uuid, Configuration &config, std::vector<char> &data) : instance(instance), config(config)
    {
        char name[100];
        snprintf(name, 100, "send:{send_%u}", instance);
        kernel = xrt::kernel(device, xclbin_uuid, name);

        const size_t buffer_size = transfer_buffer_size(config.max_num_bytes);
        std::vector<char> padded_data(buffer_size, 0);
        std::copy(data.begin(), data.end(), padded_data.begin());
        data_bo = xrt::bo(device, buffer_size, xrt::bo::flags::normal, kernel.group_id(1));

        data_bo.write(padded_data.data());
        data_bo.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    }

    SendKernel() {}

    void prepare_repetition(uint32_t repetition)
    {
        run = xrt::run(kernel);

        run.set_arg(1, data_bo);
        run.set_arg(2, config.message_sizes[repetition]);
        run.set_arg(3, config.frame_sizes[repetition]);
        run.set_arg(4, config.iterations_per_message[repetition]);
        run.set_arg(5, config.test_mode);
    }

    void start()
    {
        run.start();
    }

    bool timeout()
    {
        return run.wait(std::chrono::milliseconds(config.timeout_ms)) == ERT_CMD_STATE_TIMEOUT;
    }

    std::vector<char> data;
private:
    xrt::bo data_bo;
    xrt::kernel kernel;
    xrt::run run;
    uint32_t instance;
    Configuration config;
};

class RecvKernel
{
public:

    RecvKernel(uint32_t instance, xrt::device &device, xrt::uuid &xclbin_uuid, Configuration &config) : instance(instance), config(config)
    {
        char name[100];
        snprintf(name, 100, "recv:{recv_%u}", instance);
        kernel = xrt::kernel(device, xclbin_uuid, name);

        data_bo = xrt::bo(device, transfer_buffer_size(config.max_num_bytes),
                          xrt::bo::flags::normal, kernel.group_id(1));
        framing_errors_bo = xrt::bo(device, sizeof(uint32_t), xrt::bo::flags::normal,
                                    kernel.group_id(6));

        data.resize(config.max_num_bytes);
    }

    RecvKernel() {}

    void prepare_repetition(uint32_t repetition)
    {
        uint32_t zero = 0;
        framing_errors_bo.write(&zero);
        framing_errors_bo.sync(XCL_BO_SYNC_BO_TO_DEVICE);

        run = xrt::run(kernel);

        run.set_arg(1, data_bo);
        run.set_arg(2, config.message_sizes[repetition]);
        run.set_arg(3, config.frame_sizes[repetition]);
        run.set_arg(4, config.iterations_per_message[repetition]);
        run.set_arg(5, config.test_mode);
        run.set_arg(6, framing_errors_bo);
    }

    void start()
    {
        run.start();
    }

    bool timeout()
    {
        return run.wait(std::chrono::milliseconds(config.timeout_ms)) == ERT_CMD_STATE_TIMEOUT;
    }

    void write_back()
    {
        data_bo.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
        std::vector<char> padded_data(transfer_buffer_size(config.max_num_bytes));
        data_bo.read(padded_data.data());
        std::copy_n(padded_data.begin(), config.max_num_bytes, data.begin());
    }

    uint32_t read_framing_errors()
    {
        uint32_t framing_errors = 0;
        framing_errors_bo.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
        framing_errors_bo.read(&framing_errors);
        return framing_errors;
    }

    uint32_t compare_data(char *ref, uint32_t repetition)
    {
        uint32_t err_num = 0;
        for (uint32_t i = 0; i < config.message_sizes[repetition]; i++) {
            if (data[i] != ref[i]) {
                if (err_num < 16) {
                    printf("recv[%d] = %02x, send[%d] = %02x\n", i, (uint8_t)data[i], i, (uint8_t)ref[i]);
                }
                err_num++;
            }
        }
        if (err_num > 16) {
            std::cout << "only showing the first 16 byte errors" << std::endl;
        }
        return err_num;
    }

    std::vector<char> data;

private:
    xrt::bo data_bo;
    xrt::bo framing_errors_bo;
    xrt::kernel kernel;
    xrt::run run;
    uint32_t instance;
    Configuration config;
};
