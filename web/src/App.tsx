import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Link, Navigate, Route, Routes, useNavigate, useParams, useSearchParams } from 'react-router-dom'

import './App.css'
import ArenaStudio from './pages/ArenaStudio'
import { buildSuggestedShareUrl, generateArenaPoster, loadArenaRun } from './lib/api'
import type {
  ArenaMessage,
  ArenaOutputLinks,
  ArenaPosterAsset,
  ArenaRun,
  PosterAspectRatio,
  PosterStylePreset,
  ReasoningEffort,
} from './types'

const reasoningEffortLabels: Record<ReasoningEffort, string> = {
  low: '快',
  medium: '均衡',
  high: '深入',
  xhigh: '极深',
}

const stanceLabels: Record<NonNullable<ArenaMessage['stance']>, string> = {
  support: '支持',
  oppose: '反对',
  reflective: '反思',
  neutral: '中立',
}

const phaseLabels: Record<string, string> = {
  opening: '开场',
  reflection: '反思',
  rebuttal: '交锋',
  synthesis: '收束',
  closing: '收尾',
}

const posterStyleOptions: Array<{ value: PosterStylePreset; label: string; note: string }> = [
  { value: 'poster', label: 'Poster', note: '高对比、强标题感' },
  { value: 'editorial', label: 'Editorial', note: '纸感、克制、杂志化' },
  { value: 'cinematic', label: 'Cinematic', note: '暗场、光晕、戏剧化' },
]

const posterRatioOptions: Array<{ value: PosterAspectRatio; label: string }> = [
  { value: '3:4', label: '3:4' },
  { value: '16:9', label: '16:9' },
  { value: '1:1', label: '1:1' },
  { value: '4:3', label: '4:3' },
  { value: '3:2', label: '3:2' },
  { value: '2.35:1', label: '2.35:1' },
]

type LoadState =
  | { status: 'loading' }
  | { status: 'ready'; run: ArenaRun; links?: ArenaOutputLinks }
  | { status: 'error'; error: string }

type PosterState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ready'; poster: ArenaPosterAsset }
  | { status: 'error'; error: string }

function App() {
  return (
    <Routes>
      <Route path="/" element={<ArenaStudio />} />
      <Route path="/share" element={<LandingPage />} />
      <Route path="/share/:runId" element={<SharePage />} />
      <Route path="/share/:runId/infographic" element={<InfographicPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

function LandingPage() {
  const navigate = useNavigate()
  const [runId, setRunId] = useState('')

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const trimmedRunId = runId.trim()
    if (!trimmedRunId) {
      return
    }

    navigate(`/share/${encodeURIComponent(trimmedRunId)}`)
  }

  return (
    <div className="landing-page">
      <div className="share-atmosphere" />
      <div className="share-shell landing-shell">
        <header className="share-topbar">
          <Link to="/" className="share-brand">
            <span className="share-brand-mark" />
            <span>Time Persona Arena</span>
          </Link>
          <div className="share-topbar-right">
            <span className="share-topbar-chip">只需输入 `runId`</span>
          </div>
        </header>

        <section className="landing-hero">
          <div className="landing-copy">
            <p className="share-kicker">Arena Share Viewer</p>
            <h1>把一场讨论做成能回放、能分享、能出海报的页面。</h1>
            <p className="landing-lead">
              输入 `runId` 就能查看保存后的讨论记录。页面会直接拉取服务端结果、展示参与者、回放消息、生成海报，不再依赖临时内存态。
            </p>

            <form className="landing-form" onSubmit={handleSubmit}>
              <label className="landing-label" htmlFor="run-id">
                Run ID
              </label>
              <div className="landing-form-row">
                <input
                  id="run-id"
                  className="share-input landing-input"
                  placeholder="例如 run-1775639352301"
                  value={runId}
                  onChange={(event) => setRunId(event.target.value)}
                />
                <button className="share-btn share-btn-primary" type="submit">
                  打开回放
                </button>
              </div>
              <p className="landing-hint">示例路径：`/share/run-1775639352301`</p>
            </form>
          </div>

          <div className="landing-grid">
            <article className="landing-card">
              <p className="landing-card-kicker">回放</p>
              <h2>逐轮消息 + 人物立场</h2>
              <p>把讨论按轮次重建，保留对话节奏、阶段标签和回应关系。</p>
            </article>
            <article className="landing-card">
              <p className="landing-card-kicker">海报</p>
              <h2>一键生成分享图</h2>
              <p>支持 poster / editorial / cinematic 三种视觉气质，适合直接转发。</p>
            </article>
            <article className="landing-card">
              <p className="landing-card-kicker">资料</p>
              <h2>参与者与参数都可见</h2>
              <p>会话配置、总结、裁判结论和生成结果放在同一页里，减少来回切换。</p>
            </article>
          </div>
        </section>
      </div>
    </div>
  )
}

function SharePage() {
  const { runId } = useParams<{ runId: string }>()
  const navigate = useNavigate()
  const [loadState, setLoadState] = useState<LoadState>({ status: 'loading' })
  const [toastMessage, setToastMessage] = useState('')
  const toastTimerRef = useRef<number | null>(null)

  useEffect(() => {
    const trimmedRunId = runId?.trim()
    if (!trimmedRunId) {
      return
    }

    let active = true
    queueMicrotask(() => {
      if (!active) {
        return
      }

      setLoadState({ status: 'loading' })
      window.scrollTo({ top: 0, behavior: 'auto' })
      document.title = '正在加载分享页'
    })

    void (async () => {
      try {
        const result = await loadArenaRun(trimmedRunId)
        if (!active) {
          return
        }

        setLoadState({ status: 'ready', run: result.result, links: result.links })
        document.title = `${result.result.summary.title} · Arena Share`
      } catch (error) {
        if (!active) {
          return
        }

        const message = error instanceof Error ? error.message : '加载分享页失败'
        setLoadState({ status: 'error', error: message })
        document.title = '分享页加载失败'
      }
    })()

    return () => {
      active = false
    }
  }, [runId])

  useEffect(() => {
    return () => {
      if (toastTimerRef.current !== null) {
        window.clearTimeout(toastTimerRef.current)
      }
    }
  }, [])

  const run = loadState.status === 'ready' ? loadState.run : null
  const links = loadState.status === 'ready' ? loadState.links : undefined
  const shareUrl = buildSuggestedShareUrl(links, run?.runId ?? runId ?? 'share')
  const infographicUrl = run ? buildInfographicUrl(run.runId) : buildInfographicUrl(runId ?? 'share')
  const messageGroups = run ? groupMessagesByRound(run.messages) : []
  const roundCount = run ? countRounds(run.messages) : 0
  const messageCount = run?.messages.length ?? 0
  const statusLabel = run?.status === 'interrupted' ? '已中断' : '已完成'

  function notify(message: string) {
    setToastMessage(message)
    if (toastTimerRef.current !== null) {
      window.clearTimeout(toastTimerRef.current)
    }

    toastTimerRef.current = window.setTimeout(() => {
      setToastMessage('')
    }, 2200)
  }

  async function handleCopyShareLink() {
    if (!run) {
      return
    }

    await writeClipboardText(shareUrl)
    notify('分享链接已复制')
  }

  async function handleCopyTranscript() {
    if (!run) {
      return
    }

    await writeClipboardText(buildTranscriptText(run))
    notify('回放文本已复制')
  }

  async function handleCopyInfographicLink() {
    if (!run) {
      return
    }

    await writeClipboardText(asAbsoluteUrl(infographicUrl))
    notify('信息图页链接已复制')
  }

  if (!runId?.trim()) {
    return <Navigate to="/" replace />
  }

  return (
    <div className="share-page">
      <div className="share-atmosphere" />
      <div className="share-shell">
        <header className="share-topbar">
          <Link to="/" className="share-brand">
            <span className="share-brand-mark" />
            <span>Time Persona Arena</span>
          </Link>
          <div className="share-topbar-right">
            <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyShareLink} disabled={!run}>
              复制分享链接
            </button>
            <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyTranscript} disabled={!run}>
              复制回放文本
            </button>
            <Link className="share-btn share-btn-primary" to={infographicUrl}>
              打开信息图页
            </Link>
          </div>
        </header>

        {loadState.status === 'loading' && <LoadingState />}

        {loadState.status === 'error' && (
          <section className="share-card share-empty-state">
            <p className="share-kicker">Share unavailable</p>
            <h1 className="share-title share-title-small">这条回放暂时无法加载。</h1>
            <p className="share-lead">{loadState.error}</p>
            <div className="share-inline-actions">
              <button className="share-btn share-btn-primary" type="button" onClick={() => navigate('/')}>
                返回首页
              </button>
              <button className="share-btn share-btn-secondary" type="button" onClick={() => window.location.reload()}>
                重试加载
              </button>
            </div>
          </section>
        )}

        {run && (
          <>
            <section className="share-hero">
              <div className="share-hero-copy">
                <p className="share-kicker">Share / {run.mode === 'debate' ? '辩论场' : '对谈场'}</p>
                <h1 className="share-title">{run.summary.title}</h1>
                <p className="share-lead">{run.summary.narrativeHook || run.summary.consensus}</p>

                <div className="share-chip-row">
                  <span className="share-chip">{run.topic}</span>
                  <span className="share-chip">{run.participants.length} 位参与者</span>
                  <span className="share-chip">{run.messages.length} 条消息</span>
                  <span className="share-chip">{roundCount} 轮</span>
                  <span className={`share-chip share-chip-status ${run.status === 'interrupted' ? 'is-warn' : 'is-ok'}`}>
                    {statusLabel}
                  </span>
                </div>
              </div>

              <aside className="share-hero-aside">
                <div className="share-stat-grid">
                  <StatCard label="Run ID" value={run.runId} />
                  <StatCard label="Session" value={run.sessionId ?? '—'} />
                  <StatCard label="创建时间" value={formatDateTime(run.createdAt)} />
                  <StatCard label="模式" value={run.mode === 'debate' ? '辩论' : '对谈'} />
                </div>

                <div className="share-trace">
                  <p className="share-trace-label">当前链接</p>
                  <p className="share-trace-value">{shareUrl}</p>
                </div>

                <div className="share-launch-card">
                  <p className="share-card-eyebrow">信息图</p>
                  <h3 className="share-launch-title">独立预览与下载页</h3>
                  <p className="share-launch-copy">
                    这里把海报预览、风格切换、下载与打开动作集中到一页，避免分享页继续变得拥挤。
                  </p>
                  <div className="share-inline-actions">
                    <Link className="share-btn share-btn-primary" to={infographicUrl}>
                      进入信息图页
                    </Link>
                    <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyInfographicLink}>
                      复制信息图链接
                    </button>
                  </div>
                </div>
              </aside>
            </section>

            <div className="share-layout">
              <main className="share-main">
                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">总览</p>
                      <h2 className="share-card-title">回放摘要</h2>
                      <p className="share-note">摘要与对话分开展示，方便先看结论，再回看细节。</p>
                    </div>
                  </div>

                  <div className="share-summary-grid">
                    <article className="share-subcard">
                      <p className="share-mini-title">议题</p>
                      <p className="share-topic">{run.topic}</p>
                    </article>
                    <article className="share-subcard">
                      <p className="share-mini-title">阶段共识</p>
                      <p className="share-quote">{run.summary.consensus}</p>
                      {run.summary.moderatorNote && <p className="share-note">{run.summary.moderatorNote}</p>}
                    </article>
                    <article className="share-subcard">
                      <p className="share-mini-title">分歧</p>
                      <ul className="share-list">
                        {run.summary.disagreements.length > 0 ? run.summary.disagreements.map((item) => <li key={item}>{item}</li>) : <li>暂无显著分歧</li>}
                      </ul>
                    </article>
                    <article className="share-subcard">
                      <p className="share-mini-title">行动建议</p>
                      <ul className="share-list">
                        {run.summary.actionableAdvice.map((item) => (
                          <li key={item}>{item}</li>
                        ))}
                      </ul>
                    </article>
                  </div>
                </section>

                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">回放</p>
                      <h2 className="share-card-title">逐轮对话</h2>
                    </div>
                    <span className="share-chip">{messageCount} 条消息</span>
                  </div>

                  <div className="share-message-list">
                    {messageGroups.map((group) => (
                      <div className="share-message-group" key={group.round}>
                        <div className="share-round-label">{group.round === 0 ? '实时引导' : `第 ${group.round} 轮`}</div>
                        {group.messages.map((message) => (
                          <article
                            key={message.id}
                            className={`share-message share-message-${toneClass(message.stance)} ${message.kind === 'user' ? 'share-message-user' : ''}`}
                          >
                            <div className="share-message-meta">
                              <span>{message.displayName}</span>
                              <span>{message.stageLabel}</span>
                              <span>{phaseLabels[message.phase ?? ''] ?? '消息'}</span>
                              <span>{stanceLabels[message.stance]}</span>
                              {message.replyToDisplayName && <span>回应 {message.replyToDisplayName}</span>}
                            </div>
                            <p className="share-message-body">{message.content}</p>
                          </article>
                        ))}
                      </div>
                    ))}
                  </div>
                </section>

                {run.summary.debateVerdict && (
                  <section className="share-card">
                    <div className="share-card-header">
                      <div>
                        <p className="share-card-eyebrow">裁判</p>
                        <h2 className="share-card-title">辩论结论</h2>
                      </div>
                    </div>
                    <p className="share-quote">胜者：{run.summary.debateVerdict.winnerDisplayName ?? '未指明'}</p>
                    <p className="share-note">{run.summary.debateVerdict.rationale}</p>
                    <div className="share-scorecard-list">
                      {run.summary.debateVerdict.scorecards.map((scorecard) => (
                        <div className="share-scorecard" key={scorecard.agentId}>
                          <div className="share-scorecard-top">
                            <strong>{scorecard.displayName}</strong>
                            <span>
                              {scorecard.argumentScore} / {scorecard.evidenceScore} / {scorecard.responsivenessScore}
                            </span>
                          </div>
                          <p>{scorecard.comments}</p>
                        </div>
                      ))}
                    </div>
                  </section>
                )}
              </main>

              <aside className="share-side">
                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">参与者</p>
                      <h2 className="share-card-title">人物列表</h2>
                    </div>
                  </div>
                  <div className="share-persona-grid">
                    {run.participants.map((participant, index) => (
                      <article className="share-persona" key={participant.agentId}>
                        <div className="share-persona-avatar" aria-hidden="true">
                          {String(index + 1).padStart(2, '0')}
                        </div>
                        <div className="share-persona-copy">
                          <strong>{participant.displayName}</strong>
                          <p>{participant.stageLabel}</p>
                          <span>{participant.timeLabel}</span>
                        </div>
                      </article>
                    ))}
                  </div>
                </section>

                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">参数</p>
                      <h2 className="share-card-title">会话配置</h2>
                    </div>
                  </div>
                  <div className="share-config-grid">
                    <ConfigRow label="轮数" value={run.config?.roundCount?.toString() ?? '—'} />
                    <ConfigRow label="字数上限" value={run.config?.maxMessageChars?.toString() ?? '—'} />
                    <ConfigRow
                      label="推理强度"
                      value={run.config?.reasoningEffort ? reasoningEffortLabels[run.config.reasoningEffort] : '—'}
                    />
                    <ConfigRow label="来源" value={run.continuedFromRunId ?? '首个会话'} />
                  </div>
                </section>

                <section className="share-card share-output-entry">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">信息图</p>
                      <h2 className="share-card-title">单独页面展示与下载</h2>
                    </div>
                  </div>
                  <p className="share-note">
                    分享页只保留摘要与回放。信息图被拆到独立页面，专门负责生成、预览和下载，避免继续把当前页面堆乱。
                  </p>
                  <div className="share-inline-actions">
                    <Link className="share-btn share-btn-primary" to={infographicUrl}>
                      打开信息图页
                    </Link>
                    <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyInfographicLink}>
                      复制信息图链接
                    </button>
                  </div>
                </section>
              </aside>
            </div>
          </>
        )}
      </div>

      {toastMessage && <div className="share-toast">{toastMessage}</div>}
    </div>
  )
}

function InfographicPage() {
  const { runId } = useParams<{ runId: string }>()
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const [loadState, setLoadState] = useState<LoadState>({ status: 'loading' })
  const [posterState, setPosterState] = useState<PosterState>({ status: 'idle' })
  const [posterStyle, setPosterStyle] = useState<PosterStylePreset>(() => parsePosterStyle(searchParams.get('style')))
  const [posterAspectRatio, setPosterAspectRatio] = useState<PosterAspectRatio>(() => parsePosterAspectRatio(searchParams.get('ratio')))
  const [toastMessage, setToastMessage] = useState('')
  const toastTimerRef = useRef<number | null>(null)

  useEffect(() => {
    const trimmedRunId = runId?.trim()
    if (!trimmedRunId) {
      return
    }

    let active = true
    queueMicrotask(() => {
      if (!active) {
        return
      }

      setLoadState({ status: 'loading' })
      setPosterState({ status: 'idle' })
      window.scrollTo({ top: 0, behavior: 'auto' })
      document.title = '正在加载信息图页'
    })

    void (async () => {
      try {
        const result = await loadArenaRun(trimmedRunId)
        if (!active) {
          return
        }

        setLoadState({ status: 'ready', run: result.result, links: result.links })
        document.title = `${result.result.summary.title} · Arena Infographic`
      } catch (error) {
        if (!active) {
          return
        }

        const message = error instanceof Error ? error.message : '加载信息图页失败'
        setLoadState({ status: 'error', error: message })
        document.title = '信息图页加载失败'
      }
    })()

    return () => {
      active = false
    }
  }, [runId])

  useEffect(() => {
    const nextParams = new URLSearchParams(searchParams)
    nextParams.set('style', posterStyle)
    nextParams.set('ratio', posterAspectRatio)
    setSearchParams(nextParams, { replace: true })
  }, [posterAspectRatio, posterStyle, searchParams, setSearchParams])

  useEffect(() => {
    return () => {
      if (toastTimerRef.current !== null) {
        window.clearTimeout(toastTimerRef.current)
      }
    }
  }, [])

  const run = loadState.status === 'ready' ? loadState.run : null
  const links = loadState.status === 'ready' ? loadState.links : undefined
  const infographicUrl = run ? buildInfographicUrl(run.runId, posterStyle, posterAspectRatio) : buildInfographicUrl(runId ?? 'share', posterStyle, posterAspectRatio)
  const shareUrl = run ? buildSuggestedShareUrl(links, run.runId) : buildSuggestedShareUrl(undefined, runId ?? 'share')
  const poster = posterState.status === 'ready' ? posterState.poster : null
  const posterImageUrl = poster?.imageUrl ?? ''
  const posterDownloadName = run && poster ? buildPosterDownloadName(run, poster) : ''

  const notify = useCallback((message: string) => {
    setToastMessage(message)
    if (toastTimerRef.current !== null) {
      window.clearTimeout(toastTimerRef.current)
    }

    toastTimerRef.current = window.setTimeout(() => {
      setToastMessage('')
    }, 2200)
  }, [])

  const handleGeneratePoster = useCallback(async () => {
    if (!run) {
      return
    }

    setPosterState({ status: 'loading' })
    try {
      const response = await generateArenaPoster({
        runId: run.runId,
        stylePreset: posterStyle,
        aspectRatio: posterAspectRatio,
        language: 'zh',
      })

      setPosterState({ status: 'ready', poster: response.poster })
      notify('信息图已生成')
    } catch (error) {
      const message = error instanceof Error ? error.message : '信息图生成失败'
      setPosterState({ status: 'error', error: message })
    }
  }, [notify, posterAspectRatio, posterStyle, run])

  useEffect(() => {
    if (!run || posterState.status !== 'idle') {
      return
    }

    const timer = window.setTimeout(() => {
      void handleGeneratePoster()
    }, 0)

    return () => {
      window.clearTimeout(timer)
    }
  }, [handleGeneratePoster, posterState.status, run])

  async function handleCopyInfographicLink() {
    if (!run) {
      return
    }

    await writeClipboardText(asAbsoluteUrl(infographicUrl))
    notify('信息图链接已复制')
  }

  async function handleCopyShareLink() {
    if (!run) {
      return
    }

    await writeClipboardText(shareUrl)
    notify('分享页链接已复制')
  }

  if (!runId?.trim()) {
    return <Navigate to="/" replace />
  }

  return (
    <div className="share-page infographic-page">
      <div className="share-atmosphere" />
      <div className="share-shell">
        <header className="share-topbar">
          <Link to="/" className="share-brand">
            <span className="share-brand-mark" />
            <span>Time Persona Arena</span>
          </Link>
          <div className="share-topbar-right">
            {run ? (
              <Link className="share-btn share-btn-secondary" to={`/share/${encodeURIComponent(run.runId)}`}>
                返回分享页
              </Link>
            ) : null}
            <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyShareLink} disabled={!run}>
              复制分享页链接
            </button>
            <button className="share-btn share-btn-primary" type="button" onClick={handleCopyInfographicLink} disabled={!run}>
              复制信息图链接
            </button>
          </div>
        </header>

        {loadState.status === 'loading' && <LoadingState />}

        {loadState.status === 'error' && (
          <section className="share-card share-empty-state">
            <p className="share-kicker">Infographic unavailable</p>
            <h1 className="share-title share-title-small">这条信息图暂时无法生成。</h1>
            <p className="share-lead">{loadState.error}</p>
            <div className="share-inline-actions">
              <button className="share-btn share-btn-primary" type="button" onClick={() => navigate('/')}>
                返回首页
              </button>
              <button className="share-btn share-btn-secondary" type="button" onClick={() => window.location.reload()}>
                重试加载
              </button>
            </div>
          </section>
        )}

        {run && (
          <>
            <section className="share-hero">
              <div className="share-hero-copy">
                <p className="share-kicker">Infographic / {run.mode === 'debate' ? '辩论场' : '对谈场'}</p>
                <h1 className="share-title">{run.summary.title}</h1>
                <p className="share-lead">这里专门负责信息图的生成、展示与下载。左侧预览更像画布，右侧只保留必要控制与文件动作。</p>

                <div className="share-chip-row">
                  <span className="share-chip">{run.topic}</span>
                  <span className="share-chip">{posterStyle}</span>
                  <span className="share-chip">{posterAspectRatio}</span>
                  <span className={`share-chip share-chip-status ${run.status === 'interrupted' ? 'is-warn' : 'is-ok'}`}>
                    {run.status === 'interrupted' ? '中断结果' : '完整结果'}
                  </span>
                </div>
              </div>

              <aside className="share-hero-aside">
                <div className="share-stat-grid">
                  <StatCard label="Run ID" value={run.runId} />
                  <StatCard label="Session" value={run.sessionId ?? '—'} />
                  <StatCard label="参与者" value={`${run.participants.length} 位`} />
                  <StatCard label="轮数" value={String(countRounds(run.messages))} />
                </div>

                <div className="share-trace">
                  <p className="share-trace-label">页面地址</p>
                  <p className="share-trace-value">{asAbsoluteUrl(infographicUrl)}</p>
                </div>

                <div className="share-launch-card">
                  <p className="share-card-eyebrow">输出</p>
                  <h3 className="share-launch-title">打开、下载、复用</h3>
                  <p className="share-launch-copy">
                    生成结果会保留为独立文件，支持新标签打开和直接下载。提示词与源文档也能单独查看。
                  </p>
                </div>
              </aside>
            </section>

            <div className="share-layout infographic-layout">
              <main className="share-main">
                <section className="share-card infographic-stage">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">展示</p>
                      <h2 className="share-card-title">全息信息图预览</h2>
                    </div>
                    <div className="share-stage-meta">
                      {poster ? <span className="share-chip">{formatDateTime(poster.generatedAt)}</span> : null}
                      <span className="share-chip">{poster?.title ?? run.summary.title}</span>
                    </div>
                  </div>

                  {posterState.status === 'loading' ? (
                    <div className="share-poster-empty">
                      <p>正在调用后端重新生成信息图。</p>
                      <span>这一步会读取 run 内容、渲染视觉稿，并返回独立可访问文件。</span>
                    </div>
                  ) : posterImageUrl ? (
                    <div className="infographic-preview-stage">
                      <a className="infographic-preview-shell" href={posterImageUrl} target="_blank" rel="noreferrer" aria-label="在新标签页打开信息图预览">
                        <div className="infographic-preview-frame">
                          <div className="infographic-preview-image-wrap">
                            <img alt={`${poster?.title ?? run.summary.title} 信息图预览`} className="infographic-preview-image" src={posterImageUrl} />
                          </div>
                        </div>
                      </a>

                      <div className="infographic-preview-actions">
                        <a className="share-btn share-btn-secondary" href={posterImageUrl} target="_blank" rel="noreferrer">
                          新标签打开原图
                        </a>
                        <a className="share-btn share-btn-primary" href={posterImageUrl} download={posterDownloadName}>
                          下载海报 SVG
                        </a>
                      </div>
                    </div>
                  ) : (
                    <div className="share-poster-empty">
                      <p>{posterState.status === 'error' ? '当前版本生成失败。' : '生成后，这里会展示单页信息图。'}</p>
                      <span>{posterState.status === 'error' ? posterState.error : '你可以先调整风格与比例，再重新生成。'}</span>
                    </div>
                  )}
                </section>
              </main>

              <aside className="share-side">
                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">参数</p>
                      <h2 className="share-card-title">渲染控制</h2>
                    </div>
                  </div>

                  <div className="share-poster-controls">
                    <div className="share-pill-row">
                      {posterStyleOptions.map((option) => (
                        <button
                          key={option.value}
                          className={`share-pill ${posterStyle === option.value ? 'active' : ''}`}
                          type="button"
                          onClick={() => setPosterStyle(option.value)}
                        >
                          <span>{option.label}</span>
                          <small>{option.note}</small>
                        </button>
                      ))}
                    </div>

                    <div className="share-pill-row share-pill-row-ratio">
                      {posterRatioOptions.map((option) => (
                        <button
                          key={option.value}
                          className={`share-pill share-pill-ratio ${posterAspectRatio === option.value ? 'active' : ''}`}
                          type="button"
                          onClick={() => setPosterAspectRatio(option.value)}
                        >
                          {option.label}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="share-inline-actions">
                    <button className="share-btn share-btn-primary" type="button" onClick={handleGeneratePoster} disabled={posterState.status === 'loading'}>
                      {posterState.status === 'loading' ? '正在生成...' : '重新生成'}
                    </button>
                    <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyInfographicLink}>
                      复制当前链接
                    </button>
                  </div>
                </section>

                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">文件</p>
                      <h2 className="share-card-title">输出与原始材料</h2>
                    </div>
                  </div>

                  <div className="share-inline-actions">
                    {poster?.imageUrl ? (
                      <a className="share-btn share-btn-secondary" href={poster.imageUrl} target="_blank" rel="noreferrer">
                        打开信息图文件
                      </a>
                    ) : null}
                    {poster?.promptUrl ? (
                      <a className="share-btn share-btn-secondary" href={poster.promptUrl} target="_blank" rel="noreferrer">
                        打开提示词
                      </a>
                    ) : null}
                    {poster?.sourceUrl ? (
                      <a className="share-btn share-btn-secondary" href={poster.sourceUrl} target="_blank" rel="noreferrer">
                        打开源文档
                      </a>
                    ) : null}
                  </div>

                  <div className="share-config-grid">
                    <ConfigRow label="标题" value={poster?.title ?? run.summary.title} />
                    <ConfigRow label="风格" value={poster?.stylePreset ?? posterStyle} />
                    <ConfigRow label="比例" value={poster?.aspectRatio ?? posterAspectRatio} />
                    <ConfigRow label="状态" value={poster ? '已生成' : posterState.status === 'loading' ? '生成中' : '待生成'} />
                  </div>

                  <p className="share-note share-file-note">
                    下载会优先使用当前生成的 SVG；新标签打开可用于快速检查最终构图，提示词与源文档用于二次迭代。
                  </p>
                </section>
              </aside>
            </div>
          </>
        )}
      </div>

      {toastMessage && <div className="share-toast">{toastMessage}</div>}
    </div>
  )
}

function LoadingState() {
  return (
    <section className="share-card share-loading-state" aria-busy="true">
      <div className="share-loading-orb" />
      <div>
        <p className="share-kicker">Loading</p>
        <h1 className="share-title share-title-small">正在拉取讨论回放。</h1>
        <p className="share-lead">页面会先从服务端取回 run 数据，再补充当前页面所需的操作。</p>
      </div>
    </section>
  )
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <article className="share-stat">
      <span>{label}</span>
      <strong>{value}</strong>
    </article>
  )
}

function ConfigRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="share-config-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function toneClass(stance: NonNullable<ArenaMessage['stance']>) {
  return stance
}

function parsePosterStyle(value: string | null): PosterStylePreset {
  return posterStyleOptions.some((option) => option.value === value) ? (value as PosterStylePreset) : 'poster'
}

function parsePosterAspectRatio(value: string | null): PosterAspectRatio {
  return posterRatioOptions.some((option) => option.value === value) ? (value as PosterAspectRatio) : '3:4'
}

function buildInfographicUrl(runId: string, style: PosterStylePreset = 'poster', ratio: PosterAspectRatio = '3:4') {
  const params = new URLSearchParams({
    style,
    ratio,
  })
  return `/share/${encodeURIComponent(runId)}/infographic?${params.toString()}`
}

function asAbsoluteUrl(value: string) {
  try {
    return new URL(value, window.location.origin).toString()
  } catch {
    return value
  }
}

function sanitizeFilename(value: string) {
  return value
    .trim()
    .replace(/[\\/:*?"<>|]+/g, '-')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80)
}

function buildPosterDownloadName(run: ArenaRun, poster: ArenaPosterAsset) {
  const baseName = sanitizeFilename(run.summary.title || run.runId) || run.runId
  return `${baseName}-${poster.stylePreset}-${poster.aspectRatio.replace(/[:.]/g, '-')}.svg`
}

function countRounds(messages: ArenaMessage[]) {
  const rounds = new Set<number>()
  for (const message of messages) {
    if (typeof message.round === 'number' && message.round > 0) {
      rounds.add(message.round)
    }
  }

  return rounds.size
}

function groupMessagesByRound(messages: ArenaMessage[]) {
  const grouped = new Map<number, ArenaMessage[]>()

  for (const message of messages) {
    const round = message.round ?? 0
    const bucket = grouped.get(round)
    if (bucket) {
      bucket.push(message)
    } else {
      grouped.set(round, [message])
    }
  }

  return Array.from(grouped.entries())
    .sort(([left], [right]) => left - right)
    .map(([round, items]) => ({ round, messages: items }))
}

function buildTranscriptText(run: ArenaRun) {
  const lines: string[] = [
    `【${run.summary.title}】`,
    `主题：${run.topic}`,
    `模式：${run.mode === 'debate' ? '辩论' : '对谈'}`,
    `状态：${run.status === 'interrupted' ? '已中断' : '已完成'}`,
    `参与者：${run.participants.map((participant) => participant.displayName).join('、')}`,
    '',
    '摘要',
    `- 共识：${run.summary.consensus}`,
  ]

  if (run.summary.moderatorNote) {
    lines.push(`- 主持人备注：${run.summary.moderatorNote}`)
  }

  if (run.summary.debateVerdict) {
    lines.push(`- 胜者：${run.summary.debateVerdict.winnerDisplayName ?? '未指明'}`)
    lines.push(`- 裁判理由：${run.summary.debateVerdict.rationale}`)
  }

  lines.push('')
  lines.push('分歧')
  if (run.summary.disagreements.length > 0) {
    lines.push(...run.summary.disagreements.map((item) => `- ${item}`))
  } else {
    lines.push('- 暂无显著分歧')
  }

  lines.push('')
  lines.push('建议')
  lines.push(...run.summary.actionableAdvice.map((item) => `- ${item}`))
  lines.push('')
  lines.push('回放')

  for (const message of run.messages) {
    const roundLabel = message.round ? `第 ${message.round} 轮` : '实时引导'
    const phaseLabel = phaseLabels[message.phase ?? ''] ?? '消息'
    const originLabel = message.kind === 'user' ? '引导' : message.stageLabel
    lines.push(`- [${roundLabel} / ${phaseLabel}] ${message.displayName}（${originLabel}）：${message.content}`)
  }

  return lines.join('\n')
}

async function writeClipboardText(value: string) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value)
    return
  }

  const textarea = document.createElement('textarea')
  textarea.value = value
  textarea.setAttribute('readonly', 'true')
  textarea.style.position = 'fixed'
  textarea.style.opacity = '0'
  document.body.appendChild(textarea)
  textarea.select()
  document.execCommand('copy')
  document.body.removeChild(textarea)
}

function formatDateTime(value?: string) {
  if (!value) {
    return '—'
  }

  try {
    return new Intl.DateTimeFormat('zh-CN', {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(value))
  } catch {
    return value
  }
}

export default App
