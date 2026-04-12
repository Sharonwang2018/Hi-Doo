# AI 与语音配置说明

**文本**对话与点评支持 **火山方舟（豆包）** 或 **OpenRouter**（二选一即可，**豆包优先**：若同时配置 `ARK_*` 与 `OPENROUTER_*`，后端走豆包）。应用内**已无**「拍照读页 / 页面 OCR」流程。  
**TTS、语音转写** 仍使用 **OpenAI**（或 Web 端降级为浏览器语音）。

---

## 方案 A：火山方舟 / 豆包（推荐国内用户）

在 [火山引擎控制台](https://console.volcengine.com/ark) 开通「火山方舟」，创建 API Key，并为模型创建**推理接入点**（得到 `ep-xxxx` 形式的 ID）。

在 `server/.env` 中配置：

```bash
ARK_API_KEY=你的方舟API_Key
# 对话与点评用（文本模型接入点）
ARK_ENDPOINT_ID=ep-xxxx
# 遗留：若后端仍保留视觉 env，可单独配置（当前 App 不调用页面拍照识别）
# ARK_VISION_ENDPOINT_ID=ep-yyyy
# 可选：点评单独用；不填则与 ARK_ENDPOINT_ID 相同
# ARK_CHAT_ENDPOINT_ID=ep-xxxx
# 可选，默认北京：https://ark.cn-beijing.volces.com/api/v3
# ARK_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
```

- 接口与 OpenAI Chat Completions 兼容，后端会请求 `{ARK_BASE_URL}/chat/completions`。
- 当前产品仅需**文本**模型接入点即可支撑引导题与点评。
- 未配置 `ARK_*` 时自动回退到下面的 OpenRouter。

---

## 方案 B：OpenRouter（海外或已有 key）

用于 **AI 引导问题**、**AI 点评**（及后端若仍存在的其他文本 LLM 调用）：

```bash
OPENROUTER_API_KEY=sk-or-v1-xxxx   # https://openrouter.ai
# OPENROUTER_MODEL=openrouter/free
# OPENROUTER_VISION_MODEL=openrouter/free
```

---

## 朗读 TTS：豆包语音（推荐国内）或 OpenAI

**优先豆包语音**（自然度更好，与方舟 key 不同，需在[豆包语音控制台](https://console.volcengine.com/speech)按文档取 appid/token/cluster）：

```bash
VOLC_TTS_APP_ID=你的appid
VOLC_TTS_ACCESS_TOKEN=控制台access_token
# 与上一行二选一：新版控制台「API Key」可填在 VOLC_TTS_API_KEY，后端会当作 token 使用（仍须配 APP_ID）
# VOLC_TTS_API_KEY=
VOLC_TTS_CLUSTER=volcano_tts
# 可选音色，默认 BV700_streaming，见文档「发音人参数列表」
# VOLC_TTS_VOICE_TYPE=BV700_streaming
```

鉴权与接口说明（与本项目后端一致）：大模型 HTTP 非流式见 [1257584](https://www.volcengine.com/docs/6561/1257584)（与旧版 [79820](https://www.volcengine.com/docs/6561/79820) 同一 URL `openspeech.bytedance.com/api/v1/tts`）。后端对 `BV*` 精品音色仍传 `language`，其余音色传大模型 `explicit_language`；可选 `VOLC_TTS_MODEL=seed-tts-1.1`。部分「语音合成 2.0」音色仅支持 V3 接口，见 1257584 文内说明。

**与「豆包语音合成模型 2.0」控制台的关系：** 快捷接入里若指向 [完整调用指南 WebSocket 双向流式-V3](https://www.volcengine.com/docs/6561/1329505)，那是 **WebSocket** 协议，**不是**上面这条 HTTP POST。若你购买/开通的是 2.0 资源，请到文档树 **语音合成大模型** 下查找与 HTTP 兼容的说明（例如同目录下的 [HTTP Chunked/SSE 单向流式-V3](https://www.volcengine.com/docs/6561/1598757)、或 [HTTP 一次性合成（大模型侧文档）](https://www.volcengine.com/docs/6561/1257584)），按其中的 **cluster、voice_type、鉴权** 填入 `VOLC_TTS_*`；仍不匹配时需改 `server/routes/tts.js` 以对接新接口。控制台 **字数包仍为 0** 时，常见原因是请求实际打在旧版「在线合成」或 OpenAI 回退上，未计入 2.0 实例。

未配置豆包 TTS 时，**回退 OpenAI**：

```bash
OPENAI_API_KEY=sk-xxxx   # https://platform.openai.com
```

- **TTS**：`/api/tts` 先豆包后 OpenAI；都失败时 App 降级浏览器/设备朗读。
- **转写**：`/api/transcribe` 仍用 Whisper，需 `OPENAI_API_KEY`。

---

## 启动与自测

```bash
# 示例：仅豆包 + OpenAI
export ARK_API_KEY=...
export ARK_ENDPOINT_ID=ep-...
export OPENAI_API_KEY=sk-...
./run_all.sh
```

访问 `GET /api/status` 可查看 `llm_chat`、`llm_vision` 当前为 `ark` 还是 `openrouter`。

## 流式「边说边识别」

当前仅支持**浏览器语音识别**（Web Speech API）。录音结束后的转写走 OpenAI Whisper。

## 常见问题

- **引导问题/点评失败**：检查 `ARK_*` 或 `OPENROUTER_API_KEY`，以及 `/api/chat` 是否 200。
- **历史**：若自行恢复页面 OCR，视觉接入点须为多模态模型；当前发行版不包含该路径。
- **题目/点评播放不了**：检查 `OPENAI_API_KEY` 与 `/api/tts`。
- **转写失败**：确认 `OPENAI_API_KEY` 与 `/api/transcribe`；Web 建议 WebM/Opus。
