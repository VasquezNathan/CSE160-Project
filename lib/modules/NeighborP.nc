#include "../../includes/channels.h"
#include "../../includes/packet.h"
module NeighborP{
    provides interface Neighbor;
    // uses interface List<uint8_t> as NeighborList;
    uses interface SimpleSend;
    uses interface Flooding;
}
implementation{
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
    }
    pack sendPack;
    uint8_t NeighborList[2][20] = {                              
                                {255, 255, 255, 255, 255, 
                                255, 255, 255, 255, 255, 
                                255, 255, 255, 255, 255, 
                                255, 255, 255, 255, 255, },
                                {255, 255, 255, 255, 255, 
                                255, 255, 255, 255, 255, 
                                255, 255, 255, 255, 255, 
                                255, 255, 255, 255, 255, }}; // initially assume infinite cost (no neighbors)
    uint8_t i;
    uint8_t j;
    // NeighborList[TOS_NODE_ID] = 0;
    // 0 is next 1 is cost
    // uint8_t cum[2][20];
    // uint8_t* payload = call NeighborList.toArray;

    command bool Neighbor.isNeighbor(uint8_t neigh) {
        for(i = 0; i < sizeof(NeighborList)/sizeof(NeighborList[0]); i++) {
            if (neigh == NeighborList[0][i]){
                return TRUE;
            }
        }
        return FALSE;
    }

    // TODO: find a better way to drop motes that die
    command void Neighbor.discoverNeighbors(uint8_t prot) {
        // while (call NeighborList.isEmpty() == FALSE){
        //     call NeighborList.popback();
        // }
        // call Neighbor.showNeighbors();
        // NeighborList[TOS_NODE_ID] = 0;
        makePack(&sendPack, TOS_NODE_ID, AM_BROADCAST_ADDR, 20, prot, TOS_NODE_ID, NeighborList[1], PACKET_MAX_PAYLOAD_SIZE);
        call SimpleSend.send(sendPack, AM_BROADCAST_ADDR);
    }

    command void Neighbor.relayNeighbors(pack* myMsg){
        for(i = 0; i < sizeof(myMsg->payload)/sizeof(myMsg->payload[0]); i++){
            if (myMsg->payload[i] != 255 && i != TOS_NODE_ID) {
                // dbg(GENERAL_CHANNEL, "cum[%d]:%d\n", i, myMsg->payload[i]);
                if (myMsg->payload[i] < NeighborList[1][i]){
                    NeighborList[0][i] = myMsg->src;
                    NeighborList[1][i] = myMsg->payload[i] + 1;
                    myMsg->payload[i]++;
                }
            }
        }
        // makePack(myMsg, TOS_NODE_ID, AM_BROADCAST_ADDR, 20, 254, TOS_NODE_ID, NeighborList[1], PACKET_MAX_PAYLOAD_SIZE);
        call Flooding.flood(myMsg);
    }

    //Neighbor_ID is the source of the ping
    command error_t Neighbor.addNeighbor(uint8_t Neighbor_ID) {
        // for (i = 0; i < call NeighborList.size(); i++) {
        //     //if Neighbor already in list don't add it
        //     if (call NeighborList.get(i) == Neighbor_ID){
        //         return FAIL;
        //     }
        // }
        if (NeighborList[0][Neighbor_ID] != 255)
            return FAIL;
        if (Neighbor_ID != 0){
            // Each Neighbor of a node should have dest = nextHop and cost to be 1
            NeighborList[1][Neighbor_ID] = 1;
            NeighborList[0][Neighbor_ID] = Neighbor_ID;
            // NeighborList[Neighbor_ID] = 1;
            // Discovery now runs continuously to account for dropped motes.
            // no need to flood consol.
            dbg(GENERAL_CHANNEL, "adding %d to %d's NeighborList\n", Neighbor_ID, TOS_NODE_ID);
        }
        
        return SUCCESS;
    }
    
    command void Neighbor.showNeighbors() {
        // dbg(NEIGHBOR_CHANNEL, "Neighbors for %d: \n", TOS_NODE_ID);
        dbg(NEIGHBOR_CHANNEL, "dest\tnext\tcost\n");
        for (i = 0; i < sizeof(NeighborList[0])/sizeof(NeighborList[0][0]); i = i + 1){
            // if (NeighborList[i] != 255)
            //     dbg(NEIGHBOR_CHANNEL, "%d\n", i);
            dbg(NEIGHBOR_CHANNEL, "%d   \t%d\t%d\n", i, NeighborList[0][i], NeighborList[1][i]);
        }
    }

    command void Neighbor.send(pack msg, uint8_t destination) {
        call SimpleSend.send(msg, NeighborList[0][destination]);
    }    

    command uint8_t Neighbor.getNext(uint8_t destination) {
        return NeighborList[0][destination]; 
    }

    command uint8_t* Neighbor.getNeighbors() {
        return NeighborList[1];
    }

}
