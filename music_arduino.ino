// 設定列（Row）與行（Column）腳位對應 LED 矩陣的控制腳位
int R[] = {2, 7, A5, 5, 13, A4, 12, A2};  
int C[] = {6, 11, 10, 3, A3, 4, 8, 9};    

int heights[8] = {0}; // 用來儲存 8 欄柱狀圖的高度
String inputString = ""; // 暫存從序列埠接收到的字串

void setup() {
  Serial.begin(9600); // 啟動序列通訊，設定為 9600 baud rate

  // 設定所有 R 與 C 腳位為輸出模式
  for (int i = 0; i < 8; i++) {
    pinMode(R[i], OUTPUT);
    pinMode(C[i], OUTPUT);
  }

  clearAll();  // 開機時關閉所有 LED 燈
}

void loop() {
  readSerialData();    // 持續監聽是否有新的序列資料進來
  displayBars();       // 根據目前 heights[] 顯示柱狀圖
}

// 讀取序列埠輸入的字串，例如 "3,5,1,8,0,2,7,4"
void readSerialData() {
  if (Serial.available()) {
    inputString = Serial.readStringUntil('\n'); // 讀取直到換行符號的字串
    parseInput(inputString); // 將字串解析為整數並存入 heights[]
  }
}

// 將以逗號分隔的資料字串轉換為整數陣列
void parseInput(String data) {
  int lastComma = 0;

  data.trim();  // 移除前後空白或換行符號

  for (int i = 0; i < 8; i++) {
    int commaIndex = data.indexOf(',', lastComma); // 找到下一個逗號位置
    if (commaIndex == -1 && i < 7) return;  // 如果資料不足 8 個數值，直接退出
    // 根據是否為最後一個數值，取得對應的子字串
    String value = (i == 7) ? data.substring(lastComma) : data.substring(lastComma, commaIndex);
    heights[i] = constrain(value.toInt(), 0, 8);  // 將值限制在 0～8 之間
    lastComma = commaIndex + 1; // 更新下一次搜尋的起始位置
  }
}

// 根據 heights[] 不斷更新 LED 顯示柱狀圖
void displayBars() {
  for (int col = 0; col < 8; col++) { // 對每一欄
    for (int row = 0; row < heights[col]; row++) { // 顯示對應高度
      lightLED(7 - row, col);  // 注意：第0列在最上面，第7列在最下面
      delayMicroseconds(300);  // 給短暫的時間讓 LED 顯示，不然會閃爍
      clearAll();              // 清除全部 LED，避免殘影
    }
  }
}

// 點亮特定一顆 LED
void lightLED(int row, int col) {
  digitalWrite(R[row], HIGH);  // 將對應列設為高電位
  digitalWrite(C[col], LOW);   // 將對應行設為低電位 → 點亮交叉點的 LED
}

// 關閉所有 LED
void clearAll() {
  for (int i = 0; i < 8; i++) {
    digitalWrite(R[i], LOW);   // 所有列關閉
    digitalWrite(C[i], HIGH);  // 所有行拉高 → LED 熄滅
  }
}
