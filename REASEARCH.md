# RESEARCH

- [ ] arduino servo code
- [ ] arduino MQTT code
- [ ] NCurses code from Ruby
- [ ] NCurses JRuby code?
- [ ] any compiled JRuby code to try to test limitations of iSH
- [ ] run a simple app in Android emulator

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

