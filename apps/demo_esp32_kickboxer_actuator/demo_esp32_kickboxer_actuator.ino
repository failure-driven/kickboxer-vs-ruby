#include <ESP32Servo.h>
#include <analogWrite.h>
//#include <tone.h>         // seemed to be missing but was auto added
#include <ESP32Tone.h>
#include <ESP32PWM.h>

#include <U8x8lib.h>

#include "EspMQTTClient.h"
// a WiFi.h gets installed with EspMQTTClient and ArduinoJson
#ifdef ESP32
#include <WiFi.h>
#else
#include <ESP8266WiFi.h>
#endif
#include "secrets.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

#include <ESPmDNS.h>

#include <PubSubClient.h>

WiFiClientSecure net = WiFiClientSecure();
WiFiClient espClient;
PubSubClient client(espClient);
long lastMsg = 0;
long hitStart = 0;
char actuator_topic[] = "kick/xx:xx:xx:xx:xx:xx"; // buffer
char serverIp[] = "xxx.xxx.xxx.xxx"; // buffer
char clientName[] = "ESP32/xx.xx.xx.xx.xx.xx"; // buffer

#define LED_BUILTIN 2       // ESP32 builtin led
#define SWEEP_PERIOD 500    // 0.5 second sweep period for servo demo

// Not exactly sure which is needed here ¯\_(ツ)_/¯
#ifdef U8X8_HAVE_HW_SPI
#include <SPI.h>
#endif
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif

// this sets up the device with a reset pin specified
U8X8_SSD1306_128X64_NONAME_HW_I2C u8x8(/* reset=*/ U8X8_PIN_NONE);

const int servoPin = 4;     // SWEEP servo
Servo myservo;

void sweepServo() {
  int millisPosition = millis() % SWEEP_PERIOD;
  double floatPosition = TWO_PI * (((float) millisPosition ) / SWEEP_PERIOD);
  int servoPosition = (70 * sin(floatPosition)) + 90;
  //  Serial.println(servoPosition);
  myservo.write(servoPosition);
}

void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.println("Connecting to Wi-Fi");
  u8x8.setFont(u8x8_font_amstrad_cpc_extended_f);
  u8x8.setCursor(0, 3);
  u8x8.print("Connecting WiFi");
  u8x8.setCursor(0, 4);

  int count = 0;
  while (WiFi.status() != WL_CONNECTED) {
    count++;
    delay(500);
    Serial.print(".");
    u8x8.print(".");
    if (count % 20 == 0) {
      count = 0;
      Serial.println();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      Serial.println("Connecting to Wi-Fi");
      u8x8.setFont(u8x8_font_amstrad_cpc_extended_f);
      u8x8.setCursor(0, 3);
      u8x8.print("Connecting WiFi");
      u8x8.setCursor(0, 4);
    }
  }
}

char * mdns = NULL;

IPAddress resolve_mdns_host(const char * hostname)
{
  IPAddress ip = MDNS.queryHost(hostname, 2000); //  2 second timeout
  Serial.printf("found failure-driven: %s.%s.%s.%s\n", String(ip[0]), String(ip[1]), String(ip[2]), String(ip[3])); // how to IPAddress toString
  return ip;
}

void connectMQTT(const char * mqtt_server) {
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
  reconnect();
  Serial.println("MQTT IoT Connected!");
}

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.print("Kickboxer Client");
  Serial.println(WiFi.macAddress());
  ("ESP32/" + WiFi.macAddress()).toCharArray(clientName, 24); // 6 + 17 + 1 = 24
  ("kick/" + WiFi.macAddress()).toCharArray(actuator_topic, 23); // 4 + 1 +6x2 + 5 + 1 = 23

  myservo.attach(servoPin);
  myservo.attach(servoPin);

  u8x8.begin();
  //  u8x8.setFlipMode(1); // Allow the display to be flipped
  u8x8.clear();
  u8x8.setFont(u8x8_font_amstrad_cpc_extended_f);
  u8x8.print("Kickboxer");
  u8x8.setCursor(0, 1);
  u8x8.print("Actuator");
  u8x8.setCursor(0, 2);
  u8x8.print(WiFi.macAddress());

  connectWifi();
  Serial.println(WiFi.localIP());
  u8x8.setCursor(0, 3);
  // need to clear row as previous text is longer than IP address
  //  uint8_t U8G2::getBufferCurrTileRow()
  //  for( int r = 0; r < u8x8.getRows(); r++ )
  //  {
  //    u8x8.setCursor(c, r);
  //    u8x8.print(" ");
  //  }
  u8x8.print(WiFi.localIP());

  if (!MDNS.begin("ESP32_Browser")) {
    Serial.println("Error setting up MDNS responder!");
    while (1) {
      delay(1000);
    }
  }
  resolve_mdns_host("failure-driven").toString().toCharArray(serverIp, 16);
  Serial.printf("found failure-driven: %s\n", serverIp);
  u8x8.setCursor(0, 4);
  u8x8.print(serverIp);

  connectMQTT(serverIp);
  Serial.println("MQTT connected");
  u8x8.setCursor(0, 5);
  u8x8.print("MQTT connected");
  pinMode(LED_BUILTIN, OUTPUT);
}

// some hints on other things that can be done with the display from
// https://tronixstuff.com/2019/08/29/ssd1306-arduino-tutorial/
//  u8x8.inverse();
//  u8x8.print(" U8x8 Library ");
//  u8x8.setFont(u8x8_font_chroma48medium8_r);
//  u8x8.noInverse();
//  draw_bar example with printing " " in rows
//  can use  u8x8.getCols() and  u8x8.getRows() for width and heigh
//  u8x8.write(a); to write a 0..255 ASCII character
//  u8x8.draw2x2String(0, 5, "Scale Up");
//  u8x8.setFont(u8x8_font_px437wyse700b_2x2_r);
//  u8x8.setFont(u8x8_font_inb33_3x6_n);
//  u8x8.drawString(0, 2, u8x8_u16toa(i, 5)); // U8g2 Build-In functions
//  u8x8.setFont(u8x8_font_open_iconic_weather_4x4);
//  u8x8.drawGlyph(0, 4, '@' + c); // C 0..6

void reconnect() {
  // Loop until we're reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    if (client.connect(clientName)) {
      Serial.println("connected");
      // Subscribe
      client.subscribe("kick/manage");
      client.subscribe(actuator_topic);
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

void callback(char* topic, byte* message, unsigned int length) {
  Serial.print("Message arrived on topic: ");
  Serial.print(topic);
  Serial.print(". Message: ");
  String messageTemp;

  for (int i = 0; i < length; i++) {
    Serial.print((char)message[i]);
    messageTemp += (char)message[i];
  }
  Serial.println();

  if (String(topic) == actuator_topic) {
    Serial.println("HIT");
    digitalWrite(LED_BUILTIN, HIGH);
    hitStart = millis();
  } else {
    // do nothing
  }
}

void loop() {
  // put your main codel here, to run repeatedly:
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  long now = millis();
  if (now - lastMsg > 15000) { // 15 second ping
    lastMsg = now;
    Serial.println("management ping");
    char buffer[60];
    strcpy(buffer, "{\"message\":\"OK\",\"actuator\":\"");
    strcat(buffer, actuator_topic);
    strcat(buffer, "\"}");
    client.publish("kick/manage", buffer);
  }
  sweepServo();
  u8x8.setFont(u8x8_font_px437wyse700b_2x2_r);
  u8x8.setCursor(0, 6);
  u8x8.print(millis());
  if (hitStart > 0 && now - hitStart > 700) {
    hitStart = 0;
    digitalWrite(LED_BUILTIN, LOW);
  }
  delay(20);
}
