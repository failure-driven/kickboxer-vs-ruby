# frozen_string_literal: true

led = ESP32::GPIO::GPIO_NUM_2 # ESP32 default led pin

ESP32::GPIO.pinMode(led, ESP32::GPIO::OUTPUT)

loop do
  ESP32::GPIO.digitalWrite(led, ESP32::GPIO::HIGH)
  ESP32::System.delay(1000)
  ESP32::GPIO.digitalWrite(led, ESP32::GPIO::LOW)
  ESP32::System.delay(1000)
end
