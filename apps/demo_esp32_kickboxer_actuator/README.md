# Demo ESP32 Kickboxer Actuator

- [ ] get MQTT connected
  - install Adafruit MQTT Library by Adafruit Version 2.5.2 (and associated dependencies)
  - also try https://github.com/plapointe6/EspMQTTClient
  - but going with MQTTClient first https://bitbucket.org/amotzek/arduino/src/master/src/main/cpp/MQTTClient/ but maybe that's not the right one?

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

- [x] get a Servo connected
  ```
                                ------------------
                               | |--|  |--|  |--| |
                        EN     | |  |--|  |--|  | | GPIO23
                        GPIO36 |  --------------  | GIPO22
                        GPIO39 | |              | | GIPO1
                        GPIO34 | | ESP-WROOM-32 | | GPI03
                        GPIO35 | |              | | GPI021
                        GPIO32 | |              | | GPI019
                        GPIO33 | |              | | GPI018
                        GPIO25 | |              | | GPI05
                        GPIO26 |  --------------  | GPI017
                        GPIO27 |                  | GPI016
                        GPIO14 |                  | GPI04 ----- Servo Signal
                        GPIO12 |                  | GPI02
                        GPIO13 |                  | GPI015
                        GND    | EN   _____  BOOT | GND ------- Servo GND
      Servo VCC ------- VIN    | [ ] / USB \  [ ] | VDD 3V3
                                ------------------
  ```

- [x] get IIC OLED SSD1306 connected
  - install `U8g2` library via Arduino -> Tools -> Manage Libraries (⇧⌘I) -> search for "U8g2" by oliver Version 2.33.15
  - try the demo code from https://tronixstuff.com/2019/08/29/ssd1306-arduino-tutorial/

  ```
                                ------------------
                               | |--|  |--|  |--| |
                        EN     | |  |--|  |--|  | | GPIO23
                        GPIO36 |  --------------  | GIPO22    I2C_SCL ---- SSD1306 - SCL
                        GPIO39 | |              | | GIPO1
                        GPIO34 | | ESP-WROOM-32 | | GPI03
                        GPIO35 | |              | | GPI021    I2C_SDA ---- SSD1306 - SDA
                        GPIO32 | |              | | GPI019
                        GPIO33 | |              | | GPI018
                        GPIO25 | |              | | GPI05
                        GPIO26 |  --------------  | GPI017
                        GPIO27 |                  | GPI016
                        GPIO14 |                  | GPI04
                        GPIO12 |                  | GPI02
                        GPIO13 |                  | GPI015
                        GND    | RST  _____  BOOT | GND ------------------ SSD1306 - GND
    SSD1306 - VCC ----- VIN    | [ ] / USB \  [ ] | VDD 3V3
                                ------------------
  ```

## Arduino Software Setup

Assuming using Arduino IDE 1 - https://docs.arduino.cc/software/ide-v1

1. Connect to the Serial USB port
   1. Arduino -> Port -> "choose somethingn with usbserial"
2. Add additional board managers to get ESP32 working
   1. Arduino -> Preferences -> Additional Boards Manager URLS
      ```
      https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
      https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
      http://arduino.esp8266.com/stable/package_esp8266com_index.json
      ```
3. select the correct board
   1. Arduino -> Tools -> Board -> ESP32 Arduino -> ESP32 Dev Module
4. could not use `#include <Arduino.h>    // standard Arduino library` so instead
   1. Arduino -> Tools -> Manage Libraries (⇧⌘I) -> search for "ESP32Servo" by Kevin Harrington Version 0.12.1
5. Upload to board using
   1. Arduino -> Sketch -> Upload (⌘U)
