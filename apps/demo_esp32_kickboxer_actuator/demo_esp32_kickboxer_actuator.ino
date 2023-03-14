void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.print("Kickboxer Client");
}

void loop() {
  // put your main code here, to run repeatedly:
  Serial.print("Connected ");
  Serial.println(millis());
  delay(500);
}
