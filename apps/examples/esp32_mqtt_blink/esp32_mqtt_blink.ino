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

#define LED_BUILTIN 2           // ESP32 builtin led

void connectWifi() {
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

char * mdns = NULL;

IPAddress resolve_mdns_host(const char * hostname)
{
  IPAddress ip = MDNS.queryHost(hostname, 2000); //  2 second timeout
  Serial.printf(
    "found failure-driven: %s.%s.%s.%s\n",
    String(ip[0]),
    String(ip[1]),
    String(ip[2]),
    String(ip[3])
  ); // how to IPAddress toString
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
  ("kick/" + WiFi.macAddress()).toCharArray(actuator_topic, 23); // 4 + 1 + 6x2 + 5 + 1 = 23

  connectWifi();
  Serial.println(WiFi.localIP());

  if (!MDNS.begin("ESP32_Browser")) {
    Serial.println("Error setting up MDNS responder!");
    while (1) {
      delay(1000);
    }
  }
  resolve_mdns_host(MQTT_SERVER_NAME).toString().toCharArray(serverIp, 16);
  Serial.printf("found %s: %s\n", MQTT_SERVER_NAME, serverIp);

  connectMQTT(serverIp);
  Serial.println("MQTT connected");
  pinMode(LED_BUILTIN, OUTPUT);
}

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
  if (now - lastMsg > 5000) { // 5 second ping
    lastMsg = now;
    Serial.println("management ping");
    char buffer[60];
    strcpy(buffer, "{\"message\":\"OK\",\"actuator\":\"");
    strcat(buffer, actuator_topic);
    strcat(buffer, "\"}");
    client.publish("kick/manage", buffer);
  }
  if (hitStart > 0 && now - hitStart > 170) {
    hitStart = 0;
    digitalWrite(LED_BUILTIN, LOW);
  }
  delay(20);
}
