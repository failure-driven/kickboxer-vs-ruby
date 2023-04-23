# frozen_string_literal: true

wifi = ESP32::WiFi.new

puts "Connecting to wifi"

wifi.connect("loki", "password") # TODO: how best to externalise secrets

puts "Connected"

led = ESP32::GPIO::GPIO_NUM_2 # ESP32 default led pin
ESP32::GPIO.pinMode(led, ESP32::GPIO::OUTPUT)

mqtt = ESP32::MQTT::Client.new("failure-driven.local", 1883)
mqtt.connect
mqtt.publish("kick/manage", '{ "hello": "world." }')
mqtt.disconnect

def kick(led)
  ESP32::GPIO.digitalWrite(led, ESP32::GPIO::HIGH)
  ESP32::System.delay(200)
  ESP32::GPIO.digitalWrite(led, ESP32::GPIO::LOW)
end

#
# Loop forever otherwise the script ends
#
loop do
  mem = ESP32::System.available_memory / 1000
  puts "Free heap: #{mem}K"
  ESP32::System.delay(10000)
  kick(led)
end
