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

## Make MQTT available on LAN

- tried various options around docker and *macvlan*
    ```
    version: "3"

    services:
      mosquitto:
        image: eclipse-mosquitto:1.6
        # network_mode: host
        volumes:
          - ./conf:/mosquitto/conf
        networks:
          home-lan:
            ipv4_address: 192.168.68.108

      home-lan:
        name: home-lan
        driver: macvlan
        driver_opts:
          parent: eth0
        ipam:
          config:
            - subnet: "192.168.68.0/24"
              gateway: "192.168.68.1"
    ```
    - in the end downgrading to Mosquitto 1.5 (from 2) was enough to work on the host network
    ```
    services:
      mosquitto:
        image: eclipse-mosquitto:1.6
        network_mode: host
    ```

## Troubleshooting

can view all messages with the following (installed via brew bundle)

```
mosquitto_sub -h localhost -t \# -d
```

## References

- basics of using `mqtt` gem - https://medium.com/@nehanakrani004/setting-up-mqtt-with-ruby-on-rails-ea52bc63cab4
    - and the actual gem https://github.com/njh/ruby-mqtt
- first attempt at running `docker run -it ...` https://hub.docker.com/_/eclipse-mosquitto
- turning on unathenticated access - https://mosquitto.org/documentation/authentication-methods/
- maybe in future this could help with a **"MQTT Cheat Sheet"** - https://mpolinowski.github.io/docs/Development/Javascript/2021-06-02--mqtt-cheat-sheet/2021-06-02
- how we actually got up and running with a basic `docker-compose.yml` - https://techoverflow.net/2021/11/25/how-to-setup-standalone-mosquitto-mqtt-broker-using-docker-compose/

