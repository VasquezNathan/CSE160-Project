#include "../../includes/packet.h"

interface SimpleSend{
   command error_t send(pack msg, uint16_t dest );
   command uint8_t getaddr(message_t* msg);
}
