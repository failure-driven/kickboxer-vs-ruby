#!/usr/bin/ruby
# frozen_string_literal: true

require "socket"

server_port = ARGV[0].to_i
device_port = ARGV[1].to_i

s = UDPSocket.new

s.connect "localhost", server_port
s.send "device connected on port: #{device_port}", 0

Socket.udp_server_loop device_port do |data, src|
  src.reply data
  puts data
end
