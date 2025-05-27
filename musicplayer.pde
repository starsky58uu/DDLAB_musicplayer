// 匯入 Minim 音訊函式庫與其頻譜分析模組
import ddf.minim.analysis.*;
import ddf.minim.*;
import processing.serial.*;

Serial myPort;

// 宣告 Minim 物件與播放器
Minim minim;  
AudioPlayer jingle;

// 宣告 FFT 物件（線性與對數）
FFT fftLin;
FFT fftLog;

// 頻譜區畫面分界用變數（1/3、2/3 高度）
float height3;
float height23;

// 頻譜視覺化比例係數
float spectrumScale = 2.0;

// 儲存平滑處理後的頻譜值
float[] smoothedValues;

// 儲存每個頻率對應的 A-weighting 權重值
float[] aWeights;

// 每個長條的寬度（依據視窗與頻段數自動調整）
int smallRectWidth;

// 文字顯示字型
PFont font;

void setup()
{
  // 設定畫面大小
  size(512, 480);

  // 計算畫面高度的 1/3 與 2/3，用於視覺分區
  height3 = height / 3;
  height23 = 2 * height / 3;

  // 建立 Minim 音訊系統
  minim = new Minim(this);
  
  // 載入音樂檔案，並設定 FFT 緩衝區大小（須為 2 的次方）
  jingle = minim.loadFile("music.mp3", 1024);
  
  // 設定為無限循環播放
  jingle.loop();
  
  // 初始化線性頻譜分析（FFT）物件
  fftLin = new FFT(jingle.bufferSize(), jingle.sampleRate());
  
  // 將線性頻率平均分為 30 組（低頻較清晰）
  fftLin.linAverages(8);
  
  // 初始化對數頻譜分析 FFT（更貼近人耳感知）
  fftLog = new FFT(jingle.bufferSize(), jingle.sampleRate());
  
  // 對數頻段設定：從 22Hz 起，每個八度分為 3 段
  fftLog.logAverages(22, 3);
  
  // 設定長方形繪圖模式為兩角模式
  rectMode(CORNERS);
  
  // 建立字型物件，用系統內建 Arial 字型
  font = createFont("Arial", 12);
  
  // 計算每一條頻譜條的寬度
  smallRectWidth = width / fftLog.avgSize();
  
  // 計算 A-weighting 權重（模擬人耳聽覺靈敏度）
  aWeights = frequencyWeights(jingle.bufferSize());
  
  // 初始化平滑頻譜陣列
  smoothedValues = new float[fftLog.avgSize()];
  
  String portName = Serial.list()[0]; // 依據實際情況選擇 Serial port
  myPort = new Serial(this, portName, 9600);
}

void draw()
{
  // 清除背景（黑色）
  background(0);
  
  // 設定文字字型與大小
  textFont(font);
  textSize(18);
 
  // 中心頻率暫存變數
  float centerFrequency = 0;
  
  // 對混合聲道進行 FFT 頻譜轉換
  fftLin.forward(jingle.mix);
  fftLog.forward(jingle.mix);

  // 開始繪製對數平均的頻譜圖
  for (int i = 0; i < fftLog.avgSize(); i++)
  {
    // 取得第 i 頻段的中心頻率與頻寬
    centerFrequency = fftLog.getAverageCenterFrequency(i);
    float averageWidth = fftLog.getAverageBandWidth(i);

    // 計算每個長條的左右邊界 X 座標
    int xShowL = -16 + i * smallRectWidth;
    int xShowR = -16 + i * smallRectWidth + smallRectWidth;

    // 將中心頻率轉換成 fft 索引，用以查詢權重
    int fftIndex = fftLin.freqToIndex(centerFrequency);
    fftIndex = constrain(fftIndex, 0, aWeights.length - 1);

    // 取得頻段強度，乘上 A-weighting 權重
    float rawValue = fftLog.getAvg(i) * aWeights[fftIndex];

    // 避免頻譜值為 0（完全靜音）導致長條不顯示
    rawValue = max(rawValue, 0.3);
    
    // 使用線性插值進行平滑過渡（靈敏度可調整）
    smoothedValues[i] = lerp(smoothedValues[i], rawValue, 0.3);
    
    // 將原始值轉為畫面高度（並依比例縮放）
    float barHeight = smoothedValues[i] * spectrumScale / 1000.0;

    // 滑鼠懸停在此頻段上方時顯示資訊
    if (mouseX >= xShowL && mouseX < xShowR)
    {
      // 半透明灰底
      fill(255, 128);
      // 顯示中心頻率資訊
      text("對數平均中心頻率: " + centerFrequency, 5, height - 25);
      // 強調此長條為紅色
      fill(255, 0, 0);
    }
    else
    {
      // 一般顏色為白色
      fill(0);
    }

    // 繪製頻譜條
    drawRects(xShowL, height, xShowR, height - barHeight);
  }
  // 每次 draw 傳送 8 個頻段給 Arduino
  int totalBands = fftLog.avgSize(); // 目前是 30
  int bandsPerGroup = totalBands / 8;

  String output = "";

  for (int i = 0; i < 8; i++) {
    float sum = 0;
    for (int j = 0; j < bandsPerGroup; j++) {
      int idx = i * bandsPerGroup + j;
      sum += smoothedValues[idx];
      sum /= 60000;
print(sum);
print("\n");
}
    float avg = sum / bandsPerGroup;
    int mapped = int(map(avg, 0, 5, 0, 100)); // 轉成 0–100 間的整數
    output += mapped;
    if (i < 7) output += ",";
}

print(output);

  if (output != null && output.length() > 0) {
    myPort.write(output + "\n");
}

}

// ===== 工具函數區 =====

// 計算 A-weighting 權重表，用以模擬人耳對不同頻率的感知強度
float[] frequencyWeights(int fftSize) {
  float af = 44100.0 / float(fftSize);
  int bins = fftSize / 2;
  float[] f = new float[bins];

  for (int i = 0; i < bins; i++) {
    f[i] = float(i) * af;
    f[i] = f[i] * f[i];
  }

  float c1 = pow(12194.217, 2.0);
  float c2 = pow(20.598997, 2.0);
  float c3 = pow(107.65265, 2.0);
  float c4 = pow(737.86223, 2.0);

  float[] num = new float[bins];
  for (int i = 0; i < bins; i++) {
    num[i] = c1 * f[i] * f[i];
  }

  float[] den = new float[bins];
  for (int i = 0; i < bins; i++) {
    den[i] = (f[i] + c2) * sqrt((f[i] + c3) * (f[i] + c4) * (f[i] + c1));
  }

  float[] weights = new float[bins];
  for (int i = 0; i < bins; i++) {
    weights[i] = 1.2589 * num[i] / den[i];
  }

  return weights;
}

// 畫出條狀頻譜（使用一格一格小矩形堆疊）
void drawRects(int x1, float ymax, int xr, float ymin) {
  int gap1 = 1; // 長條間隔
  int xlnew = x1;
  int xrnew = xr - gap1;

  stroke(2);
  fill(25, 181, 254); // 藍色

  for (int i = int(ymax); i > int(ymin); i -= 5) {
    rect(xlnew, i, xrnew, i + 4); // 每格高度約 5 像素
  }
}
