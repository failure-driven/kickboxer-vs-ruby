# frozen_string_literal: true

require "socket"

server_port = ARGV[0].to_i

s = UDPSocket.new

s.connect "localhost", server_port
s.send "client connected", 0

loop do
  puts "inpt your message"
  message = $stdin.read
  s.send message, 0
end
puts s.recv 50
s.close
