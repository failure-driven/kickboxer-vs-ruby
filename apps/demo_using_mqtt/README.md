# Demo using MQTT

## Using tmux

```sh
make install
make
```

in the client enter a message and `CTRL-D`, the message will be displayed on
the device

also `make demo-attach` to reattach to tmux when in background and `make
demo-down` to kill the tmux session.

## Manually

docker-compose up

```
docker run -it \
    -p 1883:1883 -p 9001:9001 \
    -v mosquitto.conf:/mosquitto/config/ \
    eclipse-mosquitto
```

## References

- basics of using `mqtt` gem - https://medium.com/@nehanakrani004/setting-up-mqtt-with-ruby-on-rails-ea52bc63cab4
    - and the actual gem https://github.com/njh/ruby-mqtt
- first attempt at running `docker run -it ...` https://hub.docker.com/_/eclipse-mosquitto
- turning on unathenticated access - https://mosquitto.org/documentation/authentication-methods/
- maybe in future this could help with a **"MQTT Cheat Sheet"** - https://mpolinowski.github.io/docs/Development/Javascript/2021-06-02--mqtt-cheat-sheet/2021-06-02
- how we actually got up and running with a basic `docker-compose.yml` - https://techoverflow.net/2021/11/25/how-to-setup-standalone-mosquitto-mqtt-broker-using-docker-compose/

