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
#include <ap_axi_sdata.h>
#include <ap_int.h>
#include <hlslib/xilinx/Stream.h>

#include <iostream>
#include <thread>
#include <zmq.hpp>

typedef ap_axiu<512, 0, 0, 0> data_stream_t;

const int RECV_POLL_INTERVAL = 100;

class AuroraEmu {
   private:
    // ZMQ sockets used to exchange data between Aurroa cores
    zmq::context_t ctx;
    zmq::socket_t sock_out;
    zmq::socket_t sock_in;

    // ZMQ socket used to terminate send and recv threads
    zmq::socket_t kill_socket;

    // send and recv threads used to pass data to and from user kernels
    std::thread recv_thread;
    std::thread send_thread;

    // streams used to pass data to and from user kernels
    hlslib::Stream<data_stream_t> &remote_to_user;
    hlslib::Stream<data_stream_t> &user_to_remote;

    // id that is used to name the socket of the aurora emulator
    // or the network port
    std::string id;
    std::string protocol;

    void forward_from_remote() {
        zmq::socket_t kill_listener(ctx, zmq::socket_type::sub);
        kill_listener.connect("inproc://kill_" + id);
        kill_listener.set(zmq::sockopt::subscribe, "");
        zmq::message_t msg;
        // listen to kill singals and data comming in
        zmq::pollitem_t items[] = {{sock_in, 0, ZMQ_POLLIN, 0},
                                   {kill_listener, 0, ZMQ_POLLIN, 0}};
        while (true) {
            zmq::poll(&items[0], 2);
            if (items[0].revents & ZMQ_POLLIN) {
                auto result = sock_in.recv(msg, zmq::recv_flags::none);
                data_stream_t data;
                data.data = *static_cast<ap_uint<512> *>(msg.data());
                remote_to_user.write(data);
            }
            if (items[1].revents & ZMQ_POLLIN) {
                break;
            }
        }
    }

    void forward_from_user() {
        zmq::socket_t kill_listener(ctx, zmq::socket_type::sub);
        kill_listener.connect("inproc://kill_" + id);
        kill_listener.set(zmq::sockopt::subscribe, "");
        while (true) {
            // check if stream is empty. If so, sleep a bit to reduce CPU load
            while (user_to_remote.empty()) {
                std::this_thread::sleep_for(
                    std::chrono::milliseconds(RECV_POLL_INTERVAL));
                // check for kill signals in between
                zmq::message_t m;
                if (kill_listener.recv(m, zmq::recv_flags::dontwait)
                        .has_value()) {
                    return;
                }
            }
            // forward incoming data to user kernel
            ap_uint<512> data = user_to_remote.read().data;
            zmq::message_t msg(static_cast<void *>(&data),
                               sizeof(ap_uint<512>));
            sock_out.send(msg, zmq::send_flags::none);
        }
    }

   public:
    AuroraEmu(std::string host_address, int port,
              hlslib::Stream<data_stream_t> &user_to_remote,
              hlslib::Stream<data_stream_t> &remote_to_user)
        : ctx(1),
          sock_out(ctx, zmq::socket_type::pub),
          sock_in(ctx, zmq::socket_type::sub),
          kill_socket(ctx, zmq::socket_type::pub),
          user_to_remote(user_to_remote),
          remote_to_user(remote_to_user),
          id(host_address + ":" + std::to_string(port)),
          protocol("tcp") {
        sock_out.bind(protocol + "://" + id);
        kill_socket.bind("inproc://kill_" + id);
    }

    AuroraEmu(std::string pipe_name,
              hlslib::Stream<data_stream_t> &user_to_remote,
              hlslib::Stream<data_stream_t> &remote_to_user)
        : ctx(1),
          sock_out(ctx, zmq::socket_type::pub),
          sock_in(ctx, zmq::socket_type::sub),
          kill_socket(ctx, zmq::socket_type::pub),
          user_to_remote(user_to_remote),
          remote_to_user(remote_to_user),
          id(pipe_name),
          protocol("ipc") {
        sock_out.bind(protocol + "://" + id);
        kill_socket.bind("inproc://kill_" + id);
    }

    ~AuroraEmu() {
        // send kill signal to all threads
        // and wait for them to join
        zmq::message_t t(0);
        kill_socket.send(t, zmq::send_flags::none);
        if (recv_thread.joinable()) {
            recv_thread.join();
        }
        if (send_thread.joinable()) {
            send_thread.join();
        }
    }

    void connect(AuroraEmu &other_core, bool bidirectional = true) {
        if ((get_address() != other_core.get_address()) && bidirectional)
            other_core.connect(*this, false);
        sock_in.connect(other_core.get_address());
        sock_in.set(zmq::sockopt::subscribe, "");
        std::thread t1(&AuroraEmu::forward_from_remote, this);
        std::thread t2(&AuroraEmu::forward_from_user, this);
        recv_thread.swap(t1);
        send_thread.swap(t2);
        std::this_thread::sleep_for(
            std::chrono::milliseconds(RECV_POLL_INTERVAL));
    }

    std::string get_address() { return protocol + "://" + id; }
};

class AuroraEmuSwitch {
   private:
    // ZMQ sockets used to exchange data between Aurroa cores
    zmq::context_t ctx;
    zmq::socket_t distributor;
    zmq::socket_t incomming;

    // ZMQ socket used to terminate send and recv threads
    zmq::socket_t kill_socket;

    // send and recv threads used to pass data to and from user kernels
    std::thread switch_thread;

    // ZMQ address of the kill socket for this switch
    std::string kill_id;

    void forward_data() {
        zmq::socket_t kill_listener(ctx, zmq::socket_type::sub);
        kill_listener.connect(kill_id);
        kill_listener.set(zmq::sockopt::subscribe, "");
        zmq::message_t msg;
        // listen to kill singals and data comming in
        zmq::pollitem_t items[] = {{incomming, 0, ZMQ_POLLIN, 0},
                                   {kill_listener, 0, ZMQ_POLLIN, 0}};
        while (true) {
            zmq::poll(&items[0], 2);
            if (items[0].revents & ZMQ_POLLIN) {
                // forward topic
                auto result = incomming.recv(msg, zmq::recv_flags::none);
                distributor.send(msg, zmq::send_flags::sndmore);
                // forward content
                result = incomming.recv(msg, zmq::recv_flags::none);
                distributor.send(msg, zmq::send_flags::none);
            }
            if (items[1].revents & ZMQ_POLLIN) {
                break;
            }
        }
    }

   public:
    /**
     * Construct and connect a new aurora switch
     *
     * host_address: IP address or name of the host machine
     * port: Port of the aurora switch. port and port+1 will be used to
     *      establish the switch functionality.
     */
    AuroraEmuSwitch(std::string host_address, int port)
        : ctx(1),
          incomming(ctx, zmq::socket_type::pull),
          distributor(ctx, zmq::socket_type::pub),
          kill_socket(ctx, zmq::socket_type::pub),
          kill_id("inproc://kill_" + host_address + "_" +
                  std::to_string(port)) {
        incomming.bind("tcp://" + host_address + ":" + std::to_string(port));
        distributor.bind("tcp://" + host_address + ":" +
                         std::to_string(port + 1));
        kill_socket.bind(kill_id);
        switch_thread = std::thread(&AuroraEmuSwitch::forward_data, this);
    }

    ~AuroraEmuSwitch() {
        // send kill signal to all threads
        // and wait for them to join
        zmq::message_t t(0);
        kill_socket.send(t, zmq::send_flags::none);
        if (switch_thread.joinable()) {
            switch_thread.join();
        }
    }
};

class AuroraEmuCore {
   private:
    // ZMQ sockets used to exchange data between Aurroa cores
    zmq::context_t ctx;
    zmq::socket_t to_switch;
    zmq::socket_t from_switch;

    // ZMQ socket used to terminate send and recv threads
    zmq::socket_t kill_socket;

    // send and recv threads used to pass data to and from user kernels
    std::thread recv_thread;
    std::thread send_thread;

    // streams used to pass data to and from user kernels
    hlslib::Stream<data_stream_t> &remote_to_user;
    hlslib::Stream<data_stream_t> &user_to_remote;

    // id that is used to name the socket of the aurora emulator
    // or the network port
    std::string id;
    std::string remote_id;

    void forward_from_remote() {
        zmq::socket_t kill_listener(ctx, zmq::socket_type::sub);
        kill_listener.connect("inproc://kill_" + id);
        kill_listener.set(zmq::sockopt::subscribe, "");
        zmq::message_t msg;
        // listen to kill singals and data comming in
        zmq::pollitem_t items[] = {{from_switch, 0, ZMQ_POLLIN, 0},
                                   {kill_listener, 0, ZMQ_POLLIN, 0}};
        while (true) {
            zmq::poll(&items[0], 2);
            if (items[0].revents & ZMQ_POLLIN) {
                // receive aurora id of incoming message. Discard
                auto result = from_switch.recv(msg, zmq::recv_flags::none);
                // receive actual message
                result = from_switch.recv(msg, zmq::recv_flags::none);
                data_stream_t data;
                data.data = *static_cast<ap_uint<512> *>(msg.data());
                remote_to_user.write(data);
            }
            if (items[1].revents & ZMQ_POLLIN) {
                break;
            }
        }
    }

    void forward_from_user() {
        zmq::socket_t kill_listener(ctx, zmq::socket_type::sub);
        kill_listener.connect("inproc://kill_" + id);
        kill_listener.set(zmq::sockopt::subscribe, "");
        while (true) {
            // check if stream is empty. If so, sleep a bit to reduce CPU load
            while (user_to_remote.empty()) {
                std::this_thread::sleep_for(
                    std::chrono::milliseconds(RECV_POLL_INTERVAL));
                // check for kill signals in between
                zmq::message_t m;
                if (kill_listener.recv(m, zmq::recv_flags::dontwait)
                        .has_value()) {
                    return;
                }
            }
            // forward incoming data to user kernel
            ap_uint<512> data = user_to_remote.read().data;
            zmq::message_t msg(static_cast<void *>(&data),
                               sizeof(ap_uint<512>));
            zmq::message_t a_id(remote_id);
            to_switch.send(a_id, zmq::send_flags::sndmore);
            to_switch.send(msg, zmq::send_flags::none);
        }
    }

   public:
    /**
     * Construct and connect a new aurora core
     *
     * switch_address: IP address or name of the host machine the switch is
     *                  running on
     * switch_port: Port of the aurora switch id: own ID of the
     *              aurora core. Must be a unique string
     * remote_id: ID of the aurora core to connect to
     * user_to_remote: AXI stream to pass data into the aurora core
     * remote_to_user: AXI stream to read data from the aurora core
     */
    AuroraEmuCore(std::string switch_address, int switch_port, std::string id,
                  std::string remote_id,
                  hlslib::Stream<data_stream_t> &user_to_remote,
                  hlslib::Stream<data_stream_t> &remote_to_user)
        : ctx(1),
          to_switch(ctx, zmq::socket_type::push),
          from_switch(ctx, zmq::socket_type::sub),
          kill_socket(ctx, zmq::socket_type::pub),
          user_to_remote(user_to_remote),
          remote_to_user(remote_to_user),
          id(id),
          remote_id(remote_id) {
        kill_socket.bind("inproc://kill_" + id);
        to_switch.connect("tcp://" + switch_address + ":" +
                          std::to_string(switch_port));
        from_switch.connect("tcp://" + switch_address + ":" +
                            std::to_string(switch_port + 1));
        from_switch.set(zmq::sockopt::subscribe, id);
        std::thread t1(&AuroraEmuCore::forward_from_remote, this);
        std::thread t2(&AuroraEmuCore::forward_from_user, this);
        recv_thread.swap(t1);
        send_thread.swap(t2);
        std::this_thread::sleep_for(
            std::chrono::milliseconds(RECV_POLL_INTERVAL));
    }

    ~AuroraEmuCore() {
        // send kill signal to all threads
        // and wait for them to join
        zmq::message_t t(0);
        kill_socket.send(t, zmq::send_flags::none);
        if (recv_thread.joinable()) {
            recv_thread.join();
        }
        if (send_thread.joinable()) {
            send_thread.join();
        }
    }
};
