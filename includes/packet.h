//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H

// #include "TCP.h"
# include "protocol.h"
#include "channels.h"
// #include "TCP.h"
nx_uint16_t fuck;
enum{
	PACKET_HEADER_LENGTH = 8,
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
	MAX_TTL = 15
};


typedef nx_struct pack{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;	//Sequence Number
	nx_uint8_t TTL;		//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;

/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
void logPack(pack *input){
	// protocol 254 is routing discovery
	if(input->protocol == 254) {
		dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: \n",
		input->src, input->dest, input->seq, input->TTL, input->protocol);
		for(fuck = 0; fuck < sizeof(input->payload)/sizeof(input->payload[0]); fuck++){
			dbg(GENERAL_CHANNEL, "%d:\t%d\n", fuck, input->payload[fuck]);
		}
	}
	else {
		// 6 is the size of the TCP header so payload starts at index 6.
		// idealy should use TCP_HEADER_SIZE but idk how to have two headers inherit each other.
		dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
		input->src, input->dest, input->seq, input->TTL, input->protocol, &input->payload);
	}
}

enum{
	AM_PACK=6
};

#endif
