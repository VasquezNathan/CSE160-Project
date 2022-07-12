interface TCP {
    command void encapsulate(uint8_t destination, uint8_t *payload, uint8_t msg_total_size);
    command void init(uint8_t destination);
    command void receive(void* payload);
    event void send(uint8_t destination, uint8_t *payload);
}