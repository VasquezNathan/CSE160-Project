#include "../includes/packet.h"
configuration NeighborC{
    provides interface Neighbor;
}
implementation{
    components new SimpleSendC(AM_PACK);
    // components new ListC(uint8_t, 255) as NeighborList;
    components NeighborP;
    Neighbor = NeighborP;
    NeighborP.SimpleSend -> SimpleSendC;
    // NeighborP.NeighborList -> NeighborList;

    components FloodingC;
    NeighborP.Flooding -> FloodingC;
}