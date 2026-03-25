# 常见问题

## 扫码页面黑屏

手机通过 HTTP 访问时，浏览器出于安全策略不允许使用相机（`getUserMedia` 需要 HTTPS）。

**解决**：用 HTTPS 访问，见下方「存书 Load failed」的 ngrok 或 mkcert 方案。

## `ClientException: Load failed` / 存不了书

iPhone 访问自签名证书（`https://10.0.0.138:3000`）时，页面能打开但 `fetch` 请求常被拒绝，导致扫码可 succeed、存书失败。

### 方案一：ngrok（推荐，最快）

无需在手机上安装证书：

1. 安装 ngrok：`brew install ngrok` 或从 https://ngrok.com 下载
2. 终端 1 启动服务：`./run_all.sh`（或 `cd api && HTTPS=1 npm start`）
3. 终端 2 运行：`./scripts/run_with_ngrok.sh`
4. 手机浏览器访问 ngrok 输出的 `https://xxx.ngrok-free.app`（扫码和存书均可用）

### 方案二：mkcert + iPhone 信任证书

1. Mac 上：`brew install mkcert && mkcert -install`
2. 重新生成证书：`./scripts/gen_certs.sh`
3. 将 mkcert 根证书传到 iPhone：`open $(mkcert -CAROOT)`，用 AirDrop 发送 `rootCA.pem` 到手机
4. iPhone 上：点击 `rootCA.pem` 安装描述文件 → 设置 → 通用 → 关于本机 → 证书信任设置 → 启用该根证书
5. 手机访问 `https://10.0.0.138:3000`

### 其他检查

- 确认 API 已启动，手机与电脑在同一 WiFi
- `10.0.0.138` 需为本机局域网 IP（`ipconfig getifaddr en0` 查看）

## 复述后看不到「AI老师正在审阅」和「老师批阅」

**条件**：只有**已登录**且录音后**有识别出的复述文字**时，才会先出现「AI老师正在审阅」遮罩，再弹出「老师批阅」对话框（文字 + 语音）。

- 未登录：结束录音后只会播鼓励语并跳转完成页，不会出现批阅；可点右上角登录后再录一遍。
- 未识别到内容：会提示「未识别到复述内容…」。
- 若确认已登录且能识别到文字仍看不到：请用**最新构建**再测（重新执行 `./run_all.sh`，浏览器强刷或清除缓存后访问）。

## 怎么清除记录、重启测试？

### 1. 只清本地（重新登录 / 换账号）

- **App 内**：在「我的」或设置里**退出登录**，会清除本地 JWT，再登录即重新开始。
- **Web**：退出登录后，如需彻底清空本站数据，可打开开发者工具 → Application → Storage → Clear site data（或只删 Local Storage）。
- **手机 App**：设置 → 应用 → EchoReading / 绘读 → 清除数据（会同时清掉登录态和本地缓存）。

### 2. 清服务端阅读记录（数据库）

书籍和阅读记录存在后端 PostgreSQL。测试时若要「从零开始」：

- 确保 `api/.env` 里配置了 `DATABASE_URL`（或使用默认 `postgresql://localhost:5432/echo_reading`）。
- 在项目根目录或 `api` 目录执行（按需二选一）：

**只清空阅读记录（保留书籍和用户）：**

```bash
cd api && node -e "
const { query } = await import('./db.js');
await query('DELETE FROM read_logs');
console.log('read_logs 已清空');
process.exit(0);
"
```

**连书籍一起清空（用户与阅读记录都清）：**

```bash
cd api && node -e "
const { query } = await import('./db.js');
await query('DELETE FROM read_logs');
await query('DELETE FROM books');
console.log('read_logs 与 books 已清空');
process.exit(0);
"
```

- 若有 `psql`，也可直接连库执行：`psql $DATABASE_URL -c "DELETE FROM read_logs;"`

### 3. 完整重启测试流程建议

1. （可选）按上面步骤清空服务端 `read_logs` / `books`。
2. App 内退出登录（或清除应用数据）。
3. 重启后端：在 `api` 目录执行 `npm start`，或重新跑 `./run_all.sh`。
4. 重新打开/刷新页面，登录后再扫码、存书、复述，即可从干净状态测试。
