#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/TCP.h"
#include "../../includes/socket.h"
#include <Timer.h>

module TCP_P {
    provides interface TCP;
    uses interface Timer<TMilli> as timer3;
    uses interface List<tcp> as sendQueue;
    uses interface List<tcp> as rcvdQueue;
}
implementation {
    tcp sendPackage;
    uint8_t *this_payload;
    char username[10] = {0,0,0,0,0,0,0,0,0,0};
    uint8_t i, j;
    uint8_t last_seq_seen = 0;
    uint8_t this_dest;
    uint8_t this_size;
    uint8_t this_seq = 0;
    uint8_t this_ack_seq = 0;
    char joinedNodes[20][10] = {
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},

            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},           
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},

            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},           
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            
            {0,0,0,0,0,0,0,0,0,0},            
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0}
        };
    uint8_t advertized_window_size = 0;
    enum flags{SYN = 0, ACK = 1, FIN = 2, SYN_ACK = 3, DATA = 4};
    enum flags flag;
    enum socket_state state = CLOSED;
    void makeTCP(tcp *Package, uint8_t src_prt, uint8_t dest_prt, uint8_t flag, uint8_t seq, uint8_t ack_seq, uint8_t window_size, uint8_t *payload, uint8_t length);
    void rtBuff();
    void processCommand(uint8_t* payload, uint8_t origin);
    bool compare(uint8_t* one, uint8_t* two);
    // initialize the connection by sending syn to destination
    command void TCP.init(uint8_t destination) {
        // init is first called
        this_dest = destination;
        if (state == CLOSED) {
            state = SYN_SENT;   
            makeTCP(&sendPackage, 0, 0, SYN, this_seq, this_ack_seq, 0, "", TCP_MAX_PAYLOAD_SIZE);
            call timer3.startOneShotAt(call timer3.getNow(), 20000);
            signal TCP.send(destination, &sendPackage);
        }
        // connection is already established and applictaion is passing data to send
        // put data in queue if seq != ack_seq. send pack otherwise.
        else if (state == ESTABLISHED) {
            state = FIN_WAIT_1;
            makeTCP(&sendPackage, 0, 0, FIN, this_seq, this_ack_seq, 0, "", TCP_MAX_PAYLOAD_SIZE);
            if (!(call sendQueue.isEmpty())){
                dbg(GENERAL_CHANNEL, "\ncannot teardown: %d packets still not acked, restransmitting buffer...\n", call sendQueue.size());
                call sendQueue.pushback(sendPackage);
                rtBuff();
                return;
            }
            // call sendQueue.pushback(sendPackage);
            call timer3.startOneShotAt(call timer3.getNow(), 20000);
            signal TCP.send(destination, &sendPackage);

        }
        else {
            dbg(GENERAL_CHANNEL, "\nunknown state: %d\n", state);
        }
    }

    // when a node recieves a TCP pack it should check the stateto determine the next step
    command void TCP.receive(void* payload) {
        // parse payload into desired structures
        pack* myMsg = (pack*) payload;
        tcp* myTCP = (tcp*) myMsg->payload;

        // log tcp
        dbg(GENERAL_CHANNEL, "TCP RECIEVED: src_prt: %d\tdest_prt: %d\tflag: %d\t seq: %d\tack_seq: %d\twindow_size: %d\tpayload: %s\n",
                myTCP->src_prt, myTCP->dest_prt, myTCP->flag, myTCP->seq, myTCP->ack_seq, myTCP->window_size, myTCP->payload);

        // step 1. when client -> SYN -> server
        if (myTCP->flag == SYN) {
            state = SYN_RCVD;
            this_dest = myMsg->src;
            dbg(GENERAL_CHANNEL, "TCP SYN Recieved. My state is CLOSED -> SYN_RCVD\n");
            myTCP->ack_seq = myTCP->seq + 1;
            this_ack_seq = myTCP->ack_seq;
            myTCP->flag = SYN_ACK;
            // send advertized window to sender
            myTCP->window_size = call rcvdQueue.maxSize() - call rcvdQueue.size();
            call timer3.startOneShotAt(call timer3.getNow(), 2500);
            signal TCP.send(myMsg->src, myTCP);
        }

        // step 2. when client <- SYN <- server
        else if (myTCP->flag == SYN_ACK) {
            call timer3.stop();
            dbg(GENERAL_CHANNEL, "TCP SYN_ACK Recieved. My state is %d -> ESTABLISHED\n", state);
            state = ESTABLISHED;
            myTCP->seq = myTCP->ack_seq;
            this_seq = myTCP->seq;
            this_ack_seq = myTCP->ack_seq;
            myTCP->flag = ACK;
            // call timer3.startOneShotAt(call timer3.getNow(), 2000);
            signal TCP.send(myMsg->src, myTCP);
        }

        // step 3. when client <- ACK <- server
        //         and  client -> ACK -> server 
        else if (myTCP->flag == ACK && state == SYN_RCVD) {
            state = ESTABLISHED;
            call timer3.stop();
            dbg(GENERAL_CHANNEL, "TCP ACK Recieved. My state is SYN_RCVD -> ESTABLISHED.\n");
            // this_seq = myTCP->ack_seq;
            this_ack_seq = myTCP->ack_seq;
            this_seq = myTCP->seq;
            advertized_window_size = myTCP->window_size;
            // once the connection is ESTABLISHED then we can start to encapsulate the data
            // and send it. we only want to do this on the node that the message was originally from however.
        }

        // node is in a state of ESTABLISHED and recieves a SYN
        // now the data transfer can begin to take place
        else if  (myTCP->flag == DATA && state == ESTABLISHED) {
            dbg(GENERAL_CHANNEL, "TCP SYN Recieved. My state is ESTABLISHED.\nthis_seq: %d \t this_ack_seq: %d\n",this_seq, this_ack_seq);
            myTCP->flag = ACK;
            if (myTCP->seq == this_seq + 1){
                
                this_seq += 1;
                myTCP->ack_seq = myTCP->seq;
                this_ack_seq = myTCP->ack_seq;
                call rcvdQueue.pushback(*myTCP);
                myTCP->window_size = call rcvdQueue.maxSize() - call rcvdQueue.size();
            }
            if(myTCP->seq != last_seq_seen){processCommand(myTCP->payload, myMsg->src); }
            myTCP->ack_seq = this_seq;
            memcpy(myTCP->payload, "", TCP_MAX_PAYLOAD_SIZE);

            // ack the SYN
            // store the pack
            
            signal TCP.send(myMsg->src, myTCP);
        }

        // node is in a state of ESTABLISHED and recieves an ACK
        // for now the tear down can occur
        else if  (myTCP->flag == ACK && state == ESTABLISHED) {
            // the next pack expected by the revciever
            dbg(GENERAL_CHANNEL, "TCP ACK recived. My state is ESTABLISHED\n");
            this_ack_seq = myTCP->ack_seq;
            // this_seq = myTCP->ack_seq;
            advertized_window_size = myTCP->window_size;
            dbg(GENERAL_CHANNEL, "\nsendQueue: \t ack_seq recieved: %d\n", this_ack_seq);

            for(i = 0; i < call sendQueue.size(); i++) {
                dbg(GENERAL_CHANNEL, "\n%d\n", (call sendQueue.toArray())[i].seq);
                if ((call sendQueue.toArray())[i].seq == this_ack_seq || (call sendQueue.toArray())[i].seq == myTCP->seq) {
                    call sendQueue.pop(i);
                    call timer3.stop();
                }
            }   
            if (!(call sendQueue.isEmpty())) {
                call timer3.startOneShotAt(call timer3.getNow(), 2000);
            }
        }

        // step 1 in teardown. Recieve ACK from passive party that
        // active FIN was recieved.
        else if (myTCP->flag == ACK && state == FIN_WAIT_1) {
            call timer3.stop();
            dbg(GENERAL_CHANNEL, "TCP ACK Recieved. My state is FIN_WAIT_1 -> FIN_WAIT_2\n");
            state = FIN_WAIT_2;
            for(i = 0; i < call sendQueue.size(); i++) {
                // dbg(GENERAL_CHANNEL, "\n%d\n", (call sendQueue.toArray())[i].seq);
                if ((call sendQueue.toArray())[i].seq == this_ack_seq - 1) {
                    call sendQueue.pop(i);
                    call timer3.stop();
                }
            }
        }

        // step 2 in teardown. Recieve FIN from passive node
        else if (myTCP->flag == FIN && state != ESTABLISHED) {
            dbg(GENERAL_CHANNEL, "TCP FIN Recieved. My state is FIN_WAIT_2 -> TIME_WAIT\n");
            state = TIME_WAIT;


            myTCP->flag = ACK;
            // myTCP->ack_seq += 1;
            signal TCP.send(myMsg->src, myTCP);
            call timer3.startOneShot(1500); // should be RTT
        }

        // step 3 in teardown. Recieve ACK from active party that 
        // passive FIN was recieved.
        else if (myTCP->flag == ACK && state == CLOSE_WAIT) {
            dbg(GENERAL_CHANNEL, "TCP ACK Recieved. My state is CLOSED_WAIT -> CLOSED\n");
            state = CLOSED;
        }


        // node is ESTABLISHED and recieves FIN
        // send ack
        else if (myTCP->flag == FIN && state == ESTABLISHED) {
            state = CLOSE_WAIT;
            dbg(GENERAL_CHANNEL, "TCP FIN Recieved. My state is ESTABLISHED -> CLOSE_WAIT\n");
            myTCP->flag = ACK;
            myTCP->ack_seq += 1;
            memcpy(myTCP->payload, "", TCP_MAX_PAYLOAD_SIZE);
            signal TCP.send(myMsg->src, myTCP);
            myTCP->flag = FIN;
            myTCP->seq += 1;
            signal TCP.send(myMsg->src, myTCP);
            call timer3.startOneShotAt(call timer3.getNow(), 2000);
        }

        else {
            // dbg(GENERAL_CHANNEL, "TCP ??? Recieved from %d\n", myMsg->src);
            myTCP->flag = ACK;
            signal TCP.send(myMsg->src, myTCP);

        }

    }

    // takes the payload and wraps TCP header around it, then it is 
    // sent back via signal so it an be wrapped with packet header.
    command void TCP.encapsulate(uint8_t destination, uint8_t *payload, uint8_t msg_total_size) { 
        if (call sendQueue.size() >= advertized_window_size){
            // dbg(GENERAL_CHANNEL, "Packets in flight >= advertized_window_size. Wait for ACK\n");
        }
        this_seq += 1;
        makeTCP(&sendPackage, 0, 0, DATA, this_seq, this_ack_seq, 0, payload, TCP_MAX_PAYLOAD_SIZE);
        call sendQueue.pushback(sendPackage);
        call timer3.startOneShotAt(call timer3.getNow(), 2000);
        if (state == ESTABLISHED){
            signal TCP.send(destination, &sendPackage);
        }
    }


    // used to make TCP struct out of sendPackage.
    void makeTCP(tcp *Package, uint8_t src_prt, uint8_t dest_prt, uint8_t flag, uint8_t seq, uint8_t ack_seq, uint8_t window_size, uint8_t *payload, uint8_t length) {
        Package->src_prt = src_prt;
        Package->dest_prt = dest_prt;
        Package->flag = flag;
        Package->seq = seq;
        Package->ack_seq = ack_seq;
        Package->window_size = window_size;
        memcpy(Package->payload, payload, length);
    }

    event void timer3.fired() {
        if (state == TIME_WAIT) {
            state = CLOSED;
            dbg(GENERAL_CHANNEL, "TCP Timeout. My state is TIME_WAIT -> CLOSED\n");
        }
        else if(state == SYN_RCVD){
            makeTCP(&sendPackage, 0, 0, SYN_ACK, this_seq, this_ack_seq, call rcvdQueue.maxSize() - call rcvdQueue.size(), "", TCP_MAX_PAYLOAD_SIZE);
            dbg(GENERAL_CHANNEL, "I don't know if SYN_ACK was recieved or not\n");

            call timer3.startOneShotAt(call timer3.getNow(), 2000);
            signal TCP.send(this_dest, &sendPackage);
        }
        else if(state == CLOSE_WAIT){
            makeTCP(&sendPackage, 0, 0, ACK, this_seq, this_ack_seq, 0, "", TCP_MAX_PAYLOAD_SIZE);
            signal TCP.send(this_dest, &sendPackage);
            makeTCP(&sendPackage, 0, 0, FIN, this_seq, this_ack_seq, 0, "", TCP_MAX_PAYLOAD_SIZE);
            signal TCP.send(this_dest, &sendPackage);
            call timer3.startOneShotAt(call timer3.getNow(), 2000);
        }
        else if(state == FIN_WAIT_1){
             makeTCP(&sendPackage, 0, 0, FIN, this_seq, this_ack_seq, 0, "", TCP_MAX_PAYLOAD_SIZE);
            call timer3.startOneShotAt(call timer3.getNow(), 2000);
            signal TCP.send(this_dest, &sendPackage);
        }
        else if (state == ESTABLISHED){
            dbg(GENERAL_CHANNEL, "\n%d packs timed out, state: %d, retransmitting buffer...\n", call sendQueue.size(), state);
            rtBuff();
        }
        else if (state == SYN_SENT) {
            dbg(GENERAL_CHANNEL, "Connection failed... resend SYN to %d\n", this_dest);
            makeTCP(&sendPackage, 0, 0, SYN, this_seq, this_ack_seq, 0, "", TCP_MAX_PAYLOAD_SIZE);
            call timer3.startOneShotAt(call timer3.getNow(), 2000);
            signal TCP.send(this_dest, &sendPackage);
        }
    }

    void rtBuff() {
        for(i = 0; i < call sendQueue.size(); i++) {
            dbg(GENERAL_CHANNEL, "\nbuffer: %s \t seq: %d\n", (call sendQueue.toArray())[i].payload, (call sendQueue.toArray())[i].seq);
            signal TCP.send(this_dest, &((call sendQueue.toArray())[i]));
        }
        call timer3.startOneShotAt(call timer3.getNow(), 20000);
    }

    void processCommand(uint8_t* payload, uint8_t origin) {
        if (TOS_NODE_ID == 1) {      
            if (payload[0] == 'h' && payload[1] == 'e' && payload[2] == 'l' && payload[3] == 'l' && payload[4] == 'o' && payload[5] == ' ') {
                i = 6;      
                while(payload[i] != '\0'){
                    joinedNodes[origin][i-6] = payload[i];
                    i++;
                }
                // joinedNodes[origin][4] = '\0';
                dbg(GENERAL_CHANNEL, "\nCommand hello recieved from: %d as %s\n", origin, joinedNodes[origin]);
            }
            else if (payload[0] == 'm' && payload[1] == 's' && payload[2] == 'g') {
                dbg(GENERAL_CHANNEL, "\nmsg\n");
                i = 3;
                while(payload[i] != '\0') {
                    payload[i-3] = payload[i];
                    i++;
                }
                payload[i-3] = '\0';
                for(i = 0; i < 20; i ++) {
                    if(joinedNodes[i][0] != 0){
                        call TCP.encapsulate(i, payload, 0);
                    }
                }
            }
            else if (payload[0] == 'w') {
                i = 2;
                while(payload[i] != '\r') {
                    payload[i-2] = payload[i];
                    i++;
                }
                payload[i-2] = '\0';
                dbg(GENERAL_CHANNEL, "payload = %s\n", payload);
                i = 0;
                while(payload[i] != ' ') {
                    username[i] = payload[i];
                    i++;
                }
                username[i] = '\0';
                dbg(GENERAL_CHANNEL, "payload = %s username = %s i = %d\n", payload, username, i);
                i+=1;
                j = i;
                while(payload[j] != '\0'){
                    payload[j-i] = payload[j];
                    j++;
                }
                payload[j-i] = '\0';
                dbg(GENERAL_CHANNEL, "payload = %s username = %s\n", payload, username);
                for(i = 0; i < 20; i++) {
                    if (compare(joinedNodes[i], username)){
                        // dbg(GENERAL_CHANNEL, "send to %d\n", i);
                        call TCP.encapsulate(i, payload, 0);
                    }
                }
                

            }
            else if (payload[0] == 'l' && payload[1] == 's'){
                for(i = 0; i < 20; i++) {
                    if(joinedNodes[i][0] != '\0')
                        call TCP.encapsulate(origin, joinedNodes[i], 0);
                        // dbg(GENERAL_CHANNEL, "what the fuck%c\n\n\n", joinedNodes[i][0]);

                }
            }
            else {
                dbg(GENERAL_CHANNEL, "\nunknown command\n");
            }

        }
    }

    bool compare(uint8_t* one, uint8_t* two){
        j = 0;
        if (one[j] == 0){
            return FALSE;
        }
        while(two[j] != '\0') {
            if(one[j] != two[j]){
                return FALSE;
            }
            j++;
        }
        return TRUE;
    }

}