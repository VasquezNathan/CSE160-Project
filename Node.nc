/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/protocol.h"
#include "includes/TCP.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface Neighbor;
   uses interface Flooding;
   uses interface TCP;
   uses interface Timer<TMilli> as timer0; 
   uses interface Timer<TMilli> as timer1;   

}

implementation{
   pack sendPackage;
   uint8_t count;
   bool done = FALSE;
   bool flooded = FALSE;
   uint8_t sendSeq = 20;
   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call timer0.startPeriodic(9000);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      // dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         uint8_t src = myMsg->src;
         // using protocal 255 to identify Neighbor discovery packets
         if (myMsg->protocol == 255)
            call Neighbor.addNeighbor(src);
         // using protocol 254 to identify packets that contain Lists of Neighbors
         else if (myMsg->protocol == 254 && myMsg->TTL > 0) {
            call Neighbor.relayNeighbors(myMsg);
         }

         // if the address of the msg is not the same as the address in the payload then keep forwarding
         else if(call Sender.getaddr(msg) != myMsg->dest) {
            myMsg->TTL--;
            call Sender.send(*myMsg, call Neighbor.getNext(myMsg->dest));
         }

         // if node is intended recipient and protocol is TCP
         if (myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_TCP) {
            // pass the message to check flags for connection state machine
            call TCP.receive(payload);
         }
         


         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT: %s\nnext hop to destination %d: %d\n", payload, destination, call Neighbor.getNext(destination));
      sendSeq = sendSeq + 1;

      // each character is a byte so count ends up being the number of bytes
      for (count = 0; payload[count] != 0; count++) {}
      // dbg(GENERAL_CHANNEL, "\nmsg total size: %d\n", count);
      // using escape character to start/end connection
      if (("%c", payload[0]) == '\0') {
         call TCP.init(destination);
      }
      else call TCP.encapsulate(destination, payload, count);

   }

   // signaled from TCP_P
   // payload is a TCP to be wrapped in packet and sent
   event void TCP.send(uint8_t destination, uint8_t *payload){
      makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_TCP, sendSeq, payload, PACKET_MAX_PAYLOAD_SIZE);
      // dbg(GENERAL_CHANNEL, "forward to: %d\t final: %d\n", call Neighbor.getNext(destination), destination);
         
      // ping should only be called after the topology converges so there is a neighbor from getNext()
      call Sender.send(sendPackage, call Neighbor.getNext(destination));
   }



   event void CommandHandler.printNeighbors(){
      call Neighbor.showNeighbors();
   }
   
   

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   event void timer0.fired() {
      if(!done){
         // calling discoveryNeighbors uses 255 
         call Neighbor.discoverNeighbors(255);
         // start a timer of 2000 ms to give time for all of the Nodes to discover their Neighbors and then
         // start broadcasting their neighbors.
         call timer1.startOneShot(2000);
         done = TRUE;
      }
   }
   event void timer1.fired() {
      // passing 254 tells Nodes to broadcast their neighbors
      call Neighbor.discoverNeighbors(254);
   }
}
