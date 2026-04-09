import { useEffect, useRef, useState, type MouseEvent as ReactMouseEvent } from 'react'

import './arena-studio.css'
import {
  buildAgents,
  buildSuggestedShareUrl,
  generateArenaPoster,
  interruptArenaSession,
  loadArenaHistory,
  loadArenaRun,
  loadPresets,
  loadProfile,
  mergeAgents as requestMergedAgent,
  parseTimeline,
  runArenaStream,
} from '../lib/api'
import type {
  ArenaMessage,
  ArenaPhase,
  ArenaMode,
  ArenaOutputLinks,
  ArenaPosterResponse,
  ArenaRun,
  ArenaRunHistoryItem,
  ArenaStreamEvent,
  PersonaSpec,
  PresetProfile,
  TimelineNode,
} from '../types'

interface CharacterBundle {
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
}

interface LiveDraft {
  id: string
  displayName: string
  stageLabel: string
  round: number
  phase: string
  content: string
}

type LeftSidebarTab = 'sources' | 'history'
type CenterView = 'setup' | 'chat'

function dedupePersonas(agents: PersonaSpec[]): PersonaSpec[] {
  const seen = new Set<string>()
  return agents.filter((agent) => {
    if (seen.has(agent.agentId)) {
      return false
    }
    seen.add(agent.agentId)
    return true
  })
}

function upsertMessage(messages: ArenaMessage[], nextMessage: ArenaMessage): ArenaMessage[] {
  const existingIndex = messages.findIndex((message) => message.id === nextMessage.id)
  if (existingIndex === -1) {
    return [...messages, nextMessage]
  }

  const nextMessages = [...messages]
  nextMessages[existingIndex] = nextMessage
  return nextMessages
}

function upsertDraft(drafts: LiveDraft[], nextDraft: LiveDraft): LiveDraft[] {
  const existingIndex = drafts.findIndex((draft) => draft.id === nextDraft.id)
  if (existingIndex === -1) {
    return [...drafts, nextDraft]
  }

  const nextDrafts = [...drafts]
  nextDrafts[existingIndex] = nextDraft
  return nextDrafts
}

function formatTimestamp(value?: string): string {
  if (!value) {
    return '刚刚'
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return value
  }

  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

const phaseLabels: Record<ArenaPhase, string> = {
  opening: '开场',
  reflection: '反思',
  rebuttal: '交锋',
  synthesis: '收束',
  closing: '收尾',
}

function getPhaseLabel(phase?: string): string {
  if (!phase) {
    return '消息'
  }

  return phaseLabels[phase as ArenaPhase] ?? phase
}

function getAvatarText(value: string): string {
  const trimmed = value.trim()
  if (!trimmed) {
    return 'TA'
  }

  return trimmed.slice(0, 2).toUpperCase()
}

function getStatusLabel(run: ArenaRun | null, streaming: boolean, interrupting: boolean): string {
  if (interrupting) {
    return '正在中断并整理阶段性结论'
  }

  if (streaming) {
    return '讨论进行中'
  }

  if (run?.status === 'interrupted') {
    return '已打断，可继续续聊'
  }

  if (run) {
    return '讨论已完成'
  }

  return '等待发起'
}

function Divider({
  side,
  onDrag,
}: {
  side: 'left' | 'right'
  onDrag: (delta: number) => void
}) {
  const dragging = useRef(false)
  const lastX = useRef(0)

  function handleMouseDown(event: ReactMouseEvent<HTMLDivElement>) {
    event.preventDefault()
    dragging.current = true
    lastX.current = event.clientX
    document.body.style.cursor = 'col-resize'
    document.body.style.userSelect = 'none'

    const handleMouseMove = (moveEvent: MouseEvent) => {
      if (!dragging.current) {
        return
      }

      const delta = moveEvent.clientX - lastX.current
      lastX.current = moveEvent.clientX
      onDrag(delta)
    }

    const handleMouseUp = () => {
      dragging.current = false
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
      document.removeEventListener('mousemove', handleMouseMove)
      document.removeEventListener('mouseup', handleMouseUp)
    }

    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseup', handleMouseUp)
  }

  return <div className={`arena-divider arena-divider-${side}`} onMouseDown={handleMouseDown} />
}

function SourcePanel({
  showImportForm,
  allProfiles,
  loadedCharacters,
  mergeCandidates,
  mergedAgents,
  expandedIds,
  selectedAgentIds,
  importName,
  importBio,
  mergePrimaryAgentId,
  mergeSecondaryAgentId,
  mergeDisplayName,
  mergePrompt,
  loadingLabel,
  mergeLoading,
  onSelectProfile,
  onToggleAgent,
  onImport,
  onMerge,
  onRemoveMergedAgent,
  setImportName,
  setImportBio,
  setMergePrimaryAgentId,
  setMergeSecondaryAgentId,
  setMergeDisplayName,
  setMergePrompt,
}: {
  showImportForm: boolean
  allProfiles: PresetProfile[]
  loadedCharacters: Record<string, CharacterBundle>
  mergeCandidates: PersonaSpec[]
  mergedAgents: PersonaSpec[]
  expandedIds: Set<string>
  selectedAgentIds: string[]
  importName: string
  importBio: string
  mergePrimaryAgentId: string
  mergeSecondaryAgentId: string
  mergeDisplayName: string
  mergePrompt: string
  loadingLabel: string
  mergeLoading: boolean
  onSelectProfile: (profile: PresetProfile) => void
  onToggleAgent: (agentId: string) => void
  onImport: () => void
  onMerge: () => void
  onRemoveMergedAgent: (agentId: string) => void
  setImportName: (value: string) => void
  setImportBio: (value: string) => void
  setMergePrimaryAgentId: (value: string) => void
  setMergeSecondaryAgentId: (value: string) => void
  setMergeDisplayName: (value: string) => void
  setMergePrompt: (value: string) => void
}) {
  return (
    <>
      {showImportForm ? (
        <section className="panel-block panel-import">
          <div className="panel-kicker">导入人物</div>
          <input
            className="panel-input"
            placeholder="人物名称"
            value={importName}
            onChange={(event) => setImportName(event.target.value)}
          />
          <textarea
            className="panel-textarea"
            placeholder="粘贴人物传记、访谈或人物简介"
            value={importBio}
            onChange={(event) => setImportBio(event.target.value)}
          />
          <button
            className="action-button action-button-primary"
            disabled={Boolean(loadingLabel) || !importName.trim() || !importBio.trim()}
            onClick={onImport}
            type="button"
          >
            {loadingLabel ? '解析中...' : '生成时间线节点'}
          </button>
        </section>
      ) : null}

      <section className="panel-block panel-merge">
        <div className="panel-kicker">人格融合</div>
        {mergeCandidates.length >= 2 ? (
          <>
            <div className="merge-grid">
              <label className="merge-field">
                <span>人格 A</span>
                <select className="panel-select" value={mergePrimaryAgentId} onChange={(event) => setMergePrimaryAgentId(event.target.value)}>
                  <option value="">选择第一个人格</option>
                  {mergeCandidates.map((agent) => (
                    <option key={agent.agentId} value={agent.agentId}>
                      {agent.displayName}
                    </option>
                  ))}
                </select>
              </label>

              <label className="merge-field">
                <span>人格 B</span>
                <select className="panel-select" value={mergeSecondaryAgentId} onChange={(event) => setMergeSecondaryAgentId(event.target.value)}>
                  <option value="">选择第二个人格</option>
                  {mergeCandidates.map((agent) => (
                    <option key={agent.agentId} value={agent.agentId} disabled={agent.agentId === mergePrimaryAgentId}>
                      {agent.displayName}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <input
              className="panel-input"
              placeholder="新人格名称，可留空"
              value={mergeDisplayName}
              onChange={(event) => setMergeDisplayName(event.target.value)}
            />
            <textarea
              className="panel-textarea panel-textarea-compact"
              placeholder="可选：补充融合要求，例如“保留前者的行动力和后者的边界感”。"
              value={mergePrompt}
              onChange={(event) => setMergePrompt(event.target.value)}
            />
            <button
              className="action-button action-button-primary"
              disabled={mergeLoading || !mergePrimaryAgentId || !mergeSecondaryAgentId || mergePrimaryAgentId === mergeSecondaryAgentId}
              onClick={onMerge}
              type="button"
            >
              {mergeLoading ? '融合中...' : '生成新人格'}
            </button>
          </>
        ) : (
          <div className="empty-note">至少载入两个可用人格后，才能生成融合人格。</div>
        )}

        {mergedAgents.length > 0 ? (
          <div className="merge-agent-list">
            {mergedAgents.map((agent) => {
              const selected = selectedAgentIds.includes(agent.agentId)
              return (
                <article className={`merge-agent-card ${selected ? 'is-selected' : ''}`} key={agent.agentId}>
                  <button className="merge-agent-main" onClick={() => onToggleAgent(agent.agentId)} type="button">
                    <strong>{agent.displayName}</strong>
                    <span>
                      {agent.stageLabel} · {agent.timeLabel}
                    </span>
                    <p>{agent.goal}</p>
                  </button>
                  <button className="merge-agent-remove" onClick={() => onRemoveMergedAgent(agent.agentId)} type="button">
                    移除
                  </button>
                </article>
              )
            })}
          </div>
        ) : null}
      </section>

      <section className="panel-block">
        <div className="panel-kicker">角色库</div>
        <div className="profile-stack">
          {allProfiles.map((profile) => {
            const loaded = loadedCharacters[profile.id]
            const expanded = expandedIds.has(profile.id)

            return (
              <div className="profile-card" key={profile.id}>
                <button className="profile-trigger" onClick={() => onSelectProfile(profile)} type="button">
                  <span className={`profile-dot ${loaded ? 'is-loaded' : ''} ${profile.id.startsWith('custom-') ? 'is-custom' : ''}`} />
                  <span className="profile-copy">
                    <strong>{profile.displayName}</strong>
                    <small>{profile.subtitle}</small>
                  </span>
                  <span className="profile-arrow">{loaded ? (expanded ? '−' : '+') : '↗'}</span>
                </button>

                {loaded && expanded ? (
                  <div className="timeline-chip-list">
                    {loaded.nodes.map((node, index) => {
                      const agent = loaded.agents[index]
                      const selected = agent ? selectedAgentIds.includes(agent.agentId) : false
                      return (
                        <button
                          className={`timeline-chip ${selected ? 'is-selected' : ''}`}
                          key={node.nodeId}
                          onClick={() => {
                            if (agent) {
                              onToggleAgent(agent.agentId)
                            }
                          }}
                          type="button"
                        >
                          <span>{node.stageLabel}</span>
                          <small>{node.timeLabel}</small>
                        </button>
                      )
                    })}
                  </div>
                ) : null}
              </div>
            )
          })}
        </div>
      </section>
    </>
  )
}

function HistoryPanel({
  history,
  onLoadRun,
}: {
  history: ArenaRunHistoryItem[]
  onLoadRun: (runId: string) => void
}) {
  return (
    <section className="panel-block">
      <div className="panel-kicker">最近讨论</div>
      <div className="history-list">
        {history.length > 0 ? (
          history.map((item) => (
            <button className="history-item" key={item.runId} onClick={() => onLoadRun(item.runId)} type="button">
              <div className="history-head">
                <strong>{item.title}</strong>
                <span className={`status-pill ${item.status === 'interrupted' ? 'is-paused' : 'is-done'}`}>
                  {item.status === 'interrupted' ? '打断' : '完成'}
                </span>
              </div>
              <p>{item.topic}</p>
              <small>
                {item.participantNames.join(' · ')} · {formatTimestamp(item.createdAt)}
              </small>
            </button>
          ))
        ) : (
          <div className="empty-note">还没有历史讨论记录。</div>
        )}
      </div>
    </section>
  )
}

function StreamPanel({
  displayAgents,
  topic,
  arenaMode,
  setTopic,
  setArenaMode,
  roundCount,
  setRoundCount,
  maxMessageChars,
  setMaxMessageChars,
  guidance,
  setGuidance,
  statusLabel,
  phaseLabel,
  error,
  streaming,
  interrupting,
  activeSessionId,
  streamMessages,
  liveDrafts,
  liveSummaryText,
  currentRun,
  activeCenterView,
  onChangeCenterView,
  onStart,
  onContinue,
  onInterrupt,
  onToggleAgent,
}: {
  displayAgents: PersonaSpec[]
  topic: string
  arenaMode: ArenaMode
  setTopic: (value: string) => void
  setArenaMode: (value: ArenaMode) => void
  roundCount: number
  setRoundCount: (value: number) => void
  maxMessageChars: number
  setMaxMessageChars: (value: number) => void
  guidance: string
  setGuidance: (value: string) => void
  statusLabel: string
  phaseLabel: string
  error: string
  streaming: boolean
  interrupting: boolean
  activeSessionId: string
  streamMessages: ArenaMessage[]
  liveDrafts: LiveDraft[]
  liveSummaryText: string
  currentRun: ArenaRun | null
  activeCenterView: CenterView
  onChangeCenterView: (view: CenterView) => void
  onStart: () => void
  onContinue: () => void
  onInterrupt: (resumeAfterInterrupt?: boolean) => void
  onToggleAgent: (agentId: string) => void
}) {
  const messageViewportRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const viewport = messageViewportRef.current
    if (!viewport) {
      return
    }

    const frame = window.requestAnimationFrame(() => {
      viewport.scrollTop = viewport.scrollHeight
    })

    return () => {
      window.cancelAnimationFrame(frame)
    }
  }, [currentRun?.runId, liveDrafts, liveSummaryText, streamMessages, streaming])

  const messageCount = streamMessages.length + liveDrafts.length

  return (
    <section className="studio-main">
      <header className="studio-hero">
        <div className="studio-hero-copy">
          <p className="eyebrow">Arena Console</p>
          <h1>时序人格讨论台</h1>
          <p className="hero-copy">左边选人格，中间看讨论，右边出结果。</p>
        </div>
        <div className="hero-status">
          <span className={`status-pill ${streaming ? 'is-live' : currentRun?.status === 'interrupted' ? 'is-paused' : 'is-done'}`}>
            {statusLabel}
          </span>
          <strong>{phaseLabel || '等待开场'}</strong>
          <small>{currentRun?.sessionId ? `Session · ${currentRun.sessionId}` : `${displayAgents.length} 位人格待命`}</small>
        </div>
      </header>

      <div className="studio-main-body">
        <div className="center-view-toggle">
          <button
            className={activeCenterView === 'setup' ? 'is-active' : ''}
            onClick={() => onChangeCenterView('setup')}
            type="button"
          >
            开局设定
          </button>
          <button
            className={activeCenterView === 'chat' ? 'is-active' : ''}
            onClick={() => onChangeCenterView('chat')}
            type="button"
          >
            讨论现场
          </button>
        </div>

        {activeCenterView === 'setup' ? (
          <section className="composer-card">
            <div className="composer-heading">
              <div>
                <p className="eyebrow">Setup</p>
                <h2>开局设定</h2>
              </div>
              <div className="composer-status-strip">
                <span>{roundCount} 轮</span>
                <span>{maxMessageChars} 字上限</span>
                <span>{arenaMode === 'debate' ? '辩论' : '对谈'}</span>
              </div>
            </div>

            <div className="agent-ribbon">
              {displayAgents.length > 0 ? (
                displayAgents.map((agent) => (
                  <button className="agent-token" key={agent.agentId} onClick={() => onToggleAgent(agent.agentId)} type="button">
                    <span>{agent.displayName}</span>
                    <small>{agent.stageLabel}</small>
                  </button>
                ))
              ) : (
                <div className="empty-note">先在左侧展开时间线，至少选中两个阶段人格。</div>
              )}
            </div>

            <div className="composer-grid">
              <div className="composer-field composer-field-topic">
                <span className="composer-label">讨论议题</span>
                <textarea
                  className="topic-textarea"
                  placeholder="输入议题，例如：我现在要不要离开这份长期消耗我的工作？"
                  value={topic}
                  onChange={(event) => setTopic(event.target.value)}
                />
              </div>

              <div className="composer-field composer-field-guidance">
                <span className="composer-label">实时引导</span>
                <textarea
                  className="guidance-textarea"
                  placeholder="可选：给这场讨论一个新的引导。新开场会作为实时引导插入；打断后继续时，也会作为新的 steer。"
                  value={guidance}
                  onChange={(event) => setGuidance(event.target.value)}
                />
              </div>

              <div className="composer-field composer-field-controls">
                <div className="control-row">
                  <div className="segmented">
                    <button className={arenaMode === 'chat' ? 'is-active' : ''} onClick={() => setArenaMode('chat')} type="button">
                      对谈
                    </button>
                    <button className={arenaMode === 'debate' ? 'is-active' : ''} onClick={() => setArenaMode('debate')} type="button">
                      辩论
                    </button>
                  </div>

                  <label className="numeric-control">
                    <span>轮数</span>
                    <input
                      max={20}
                      min={1}
                      type="number"
                      value={roundCount}
                      onChange={(event) => setRoundCount(Number(event.target.value) || 1)}
                    />
                  </label>

                  <label className="numeric-control">
                    <span>单条上限</span>
                    <input
                      max={500}
                      min={60}
                      step={10}
                      type="number"
                      value={maxMessageChars}
                      onChange={(event) => setMaxMessageChars(Number(event.target.value) || 60)}
                    />
                  </label>
                </div>
              </div>

              <div className="composer-field composer-field-actions">
                <div className="action-row">
                  <button className="action-button action-button-primary" disabled={streaming} onClick={onStart} type="button">
                    {streaming ? '讨论进行中' : '启动讨论'}
                  </button>
                  <button className="action-button" disabled={streaming || !currentRun} onClick={onContinue} type="button">
                    基于当前结果继续
                  </button>
                  <button
                    className="action-button action-button-danger"
                    disabled={!streaming || interrupting || !activeSessionId}
                    onClick={() => onInterrupt(false)}
                    type="button"
                  >
                    {interrupting ? '正在中断...' : '中途打断'}
                  </button>
                </div>

                {error ? <p className="error-banner">{error}</p> : null}
              </div>
            </div>
          </section>
        ) : (
          <section className="transcript-card">
            <div className="transcript-head">
              <div>
                <p className="eyebrow">Live Chat</p>
                <strong>{messageCount} 条消息</strong>
              </div>
              <div className="transcript-status">
                <small>{streaming ? '自动跟随最新发言' : '已停止更新'}</small>
                <span className="chat-follow-indicator" aria-hidden="true" />
              </div>
            </div>

            <div className="message-list" ref={messageViewportRef}>
              <div className="message-thread-badge">本场讨论</div>

              {streamMessages.map((message) => (
                <article className={`message-row ${message.kind === 'user' ? 'is-self' : ''}`} key={message.id}>
                  <div className={`message-avatar ${message.kind === 'user' ? 'is-self' : ''}`} aria-hidden="true">
                    {message.kind === 'user' ? '你' : getAvatarText(message.displayName)}
                  </div>

                  <div className="message-stack">
                    <div className="message-meta">
                      <strong>{message.displayName}</strong>
                      <span>{message.stageLabel}</span>
                      <span>{message.round ? `第 ${message.round} 轮` : '实时引导'}</span>
                    </div>
                    <div className={`message-card ${message.kind === 'user' ? 'is-user' : `stance-${message.stance}`}`}>
                      <p>{message.content}</p>
                    </div>
                    <div className="message-submeta">
                      <span>{getPhaseLabel(message.phase)}</span>
                      {message.replyToDisplayName ? <span>回应 {message.replyToDisplayName}</span> : null}
                    </div>
                  </div>
                </article>
              ))}

              {liveDrafts.map((draft) => (
                <article className="message-row" key={draft.id}>
                  <div className="message-avatar is-draft" aria-hidden="true">
                    {getAvatarText(draft.displayName)}
                  </div>

                  <div className="message-stack">
                    <div className="message-meta">
                      <strong>{draft.displayName}</strong>
                      <span>{draft.stageLabel}</span>
                      <span>{`第 ${draft.round} 轮 · ${getPhaseLabel(draft.phase)}`}</span>
                    </div>
                    <div className="message-card is-draft">
                      {draft.content ? <p>{draft.content}</p> : <div className="typing-dots" aria-label="正在输入"><span /><span /><span /></div>}
                    </div>
                    <div className="message-submeta">
                      <span>正在流式生成</span>
                    </div>
                  </div>
                </article>
              ))}

              {streamMessages.length === 0 && liveDrafts.length === 0 ? (
                <div className="empty-note message-empty-state">发起后这里会像微信聊天一样自动跟随最新发言，不需要手动一直往下滑。</div>
              ) : null}
            </div>

            {liveSummaryText ? (
              <div className="summary-draft">
                <p className="eyebrow">Live Summary</p>
                <p>{liveSummaryText}</p>
              </div>
            ) : null}

            <div className="intervention-dock">
              <div className="intervention-head">
                <div>
                  <p className="eyebrow">Manual Steer</p>
                  <strong>人工介入</strong>
                </div>
                <span className={`status-pill ${streaming ? 'is-live' : currentRun?.status === 'interrupted' ? 'is-paused' : 'is-done'}`}>
                  {streaming ? '可中途打断' : currentRun?.status === 'interrupted' ? '可续聊' : '待下一轮'}
                </span>
              </div>

              <textarea
                className="guidance-textarea guidance-textarea-inline"
                placeholder="需要人工介入时，在这里输入新的 steer。点击后会先打断当前讨论，再基于当前结果继续。"
                value={guidance}
                onChange={(event) => setGuidance(event.target.value)}
              />

              <div className="intervention-actions">
                {streaming ? (
                  <>
                    <button
                      className="action-button action-button-primary"
                      disabled={interrupting || !activeSessionId || !guidance.trim()}
                      onClick={() => onInterrupt(true)}
                      type="button"
                    >
                      {interrupting ? '等待停下...' : '打断并按引导继续'}
                    </button>
                    <button
                      className="action-button action-button-danger"
                      disabled={interrupting || !activeSessionId}
                      onClick={() => onInterrupt(false)}
                      type="button"
                    >
                      只打断
                    </button>
                  </>
                ) : (
                  <button className="action-button action-button-primary" disabled={!currentRun} onClick={onContinue} type="button">
                    {currentRun?.status === 'interrupted' ? '继续这场讨论' : '基于当前结果继续'}
                  </button>
                )}

                <span className="intervention-hint">
                  {streaming
                    ? '聊天页内可直接打断；有 steer 时会在安全中断后自动续聊。'
                    : '当前未流式生成。需要续聊时，这里的 steer 会作为新的实时引导插入。'}
                </span>
              </div>
            </div>
          </section>
        )}
      </div>
    </section>
  )
}

function OutputPanel({
  currentRun,
  links,
  poster,
  posterLoading,
  onLoadRun,
  onGeneratePoster,
  onOpenShare,
  onCopyShare,
}: {
  currentRun: ArenaRun | null
  links?: ArenaOutputLinks
  poster: ArenaPosterResponse | null
  posterLoading: boolean
  onLoadRun: (runId: string) => void
  onGeneratePoster: () => void
  onOpenShare: () => void
  onCopyShare: () => void
}) {
  return (
    <section className="output-stack">
      {currentRun ? (
        <>
          <section className="panel-block">
            <div className="panel-kicker">结论摘要</div>
            <h3 className="summary-title">{currentRun.summary.title}</h3>
            <p className="summary-copy">{currentRun.summary.consensus}</p>
            <div className="summary-list">
              {currentRun.summary.actionableAdvice.slice(0, 3).map((item) => (
                <span className="summary-chip" key={item}>
                  {item}
                </span>
              ))}
            </div>
          </section>

          <section className="panel-block">
            <div className="panel-kicker">快速动作</div>
            <div className="action-grid">
              <button className="action-button" onClick={onOpenShare} type="button">
                打开分享页
              </button>
              <button className="action-button" onClick={onCopyShare} type="button">
                复制分享链接
              </button>
              <button className="action-button" disabled={posterLoading} onClick={onGeneratePoster} type="button">
                {posterLoading ? '生成中...' : '生成全息海报'}
              </button>
              <button className="action-button" onClick={() => onLoadRun(currentRun.runId)} type="button">
                重新载入本次结果
              </button>
            </div>
            <div className="meta-grid">
              <div>
                <span>Session</span>
                <strong>{currentRun.sessionId ?? currentRun.runId}</strong>
              </div>
              <div>
                <span>模式</span>
                <strong>{currentRun.mode}</strong>
              </div>
              <div>
                <span>轮数</span>
                <strong>{currentRun.config?.roundCount ?? '未记录'}</strong>
              </div>
              <div>
                <span>时间</span>
                <strong>{formatTimestamp(currentRun.createdAt)}</strong>
              </div>
            </div>
            {links?.suggestedSharePath ? <small className="link-hint">{buildSuggestedShareUrl(links, currentRun.runId)}</small> : null}
          </section>

          {poster ? (
            <section className="panel-block">
              <div className="panel-kicker">海报输出</div>
              <h3 className="summary-title">{poster.poster.title}</h3>
              <p className="summary-copy">{poster.poster.summary}</p>
              {poster.poster.imageUrl ? (
                <img alt={poster.poster.title} className="poster-preview" src={poster.poster.imageUrl} />
              ) : (
                <div className="empty-note">海报已生成，但当前没有可直接访问的公开 URL。</div>
              )}
            </section>
          ) : null}
        </>
      ) : (
        <section className="panel-block">
          <div className="panel-kicker">输出面板</div>
          <div className="empty-note">讨论完成后，分享链接、海报和摘要会出现在这里。</div>
        </section>
      )}
    </section>
  )
}

export default function ArenaStudio() {
  const [presets, setPresets] = useState<PresetProfile[]>([])
  const [customProfiles, setCustomProfiles] = useState<PresetProfile[]>([])
  const [history, setHistory] = useState<ArenaRunHistoryItem[]>([])
  const [loadedCharacters, setLoadedCharacters] = useState<Record<string, CharacterBundle>>({})
  const [mergedAgents, setMergedAgents] = useState<PersonaSpec[]>([])
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set())
  const [selectedAgentIds, setSelectedAgentIds] = useState<string[]>([])
  const [topic, setTopic] = useState('现在该不该离开这份长期消耗我的工作？')
  const [arenaMode, setArenaMode] = useState<ArenaMode>('chat')
  const [roundCount, setRoundCount] = useState(3)
  const [maxMessageChars, setMaxMessageChars] = useState(180)
  const [guidance, setGuidance] = useState('')
  const [showImportForm, setShowImportForm] = useState(false)
  const [leftSidebarTab, setLeftSidebarTab] = useState<LeftSidebarTab>('sources')
  const [importName, setImportName] = useState('')
  const [importBio, setImportBio] = useState('')
  const [mergePrimaryAgentId, setMergePrimaryAgentId] = useState('')
  const [mergeSecondaryAgentId, setMergeSecondaryAgentId] = useState('')
  const [mergeDisplayName, setMergeDisplayName] = useState('')
  const [mergePrompt, setMergePrompt] = useState('')
  const [loadingLabel, setLoadingLabel] = useState('')
  const [mergeLoading, setMergeLoading] = useState(false)
  const [streaming, setStreaming] = useState(false)
  const [interrupting, setInterrupting] = useState(false)
  const [phaseLabel, setPhaseLabel] = useState('')
  const [error, setError] = useState('')
  const [activeSessionId, setActiveSessionId] = useState('')
  const [streamMessages, setStreamMessages] = useState<ArenaMessage[]>([])
  const [liveDrafts, setLiveDrafts] = useState<LiveDraft[]>([])
  const [liveSummaryText, setLiveSummaryText] = useState('')
  const [currentRun, setCurrentRun] = useState<ArenaRun | null>(null)
  const [currentLinks, setCurrentLinks] = useState<ArenaOutputLinks>()
  const [posterResponse, setPosterResponse] = useState<ArenaPosterResponse | null>(null)
  const [posterLoading, setPosterLoading] = useState(false)
  const [leftWidth, setLeftWidth] = useState(320)
  const [rightWidth, setRightWidth] = useState(360)
  const [leftSidebarCollapsed, setLeftSidebarCollapsed] = useState(false)
  const [rightSidebarCollapsed, setRightSidebarCollapsed] = useState(false)
  const [activeCenterView, setActiveCenterView] = useState<CenterView>('setup')
  const streamAbortRef = useRef<AbortController | null>(null)
  const autoResumeAfterInterruptRef = useRef(false)

  const allProfiles = [...presets, ...customProfiles]
  const libraryAgents = Object.values(loadedCharacters).flatMap((bundle) => bundle.agents)
  const allArenaAgents = dedupePersonas([...libraryAgents, ...mergedAgents, ...(currentRun?.participants ?? [])])
  const mergeCandidates = allArenaAgents
  const selectedAgents = allArenaAgents.filter((agent) => selectedAgentIds.includes(agent.agentId))
  const displayAgents = selectedAgents.length > 0 ? selectedAgents : currentRun?.participants ?? []

  useEffect(() => {
    void (async () => {
      try {
        setPresets(await loadPresets())
      } catch {
        setError('加载预设角色失败')
      }
    })()

    void (async () => {
      try {
        setHistory(await loadArenaHistory(8))
      } catch {
        setHistory([])
      }
    })()

    return () => {
      streamAbortRef.current?.abort()
    }
  }, [])

  async function handleSelectProfile(profile: PresetProfile) {
    const profileId = profile.id

    if (loadedCharacters[profileId]) {
      setExpandedIds((previous) => {
        const next = new Set(previous)
        if (next.has(profileId)) {
          next.delete(profileId)
        } else {
          next.add(profileId)
        }
        return next
      })
      return
    }

    setError('')
    setLoadingLabel(`正在加载 ${profile.displayName}...`)

    try {
      if (!profileId.startsWith('custom-')) {
        try {
          const bundle = await loadProfile(profileId)
          const resolvedProfile = bundle.profile ?? profile
          setLoadedCharacters((previous) => ({
            ...previous,
            [profileId]: {
              profile: resolvedProfile,
              nodes: bundle.nodes,
              agents: bundle.agents,
            },
          }))
          setExpandedIds((previous) => new Set(previous).add(profileId))
          return
        } catch {
          // Fall back to parse + build below.
        }
      }

      const timeline = await parseTimeline({
        profileId,
        displayName: profile.displayName,
        biography: profile.biography,
      })
      const agents = await buildAgents({
        personId: timeline.personId,
        displayName: timeline.displayName,
        biography: profile.biography,
        nodes: timeline.nodes,
      })

      setLoadedCharacters((previous) => ({
        ...previous,
        [profileId]: {
          profile,
          nodes: timeline.nodes,
          agents,
        },
      }))
      setExpandedIds((previous) => new Set(previous).add(profileId))
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '角色加载失败')
    } finally {
      setLoadingLabel('')
    }
  }

  function toggleAgent(agentId: string) {
    setSelectedAgentIds((current) => {
      if (current.includes(agentId)) {
        return current.filter((id) => id !== agentId)
      }
      if (current.length >= 3) {
        return [...current.slice(1), agentId]
      }
      return [...current, agentId]
    })
  }

  async function handleImport() {
    if (!importName.trim() || !importBio.trim()) {
      setError('请填写人物名称和传记文本')
      return
    }

    setError('')
    setLoadingLabel(`正在解析 ${importName}...`)

    try {
      const timeline = await parseTimeline({
        displayName: importName,
        biography: importBio,
      })
      const agents = await buildAgents({
        personId: timeline.personId,
        displayName: timeline.displayName,
        biography: importBio,
        nodes: timeline.nodes,
      })

      const profile: PresetProfile = {
        id: `custom-${Date.now()}`,
        displayName: importName,
        subtitle: '自定义导入',
        category: 'self',
        coverSeed: 'custom',
        biography: importBio,
        highlights: [],
        suggestedTopics: [],
      }

      setCustomProfiles((previous) => [...previous, profile])
      setLoadedCharacters((previous) => ({
        ...previous,
        [profile.id]: {
          profile,
          nodes: timeline.nodes,
          agents,
        },
      }))
      setExpandedIds((previous) => new Set(previous).add(profile.id))
      setImportName('')
      setImportBio('')
      setShowImportForm(false)
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '导入失败')
    } finally {
      setLoadingLabel('')
    }
  }

  async function handleMergeAgents() {
    if (!mergePrimaryAgentId || !mergeSecondaryAgentId || mergePrimaryAgentId === mergeSecondaryAgentId) {
      setError('请选择两个不同的人格再进行融合')
      return
    }

    const primary = mergeCandidates.find((agent) => agent.agentId === mergePrimaryAgentId)
    const secondary = mergeCandidates.find((agent) => agent.agentId === mergeSecondaryAgentId)

    if (!primary || !secondary) {
      setError('待融合人格不存在，请重新选择')
      return
    }

    setError('')
    setMergeLoading(true)

    try {
      const response = await requestMergedAgent({
        primary,
        secondary,
        displayName: mergeDisplayName.trim() || undefined,
        mergePrompt: mergePrompt.trim() || undefined,
      })

      setMergedAgents((current) => dedupePersonas([response.agent, ...current]))
      setSelectedAgentIds((current) => {
        const next = [...current.filter((id) => id !== response.agent.agentId), response.agent.agentId]
        return next.length <= 3 ? next : next.slice(next.length - 3)
      })
      setMergeDisplayName('')
      setMergePrompt('')
      setMergePrimaryAgentId(response.agent.agentId)
      setMergeSecondaryAgentId('')
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '人格融合失败')
    } finally {
      setMergeLoading(false)
    }
  }

  function handleRemoveMergedAgent(agentId: string) {
    setMergedAgents((current) => current.filter((agent) => agent.agentId !== agentId))
    setSelectedAgentIds((current) => current.filter((id) => id !== agentId))
    if (mergePrimaryAgentId === agentId) {
      setMergePrimaryAgentId('')
    }
    if (mergeSecondaryAgentId === agentId) {
      setMergeSecondaryAgentId('')
    }
  }

  function handleArenaEvent(event: ArenaStreamEvent) {
    switch (event.type) {
      case 'run_started':
        setActiveSessionId(event.sessionId ?? '')
        setPhaseLabel('开场准备')
        break
      case 'phase_started':
        setPhaseLabel(`第 ${event.round} 轮 · ${event.phase}`)
        break
      case 'speaker_started':
        setActiveCenterView('chat')
        setPhaseLabel(`第 ${event.round} 轮 · ${getPhaseLabel(event.phase)} · ${event.participant.displayName}`)
        setLiveDrafts((current) =>
          upsertDraft(current, {
            id: event.messageId,
            displayName: event.participant.displayName,
            stageLabel: event.participant.stageLabel,
            round: event.round,
            phase: event.phase,
            content: '',
          }),
        )
        break
      case 'speaker_delta':
        if (event.channel !== 'text') {
          break
        }
        setLiveDrafts((current) => {
          const currentDraft =
            current.find((draft) => draft.id === event.messageId) ??
            ({
              id: event.messageId,
              displayName: event.displayName,
              stageLabel: event.displayName,
              round: event.round,
              phase: event.phase,
              content: '',
            } as LiveDraft)

          return upsertDraft(current, {
            ...currentDraft,
            content: event.accumulatedText,
          })
        })
        break
      case 'speaker_completed':
        setPhaseLabel(`第 ${event.round} 轮 · ${getPhaseLabel(event.phase)} · ${event.displayName} 已发完`)
        break
      case 'message':
        setLiveDrafts((current) => current.filter((draft) => draft.id !== event.message.id))
        setStreamMessages((current) => upsertMessage(current, event.message))
        break
      case 'summary_started':
        setPhaseLabel('总结阶段')
        setLiveSummaryText('')
        break
      case 'summary_delta':
        if (event.channel === 'text') {
          setLiveSummaryText(event.accumulatedText)
        }
        break
      case 'summary':
        setLiveSummaryText(event.summary.consensus)
        break
      case 'done': {
        const shouldAutoResume = event.result.status === 'interrupted' && autoResumeAfterInterruptRef.current
        autoResumeAfterInterruptRef.current = false

        setCurrentRun(event.result)
        setCurrentLinks(event.links)
        setStreamMessages(event.result.messages)
        setLiveDrafts([])
        setLiveSummaryText('')
        setStreaming(false)
        setInterrupting(false)
        setActiveSessionId(event.result.sessionId ?? '')
        void (async () => {
          try {
            setHistory(await loadArenaHistory(8))
          } catch {
            setHistory([])
          }
        })()
        if (shouldAutoResume) {
          setPhaseLabel('人工引导已接入，重新继续中')
          window.setTimeout(() => {
            void startArena(true, event.result)
          }, 0)
        }
        break
      }
      case 'error':
        autoResumeAfterInterruptRef.current = false
        setError(event.error)
        setStreaming(false)
        setInterrupting(false)
        break
      default:
        break
    }
  }

  function resolveRunPayload(baseRun?: ArenaRun | null) {
    if (selectedAgents.length >= 2) {
      return {
        agents: allArenaAgents,
        selectedAgentIds,
      }
    }

    const fallbackRun = baseRun ?? currentRun

    if (fallbackRun?.participants.length && fallbackRun.participants.length >= 2) {
      return {
        agents: fallbackRun.participants,
        selectedAgentIds: fallbackRun.participants.map((participant) => participant.agentId),
      }
    }

    return null
  }

  async function startArena(continueFromCurrent: boolean, baseRunOverride?: ArenaRun | null) {
    const continuedRun = continueFromCurrent ? baseRunOverride ?? currentRun : null
    const payload = resolveRunPayload(continuedRun)
    if (!payload) {
      setError('至少选择两个阶段人格，或者先载入一场可继续的历史讨论')
      return
    }

    if (!topic.trim()) {
      setError('请先填写议题')
      return
    }

    setError('')
    setPosterResponse(null)
    setStreaming(true)
    setInterrupting(false)
    setCurrentLinks(undefined)
    setLiveDrafts([])
    setLiveSummaryText('')
    setPhaseLabel('即将开场')
    setActiveCenterView('chat')
    setCurrentRun((previous) => (continueFromCurrent ? continuedRun ?? previous : null))
    setStreamMessages(continueFromCurrent && continuedRun ? [...continuedRun.messages] : [])

    streamAbortRef.current?.abort()
    const controller = new AbortController()
    streamAbortRef.current = controller

    try {
      await runArenaStream(
        {
          topic: topic.trim(),
          mode: arenaMode,
          selectedAgentIds: payload.selectedAgentIds,
          agents: payload.agents,
          roundCount,
          maxMessageChars,
          guidance: guidance.trim() || undefined,
          continueFromRunId: continueFromCurrent ? continuedRun?.runId : undefined,
          sessionId: continueFromCurrent ? continuedRun?.sessionId : undefined,
        },
        {
          signal: controller.signal,
          onEvent: handleArenaEvent,
        },
      )
    } catch (caughtError) {
      if (controller.signal.aborted) {
        return
      }
      setError(caughtError instanceof Error ? caughtError.message : '讨论失败')
      setStreaming(false)
      setInterrupting(false)
    }
  }

  async function handleInterrupt(resumeAfterInterrupt = false) {
    if (!streaming || interrupting) {
      return
    }

    if (!activeSessionId) {
      setError('会话尚未建立，暂时不能打断')
      return
    }

    setError('')
    setInterrupting(true)
    autoResumeAfterInterruptRef.current = resumeAfterInterrupt
    setPhaseLabel(resumeAfterInterrupt ? '人工介入中，等待安全停下' : '正在打断')

    try {
      await interruptArenaSession(activeSessionId)
    } catch (caughtError) {
      autoResumeAfterInterruptRef.current = false
      setInterrupting(false)
      setError(caughtError instanceof Error ? caughtError.message : '中断失败')
    }
  }

  async function handleLoadRun(runId: string) {
    setError('')
    streamAbortRef.current?.abort()
    setStreaming(false)
    setInterrupting(false)

    try {
      const response = await loadArenaRun(runId)
      setCurrentRun(response.result)
      setCurrentLinks(response.links)
      setPosterResponse(null)
      setTopic(response.result.topic)
      setArenaMode(response.result.mode)
      setRoundCount(response.result.config?.roundCount ?? 3)
      setMaxMessageChars(response.result.config?.maxMessageChars ?? 180)
      setActiveSessionId(response.result.sessionId ?? '')
      setPhaseLabel(response.result.status === 'interrupted' ? '已载入被打断的结果' : '已载入历史结果')
      setStreamMessages(response.result.messages)
      setLiveDrafts([])
      setLiveSummaryText('')
      setActiveCenterView('chat')
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '载入历史讨论失败')
    }
  }

  async function handleGeneratePoster() {
    if (!currentRun) {
      return
    }

    setPosterLoading(true)
    setError('')

    try {
      setPosterResponse(await generateArenaPoster({ runId: currentRun.runId }))
    } catch (caughtError) {
      setError(caughtError instanceof Error ? caughtError.message : '海报生成失败')
    } finally {
      setPosterLoading(false)
    }
  }

  async function handleCopyShare() {
    if (!currentRun) {
      return
    }

    const url = buildSuggestedShareUrl(currentLinks, currentRun.runId)
    await navigator.clipboard.writeText(url)
  }

  function handleOpenShare() {
    if (!currentRun) {
      return
    }

    window.open(buildSuggestedShareUrl(currentLinks, currentRun.runId), '_blank', 'noopener,noreferrer')
  }

  const leftColumn = leftSidebarCollapsed ? '68px' : `${leftWidth}px`
  const rightColumn = rightSidebarCollapsed ? '68px' : `${rightWidth}px`

  return (
    <div className="arena-shell" style={{ gridTemplateColumns: `${leftColumn} 14px minmax(0, 1fr) 14px ${rightColumn}` }}>
      <aside className={`arena-sidebar ${leftSidebarCollapsed ? 'is-collapsed' : ''}`}>
        {leftSidebarCollapsed ? (
          <button className="sidebar-rail-button" onClick={() => setLeftSidebarCollapsed(false)} type="button">
            <span>展开</span>
            <strong>素材 / 历史</strong>
          </button>
        ) : (
          <>
            <div className="sidebar-head">
              <div>
                <p className="eyebrow">{leftSidebarTab === 'sources' ? 'Source Dock' : 'History Deck'}</p>
                <h2>{leftSidebarTab === 'sources' ? '人格素材' : '最近讨论'}</h2>
              </div>
              <div className="sidebar-actions">
                {leftSidebarTab === 'sources' ? (
                  <button className="ghost-toggle" onClick={() => setShowImportForm((current) => !current)} type="button">
                    {showImportForm ? '收起导入' : '导入人物'}
                  </button>
                ) : null}
                <button className="ghost-toggle" onClick={() => setLeftSidebarCollapsed(true)} type="button">
                  隐藏
                </button>
              </div>
            </div>
            <div className="sidebar-tabs">
              <button
                className={`sidebar-tab ${leftSidebarTab === 'sources' ? 'is-active' : ''}`}
                onClick={() => setLeftSidebarTab('sources')}
                type="button"
              >
                人格素材
              </button>
              <button
                className={`sidebar-tab ${leftSidebarTab === 'history' ? 'is-active' : ''}`}
                onClick={() => setLeftSidebarTab('history')}
                type="button"
              >
                最近讨论
              </button>
            </div>

            <div className="sidebar-scroll">
              {leftSidebarTab === 'sources' ? (
                <SourcePanel
                  allProfiles={allProfiles}
                  expandedIds={expandedIds}
                  importBio={importBio}
                  importName={importName}
                  loadedCharacters={loadedCharacters}
                  loadingLabel={loadingLabel}
                  mergeCandidates={mergeCandidates}
                  mergeDisplayName={mergeDisplayName}
                  mergeLoading={mergeLoading}
                  mergePrimaryAgentId={mergePrimaryAgentId}
                  mergePrompt={mergePrompt}
                  mergeSecondaryAgentId={mergeSecondaryAgentId}
                  mergedAgents={mergedAgents}
                  onImport={handleImport}
                  onMerge={() => void handleMergeAgents()}
                  onRemoveMergedAgent={handleRemoveMergedAgent}
                  onSelectProfile={handleSelectProfile}
                  onToggleAgent={toggleAgent}
                  selectedAgentIds={selectedAgentIds}
                  setImportBio={setImportBio}
                  setImportName={setImportName}
                  setMergeDisplayName={setMergeDisplayName}
                  setMergePrimaryAgentId={setMergePrimaryAgentId}
                  setMergePrompt={setMergePrompt}
                  setMergeSecondaryAgentId={setMergeSecondaryAgentId}
                  showImportForm={showImportForm}
                />
              ) : (
                <HistoryPanel history={history} onLoadRun={handleLoadRun} />
              )}
            </div>
          </>
        )}
      </aside>

      <Divider
        side="left"
        onDrag={(delta) => {
          if (!leftSidebarCollapsed) {
            setLeftWidth((current) => Math.max(280, Math.min(420, current + delta)))
          }
        }}
      />

      <StreamPanel
        arenaMode={arenaMode}
        activeSessionId={activeSessionId}
        currentRun={currentRun}
        displayAgents={displayAgents}
        error={error}
        guidance={guidance}
        interrupting={interrupting}
        liveDrafts={liveDrafts}
        liveSummaryText={liveSummaryText}
        maxMessageChars={maxMessageChars}
        activeCenterView={activeCenterView}
        onChangeCenterView={setActiveCenterView}
        onContinue={() => void startArena(true)}
        onInterrupt={(resumeAfterInterrupt) => void handleInterrupt(resumeAfterInterrupt)}
        onStart={() => void startArena(false)}
        onToggleAgent={toggleAgent}
        phaseLabel={phaseLabel}
        roundCount={roundCount}
        setArenaMode={setArenaMode}
        setGuidance={setGuidance}
        setMaxMessageChars={(value) => setMaxMessageChars(Math.max(60, Math.min(500, value)))}
        setRoundCount={(value) => setRoundCount(Math.max(1, Math.min(20, value)))}
        setTopic={setTopic}
        statusLabel={getStatusLabel(currentRun, streaming, interrupting)}
        streamMessages={streamMessages}
        streaming={streaming}
        topic={topic}
      />

      <Divider
        side="right"
        onDrag={(delta) => {
          if (!rightSidebarCollapsed) {
            setRightWidth((current) => Math.max(320, Math.min(440, current - delta)))
          }
        }}
      />

      <aside className={`arena-output ${rightSidebarCollapsed ? 'is-collapsed' : ''}`}>
        {rightSidebarCollapsed ? (
          <button className="sidebar-rail-button" onClick={() => setRightSidebarCollapsed(false)} type="button">
            <span>展开</span>
            <strong>结果 / 分享</strong>
          </button>
        ) : (
          <>
            <div className="sidebar-head">
              <div>
                <p className="eyebrow">Output Deck</p>
                <h2>结果与分享</h2>
              </div>
              <div className="sidebar-actions">
                <button className="ghost-toggle" onClick={() => setRightSidebarCollapsed(true)} type="button">
                  隐藏
                </button>
              </div>
            </div>
            <div className="sidebar-scroll">
              <OutputPanel
                currentRun={currentRun}
                links={currentLinks}
                onCopyShare={() => void handleCopyShare()}
                onGeneratePoster={() => void handleGeneratePoster()}
                onLoadRun={handleLoadRun}
                onOpenShare={handleOpenShare}
                poster={posterResponse}
                posterLoading={posterLoading}
              />
            </div>
          </>
        )}
      </aside>
    </div>
  )
}
