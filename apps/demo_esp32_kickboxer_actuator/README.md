# Demo ESP32 Kickboxer Actuator

- [x] get simple terminal message printed
  - use Arduino -> Tools -> Serial Monitor (⇧⌘M)
  - OR screen
    ```sh
    # start screen against USB Serial with 115,200 baud speed
    screen /dev/tty.usbserial-0001 115200

    CTRL-A d        # to detach
    screen -h       # to get a help screen
    CTRL-A h        # to get help
    screen -ls      # to list screens
    screen -r       # to re-attach
    CTRL-A CTRL \   # to quit the sceen session
    ```
## Arduino Software Setup

Assuming using Arduino IDE 1 - https://docs.arduino.cc/software/ide-v1

1. Add additional board managers to get ESP32 working
   1. Arduino -> Preferences -> Additional Boards Manager URLS
      ```
      https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
      https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
      http://arduino.esp8266.com/stable/package_esp8266com_index.json
      ```