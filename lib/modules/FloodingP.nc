#include "../../includes/packet.h"
#include "../../includes/channels.h"
module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend;
}
implementation{
    uint8_t storedSeq[20] = {0,0,0,0,0,
                            0,0,0,0,0,
                            0,0,0,0,0,
                            0,0,0,0,0};
    uint8_t shit;
    uint8_t shitit = 0;
    //called upon Recieve.recieve from Node.nc
    //increment recieved msg->sequence and decrease
    //msg->TTL. If the destination of the message is not
    //this motes ID then broadcast.
    //using protocol to see which neighbor forwarded msg
    command void Flooding.flood(pack* msg) {
        // logPack(msg);
        msg->TTL = msg->TTL - 1;
        msg->src = TOS_NODE_ID;
        for(shit = 0; shit < 20; shit++) {
            if (msg->seq == storedSeq[shit]){
                return;
            }
        }
        if(msg->dest != TOS_NODE_ID){
            if (shitit == 20){
                shitit = 0;
            }
            storedSeq[shitit] = msg->seq;
            shitit++;
            call SimpleSend.send(*msg, AM_BROADCAST_ADDR);
        }   
    }
}