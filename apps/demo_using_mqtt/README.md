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

