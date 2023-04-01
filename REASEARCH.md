# RESEARCH

- [ ] rewrite MQTT ruby client as template (for jruby redo)
- [ ] rewrite MQTT ESP32 C code actuator as template (for mruby redo)
- [x] arduino servo code
- [x] arduino MQTT code
- [ ] NCurses code from Ruby
- [ ] NCurses JRuby code?
- [ ] any compiled JRuby code to try to test limitations of iSH
- [ ] run a simple app in Android emulator
- [ ] get up and running with ruboto
- [ ] ask chatGPT how to run jruby on android
  - [ ] http://shoesrb.com/
  - [ ] http://www.rubymotion.com/
  - [ ] http://ruboto.org/
- [ ] run the search on the internet for the following terms: "ruby code on ios"
  - [ ] https://rubyist.app/
  - [ ] https://github.com/fastlane/fastlane
  - [ ] https://github.com/tryzealot/zealot

## Sat 1st April

- follow steps from https://github.com/mruby-esp32/mruby-esp32
- needed to install idf.py
- went to here https://github.com/espressif/esp-idf/tree/master/docs
- which led us to https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/linux-macos-setup.html
- ran the following
```shell
 9705  git clone --recursive https://github.com/mruby-esp32/mruby-esp32.git
 9707  cd mruby-esp32
 9709  mine .
 9710  idf.py build
 9712  brew install cmake ninja dfu-util
 9715  asdf plugin add python
 9716  asdf list-all python
 9717  asdf install python 3.9.16
 9718  cd ..
 9719  git clone -b v5.0.1 --recursive https://github.com/espressif/esp-idf.git
 9720  cd esp-idf
 9721  ./install.sh esp32
 9722  . ./export.sh
 # failed needed to set the python
 9723  asdf global python 3.9.16
 # then we later did this
 9738  . ../esp-idf/export.sh
 9741  idf.py set-target esp32
 
 9727  cp -r esp-idf/examples/get-started/hello_world .
 9729  cd hello_world
 9730  ls /dev/cu.usbserial-0001
 9732  idf.py set-target esp32
 
 # didn't need menuconfig for hworld
 9743  idf.py set-target esp32
 9744  idf.py menuconfig
 9745  idf.py build
 9746  ls /dev/cu.usbserial-0001
 
 # first build flash of C example testing out idf.py - make sure arduino IDE is not connected
 9752  idf.py -p /dev/cu.usbserial-0001 flash
 9753  screen /dev/tty.usbserial-0001 115200
 
 9756  cat main/hello_world_main.c
 
 # now for ruby
 9759  cd mruby-esp32
 
 9761  mine .
 9762  idf.py build
 9763  idf.py -p /dev/cu.usbserial-0001 flash monitor
 # note monitor prevents exit so need to kill
 9764* ps aux | ag idf
 9765* kill 67589
 # note for next time just use screen
 
 
 # before starting MQTT example run mosquitto and monitor
 docker-compose up # in mqtt dir of our project
 9771* mosquitto_sub -h localhost -t \# -d
 9781* ipconfig getifaddr en0 # get address of machine
 
 # update SSID, password and IP of MQTT server in demo code 
 cat mruby-esp32/main/examples/mqtt_publish.rb
 9784  idf.py build
 9785  idf.py -p /dev/cu.usbserial-0001 flash
# AND IT WORKED 🎉🤩
```

## Sat 18th March

- finally got the ESP32 connected
- seems like each client needs a different name, not all being "ESP32Client" or **Mosquitto** throws error
    ```sh
    Client ESP32Client already connected, closing old connection.
    ```

## Thu 16th March

- talk through the states of the system
    - WiFi connected
    - MQTT found and connected
    - Ping to `kick/manage` to notify actuators exist and are alive
    - demo showing need for Threads for client as the MQTT client code seems to
      block?
    - should probably deal with expiring an actuator if a ping is missed for
      some number of seconds
- expand the demo to show device registration

## Wed 15th March

- IP resolution of mac on network
  ```sh
  ipconfig getifaddr en0
  ➜ 192.168.68.108

  # OR

  ipconfig getifaddr $(route -n get default|awk '/interface/ { print $2 }')
  ➜ 192.168.68.108

  # and using Bonjur, Avahi, MDNS
  dns-sd -Gv4v6 failure-driven.local
  ```
## Tue 14th March

- Start on Demo ESP32 Kickboxer Actuator
  - time to checkout Arduino IDE 2 https://docs.arduino.cc/software/ide-v2
  - and more importantly CLI https://arduino.github.io/arduino-cli/0.31/
- what back up equipement would we need?
  - a Usb C powered hub?
    - $19 super simple (but not powered) https://www.scorptec.com.au/product/kvm-hubs-&-controllers/hubs/90626-mb-c3h-4k
    - with a display would be cool https://www.smartcases.com.au/product/multi-port-usb-charger-hub-8-port-fast-charging-quick-charge-qc3-0-pd-charger-led-display-charging-station-mobile-phone-desktop-wall-home/
    - something with a power bank as well? but it's not a hub? https://www.shargeek.com/products/storm2
- [ ] plan
    - [ ] mruby/c get running
    - [ ] mruby-esp32 get running
    - [x] basics of ESP32: terminal, move servo, talk to screen, connect to wifi, connect to MQTT server
- code samples
  - [x] **terminal**
  ```c
  #include <Arduino.h>

  void setup() {
    Serial.begin(115200);
  }

  void loop() {
    Serial.println("Connected ");
    Serial.println(milli());
    delay(20);
  }

  ```
  - [x] **move servo**
  ```c
  /*
   servo sweep
  */
  #include <Servo.h>          // external library to control a servo
  #define SWEEP_PERIOD 1000   // 1 second sweep period for servo demo

  const int servoPin = 4;     // SWEEP servo

  Servo myservo;

  void sweepServo() {
    int millisPosition = millis() % SWEEP_PERIOD;
    double floatPosition = TWO_PI * (((float) millisPosition ) / SWEEP_PERIOD);
    int servoPosition = (70 * sin(floatPosition)) + 90;
    Serial.println(servoPosition);
    myservo.write(servoPosition);
  }
  ```
  - [x] **logo on screen**
  ```c
  #include <Arduino.h>

  #include <driver/gpio.h>
  #include <driver/spi_master.h>
  #include <stdio.h>
  #include <string.h>
  #include <U8g2lib.h>

  #include "u8g2_esp32_hal.h"
  #include "logos.h"
  // CLK - GPIO14 HSPI CLK
  #define PIN_CLK GPIO_NUM_14
  // MOSI - GPIO 13 HSPI MOSI
  #define PIN_MOSI GPIO_NUM_13
  // RESET - GPIO 26
  #define PIN_RESET GPIO_NUM_26
  // DC - GPIO 27
  #define PIN_DC GPIO_NUM_27
  // CS - GPIO 15 HSPI CS0
  #define PIN_CS GPIO_NUM_15
  u8g2_t u8g2; // a structure which will contain all the data for one display

  //void task_test_SSD1306(void *ignore) {
  void task_test_SSD1306() {
    u8g2_esp32_hal_t u8g2_esp32_hal = U8G2_ESP32_HAL_DEFAULT;
    u8g2_esp32_hal.clk   = PIN_CLK;
    u8g2_esp32_hal.mosi  = PIN_MOSI;
    u8g2_esp32_hal.cs    = PIN_CS;
    u8g2_esp32_hal.dc    = PIN_DC;
    u8g2_esp32_hal.reset = PIN_RESET;
    u8g2_esp32_hal_init(u8g2_esp32_hal);

    // flip screen, if required
    // u8g.setRot180();
    u8g2_Setup_sh1106_128x64_noname_f(
      &u8g2,
      U8G2_R2,
      u8g2_esp32_spi_byte_cb,
      u8g2_esp32_gpio_and_delay_cb);  // init u8g2 structure

    u8g2_InitDisplay(&u8g2); // send init sequence to the display, display is in sleep mode after this,

    u8g2_SetPowerSave(&u8g2, 0); // wake up display
    u8g2_ClearBuffer(&u8g2);
    u8g2_DrawBitmap(&u8g2, 0, 0, 16, 64, failure_driven_bitmap); // 128x64 so 0 X offset full width of 16 bytes wide
    u8g2_SendBuffer(&u8g2);
    delay(1000);
    u8g2_DrawBitmap(&u8g2, 0, 0, 16, 64, failure_driven_2_bitmap); // 128x64 so 0 X offset full width of 16 bytes wide
    u8g2_SendBuffer(&u8g2);
  }

  void publishMessage() {
    u8g2_ClearBuffer(&u8g2);
    u8g2_DrawBitmap(&u8g2, 0, 0, 9, 20, failure_driven_mini_bitmap); // 67x20 128x64 9 bytes wide

    u8g2_SetFont(&u8g2, u8g2_font_unifont_t_symbols);
    u8g2_DrawGlyph(&u8g2, 72, 20, 0x2103); // Degree Celsius ℃ or could use 0x00B0 ° and C
    u8g2_SetFont(&u8g2, u8g2_font_ncenB12_tr);
    u8g2_DrawStr(&u8g2, 90, 20, "some text");

    u8g2_SetDrawColor(&u8g2, 0);
    u8g2_DrawBox(&u8g2, 72, 24, 10, 2);
    // u8g2_SetDrawColor(&u8g2, 1);

    u8g2_SetFont(&u8g2, u8g2_font_ncenB24_tr);
    char demoString[5];
    snprintf(demoString, 5, "%03d", (int)42);
    u8g2_DrawStr(&u8g2, 72, 62, demoString);
    u8g2_SendBuffer(&u8g2);
  }

  void setup() {
    Serial.begin(115200);
    task_test_SSD1306();
  }

  void loop() {
    publishMessage();
    delay(20);
  }
  ```

  - [x] **connect to wifi**
  ```c
  #include "secrets.h"
  #include <HTTPClient.h>
  #include <WiFiClientSecure.h>

  WiFiClientSecure net = WiFiClientSecure();

  void connect() {
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    Serial.println("Connecting to Wi-Fi");

    int count = 0;
    while (WiFi.status() != WL_CONNECTED) {
      count++;
      delay(500);
      Serial.print(".");
      if (count % 20 == 0) {
        count = 0;
        Serial.println();
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
        Serial.println("Connecting to Wi-Fi");
      }
    }
  }

  void setup() {
    Serial.begin(115200);
    connect();
  }

  void loop() {
    publishMessage();
    //  client.loop();
    delay(20);
  }
  ```
    - assuming a `secrets.h` file like
    ```c
    #include <pgmspace.h>

    #define SECRET

    const char WIFI_SSID[] = "";
    const char WIFI_PASSWORD[] = "";
    ```

  - [x] **connect to MQTT server**
  ```c
  #include <MQTTClient.h>
  #include <ArduinoJson.h>

  // The MQTT topics that this device should publish/subscribe
  #define IOT_PUBLISH_TOPIC   "esp32/pub"
  #define IOT_SUBSCRIBE_TOPIC "esp32/sub"

  MQTTClient client = MQTTClient(256);

  void connectMQTT() {
    // if connecting with SSL and Certificates like AWS IoT
    <!-- net.setCACert(AWS_CERT_CA);
    net.setCertificate(AWS_CERT_CRT);
    net.setPrivateKey(AWS_CERT_PRIVATE); -->

    // Connect to the MQTT broker
    client.begin(IOT_ENDPOINT, 8883, net);

    // Create a message handler
    client.onMessage(messageHandler);
    Serial.print("Connecting to AWS IOT");
    while (!client.connect(THINGNAME)) {
      Serial.print(".");
      delay(100);
    }

    if (!client.connected()) {
      Serial.println("MQTT IoT Timeout!");
      return;
    }

    // Subscribe to a topic
    client.subscribe(IOT_SUBSCRIBE_TOPIC);

    Serial.println("MQTT IoT Connected!");
  }

  void publishMessage() {
    StaticJsonDocument<200> doc;
    doc["time"] = millis();
    doc["data"] = 42;
    char jsonBuffer[512];
    serializeJson(doc, jsonBuffer); // print to client
    client.publish(IOT_PUBLISH_TOPIC, jsonBuffer);
  }

  void messageHandler(String &topic, String &payload) {
    Serial.println("incoming: " + topic + " - " + payload);

    //  StaticJsonDocument<200> doc;
    //  deserializeJson(doc, payload);
    //  const char* message = doc["message"];
  }

  void setup() {
    Serial.begin(115200);
    connectMQTT();
  }

  void loop() {
    publishMessage();
    delay(20);
  }

  ```

## Mon 13th March

- also attempted to build some mechanical hardware and failed
- compare the ruby **cruby**
```ruby
asdf local ruby 3.2.1
ruby -v
ruby 3.2.1 (2023-02-08 revision 31819e82c8) [arm64-darwin22]

irb
puts 'Hello World!'
Hello World!
rss = `ps -o rss= -p #{Process.pid}`.to_f / 1024
=> 21.3125 # 21MB
`ps` **rss** - the real memory (resident set) size of the process (in 1024 byte
units).
```
- **mruby**
```sh
asdf list-all ruby | ag mr
asdf install ruby mruby-3.2.0
asdf local ruby mruby-3.2.0
ruby -v
mruby 3.2.0 (2023-02-24)
```
    - and run `mirb`
    ```ruby
    mirb
    mirb - Embeddable Interactive Ruby Shell

    > puts 'hello world'
    hello world

    ps aux | ag mirb
    ps -o rss= -p 67605
    => 1952
    1952.to_f / 1024
    => 1.90625 # MB
    ```
    - [ ] there is also a more complete example of how to compile it
      https://mruby.org/docs/articles/executing-ruby-code-with-mruby.html

- **mruby/c**
  ```sh
  ???
  ```

  - [ ] note mruby/c use Cypress PSoC5LP [CY8CKIT-059 - development board](https://au.element14.com/cypress-semiconductor/cy8ckit-059/dev-board-psoc-5-prototyping/dp/2476010) board in thier examples
    - [ ] the [FreeSoC2 Development Board - PSoC5LP](https://www.sparkfun.com/products/13714) might be another option
  - [ ] specifically look at https://github.com/mruby-esp32/mruby-esp32

- **PicoRuby**
```sh
asdf list-all ruby | ag pi
picoruby-3.0.0
asdf local ruby picoruby-3.0.0

ruby -v
PicoRuby 3.0.0

irb
picoirb> puts 'Hello World!'
Hello World!
=> nil

# in terminal
ps aux | ag pico
ps -o rss= -p 75430
  1328

picoirb> 1328.to_f /1024
=> 1.29688 # MB
```

## Fri 10th March

- got a hint of [PicoRuby](https://github.com/picoruby/picoruby) from [Paul Joe George - mruby/c RubyConfAU 2020](https://twitter.com/pauljoegeorge)
    - written by his boss https://github.com/hasumikin
    - runs on RasPi or a PSoC5LP like a [FreeSoC2 Development Board - PSoC5LP](https://www.sparkfun.com/products/13714)
    - also intresting build on the sparkfun site using Actobotics - https://www.sparkfun.com/pages/Actobotics pre drilled aluminium parts
- more repos worth checking out from [Paul Joe George - mruby/c RubyConfAU 2020](https://twitter.com/pauljoegeorge)
    - https://github.com/pauljoegeorge/m5stickc-mrubyc-template
    - https://github.com/hasumikin/mrubyc-test
    - https://github.com/hasumikin/IoT_workshop
        - hellow world mruby/c
        - hellow world ESP32
        - blink LED, take temperature
        - [ ] multi tasking with mruby/c
            - https://hackmd.io/@pySgLnmoQRGCAHO4NFCFag/Bkwp8S7oV?type=view
- [ ] get started in PicoRuby https://hasumikin.com/about/

## Thu 9th March

- [x] Yuji Yokoo mruby on Dreamcast - https://www.youtube.com/watch?v=ni-1x5Esa_o - some minor snippets of code around video etc - might not be that relevant
- MQTT on Android - https://medium.com/swlh/android-and-mqtt-a-simple-guide-cb0cbba1931c
    - MQTT clients
        - https://www.hivemq.com/
        - https://mosquitto.org/
        - https://www.cloudmqtt.com/
        - https://io.adafruit.com/
- somewhat old example of RubyMotion (mruby) on Android in the book
    - https://pragprog.com/titles/7apps/seven-mobile-apps-in-seven-weeks/
- ideas for a remote network
    - [LinkStar-H68K-0232 Router](https://www.seeedstudio.com/LinkStar-H68K-0232-p-5499.html) for router as well as server of Mosquitto MQTT server using Docker?
        - as per https://wiki.seeedstudio.com/h68k-ha-esphome/
    - RasPi IP camera [example from littlebird](https://littlebirdelectronics.com.au/guides/140/build-a-raspberry-pi-security-camera) using something like [MotionEyeOS](https://github.com/motioneye-project/motioneyeos/wiki)
        - another tutorial on MotionEyeOS - [How to Build a Motion-Triggered Raspberry Pi Security Camera](https://www.tomshardware.com/how-to/raspberry-pi-security-camera)
        - alternately can just install [motion](http://lavrsen.dk/foswiki/bin/view/Motion/WebHome) as per [How to setup a Raspberry Pi Security Camera Livestream](https://tutorials-raspberrypi.com/raspberry-pi-security-camera-livestream-setup/) with `sudo apt-get install motion -y` etc.
    - alternately Beelink computer with GL.iNet Secure Travel WiFi Router
- there is an old thing called GoRuby - ruby implementation written in Go
    - https://github.com/goruby/goruby
- came across a retired product M5StickC
    - https://m5stack.hackster.io/products/m5stickc-esp32-pico-mini-iot-development-board
    - https://core-electronics.com.au/m5stick-c-pico-mini-iot-development-board.html
    - seems part of the M5Stack series
        - https://core-electronics.com.au/m5stack-m5go-iot-starter-kit.html
        - https://core-electronics.com.au/m5stack-esp32-basic-core-iot-development-kit.html
        - https://core-electronics.com.au/m5stack-core2-esp32-iot-development-kit-48597.html
- actual radio controlled boxing robots KMart $35
    - https://www.kmart.co.nz/product/radio-control-boxing-robots-42235415/
- another attempt to get jruby running on iPhone
    - asked on iSH discord how to get more heap to run java - https://discord.com/channels/508839261924229141/510973900209913857/1083147677308555325
    - got this response - https://discord.com/channels/508839261924229141/510973900209913857/1075501395735752745
    - basically `export _JAVA_OPTIONS="-Xmx512m"`
    - added this to the `.bash_profile` using vi which just happened to be isntalled
    - following https://github.com/jruby/jruby/wiki/JRuby-on-Alpine-Linux tried to `apk add jruby`
      ```
      echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
      apk update
      apk add jruby
      ```
    - but didn't work
    - ended up downloading manually, extracting it and adding it to the path
      ```
      vi https://www.jruby.org/download
      wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.2.0/jruby-dist-9.4.2.0-bin.tar.gz
      tar -zxvf jruby-dist-9.4.2.0-bin.tar.gz
      export PATH="$PATH:/root/jruby-9.4.2.0/bin/"

      source .bash_profile # seems this is not sourced on restart either
      jruby -v
      !!! works

      jruby -e -v 'puts "hi"' # just sits there :(
      ```
    - [ ] next up try https://github.com/jruby/warbler to build an executable jar

## Wed 8th March

- on mruby
    - [x] from RubyConf 2020 [Build a voice based smart home using Sinatra & mruby/c](https://www.youtube.com/watch?v=0V-MJgklza4)
        - inspired by Paul Joe George, Do Xuan Thanh from RubyConfAU 2019 - Matsue City Japan - devs at Monstarlab
        - mruby/c - mruby, goRuby, jRuby, cRuby, etc?
        - mruby -> `*.mrb`
        - demo of memory taken to run cRuby
        ```
        puts "Hello World!"
        Hello World!
        => nil
        irb(main):002:0> rss = `ps -o rss= -p #{Process.pid}`.to_f / 1024
        => 40.59375 # 40MB
        ```
        **NOTE:** _the above uses Process.pid to get the process id of IRB
          session and calls out to ps to list that process and the output is
          **rss** - the real memory (resident set) size of the process (in 1024
          byte units)._
        - as well as mruby and mruby/c
        - mruby/c is limited to: Array, FalseClass, Fixnum... classes - not many
        - define ruby method from C using mrbc in C - use this to integrate a C library
        - blink LED example with `led.turn_on` and `led.turn_off`, add `class Led` this is done by extending using C
        ```c
        static voic c_turn_on(mrb_vm *vm, mrb_value *v, int argc) {
            int on = GET_INT_ARG(1);
            gpio_set_level(PIN, on)
        }
        void app_main(void) {
            ...
            mrbc_define_method(0, mrbc_class_object, "mrb_turn_on", c_turn_on);
            ...
        }
        ```
        - example of JavaScript simplifed by JQuery, so to is mruby/c a simplicity over C
        - mruby will not work as it is too heavy weight
        - not yet official https://github.com/mrubyc/mrubyc
        - using Cloud MQTT - https://www.cloudmqtt.com/ - has a free tier
        - one github https://github.com/paul-ml seems to have some ESP32 and Alexa voice command - seems like an old repo (see below)
        - example of mrblib/loops/master.rb to loop and listen for MQTT messages
        - code repo https://github.com/pauljoegeorge/home-automation
        - twitter
            - https://twitter.com/pauljoegeorge
            - https://twitter.com/HustMaroon

- Ruboto
    - https://github.com/ruboto/ruboto
    - http://ruboto.org/
    - Charles updated the settings to get it back up and running
- https://dragonruby.org/
- http://www.rubymotion.com/
- example head movements counters [11 Head Movement Counters with World's 1ST Sparring Robot](https://youtu.be/RjPrg_tL5Fo)
- [How to use the MQTT Protocol with Ruby - August 22, 2022](https://gorails.com/episodes/how-to-use-mqtt-ruby)
- https://github.com/mruby-esp32/mruby-esp32
- options for terminal to run a Ruby/JRuby app
    - Termux on Android
        - https://computerbitsdaily.medium.com/best-way-to-run-java-on-android-using-termux-7dab91feda6a
        - https://github.com/termux/termux-app/wiki/Termux-on-android-5-or-6
    - https://github.com/ish-app/ish
        - https://alternativeto.net/software/ish/about/
    - https://viem.sh/ ?
        - https://github.com/wagmi-dev/viem
    - https://alternativeto.net/software/rayon/about/ ?
    - https://alternativeto.net/software/serverauditor/about/
    - https://alternativeto.net/software/blink-shell/about/
    - probably have to build NCurses library
        - https://www.2n.pl/blog/basics-of-curses-library-in-ruby-make-awesome-terminal-apps
- look at using a brushless motor
    - as per OpenDog - https://github.com/XRobots
        - open dog vs 2 https://youtu.be/nwqSjMttcSg?t=526
        - [9225-160KV Turnigy Multistar Brushless Multi-Rotor Motor](https://hobbyking.com/en_us/9225-160kv-turnigy-multistar-brushless-multi-rotor-motor.html) AUD$182
    - power supply 12 v
        - Turnigy 2200mAh 3S 40C LiPo Pack
            - https://hobbyking.com/en_us/turnigy-2200mah-3s-40c-lipo-pack.html
- what about a linear actuator?
    - https://www.hackster.io/news/budget-linear-actuator-from-james-bruton-4f13e41c35ee
- how to get started in Android dev?
    - https://www.android.com/intl/en_au/android-12/
- cheap Android phones
    - Kogan - Unlocked Telstra Lite Smart Zte L111 - $49 running Android 5.1
        - https://www.kogan.com/au/buy/unique-deals-unlocked-telstra-lite-smart-zte-l111-3g-wifi-hotpost-blue-tick-4-android-gps-fm-9316423039895/
    - [Optus X Swift 5g Mobile Phone Each ~~$279~~ $99](https://www.woolworths.com.au/shop/productdetails/182107) - but is it android?
    - [Optus X Start 3](https://www.optus.com.au/prepaid/phones/optus/x-start-3) - Android R GO
    - [Unlocked Telstra Slim Plus Zte Blade L5](https://www.kogan.com/au/buy/unique-deals-unlocked-telstra-slim-plus-zte-blade-l5-3g-5-android-8gb-wifi-hotspot-easy-use-9316423035149/) - $49.95 Android 5.1
- RubyMotion for Game development
    - [x] [RubyConf 2022: Building a Commercial Game Engine using mRuby and SDL by Amir Rajan](https://youtu.be/s2rngApV1WU)
    - good idea of why you want to use Ruby as a language - because it's fun
    - it can be performant
    - https://dragonruby.itch.io/
    - seems fast compared to Unity
    - SDL - can create window on any platform including WASM
    - chipset architecture available due to the mRuby - can deploy to WASM and Ras Pi
    - `mruby -Bmain_ruby -o main_ruby.c ./main.rb` is main part of tooling
    - more info then game loop (60Hz)
    - invoke ruby from C example
    - Amir Rajan
        - github https://github.com/amirrajan
        - twitter https://twitter.com/amirrajan
        - http://discord.dragonruby.org/
        - http://slack.rubymotion.com/
        - https://www.twitch.tv/amirrajan
    - mruby hello world example [amirrajan/build_and_run.sh](https://gist.github.com/amirrajan/6d5fc4e11ce5676fb574734405bc9759)
    - some game dev examples
        - https://github.com/amirrajan/ruby-conf-2021-gamedev
        - https://github.com/amirrajan/roguelike-tutorial-2021
    - get started https://dragonruby.itch.io/dragonruby-gtk $32 - with lots of samples

- [Building realtime apps with Ruby and WebSockets - Alex Diaconu](https://ably.com/topic/websockets-ruby)
- [Setting up MQTT with Ruby on Rails - Neha Nakrani - 22 Mar 2020](https://dev.to/nehanakrani/setting-up-mqtt-with-ruby-on-rails-3dbi)
