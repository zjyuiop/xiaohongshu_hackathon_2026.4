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
} from './types'

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
  const highlightGroups = messageGroups.slice(-3).map((group) => ({
    ...group,
    messages: group.messages.slice(-2),
  }))

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
            <Link className="share-btn share-btn-primary" to={infographicUrl}>
              查看信息图海报
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
            <section className="share-hero share-hero-focused">
              <div className="share-hero-copy">
                <p className="share-kicker">Share / {run.mode === 'debate' ? '辩论场' : '对谈场'}</p>
                <h1 className="share-title">{run.summary.title}</h1>
                <p className="share-lead">{run.summary.narrativeHook || run.summary.consensus}</p>

                <div className="share-chip-row">
                  <span className="share-chip">{run.participants.length} 位参与者</span>
                  <span className="share-chip">{roundCount} 轮</span>
                  <span className="share-chip">{run.mode === 'debate' ? '观点交锋' : '多阶段对谈'}</span>
                  <span className={`share-chip share-chip-status ${run.status === 'interrupted' ? 'is-warn' : 'is-ok'}`}>
                    {run.status === 'interrupted' ? '阶段性结果' : '完整结果'}
                  </span>
                </div>

                <div className="share-hero-actions">
                  <Link className="share-btn share-btn-primary" to={infographicUrl}>
                    查看信息图海报
                  </Link>
                  <button className="share-btn share-btn-secondary" type="button" onClick={handleCopyInfographicLink}>
                    复制海报链接
                  </button>
                </div>
              </div>

              <aside className="share-hero-aside share-cast-panel">
                <p className="share-card-eyebrow">参与角色</p>
                <div className="share-cast-list">
                  {run.participants.map((participant) => (
                    <article className="share-cast-item" key={participant.agentId}>
                      <strong>{participant.displayName}</strong>
                      <span>{participant.stageLabel}</span>
                    </article>
                  ))}
                </div>
              </aside>
            </section>

            <div className="share-story-stack">
              <section className="share-card share-focus-card">
                <div className="share-card-header">
                  <div>
                    <p className="share-card-eyebrow">这场讨论最后落在</p>
                    <h2 className="share-card-title">一个结论，三条行动</h2>
                  </div>
                </div>

                <p className="share-topic">{run.topic}</p>
                <p className="share-quote">{run.summary.consensus}</p>
                {run.summary.moderatorNote ? <p className="share-note">{run.summary.moderatorNote}</p> : null}

                <div className="share-summary-grid">
                  <article className="share-subcard">
                    <p className="share-mini-title">建议现在就做</p>
                    <ul className="share-list">
                      {run.summary.actionableAdvice.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  </article>
                  <article className="share-subcard">
                    <p className="share-mini-title">仍然需要面对</p>
                    <ul className="share-list">
                      {run.summary.disagreements.length > 0 ? run.summary.disagreements.map((item) => <li key={item}>{item}</li>) : <li>当前没有新的明显分歧</li>}
                    </ul>
                  </article>
                </div>
              </section>

              {run.summary.debateVerdict && (
                <section className="share-card">
                  <div className="share-card-header">
                    <div>
                      <p className="share-card-eyebrow">裁判结论</p>
                      <h2 className="share-card-title">{run.summary.debateVerdict.winnerDisplayName ?? '未指明胜者'}</h2>
                    </div>
                  </div>
                  <p className="share-note share-note-strong">{run.summary.debateVerdict.rationale}</p>
                </section>
              )}

              <section className="share-card">
                <div className="share-card-header">
                  <div>
                    <p className="share-card-eyebrow">关键片段</p>
                    <h2 className="share-card-title">只保留最值得看的几段</h2>
                  </div>
                </div>

                <div className="share-message-list">
                  {highlightGroups.map((group) => (
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
                            {message.replyToDisplayName ? <span>回应 {message.replyToDisplayName}</span> : null}
                          </div>
                          <p className="share-message-body">{message.content}</p>
                        </article>
                      ))}
                    </div>
                  ))}
                </div>
              </section>
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
            <section className="share-hero share-hero-solo">
              <div className="share-hero-copy">
                <p className="share-kicker">Infographic / {run.mode === 'debate' ? '辩论场' : '对谈场'}</p>
                <h1 className="share-title">{run.summary.title}</h1>
                <p className="share-lead">这里专门负责信息图的生成、展示与下载。只保留看图、换风格、重新生成这几个必要动作。</p>

                <div className="share-chip-row">
                  <span className="share-chip">{posterStyle}</span>
                  <span className="share-chip">{posterAspectRatio}</span>
                  <span className={`share-chip share-chip-status ${run.status === 'interrupted' ? 'is-warn' : 'is-ok'}`}>
                    {run.status === 'interrupted' ? '中断结果' : '完整结果'}
                  </span>
                </div>
              </div>
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
                      <h2 className="share-card-title">风格与比例</h2>
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
                      <p className="share-card-eyebrow">说明</p>
                      <h2 className="share-card-title">当前输出</h2>
                    </div>
                  </div>

                  <div className="share-config-grid">
                    <ConfigRow label="标题" value={poster?.title ?? run.summary.title} />
                    <ConfigRow label="风格" value={poster?.stylePreset ?? posterStyle} />
                    <ConfigRow label="比例" value={poster?.aspectRatio ?? posterAspectRatio} />
                    <ConfigRow label="状态" value={poster ? '已生成' : posterState.status === 'loading' ? '生成中' : '待生成'} />
                  </div>

                  <p className="share-note share-file-note">
                    海报生成后可直接在左侧预览；需要单独发送时，使用“复制当前链接”或“下载海报”即可。
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
  const extensionMatch = poster.imagePath.match(/\.([a-z0-9]+)$/i)
  const extension = extensionMatch?.[1]?.toLowerCase() ?? 'svg'
  return `${baseName}-${poster.stylePreset}-${poster.aspectRatio.replace(/[:.]/g, '-')}.${extension}`
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
