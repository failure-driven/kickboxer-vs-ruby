# frozen_string_literal: true

require "mqtt"
require "JSON"

client = MQTT::Client.connect("localhost", 1883)
topic = "mqtt/test"
client.subscribe(topic)

loop do
  # topic, message = client.get
  # puts [topic, message]
  client.get do |topic, message|
    pp [topic, message]
  end
end
