#include "../../includes/packet.h"
interface Neighbor{
    command void discoverNeighbors(uint8_t prot);
    command error_t addNeighbor(uint8_t Neighbor_ID);
    command void showNeighbors();
    command bool isNeighbor(uint8_t Neigh);
    command void relayNeighbors(pack* msg);
    command void send(pack msg, uint8_t destination);
    command uint8_t getNext(uint8_t destination);
    command uint8_t* getNeighbors();
}
