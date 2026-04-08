import { useState, useEffect, useEffectEvent, useRef, useCallback } from 'react'

import './App.css'
import {
  buildAgents,
  loadPresets,
  loadProfile,
  parseTimeline,
  runArena,
} from './lib/api'
import type {
  ArenaMode,
  ArenaRun,
  PersonaSpec,
  PresetProfile,
  TimelineNode,
} from './types'

/** A loaded character bundle containing its profile, timeline, and agents */
interface CharacterBundle {
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
}

function App() {
  // ── Data state ──
  const [presets, setPresets] = useState<PresetProfile[]>([])
  const [loadedCharacters, setLoadedCharacters] = useState<Record<string, CharacterBundle>>({})
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set())
  const [selectedAgentIds, setSelectedAgentIds] = useState<string[]>([])
  const [topic, setTopic] = useState('现在该不该离开这份长期消耗我的工作？')
  const [arenaMode, setArenaMode] = useState<ArenaMode>('chat')
  const [arenaResult, setArenaResult] = useState<ArenaRun | null>(null)

  // ── UI state ──
  const [loading, setLoading] = useState('')
  const [error, setError] = useState('')

  // ── Resizable & collapsible columns ──
  const [leftWidth, setLeftWidth] = useState(260)
  const [rightWidth, setRightWidth] = useState(340)
  const [leftCollapsed, setLeftCollapsed] = useState(false)
  const [rightCollapsed, setRightCollapsed] = useState(false)

  // ── Import state (left panel) ──
  const [showImportForm, setShowImportForm] = useState(false)
  const [importName, setImportName] = useState('')
  const [importBio, setImportBio] = useState('')
  const [customProfiles, setCustomProfiles] = useState<PresetProfile[]>([])

  // ── All characters (presets + custom) ──
  const allProfiles = [...presets, ...customProfiles]

  // ── Compute all loaded agents and the selected subset ──
  const allLoadedAgents = Object.values(loadedCharacters).flatMap((c) => c.agents)
  const selectedAgents = allLoadedAgents.filter((a) => selectedAgentIds.includes(a.agentId))

  // ── Load presets on mount ──
  const hydratePresets = useEffectEvent(async () => {
    try {
      const data = await loadPresets()
      setPresets(data)
    } catch {
      setError('加载预设角色失败')
    }
  })

  useEffect(() => {
    hydratePresets()
  }, [])

  // ── Load a character (or toggle expand/collapse if already loaded) ──
  async function handleSelectProfile(profile: PresetProfile) {
    const pid = profile.id

    // Already loaded → just toggle expand
    if (loadedCharacters[pid]) {
      setExpandedIds((prev) => {
        const next = new Set(prev)
        if (next.has(pid)) next.delete(pid)
        else next.add(pid)
        return next
      })
      return
    }

    // Load new character
    setError('')
    setLoading(`正在加载 ${profile.displayName}...`)
    try {
      let nodes: TimelineNode[]
      let agents: PersonaSpec[]

      // Preset characters: one-shot fetch
      if (!pid.startsWith('custom-')) {
        try {
          const bundle = await loadProfile(pid)
          nodes = bundle.nodes
          agents = bundle.agents
          // Use profile from bundle since it may be richer
          const resolvedProfile = bundle.profile ?? profile
          setLoadedCharacters((prev) => ({ ...prev, [pid]: { profile: resolvedProfile, nodes, agents } }))
          setExpandedIds((prev) => new Set(prev).add(pid))
          return
        } catch {
          // fallback to parse+build
        }
      }

      // Custom or fallback: parse + build
      const timeline = await parseTimeline({
        profileId: pid,
        displayName: profile.displayName,
        biography: profile.biography,
      })
      const built = await buildAgents({
        personId: timeline.personId,
        displayName: timeline.displayName,
        biography: profile.biography,
        nodes: timeline.nodes,
      })
      nodes = timeline.nodes
      agents = built

      setLoadedCharacters((prev) => ({ ...prev, [pid]: { profile, nodes, agents } }))
      setExpandedIds((prev) => new Set(prev).add(pid))
    } catch (e) {
      setError(e instanceof Error ? e.message : '解析失败')
    } finally {
      setLoading('')
    }
  }

  // ── Toggle an agent into/out of council (cross-character) ──
  function toggleAgent(agentId: string) {
    setSelectedAgentIds((cur) => {
      if (cur.includes(agentId)) return cur.filter((id) => id !== agentId)
      if (cur.length >= 3) return [...cur.slice(1), agentId]
      return [...cur, agentId]
    })
  }

  // ── Run the council ──
  async function handleRunArena() {
    if (selectedAgents.length < 2) {
      setError('至少选择 2 个阶段人格进入议会')
      return
    }
    setError('')
    setLoading('阶段人格正在会议中...')
    try {
      const result = await runArena({
        topic,
        mode: arenaMode,
        selectedAgentIds,
        agents: allLoadedAgents,
      })
      setArenaResult(result)
    } catch (e) {
      setError(e instanceof Error ? e.message : '议会运行失败')
    } finally {
      setLoading('')
    }
  }

  // ── Import custom biography ──
  async function handleImport() {
    if (!importName.trim() || !importBio.trim()) {
      setError('请填写人物名称和传记文本')
      return
    }
    setError('')
    setLoading(`正在解析自定义人物 ${importName}...`)
    try {
      const timeline = await parseTimeline({
        displayName: importName,
        biography: importBio,
      })
      const built = await buildAgents({
        personId: timeline.personId,
        displayName: timeline.displayName,
        biography: importBio,
        nodes: timeline.nodes,
      })

      const customProfile: PresetProfile = {
        id: `custom-${Date.now()}`,
        displayName: importName,
        subtitle: '自定义导入角色',
        category: 'self',
        coverSeed: 'custom',
        biography: importBio,
        highlights: [],
        suggestedTopics: [],
      }

      const pid = customProfile.id
      setCustomProfiles((prev) => [...prev, customProfile])
      setLoadedCharacters((prev) => ({
        ...prev,
        [pid]: { profile: customProfile, nodes: timeline.nodes, agents: built },
      }))
      setExpandedIds((prev) => new Set(prev).add(pid))
      setArenaResult(null)
      setImportName('')
      setImportBio('')
      setShowImportForm(false)
    } catch (e) {
      setError(e instanceof Error ? e.message : '导入解析失败')
    } finally {
      setLoading('')
    }
  }

  // ── Compute grid columns ──
  const leftCol = leftCollapsed ? '48px' : `${leftWidth}px`
  const rightCol = rightCollapsed ? '48px' : `${rightWidth}px`

  return (
    <div
      className="app-shell"
      style={{ gridTemplateColumns: `${leftCol} 16px 1fr 16px ${rightCol}` }}
    >
      {/* ═══ LEFT ═══ */}
      <div className={`col col-left ${leftCollapsed ? 'collapsed' : ''}`}>
        <div className="col-header">
          <button
            className="collapse-btn"
            onClick={() => setLeftCollapsed((c) => !c)}
            title={leftCollapsed ? '展开' : '折叠'}
          >
            {leftCollapsed ? '▶' : '◀'}
          </button>
          {!leftCollapsed && (
            <div style={{display: 'flex', width: '100%', alignItems: 'center'}}>
              <span className="section-label" style={{ flex: 1, marginBottom: 0 }}>角色库</span>
              <button
                className="add-btn"
                onClick={() => setShowImportForm((v) => !v)}
                title="导入自定义角色"
              >
                {showImportForm ? '✕' : '+'}
              </button>
            </div>
          )}
        </div>

        {!leftCollapsed && (
          <SourcePanel
            showImportForm={showImportForm}
            allProfiles={allProfiles}
            loadedCharacters={loadedCharacters}
            expandedIds={expandedIds}
            selectedAgentIds={selectedAgentIds}
            onSelectProfile={handleSelectProfile}
            onToggleAgent={toggleAgent}
            importName={importName}
            importBio={importBio}
            setImportName={setImportName}
            setImportBio={setImportBio}
            onImport={handleImport}
            loading={loading}
          />
        )}
      </div>

      <Divider
        side="left"
        onDrag={(delta) => setLeftWidth((w) => Math.max(180, Math.min(450, w + delta)))}
      />

      {/* ═══ CENTER ═══ */}
      <div className="col col-center">
        <CouncilStage
          selectedAgents={selectedAgents}
          onToggleAgent={toggleAgent}
          topic={topic}
          setTopic={setTopic}
          arenaMode={arenaMode}
          setArenaMode={setArenaMode}
          arenaResult={arenaResult}
          loading={loading}
          error={error}
          onRun={handleRunArena}
        />
      </div>

      <Divider
        side="right"
        onDrag={(delta) => setRightWidth((w) => Math.max(240, Math.min(520, w - delta)))}
      />

      {/* ═══ RIGHT ═══ */}
      <div className={`col col-right ${rightCollapsed ? 'collapsed' : ''}`}>
        <div className="col-header col-header-right">
          {!rightCollapsed && <span className="section-label" style={{marginBottom: 0}}>输出与扩展</span>}
          <button
            className="collapse-btn"
            onClick={() => setRightCollapsed((c) => !c)}
            title={rightCollapsed ? '展开' : '折叠'}
          >
            {rightCollapsed ? '◀' : '▶'}
          </button>
        </div>

        {!rightCollapsed && (
          <ExportPanel
            arenaResult={arenaResult}
          />
        )}
      </div>
    </div>
  )
}

/* ────────────────────────────────────────────
   Drag Divider
   ──────────────────────────────────────────── */

function Divider({
  side,
  onDrag,
}: {
  side: 'left' | 'right'
  onDrag: (delta: number) => void
}) {
  const dragging = useRef(false)
  const lastX = useRef(0)

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault()
      dragging.current = true
      lastX.current = e.clientX
      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'

      const onMove = (ev: MouseEvent) => {
        if (!dragging.current) return
        const delta = ev.clientX - lastX.current
        lastX.current = ev.clientX
        onDrag(delta)
      }

      const onUp = () => {
        dragging.current = false
        document.body.style.cursor = ''
        document.body.style.userSelect = ''
        document.removeEventListener('mousemove', onMove)
        document.removeEventListener('mouseup', onUp)
      }

      document.addEventListener('mousemove', onMove)
      document.addEventListener('mouseup', onUp)
    },
    [onDrag],
  )

  return (
    <div
      className={`divider-handle divider-${side}`}
      onMouseDown={onMouseDown}
    />
  )
}

/* ────────────────────────────────────────────
   LEFT: Source Panel (Multi-character timelines)
   ──────────────────────────────────────────── */

function SourcePanel({
  showImportForm,
  allProfiles,
  loadedCharacters,
  expandedIds,
  selectedAgentIds,
  onSelectProfile,
  onToggleAgent,
  importName,
  importBio,
  setImportName,
  setImportBio,
  onImport,
  loading,
}: {
  showImportForm: boolean
  allProfiles: PresetProfile[]
  loadedCharacters: Record<string, CharacterBundle>
  expandedIds: Set<string>
  selectedAgentIds: string[]
  onSelectProfile: (p: PresetProfile) => void
  onToggleAgent: (id: string) => void
  importName: string
  importBio: string
  setImportName: (v: string) => void
  setImportBio: (v: string) => void
  onImport: () => void
  loading: string
}) {
  return (
    <>
      {/* Inline import form */}
      {showImportForm && (
        <div className="import-view">
          <p className="import-hint">粘贴任意人物传记，系统将自动解析成时间线节点。</p>
          <input
            className="import-name-input"
            placeholder="人物名称"
            value={importName}
            onChange={(e) => setImportName(e.target.value)}
          />
          <textarea
            className="import-textarea"
            placeholder="粘贴人物传记文本..."
            value={importBio}
            onChange={(e) => setImportBio(e.target.value)}
          />
          <button
            className="btn-import"
            disabled={!!loading || !importName.trim() || !importBio.trim()}
            onClick={onImport}
          >
            {loading ? '解析中...' : '解析传记并生成时间线'}
          </button>
          <hr className="divider" />
        </div>
      )}

      {/* Character list with inline expandable timelines */}
      <div className="role-list">
        {allProfiles.map((p) => {
          const loaded = loadedCharacters[p.id]
          const expanded = expandedIds.has(p.id)

          return (
            <div key={p.id} className="role-group">
              <button
                className={`role-item ${loaded ? 'loaded' : ''} ${expanded ? 'expanded' : ''}`}
                onClick={() => onSelectProfile(p)}
              >
                <span className={`role-dot ${p.id.startsWith('custom-') ? 'custom' : ''} ${loaded ? 'loaded' : ''}`} />
                <div style={{ flex: 1, textAlign: 'left' }}>
                  <span className="role-name">{p.displayName}</span>
                  <span className="role-sub">{p.subtitle}</span>
                </div>
                <span className="expand-arrow">{loaded ? (expanded ? '▾' : '▸') : '›'}</span>
              </button>

              {/* Inline timeline nodes (visible when expanded) */}
              {loaded && expanded && (
                <div className="timeline-spine nested">
                  {loaded.nodes.map((node, i) => {
                    const agent = loaded.agents[i]
                    const selected = agent ? selectedAgentIds.includes(agent.agentId) : false
                    return (
                      <button
                        key={node.nodeId}
                        className={`tl-node ${selected ? 'selected' : ''}`}
                        onClick={() => agent && onToggleAgent(agent.agentId)}
                        title={node.keyEvent}
                      >
                        <span className="tl-label">{node.stageLabel}</span>
                        <span className="tl-badge">{node.timeLabel}</span>
                      </button>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </>
  )
}

/* ────────────────────────────────────────────
   CENTER: Council Stage
   ──────────────────────────────────────────── */

function CouncilStage({
  selectedAgents,
  onToggleAgent,
  topic,
  setTopic,
  arenaMode,
  setArenaMode,
  arenaResult,
  loading,
  error,
  onRun,
}: {
  selectedAgents: PersonaSpec[]
  onToggleAgent: (id: string) => void
  topic: string
  setTopic: (v: string) => void
  arenaMode: ArenaMode
  setArenaMode: (v: ArenaMode) => void
  arenaResult: ArenaRun | null
  loading: string
  error: string
  onRun: () => void
}) {
  return (
    <>

      <div className="col-header col-header-center">
        <h1 className="center-title">时序人格局</h1>
        <p className="center-subtitle" style={{marginBottom: 0}}>
          {selectedAgents.length > 0
            ? `已选 ${selectedAgents.length} 个阶段人格 — 可跨角色混合`
            : '在左侧点选角色展开时间线，勾选节点加入议会'}
        </p>
      </div>

      {/* Avatar bar */}
      {selectedAgents.length > 0 ? (
        <div className="avatar-bar">
          {selectedAgents.map((a) => (
            <div key={a.agentId} className="avatar-chip">
              <span className="dot" />
              <span>{a.displayName}</span>
              <span className="chip-time">{a.timeLabel}</span>
              <button
                className="chip-remove"
                onClick={() => onToggleAgent(a.agentId)}
                title="移除"
              >
                ×
              </button>
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-avatar-bar">
          尚未连入任何阶段人格
        </div>
      )}

      {/* Topic & Run */}
      <div className="topic-area">
        <textarea
          className="topic-input"
          value={topic}
          onChange={(e) => setTopic(e.target.value)}
          placeholder="输入议题（例如：现在该不该离职？）"
        />
        <div className="btn-row">
          <div className="mode-toggle">
            <button
              className={`mode-btn ${arenaMode === 'chat' ? 'active' : ''}`}
              onClick={() => setArenaMode('chat')}
            >
              对谈
            </button>
            <button
              className={`mode-btn ${arenaMode === 'debate' ? 'active' : ''}`}
              onClick={() => setArenaMode('debate')}
            >
              辩论
            </button>
          </div>
          <button
            className="btn-primary"
            disabled={selectedAgents.length < 2 || !!loading}
            onClick={onRun}
          >
            {loading ? '处理中...' : '启动议会'}
          </button>
        </div>
        {error && <p className="error-text">{error}</p>}
      </div>

      {/* Message stream or empty state */}
      {loading && !arenaResult ? (
        <p className="loading-text">⟡ {loading}</p>
      ) : arenaResult ? (
        <div className="msg-stream">
          {arenaResult.messages.map((msg) => (
            <div key={msg.id} className={`msg-bubble ${msg.stance}`}>
              <p className="msg-who">{msg.stageLabel} · {msg.displayName}</p>
              <p className="msg-text">{msg.content}</p>
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-council">
          <div className="icon">◈</div>
          <p>选择至少两个时间线节点，设定议题，然后启动人格议会。</p>
          <p className="hint">支持跨角色选择 — 让不同人物的不同阶段互相对话。</p>
        </div>
      )}
    </>
  )
}

/* ────────────────────────────────────────────
   RIGHT: Export Panel
   ──────────────────────────────────────────── */

function ExportPanel({
  arenaResult,
}: {
  arenaResult: ArenaRun | null
}) {
  return (
    <>
      {arenaResult ? (
        <>
          <div className="summary-card">
            <h4>{arenaResult.summary.title}</h4>
            <div className="quote-highlight">"{arenaResult.summary.consensus}"</div>
          </div>

          <div className="export-section">
            <h4 className="export-title">导出选项</h4>
            <div className="export-btns">
              <button className="export-btn" onClick={() => {
                const text = `【${arenaResult.summary.title}】\n\n共识：${arenaResult.summary.consensus}\n\n分歧：\n${arenaResult.summary.disagreements.join('\n')}\n\n建议：\n${arenaResult.summary.actionableAdvice.join('\n')}`
                navigator.clipboard.writeText(text).then(() => alert('已复制到剪贴板'))
              }}>
                <span className="export-icon">📄</span> <div style={{textAlign: 'left'}}><span style={{fontWeight: 600}}>对话文本</span><br/><span style={{fontSize: '0.75rem', opacity: 0.7}}>导出为 TXT 格式</span></div>
              </button>
              <button className="export-btn" onClick={() => alert('全息海报接口')}>
                <span className="export-icon" style={{color: '#c290ff', background: '#f5edff'}}>⬇️</span> <div style={{textAlign: 'left'}}><span style={{fontWeight: 600}}>全息海报</span><br/><span style={{fontSize: '0.75rem', opacity: 0.7}}>生成可视化海报</span></div>
              </button>
              <button className="export-btn" onClick={() => alert('分享链接接口')}>
                <span className="export-icon" style={{color: '#659fff', background: '#edf4ff'}}>🔗</span> <div style={{textAlign: 'left'}}><span style={{fontWeight: 600}}>分享链接</span><br/><span style={{fontSize: '0.75rem', opacity: 0.7}}>生成分享链接</span></div>
              </button>
            </div>
          </div>

          <div className="stats-section">
            <h4 className="export-title">会话统计</h4>
            <div className="stat-row">
              <span>对话轮次</span>
              <span className="stat-val">{Math.ceil(arenaResult.messages.length / 2)}</span>
            </div>
            <div className="stat-row">
              <span>总字数</span>
              <span className="stat-val">{arenaResult.messages.reduce((acc, m) => acc + m.content.length, 0)}</span>
            </div>
            <div className="stat-row">
              <span>耗时</span>
              <span className="stat-val">3s</span>
            </div>
          </div>
        </>
      ) : (
        <div className="empty-studio">
          启动一次议会后，纪要与导出选项将出现在此处
        </div>
      )}
    </>
  )
}

export default App
