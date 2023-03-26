# frozen_string_literal: true

$LOAD_PATH << File.join(__dir__, "lib")

require "kick_client"
require "ascii_ui"

kick_client = KickClient.new(
  mqtt_server: ENV.fetch("MQTT_SERVER", "localhost"),
  mqtt_port: 1883,
  ui: AsciiUi.new,
)

kick_client.start
