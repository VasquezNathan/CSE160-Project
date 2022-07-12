configuration FloodingC{
    provides interface Flooding;
}
implementation{
    components FloodingP;
    components new SimpleSendC(AM_PACK);
    Flooding = FloodingP;
    FloodingP.SimpleSend -> SimpleSendC;
}