# Gemini Web API Router (`gemini.google.com` 사용량 기반 Antigravity 스타일 라우터)

`gemini.google.com` 웹 세션(Google AI Pro/Free 쿼터)을 별도의 유료 Google AI Studio API 키 없이 **Antigravity 브릿지(`http://127.0.0.1:8765/v1`)와 동일한 OpenAI / Anthropic 호환 라우터(`http://127.0.0.1:8766/v1`)**로 변환해 주는 로컬 라우터입니다.

---

## 🔍 활용한 핵심 오픈소스 생태계

1. **[HanaokaYuzu/Gemini-API (`gemini-webapi` v2.1.1+)](https://github.com/HanaokaYuzu/Gemini-API)**
   - `gemini.google.com`의 내부 gRPC-Web / RPC 프로토콜을 역공학한 비동기 Python 라이브러리입니다.
   - `curl_cffi`(`chrome145` TLS 핑거프린트 스푸핑) 기반으로 WAF/봇 탐지를 우회하며, 백그라운드에서 `__Secure-1PSIDTS` 쿠키와 `SNlM0e` 토큰을 자동 갱신합니다.
   - 계정의 실시간 모델 목록(`list_models`), **5시간 윈도우 잔여 크레딧(`current_5h`: 2,400 크레딧)** 및 **주간 잔여 크레딧(`weekly`: 48,380 크레딧)**, 리셋 시각, 계정 상태(`abuse_status`)를 RPC로 직접 조회합니다.
2. **[borisbabic/browser_cookie3](https://github.com/borisbabic/browser_cookie3)**
   - 로컬 Chrome / Edge 브라우저에 로그인된 `.google.com` 쿠키(`__Secure-1PSID`, `__Secure-1PSIDTS`)를 자동으로 추출하여 수동 쿠키 복사 없이 즉시 세션을 초기화합니다.
3. **관련 참고 오픈소스 프로젝트**
   - [FarisHijazi/gemini-web-api](https://github.com/FarisHijazi/gemini-web-api): `gemini-webapi` 기반 OpenAI 호환 래퍼
   - [n0madic/go-gemini-web2api](https://github.com/n0madic/go-gemini-web2api): Go 기반 Gemini Web to OpenAI 프록시

---

## ✨ 주요 아키텍처 및 Antigravity 라우터 기능

- **듀얼 프로토콜 완벽 지원**:
  - OpenAI 호환: `POST http://127.0.0.1:8766/v1/chat/completions` (스트리밍 SSE & 비스트리밍)
  - Anthropic 호환: `POST http://127.0.0.1:8766/v1/messages` (Claude Code / ZCode / OpenCode 호환)
- **실시간 사용량/쿼터 모니터링 및 스마트 라우팅 (`/v1/usage`, `/v1/quota`)**:
  - `gemini.google.com`의 5시간 쿼터(`2,400 크레딧/5h`) 및 주간 쿼터(`48,380 크레딧/주`)를 실시간 추적합니다.
  - 모든 응답 헤더에 `X-Gemini-Remaining-5h`, `X-Gemini-Remaining-Weekly`, `X-Gemini-Resolved-Model`을 포함합니다.
  - 5시간 잔여 크레딧이 25 미만으로 떨어지면 `gemini-4-carbon`/`gemini-4-neon` 요청을 자동으로 경량 `gemini-4-hydrogen`으로 폴백하여 쿼터 고갈을 방지합니다.
- **무상태 임시 채팅 GC (`temporary=True`)**:
  - 모든 API 요청을 임시 채팅(`temporary=True`) 및 완료 즉시 `delete_chat`으로 처리하여 `gemini.google.com` 왼쪽 사이드바 대화 기록이 지저분하게 쌓이지 않습니다.
- **에이전트 도구 호출 (Tool Calling) & 추론 (`reasoning_content`)**:
  - `<aside_tool_call>` 프로토콜 브릿지를 통해 OpenCode / ZCode / Cursor / Aside 에이전트의 `tools` 및 `tool_calls`를 지원합니다.
  - Gemini 웹의 사고 과정(`thoughts` / `thoughts_delta`)을 OpenAI 표준 `reasoning_content` 및 Anthropic `thinking` 블록으로 실시간 스트리밍합니다.

---

## 📋 지원 모델 및 별칭 매핑 (포트 8766)

현재 로그인된 Google AI Pro 웹 계정에서 발견된 최신 Gemini 4 웹 모델 4종과 Antigravity/OpenAI 호환 별칭을 모두 지원합니다:

| 라우터 모델 ID (권장) | `gemini.google.com` 실제 웹 모델 | Hex ID | 기본 Thinking | 용도 및 특징 |
| :--- | :--- | :--- | :---: | :--- |
| `gemini-4-carbon` | **4 카본 (코드 및 복잡한 작업)** | `95a4c0abcba24364` | O | 코딩, 복잡한 설계 (`gemini-2.5-pro`, `gemini-4-argon` 별칭 호환) |
| `gemini-4-neon` | **4 Neon (심층 분석)** | `e6fa609c3fa255c0` | O | 심층 추론 및 복잡한 분석 (`gemini-thinking` 별칭 호환) |
| `gemini-4-hydrogen` | **4 Hydrogen (일상생활 지원)** | `56fdd199312815e2` | X | 초고속 응답 (`gemini-2.5-flash`, `gemini-3.8-flash` 별칭 호환) |
| `gemini-auto` | **자동 모드** | `8c46e95b1a07cecc` | 자동 | 프롬프트 난이도에 따라 Gemini 웹이 자동 라우팅 |

> 각 모델 뒤에 `-low`, `-medium`, `-high`, `-xhigh` 접미사(예: `gemini-4-carbon-high`, `gemini-4-hydrogen-low`)를 붙이면 `extended_thinking` 활성화 여부를 자동으로 제어합니다.

---

## 🚀 실행 및 연동 방법 (어느 컴퓨터에서든 1클릭 자동 실행)

어떤 컴퓨터(Windows / macOS / Linux)에서든 클론 후 **단 한 번의 명령**만으로 Python 패키지 자동 설치, 부팅 시 무콘솔 자동 시작 등록, Aside/OpenCode/ZCode 공급자 등록까지 동일하게 완료됩니다.

### 방법 A. Windows (어느 PC에서나 원클릭 설치 & 부팅 자동 실행 등록)
```cmd
git clone https://github.com/khs0927/Gemini-Web-Router.git
cd Gemini-Web-Router
setup-any-pc.bat
```
*(또는 PowerShell에서 `powershell -ExecutionPolicy Bypass -File .\register-startup.ps1` 실행)*

`setup-any-pc.bat` (`register-startup.ps1`)이 자동으로 수행하는 작업:
1. **동적 경로 및 Python 자동 탐색 (`ensure-router.ps1`)**: 사용자 계정명(`%USERPROFILE%`)이나 클론 위치에 상관없이 현재 폴더(`$PSScriptRoot`)와 시스템 Python 3.11+ 경로를 자동 감지하고, `requirements.txt` 패키지가 없으면 자동으로 설치합니다.
2. **3중 부팅 자동 시작 & 무중단 워치독 등록**:
   - **Windows 시작프로그램 폴더 VBS**: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\gemini-web-api-router.vbs`
   - **레지스트리 자동 시작 (`HKCU\...\Run`)**: `GeminiWebApiRouter` 키 등록
   - **작업 스케줄러 (`Gemini Web API Router`)**: 5분 주기 헬스 체크 및 자동 재기동 워치독 등록 (로컬 Mutex `Local\GeminiWebApiRouterEnsure`로 중복 실행 완벽 방지)
3. **에이전트 공급자 자동 병합**: Aside(`u/0`~`u/3`), OpenCode, ZCode 설정 파일에 `gemini-web` 공급자를 자동 등록합니다.
4. **자동 시작 해제**: `powershell -ExecutionPolicy Bypass -File .\unregister-startup.ps1`

### 방법 B. macOS / Linux (부팅 시 `launchd` / `systemd` 데몬 자동 실행)
```bash
git clone https://github.com/khs0927/Gemini-Web-Router.git
cd Gemini-Web-Router
chmod +x register-startup.sh
./register-startup.sh
```

### 수동 서버 시작 / 중지
- **백그라운드 데몬 보장 실행 (무콘솔)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\ensure-router.ps1
  ```
- **수동 배치 실행 / 중지**:
  - 시작: `start-server.bat` (최소화 실행: `start-server.bat /min`) / `./start-server.sh`
  - 중지: `stop-server.bat` / `./stop-server.sh`

### 2. 실시간 사용량 조회
```bash
curl http://127.0.0.1:8766/v1/usage
```

### 3. OpenCode / ZCode 원클릭 등록
```powershell
# OpenCode 등록 (~/.config/opencode/opencode.json)
powershell -ExecutionPolicy Bypass -File .\configs\setup-opencode.ps1

# ZCode 등록 (~/.zcode/v2/config.json)
powershell -ExecutionPolicy Bypass -File .\configs\setup-zcode.ps1
```
