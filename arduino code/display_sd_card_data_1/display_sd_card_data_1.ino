#include <SPI.h>
#include <SD.h>

const int chipSelect = 10;  // CS pin for SD card
bool sdInitialized = false;

void setup() {
  Serial.begin(9600);
  while (!Serial) {
    ;  // Wait for serial port to connect
  }
  initSDCard();
  Serial.println("Arduino SD Card Interface Ready");
  Serial.println("Commands: LIST, PING, CONNECT, READ <filename>");
}

void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    
    if (command == "LIST") {
      listFiles();
    } 
    else if (command == "PING") {
      Serial.println("PONG");
    }
    else if (command == "CONNECT") {
      initSDCard();
    }
    else if (command.startsWith("READ ")) {
      // Extract filename from command (remove "READ " prefix)
      String filename = command.substring(5);
      readFile(filename);
    }
    else {
      Serial.println("ERROR: Unknown command");
    }
  }
}

void initSDCard() {
  Serial.print("Initializing SD card... ");
  
  if (!SD.begin(chipSelect)) {
    Serial.println("FAILED");
    Serial.println("ERROR: SD card initialization failed!");
    sdInitialized = false;
    return;
  }
  
  Serial.println("SUCCESS");
  sdInitialized = true;
  
  // Print card type
  /*uint8_t cardType = SD.cardType();
  Serial.print("Card type: ");
  
  if (cardType == CARD_NONE) {
    Serial.println("No SD card attached");
    sdInitialized = false;
  } else if (cardType == CARD_MMC) {
    Serial.println("MMC");
  } else if (cardType == CARD_SD) {
    Serial.println("SDSC");
  } else if (cardType == CARD_SDHC) {
    Serial.println("SDHC");
  } else {
    Serial.println("UNKNOWN");
  }
  
  // Print card size
  uint64_t cardSize = SD.cardSize() / (1024 * 1024);
  Serial.print("SD Card Size: ");
  Serial.print(cardSize);
  Serial.println(" MB");
}*/}

void listFiles() {
  if (!sdInitialized) {
    Serial.println("ERROR: SD card not initialized. Send CONNECT command first.");
    return;
  }
  
  Serial.println("START_FILE_LIST");
  
  File root = SD.open("/");
  if (!root) {
    Serial.println("ERROR: Failed to open root directory");
    return;
  }
  
  if (!root.isDirectory()) {
    Serial.println("ERROR: Not a directory");
    root.close();
    return;
  }
  
  File entry = root.openNextFile();
  int fileCount = 0;
  
  while (entry) {
    if (entry.isDirectory()) {
      Serial.print("DIR: ");
    } else {
      Serial.print("FILE: ");
      fileCount++;
    }
    
    Serial.print(entry.name());
    
    if (!entry.isDirectory()) {
      Serial.print(" (");
      Serial.print(entry.size());
      Serial.println(" bytes)");
    } else {
      Serial.println(" [DIR]");
    }
    
    entry.close();
    entry = root.openNextFile();
  }
  
  root.close();
  Serial.println("END_FILE_LIST");
  Serial.print("Total files found: ");
  Serial.println(fileCount);
}

void readFile(String filename) {
  if (!sdInitialized) {
    Serial.println("READ_ERROR: SD card not initialized");
    return;
  }
  
  // Check if it's a directory (skip "DIR:" prefix if present)
  String cleanFilename = filename;
  if (cleanFilename.startsWith("FILE: ")) {
    cleanFilename = cleanFilename.substring(6);
  }
  
  // Try to open the file
  File file = SD.open(cleanFilename);
  if (!file) {
    Serial.println("READ_ERROR: File not found - " + cleanFilename);
    return;
  }
  
  if (file.isDirectory()) {
    Serial.println("READ_ERROR: Cannot read directory - " + cleanFilename);
    file.close();
    return;
  }
  
  Serial.println("START_FILE_CONTENT");
  Serial.println("File: " + cleanFilename);
  Serial.println("Size: " + String(file.size()) + " bytes");
  Serial.println("--- Content ---");
  
  // Read and send file content line by line
  while (file.available()) {
    String line = file.readStringUntil('\n');
    if (line.length() == 0 && !file.available()) break; // End of file
    
    // Replace any problematic characters and send
    line.replace("\n", "");
    line.replace("\r", "");
    
    // Send line with prefix
    Serial.println("FILE_CONTENT:" + line);
    
    // Small delay to prevent overwhelming the serial buffer
    delay(10);
  }
  
  file.close();
  Serial.println("--- End of Content ---");
  Serial.println("END_FILE_CONTENT");
}