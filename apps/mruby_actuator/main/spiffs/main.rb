wifi = ESP32::WiFi.new

puts 'Connecting to wifi'

wifi.connect("loki", "password") # TODO: how best to externalise secrets

puts "Connected"

mqtt = ESP32::MQTT::Client.new('failure-driven.local', 1883)
mqtt.connect
mqtt.publish("kick/manage", '{ "hello": "world." }')
mqtt.disconnect

#
# Loop forever otherwise the script ends
#
while true do
  mem = ESP32::System.available_memory() / 1000
  puts "Free heap: #{mem}K"
  ESP32::System.delay(10000)
end
