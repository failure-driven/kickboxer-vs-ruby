# frozen_string_literal: true

require "mqtt"
require "JSON"

client = MQTT::Client.connect("localhost", 1883)
topic = "mqtt/test"

loop do
  puts "inpt your message"
  message = $stdin.read.chomp
  payload = {test: message}.to_json
  client.publish(topic, payload, false, 1) # retain = false, qos = 1
end
