configuration TCP_C {
    provides interface TCP;
}
implementation {
    components TCP_P;
    components new TimerMilliC() as timer3;
    components new ListC(tcp, 20) as sendQueue;
    components new ListC(tcp, 20) as rcvdQueue;
    TCP = TCP_P;
    TCP_P.timer3 -> timer3;
    TCP_P.sendQueue -> sendQueue;
    TCP_P.rcvdQueue -> rcvdQueue;
}