# Time Persona 鍓嶇 API 鎺ュ叆鏂囨。

鏈€鍚庢洿鏂帮細2026-04-08

## 1. 姒傝堪

鏈枃妗ｆ弿杩颁簡鍓嶇濡備綍鎺ュ叆鍚庣 Time Persona Backend API銆傚凡瀹屾垚鐨勬帴鍏ョ偣浣嶄簬 `entry/src/main/ets/service/PersonaApi.ets`銆?
## 2. 鍚庣鏈嶅姟鍦板潃

### 绾夸笂鏈嶅姟锛堝凡鎺ュ叆锛?```
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com
```

### 瓒呮椂閰嶇疆
| 鎺ュ彛 | 瓒呮椂鏃堕棿 |
|------|---------|
| `/api/presets` | 15s |
| `/api/profiles/:id` | 20s |
| `/api/timeline/parse` | 180s |
| `/api/agents/build` | 180s |
| `/api/arena/run` | 300s |
| `/api/arena/stream` | 300s |

## 3. 宸插疄鐜扮殑 API 鏂规硶

### 3.1 鍋ュ悍妫€鏌?```typescript
PersonaApi.checkHealth(): Promise<HealthCheckResponse | null>
```
妫€鏌ュ悗绔湇鍔＄姸鎬侊紝杩斿洖鏈嶅姟淇℃伅鍜屽鍏ョ姸鎬併€?
### 3.2 鑾峰彇棰勮浜虹墿鍒楄〃
```typescript
PersonaApi.getPresets(): Promise<PresetProfile[]>
```
鑾峰彇榛樿浜虹墿鍗＄墖鍒楄〃銆?
### 3.3 鑾峰彇浜虹墿瀹屾暣鏁版嵁
```typescript
PersonaApi.getProfileBundle(profileId: string): Promise<ProfileBundle>
```
鑾峰彇鏌愪釜浜虹墿鐨勫畬鏁?bundle锛屽寘鍚?profile銆乶odes銆乤gents 鍜?sourceDocument銆?
### 3.4 鑾峰彇閫変腑鐨?Agents
```typescript
PersonaApi.getSelectedAgents(profileId: string, selectedAgentIds: string[]): Promise<SelectedAgentsBundle>
```
鑾峰彇鎸囧畾浜虹墿鐨勯€変腑 agents銆?
### 3.5 鍒涘缓鑷畾涔変汉鐗?```typescript
PersonaApi.importCustomProfile(displayName: string, biography: string): Promise<ProfileBundle>
```
鏍规嵁鐢ㄦ埛杈撳叆鐨?displayName + biography 鐢熸垚鏃堕棿绾胯妭鐐瑰拰浜烘牸 agents銆?
### 3.6 杩愯 Arena 璁ㄨ锛堥潪娴佸紡锛?```typescript
PersonaApi.runArena(topic: string, selectedAgents: PersonaSpec[], mode: ArenaMode): Promise<ArenaRun>
```
涓€娆℃€ц繑鍥炲畬鏁寸殑 arena 缁撴灉銆?
### 3.7 杩愯 Arena 璁ㄨ锛堟祦寮忥級
```typescript
PersonaApi.streamArena(
  topic: string,
  selectedAgents: PersonaSpec[],
  mode: ArenaMode,
  onEvent?: SSEEventHandler,
  onError?: SSEErrorHandler,
  onComplete?: SSECompleteHandler
): Promise<void>
```
浠?SSE 鏂瑰紡瀹炴椂杩斿洖 arena 鎵ц杩囩▼銆?
## 4. 鏁版嵁绫诲瀷

鎵€鏈夋暟鎹被鍨嬪畾涔変綅浜?`entry/src/main/ets/common/Models.ets`銆?
### 4.1 鏍稿績绫诲瀷

| 绫诲瀷 | 璇存槑 |
|------|------|
| `PresetProfile` | 浜虹墿鍗＄墖淇℃伅 |
| `TimelineNode` | 鏃堕棿绾胯妭鐐?|
| `PersonaSpec` | 浜烘牸 Agent 瑙勬牸 |
| `ArenaMessage` | Arena 娑堟伅 |
| `ArenaRun` | Arena 杩愯缁撴灉 |

### 4.2 鏋氫妇绫诲瀷

| 鏋氫妇 | 鍊?|
|------|---|
| `ArenaMode` | `'chat'` \| `'debate'` |
| `TimelineStageType` | `'early'` \| `'turning-point'` \| `'stable'` \| `'crisis'` \| `'rebuild'` \| `'peak'` |
| `ArenaStance` | `'support'` \| `'oppose'` \| `'reflective'` \| `'neutral'` |
| `ArenaPhase` | `'opening'` \| `'reflection'` \| `'rebuttal'` \| `'synthesis'` \| `'closing'` |

## 5. SSE 娴佸紡浜嬩欢绫诲瀷

娴佸紡鎺ュ彛杩斿洖鐨勪簨浠剁被鍨嬶細

| 浜嬩欢绫诲瀷 | 璇存槑 |
|----------|------|
| `run_started` | 寮€濮嬭繍琛?|
| `phase_started` | 闃舵寮€濮?|
| `message` | 鏂版秷鎭?|
| `phase_completed` | 闃舵瀹屾垚 |
| `summary_started` | 鎬荤粨寮€濮?|
| `summary` | 鎬荤粨鍐呭 |
| `done` | 瀹屾垚 |
| `error` | 閿欒 |

## 6. 椤甸潰闆嗘垚鎯呭喌

| 椤甸潰 | 浣跨敤鐨?API |
|------|----------|
| `Index.ets` | `getPresets()`, `getProfileBundle()`, `importCustomProfile()`, `runArena()` |
| `ProfileDetail.ets` | `getProfileBundle()` |
| `Arena.ets` | `getSelectedAgents()`, `runArena()` |
| `CreateRole.ets` | `importCustomProfile()` |

## 7. 閿欒澶勭悊

API 鏈嶅姟宸插唴缃互涓嬮敊璇鐞嗭細

1. **API-only mode**: when the online service is unavailable, the app now reports an error instead of showing fallback content.
2. **杩炴帴鐘舵€佹寚绀?*锛歚PersonaApi.getConnectionLabel()` 杩斿洖褰撳墠杩炴帴鐘舵€?3. **瀛楁绾ч敊璇彁绀?*锛氳В鏋?Zod 楠岃瘉閿欒

## 8. 娉ㄦ剰浜嬮」

1. **涓嶈鍙紶 `selectedAgentIds` 缁?arena**锛屽繀椤绘妸瀹屾暣 `agents[]` 涓€璧蜂紶
2. **涓嶈鍋囪 `personId` 涓€瀹氭槸鑻辨枃 slug**锛屼腑鏂囦篃鏄彲鑳界殑
3. **棣栧睆涓嶈鎶婂垪琛ㄦ帴鍙ｅ拰璇︽儏鎺ュ彛涓茶缁戞**
4. **SSE 瑕佸拷鐣?`: ping` 蹇冭烦娑堟伅**
5. **鑷畾涔変汉鐗╁垱寤洪渶瑕?biography 鑷冲皯 10 涓瓧绗?*


