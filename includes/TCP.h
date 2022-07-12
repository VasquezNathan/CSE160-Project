
#ifndef TCP_H
#define TCP_H
#include "packet.h"

enum{
    TCP_HEADER_SIZE = 6,
    TCP_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_SIZE
};

typedef nx_struct tcp {
    nx_uint8_t src_prt;
    nx_uint8_t dest_prt;
    nx_uint8_t flag;
    nx_uint8_t seq;
    nx_uint8_t ack_seq;
    nx_uint8_t window_size;
    nx_uint8_t payload[TCP_MAX_PAYLOAD_SIZE];
}tcp;


#endif