# OpenPaper 本地配置说明

本文档记录当前仓库在本机上的运行约定，方便后续继续开发或排障。

## 1. 整体架构

- `client`：Next.js 前端，开发端口 `3000`
- `server`：FastAPI 主后端，端口 `8000`
- `jobs`：FastAPI + Celery 任务服务，端口 `8001`
- 依赖组件：
  - PostgreSQL
  - RabbitMQ
  - Redis
  - Cloudflare R2（S3 兼容对象存储）
  - OpenAI API

## 2. 当前默认行为

- 认证：
  - 开发环境已开启默认登录旁路
  - 未登录时会自动使用 `suchunsv@gmail.com`
- LLM：
  - `server` 默认 provider 已切到 `openai`
  - `jobs` 默认 provider 也已切到 `openai`
- 前端监听：
  - `0.0.0.0:3000`
- 后端监听：
  - `0.0.0.0:8000`
- jobs 监听：
  - `0.0.0.0:8001`

## 3. R2 配置约定

当前代码区分三类地址：

- `S3_ENDPOINT_URL`
  - R2 API 入口
  - 用于后端/任务服务通过 S3 协议上传和下载文件
- `S3_BUCKET_NAME`
  - R2 中真实 bucket 名
- `CLOUDFLARE_BUCKET_NAME`
  - 对外公开访问文件时使用的 host
  - 例如 `pub-xxxx.r2.dev`

注意：

- 之前验证过，当前环境可用的 R2 API endpoint 形态是：
  - `https://<account-id>.r2.cloudflarestorage.com`
- 不是：
  - `https://<account-id>.eu.r2.cloudflarestorage.com`

## 4. PDF 预览策略

前端 PDF 预览目前不再直接使用跨域 R2 presigned URL。

原因：

- `pdf.js` 会发 `Range` 请求
- 浏览器会触发 CORS / preflight
- R2 对该跨域场景容易出现 `Failed to fetch`

当前处理方式：

- 后端返回同源 PDF 地址：
  - `/api/paper/{id}/content`
- 由 `server` 代理读取 R2 内容并转发 `Range` 响应

这样前端加载 PDF 不再依赖浏览器直接跨域访问 R2。

## 5. Cloudflare Tunnel 约定

若使用同一域名同时暴露前端和后端，建议按路径分流：

- `/api/*` -> `server:8000`
- 其他路径 -> `client:3000`

典型 `cloudflared` ingress 结构：

```yaml
ingress:
  - hostname: openpaper.suchunsv.org
    path: /api/*
    service: http://127.0.0.1:8000

  - hostname: openpaper.suchunsv.org
    service: http://127.0.0.1:3000

  - service: http_status:404
```

## 6. 启动方式

### server

```bash
cd server
uv sync
uv run start
```

### jobs

```bash
cd jobs
uv sync
./scripts/start.sh
```

### client

```bash
cd client
yarn install
yarn dev
```

## 7. 关键环境变量

### `server/.env`

至少需要：

- `DATABASE_URL`
- `OPENAI_API_KEY`
- `DEFAULT_LLM_PROVIDER=openai`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION=auto`
- `S3_BUCKET_NAME`
- `CLOUDFLARE_BUCKET_NAME`
- `S3_ENDPOINT_URL`
- `CELERY_BROKER_URL`
- `CELERY_API_URL`
- `WEBHOOK_BASE_URL`

### `jobs/.env`

至少需要：

- `DEFAULT_LLM_PROVIDER=openai`
- `OPENAI_API_KEY`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION=auto`
- `S3_BUCKET_NAME`
- `CLOUDFLARE_BUCKET_NAME`
- `S3_ENDPOINT_URL`
- `CELERY_BROKER_URL`
- `CELERY_RESULT_BACKEND`

### `client/.env.local`

建议：

- `NEXT_PUBLIC_API_URL=https://openpaper.suchunsv.org`

如果走同域 `/api` 反代，也可以改成同源策略，但当前配置仍兼容显式 API 域名。

## 8. 已知说明

- `STRIPE_API_KEY` 未配置时，订阅接口不可用，但不会阻止本地启动
- `POSTHOG_API_KEY` 未配置时，埋点会自动禁用
- `Resend` / 邮箱验证码未配置时，邮件登录不可用；开发环境默认依赖自动登录旁路

## 9. 提交约定

- 不要提交：
  - `server/.env`
  - `jobs/.env`
  - `client/.env.local`
- 只提交：
  - `.env.example`
  - 代码改动
  - 本文档
