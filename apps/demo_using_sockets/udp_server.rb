#!/usr/bin/ruby
# frozen_string_literal: true

require "socket"

port = ARGV[0].to_i
puts "starting server on port #{port}"

devices = []

Socket.udp_server_loop port do |data, src|
  src.reply data
  puts data
  if (matches = /device connected on port: (\d*)/.match(data))
    puts "device on port #{matches[1].to_i}"
    devices << matches[1].to_i
  end
  if (matches = /hit port: (\d*)/.match(data))
    puts "hitting device on port #{matches[1].to_i}"
    s = UDPSocket.new
    s.connect "localhost", matches[1].to_i
    s.send "hit from client", 0
  end
end
