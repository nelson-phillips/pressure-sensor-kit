#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include <SparkFunBME280.h>
#include <Adafruit_ADS1X15.h>

// SD Card
const int chipSelect = 10;
bool sdInitialized = false;

// Button for data logging control
const int buttonPin = 4;
bool lastButtonState = HIGH;
bool buttonState = HIGH;
bool loggingActive = false;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

// BME280
BME280 bme280;
bool bmeConnected = false;

// ADS1115
Adafruit_ADS1115 ads1;  // 0x48
Adafruit_ADS1115 ads2;  // 0x49
Adafruit_ADS1115 ads3;  // 0x4A
Adafruit_ADS1115 ads4;  // 0x4B
bool ads1Connected = false;
bool ads2Connected = false;
bool ads3Connected = false;
bool ads4Connected = false;

// File for data logging
File dataFile;
char currentFilename[15];  // "LOG_XXX.CSV"

// Data array (max 16 values: timestamp + temp + press + 4 analog + 8 ADS1115)
#define DATA_ARRAY_SIZE 16
float dataArray[DATA_ARRAY_SIZE];
int dataCount = 0;

// Logging interval (100ms = 10Hz)
unsigned long lastLogTime = 0;
const unsigned long logInterval = 100;

void setup() {
  Serial.begin(9600);
  
  // Setup button
  pinMode(buttonPin, INPUT_PULLUP);
  
  // Initialize SD card
  initSDCard();
  
  // Initialize I2C devices
  initI2CDevices();
  
  // Read and print initial BME280 values
  if (bmeConnected) {
    initialisation_BME_sensor();
  }
  
  Serial.println("System Ready");
}

void loop() {
  // Check button state with debouncing
  bool reading = digitalRead(buttonPin);
  
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != buttonState) {
      buttonState = reading;
      
      if (buttonState == LOW) {
        toggleDataLogging();
      }
    }
  }
  
  lastButtonState = reading;
  
  // Data logging routine
  if (loggingActive && sdInitialized) {
    if (millis() - lastLogTime >= logInterval) {
      readAllSensors();
      writeDataToSD();
      lastLogTime = millis();
    }
  }
  
  delay(1);  // Small delay
}

void initSDCard() {
  Serial.print("SD Card... ");
  
  if (!SD.begin(chipSelect)) {
    Serial.println("Failed");
    sdInitialized = false;
    return;
  }
  
  Serial.println("OK");
  sdInitialized = true;
}

void initI2CDevices() {
  Wire.begin();
  
  // Initialize BME280
  Wire.setClock(400000);

  // mySensor.setI2CAddress(0x76);//changes to BME280 sensor address 0x76
  // if(mySensor.beginI2C() == false){ Serial.println("Sensor A connect failed");}
  bme280.setI2CAddress(0x76);
  if (bme280.beginI2C() == 1) {
    bmeConnected = true;
  }
  
  // Initialize ADS1115 boards
  ads1Connected = ads1.begin(0x48);
  if (ads1Connected) {
    ads1.setGain(GAIN_SIXTEEN);
  }
  
  ads2Connected = ads2.begin(0x49);
  if (ads2Connected) {
    ads2.setGain(GAIN_SIXTEEN);
  }
  
  ads3Connected = ads3.begin(0x4A);
  if (ads3Connected) {
    ads3.setGain(GAIN_SIXTEEN);
  }
  
  ads4Connected = ads4.begin(0x4B);
  if (ads4Connected) {
    ads4.setGain(GAIN_SIXTEEN);
  }
}

void toggleDataLogging() {
  if (!sdInitialized) {
    Serial.println("SD not ready");
    return;
  }
  
  if (!loggingActive) {
    startLogging();
  } else {
    stopLogging();
  }
}

void startLogging() {
  // Create unique filename
  createLogFilename();
  
  // Open file for writing
  dataFile = SD.open(currentFilename, FILE_WRITE);
  
  if (dataFile) {
    loggingActive = true;
    Serial.print("Logging to: ");
    Serial.println(currentFilename);
    
    // Write CSV header
    writeCSVHeader();
  } else {
    Serial.println("File create failed");
  }
}

void stopLogging() {
  if (dataFile) {
    dataFile.close();
  }
  
  loggingActive = false;
  Serial.print("Stopped: ");
  Serial.println(currentFilename);
  currentFilename[0] = '\0';
}

void createLogFilename() {
  // Find next available file number
  for (int i = 1; i < 1000; i++) {
    sprintf(currentFilename, "LOG%03d.CSV", i);
    
    if (!SD.exists(currentFilename)) {
      return;
    }
  }
  
  // Fallback
  sprintf(currentFilename, "LOG%lu.CSV", millis());
}

void writeCSVHeader() {
  if (!dataFile) return;
  
  dataFile.print("Timestamp,");
  dataFile.print("Temp(C),");
  dataFile.print("Press(hPa),");
  
  // Analog pins
  dataFile.print("A0,A1,A2,A3,");
  
  // ADS1115 differential channels
  if (ads1Connected) dataFile.print("ADS1_01,ADS1_23,");
  if (ads2Connected) dataFile.print("ADS2_01,ADS2_23,");
  if (ads3Connected) dataFile.print("ADS3_01,ADS3_23,");
  if (ads4Connected) dataFile.print("ADS4_01,ADS4_23");
  
  dataFile.println();
  dataFile.flush();
}

void readAllSensors() {
  dataCount = 0;
  
  // 1. Timestamp (as float for CSV compatibility)
  dataArray[dataCount++] = (float)millis();
  
  // 2. BME280 readings (temperature and pressure only)
  if (bmeConnected) {
    dataArray[dataCount++] = bme280.readTempC();
    dataArray[dataCount++] = bme280.readFloatPressure() / 100.0;
  } else {
    dataArray[dataCount++] = 0.0;
    dataArray[dataCount++] = 0.0;
  }
  
  // 3. Analog pins (A0-A3)
  for (int i = 0; i < 4; i++) {
    dataArray[dataCount++] = (float)analogRead(i);
  }
  
  // 4. ADS1115 differential readings
  // ADS1
  if (ads1Connected) {
    dataArray[dataCount++] = (float)ads1.readADC_Differential_0_1();
    dataArray[dataCount++] = (float)ads1.readADC_Differential_2_3();
  }
  
  // ADS2
  if (ads2Connected) {
    dataArray[dataCount++] = (float)ads2.readADC_Differential_0_1();
    dataArray[dataCount++] = (float)ads2.readADC_Differential_2_3();
  }
  
  // ADS3
  if (ads3Connected) {
    dataArray[dataCount++] = (float)ads3.readADC_Differential_0_1();
    dataArray[dataCount++] = (float)ads3.readADC_Differential_2_3();
  }
  
  // ADS4
  if (ads4Connected) {
    dataArray[dataCount++] = (float)ads4.readADC_Differential_0_1();
    dataArray[dataCount++] = (float)ads4.readADC_Differential_2_3();
  }
}

void writeDataToSD() {
  if (!dataFile || dataCount == 0) return;
  
  // Write each value from the array
  for (int i = 0; i < dataCount; i++) {
    dataFile.print(dataArray[i], 2);
    if (i < dataCount - 1) {
      dataFile.print(",");
    }
  }
  
  dataFile.println();
  dataFile.flush();
}
void initialisation_BME_sensor(){
  bme280.readFloatHumidity();
  bme280.readFloatPressure();
  bme280.readFloatAltitudeMeters();
  bme280.readTempC();
  Serial.print("Humidity: ");
  Serial.print(bme280.readFloatHumidity(), 0);

  Serial.print(" Pressure: ");
  Serial.print(bme280.readFloatPressure());
// float a = mySensor.readFloatPressure();//debugging
// a=a/100;
// int b = (int)a; Serial.print(" b ");
// Serial.print(b);
  Serial.print(" Locally Adjusted Altitude: ");
  Serial.print(bme280.readFloatAltitudeMeters(), 1);
  //Serial.print(mySensor.readFloatAltitudeFeet(), 1);

  Serial.print(" Temp: ");
  Serial.print(bme280.readTempC(), 2);
  //Serial.print(mySensor.readTempF(), 2);

  Serial.println();
  }