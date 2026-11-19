# Gemini Web API Router (`gemini.google.com` 사용량 기반 Antigravity 스타일 라우터) 운영 메모리 및 통합 지침 (2026-11-19 기준)

- **GitHub 저장소**: `https://github.com/khs0927/Gemini-Web-Router`
- **로컬 워크스페이스 경로**: `C:\Users\USER\.gemini\antigravity\scratch\Gemini-Web-Router`
- **Google Drive 백업 경로**: `G:\내 드라이브\Gemini-Web-Router`
- **라우터 엔드포인트**: `http://127.0.0.1:8766/v1` (OpenAI `/v1/chat/completions`, Anthropic `/v1/messages`, 실시간 쿼터 `/v1/usage`)

---

## 1. 아키텍처 및 핵심 오픈소스 구성

1. **`gemini-webapi` (v2.1.1+, `HanaokaYuzu/Gemini-API`)**:
   - `gemini.google.com`의 비공개 gRPC-Web / RPC 프로토콜 비동기 클라이언트.
   - `curl_cffi` (`chrome145` TLS 핑거프린트 스푸핑)로 WAF 및 봇 차단을 우회하고 백그라운드에서 `__Secure-1PSIDTS` 및 `SNlM0e` 토큰을 10분 주기로 자동 갱신.
   - 계정의 실시간 모델 목록(`list_models`), **5시간 윈도우 크레딧(`2,400 크레딧/5h`)**, **주간 크레딧(`48,380 크레딧/주`)**, 리셋 시각, 계정 상태(`abuse_status`)를 RPC로 직접 조회.
2. **`browser_cookie3`**:
   - 로컬 Chrome / Edge 브라우저의 `.google.com` 쿠키를 자동 추출하여 별도 API 키나 수동 쿠키 입력 없이 즉시 인증.
3. **무상태 임시 세션 GC (`temporary=True` + `delete_chat`)**:
   - 모든 요청을 임시 대화로 생성 및 완료 즉시 삭제하여 `gemini.google.com` 대화 목록에 세션이 누적되지 않음.

---

## 2. Aside에서 Gemini Web 모델 호출 시 "도구 호출 한도 0" 현상 원인 및 해결 내역 (v1.1.0)

### 원인 진단 (`2026-11-19_9rMCs4LukvccM8L3` 세션 분석)
1. **스트리밍 청크 분할 시 `<aside_tool_call>` 누락 버그**:
   - Aside 에이전트는 기본적으로 `stream: true`로 요청을 보냄.
   - `v1.0.0`의 단순 문자열 포함 검사(`if "<aside_tool_call" in accumulated_text`)에서는 모델이 `<aside_`와 `tool_call>`을 서로 다른 네트워크 청크로 나누어 스트리밍할 때 앞 조각(`<aside_`)이 일반 텍스트로 먼저 유출되거나, 닫는 태그 이후 `finish_reason: "tool_calls"`가 정상 전달되지 않는 문제가 있었음.
2. **초대형 시스템 프롬프트에서의 Recency Bias 및 도구 권한 오인**:
   - Aside가 수만 자의 시스템 프롬프트와 히스토리를 평문으로 보낼 때, `gemini.google.com` 웹 모델(`gemini-4-hydrogen`)이 자신이 웹 챗봇 환경에 있다고 착각하여 `"현재 턴에서는 도구 호출 한도가 0으로 제한되어 있어 조회할 수 없습니다"`라고 응답하며 도구 호출을 포기하는 현상 발생.

### 해결 조치 (`router.py` v1.1.0)
1. **XML 섹션 기반 Modern Agent Mode 프롬프트 구조화**:
   - `<system>`, `<tools>`, `<recent>`, `<current_task>`, `<output_rules>` 구조로 프롬프트를 명확히 분리하고, 마지막 사용자 요청을 `<current_task>`에 배치(Recency Anchor).
   - `<system>` 상단에 `"Your tool call quota is NOT 0. You have unlimited tool calls available right now. NEVER claim that tool calls are disabled or exhausted."` 오버라이드 지침을 명시.
2. **Antigravity 브릿지(`agy-bridge.js`)와 동일한 슬라이딩 윈도우 홀드백 스트리밍 파서 탑재**:
   - `longest_tag_prefix_suffix()` 및 `find_tool_tag_start()`를 구현하여 `<aside_tool_call` 또는 `<<<TOOL_CALL`의 접두사 조각이 청크 경계에 걸치더라도 절대 일반 텍스트로 유출되지 않고 홀드백 버퍼에서 안전하게 대기한 뒤 표준 OpenAI SSE `delta.tool_calls` + `finish_reason: "tool_calls"`로 변환되도록 수정 완료.
3. **관용적(Tolerant) 도구 JSON 파서**:
   - `<aside_tool_call>`뿐 아니라 `<<<TOOL_CALL>>>`, 마크다운 코드펜스(` ```json `) 감싸기, 대체 키(`tool`/`parameters`/`args`)까지 모두 표준 OpenAI `tool_calls`로 자동 정규화.

---

## 3. 지원 모델 및 매핑 표 (포트 `8766`)

| 라우터 모델 ID | `gemini.google.com` 실제 모델 | 내부 Hex ID | 기본 Thinking | 호환 별칭 |
| :--- | :--- | :--- | :---: | :--- |
| **`gemini-4-carbon`** | **4 카본 (코드 및 복잡한 작업)** | `95a4c0abcba24364` | O | `gemini-2.5-pro`, `gemini-4-argon`, `gemini-pro` |
| **`gemini-4-neon`** | **4 Neon (심층 분석)** | `e6fa609c3fa24364` / `e6fa609c3fa255c0` | O | `gemini-thinking`, `gemini-deep-research` |
| **`gemini-4-hydrogen`** | **4 Hydrogen (일상생활 지원)** | `56fdd199312815e2` | X | `gemini-2.5-flash`, `gemini-3.8-flash`, `gemini-flash` |
| **`gemini-auto`** | **자동 모드** | `8c46e95b1a07cecc` | 자동 | `auto`, `gemini-자동-모드` |

---

## 4. 전 구간 연동 현황

1. **Aside (`u/0`, `u/1`, `u/2`, `u/3`)**:
   - `models.json` 내 `providers["gemini-web"]` (`http://127.0.0.1:8766/v1`) 등록 완료.
2. **Claude Code (`aside-models` MCP & 서브에이전트)**:
   - `C:\Users\USER\.local\bin\aside-models-mcp.mjs`: `provider="gemini-web"` (별칭 `geminiweb`, `gweb`) 등록 완료.
   - `C:\Users\USER\.local\bin\openai-bridge.mjs` (포트 `8791`): `gemini-web/*` 다이렉트 프록시 연결 완료.
   - `C:\Users\USER\.claude\agents\gemini-web-agent.md` 및 `C:\Users\USER\.claude\CLAUDE.md` 등록 완료.
3. **OpenCode & ZCode**:
   - `gemini-web-local` 공급자 자동 병합 완료 (`configs/setup-opencode.ps1`, `configs/setup-zcode.ps1`).
4. **부팅 시 자동 시작 & 멀티 PC 포터블 설치 (`setup-any-pc.bat` / `register-startup.ps1` / `register-startup.sh`)**:
   - **어느 컴퓨터에서든 동일 동작**: 하드코딩된 경로 없이 `$PSScriptRoot` 상대 경로와 동적 Python 탐색(`Find-PythonExe`) 및 `requirements.txt` 자동 부트스트랩을 수행.
   - **Windows 4중 자동 기동 보장**:
     1. Windows 시작프로그램 폴더: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\gemini-web-api-router.vbs`
     2. Windows 레지스트리 Run 키: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\GeminiWebApiRouter`
     3. Windows 작업 스케줄러: `Gemini Web API Router` (5분 주기 워치독)
     4. 통합 라우터 런처: `C:\Users\USER\.gemini\antigravity\scratch\Unified-API-Routers\start-unified-routers.ps1` 9번 항목
   - **macOS / Linux 지원**: `register-startup.sh`를 통해 macOS `launchd` (`~/Library/LaunchAgents/com.antigravity.gemini-web-router.plist`) 및 Linux `systemd --user` 서비스 자동 등록.
