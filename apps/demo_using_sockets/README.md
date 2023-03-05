# Demo using sockets

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
