# frozen_string_literal: true

require "mqtt"
require "JSON"
require "SecureRandom"

client = MQTT::Client.connect("localhost", 1883)
# TODO: uniq ID for device - Actuator - MAC address
# TODO: topic for registering actuators and devices
actuator_id = SecureRandom.hex(3) # on device this is MAC address
management_topic = "kick/manage"
actuator_topic = "kick/#{actuator_id}"
# topic = "mqtt/test"

# tell system I am online
payload = {message: "OK", actuator: actuator_topic}.to_json
client.publish(management_topic, payload, false, 1) # retain = false, QoS = 1
client.subscribe(actuator_topic)

# I'm alive
Thread.new do
  loop do
    puts "sending i'm alive ping"
    payload = {message: "OK", actuator: actuator_topic}.to_json
    client.publish(management_topic, payload, false, 1) # retain = false, QoS = 1
    sleep(5)
  end
end

loop do
  # topic, message = client.get
  # puts [topic, message]
  client.get do |topic, message|
    pp [topic, message]
  end
end
