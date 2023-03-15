# frozen_string_literal: true

require "mqtt"
require "JSON"

MQTT_SERVER = "failure-driven.local" # depends on your computer name
# TODO: should we try to resolve the IP of the server above?
# Resolv::MDNS.each_address("failure-driven")
# TODO: can we just search the network for an MQTT service provider?
# MQTT_SERVER = "localhost"

client = nil
# connect to MQTT server loop
loop do
  begin
    client = MQTT::Client.connect(MQTT_SERVER, 1883)
    break # got a lient connection
  rescue Errno::ECONNREFUSED => e
    puts e.message
    puts "will retry in 1 second"
    sleep(1)
  end
end

management_topic = "kick/manage"
client.subscribe(management_topic)

devices = []
Thread.new do
  client.get do |topic, message|
    pp [topic, message]
    actuator_topic = JSON.parse(message).dig("actuator")
    devices << actuator_topic unless devices.include?(actuator_topic)
    # TODO: remove actuators if we don't get a sign of life (ping) for 30 seconds
  end
end

# 1. remove device if it is no longer alive
# 2. allow client to send message to device
# 3. allow device to listen on the topic

loop do
  topic, message = client.get
  puts "inpt your message"
  pp devices
  # 2. above - allow to publish to a topic on devices aray
  message = $stdin.read.chomp
  payload = {test: message}.to_json
  client.publish(topic, payload, false, 1) # retain = false, qos = 1
end
