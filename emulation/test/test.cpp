#include <chrono>
/*
 * Copyright 2024 Marius Meyer
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
#include <iostream>

#include "auroraemu.hpp"
#include "gtest/gtest.h"
#include "hlslib/xilinx/Stream.h"

struct AuroraEmuTest : public ::testing::Test {
    AuroraEmuTest() {
        // Empty
    }

    void SetUp() {
        // Empty
    }
};

TEST_F(AuroraEmuTest, ConstructorNamedPipes) {
    hlslib::Stream<data_stream_t> in, out;
    AuroraEmu e("hans", in, out);
    EXPECT_EQ(e.get_address(), "ipc://hans");
}

TEST_F(AuroraEmuTest, ConstructorTCP) {
    hlslib::Stream<data_stream_t> in, out;
    AuroraEmu e("127.0.0.1", 20003, in, out);
    EXPECT_EQ(e.get_address(), "tcp://127.0.0.1:20003");
}

TEST_F(AuroraEmuTest, ConnectLoopback) {
    hlslib::Stream<data_stream_t> in, out;
    AuroraEmu e("hans", in, out);
    e.connect(e);

    data_stream_t data;
    data.data = ap_uint<512>(7);
    in.write(data);
    data_stream_t data2 = out.read();
    EXPECT_EQ(data.data, data2.data);
}

TEST_F(AuroraEmuTest, ConstructorSwitch) {
    AuroraEmuSwitch s("127.0.0.1", 20000);
    zmq::context_t ctx(1);
    zmq::socket_t to_switch(ctx, zmq::socket_type::push);
    zmq::socket_t from_switch(ctx, zmq::socket_type::sub);

    to_switch.connect("tcp://127.0.0.1:20000");
    from_switch.connect("tcp://127.0.0.1:20001");
    std::string id = "test";
    from_switch.set(zmq::sockopt::subscribe, id);
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    std::string content = "hello";
    zmq::message_t msg(content);
    zmq::message_t a_id(id);
    to_switch.send(a_id, zmq::send_flags::sndmore);
    to_switch.send(msg, zmq::send_flags::none);

    auto result = from_switch.recv(msg, zmq::recv_flags::none);
    EXPECT_EQ(result.has_value(), true);
    EXPECT_EQ(result.value(), 4);
    EXPECT_EQ(msg.to_string(), id);
    result = from_switch.recv(msg, zmq::recv_flags::none);
    EXPECT_EQ(result.has_value(), true);
    EXPECT_EQ(result.value(), 5);
    EXPECT_EQ(msg.to_string(), content);
}

TEST_F(AuroraEmuTest, ConnectSwitchLoopback) {
    hlslib::Stream<data_stream_t> in, out;
    AuroraEmuSwitch s("127.0.0.1", 20000);
    std::cout << "Start core" << std::endl;
    AuroraEmuCore e("127.0.0.1", 20000, "hans", "hans", in, out);
    data_stream_t data;
    data.data = ap_uint<512>(7);
    std::cout << "write data" << std::endl;
    in.write(data);
    std::cout << "read data" << std::endl;
    data_stream_t data2 = out.read();
    EXPECT_EQ(data.data, data2.data);
}

TEST_F(AuroraEmuTest, SwitchConnectTwo) {
    hlslib::Stream<data_stream_t> in1("in1"), out1("out1"), in2("in2"),
        out2("out2");
    AuroraEmuSwitch s("127.0.0.1", 20000);
    AuroraEmuCore a1("127.0.0.1", 20000, "hans", "franz", in1, out1);
    AuroraEmuCore a2("127.0.0.1", 20000, "franz", "hans", in2, out2);
    std::cout << "Write stuff" << std::endl;
    for (int i = 0; i < 100; i += 10) {
        std::cout << "Send " << i << std::endl;
        data_stream_t data;
        data.data = ap_uint<512>(i);
        in1.write(data);
        std::cout << "Send back " << i << std::endl;
        in2.write(out2.read());
        std::cout << "Check " << i << std::endl;
        EXPECT_EQ(out1.read().data, ap_uint<512>(i));
    }
    EXPECT_TRUE(in1.empty());
    EXPECT_TRUE(in2.empty());
    EXPECT_TRUE(out1.empty());
    EXPECT_TRUE(out2.empty());
}

TEST_F(AuroraEmuTest, ConnectTwo) {
    hlslib::Stream<data_stream_t> in1("in1"), out1("out1"), in2("in2"),
        out2("out2");
    AuroraEmu a1("20000", in1, out1);
    AuroraEmu a2("20001", in2, out2);
    a1.connect(a2);
    std::cout << "Write stuff" << std::endl;
    for (int i = 0; i < 100; i += 10) {
        std::cout << "Send " << i << std::endl;
        data_stream_t data;
        data.data = ap_uint<512>(i);
        in1.write(data);
        std::cout << "Send back " << i << std::endl;
        in2.write(out2.read());
        std::cout << "Check " << i << std::endl;
        EXPECT_EQ(out1.read().data, ap_uint<512>(i));
    }
    EXPECT_TRUE(in1.empty());
    EXPECT_TRUE(in2.empty());
    EXPECT_TRUE(out1.empty());
    EXPECT_TRUE(out2.empty());
}

int main(int argc, char *argv[]) {
    ::testing::InitGoogleTest(&argc, argv);

    bool result = RUN_ALL_TESTS();

    return result;
}