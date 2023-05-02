# frozen_string_literal: true

last_msg = 0
hit_start = 0

wifi = ESP32::WiFi.new

puts "Connecting to wifi"

wifi.connect("loki", "password") # TODO: how best to externalise secrets
# client_name = "ESP32/#{wifi.mac_address}" # TODO: why no client name
actuator_topic = "kick/wifi.mac_address"

puts "Connected"

led = ESP32::GPIO::GPIO_NUM_2 # ESP32 default led pin
ESP32::GPIO.pinMode(led, ESP32::GPIO::OUTPUT)

mqtt = ESP32::MQTT::Client.new("failure-driven.local", 1883)
mqtt.connect
mqtt.publish("kick/manage", '{ "message":"OK", "actuator":"' + actuator_topic + '" }')
mqtt.subscribe(actuator_topic)

loop do
  now = ESP32::Timer.get_time
  if (now - last_msg) > 5_000_000 # 5 second ping
    last_msg = now
    mqtt.publish("kick/manage", '{ "message":"OK", "actuator":"' + actuator_topic + '" }')
  end
  if hit_start > 0 && now - hit_start > 170_000 # 170 milliseconds
    hit_start = 0
    ESP32::GPIO.digitalWrite(led, ESP32::GPIO::LOW)
  end
  ESP32::System.delay(20)

  # this seems to block
  topic, _message = mqtt.get
  if topic == actuator_topic
    puts "HIT"
    ESP32::GPIO.digitalWrite(led, ESP32::GPIO::HIGH)
    hit_start = ESP32::Timer.get_time
  end
end
