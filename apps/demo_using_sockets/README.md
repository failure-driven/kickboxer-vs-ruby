# Demo using sockets

## Using tmux

```sh
make
# in client type
hit port: 4445
CTRL-D
```

also `make demo-attach` to reattach to tmux when in background and `make
demo-down` to kill the tmux session.

## Manually

setup a server, client and device

```sh
# Terminal 1 start a server
bundle exec ruby udp_server.rb 4444

# Terminal 2 start a client
bundle exec ruby udp_client.rb 4444

# Terminal 3 start a device
bundle exec ruby udp_device.rb 4444 4445
```

Now enter a message to hit device on it's listening port 4445, use `CTRL-D` to
finish the command

```
...
inpt your message
hit port: 4445
^D

# server
hit port: 4445
hitting device on port 4445

# device
hit from client
```

## Troubleshooting

if you can't find where the socket server is running or it didn't stop properly
you can find what is listening on that port and kill the associated process

```sh
lsof -i :4444 -nP -sTCP:LISTEN
```

