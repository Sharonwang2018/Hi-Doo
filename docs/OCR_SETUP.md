# 绘本拍照 OCR 配置说明

## 功能概述

- **本地识别**：PaddleOCR (PP-OCR) 离线识别，支持 Android/iOS
- **预处理**：透视矫正 + 二值化（移动端 OpenCV，Web 用 image 包）
- **段落结构**：按 Y 坐标排序，保持原有段落，不合并成一行
- **置信度补偿**：本地置信度 < 80% 时自动调用 Azure AI Vision Read API

## 运行平台

| 平台 | PaddleOCR | 预处理 | 补偿 |
|------|-----------|--------|------|
| Android | ✅ | OpenCV | Azure |
| iOS | ✅ | OpenCV | Azure |
| Web | ❌ | image 包二值化 | Azure 或后端 OpenRouter 视觉 |

**注意**：PaddleOCR 仅支持 Android/iOS。Web 需配置 Azure 或后端 `OPENROUTER_API_KEY`（见 docs/DOUBAO_SETUP.md）。

## 配置项

### 1. Azure AI Vision（可选，用于置信度补偿或 Web）

1. 创建 [Computer Vision 资源](https://portal.azure.com/#create/Microsoft.CognitiveServicesComputerVision)
2. 获取 Endpoint 和 Key
3. 启动时传入：

```bash
--dart-define=AZURE_VISION_ENDPOINT=https://xxx.cognitiveservices.azure.com \
--dart-define=AZURE_VISION_KEY=你的Key
```

### 2. 后端 OpenRouter 视觉（推荐，Web 或 Azure 不可用时）

配置后端 `OPENROUTER_API_KEY` 与可选 `OPENROUTER_VISION_MODEL`，见 docs/DOUBAO_SETUP.md。客户端在配置了 API_BASE_URL 时会自动走 `/api/vision`。

### 3. PaddleOCR 模型

paddle_ocr 插件自带模型，首次运行会自动下载。若需 PP-OCRv4，需自行替换插件内模型文件（需修改原生插件）。

## 流程说明

1. 拍摄照片 → 预处理（透视矫正 + 二值化）
2. PaddleOCR 识别 → 按 Y 坐标排序，保持段落
3. 若平均置信度 < 80% 且配置了 Azure → 调用 Azure Read
4. 若 Web 或 PaddleOCR 失败 → Azure 或后端 OpenRouter 视觉

## 测试建议

- Android/iOS：在真机或模拟器运行 `flutter run`
- Web：需配置 Azure 或后端 OPENROUTER_API_KEY，否则 OCR 会失败
