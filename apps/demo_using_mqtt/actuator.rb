# frozen_string_literal: true

$LOAD_PATH << File.join(__dir__, "lib")

require "ascii_ui"
require "kick_actuator"

kick_actuator = KickActuator.new(
  mqtt_server: ENV.fetch("MQTT_SERVER", "localhost"),
  mqtt_port: 1883,
  ui: AsciiUi.new,
)

kick_actuator.start
