import { PersonaSpec } from '../common/Models'

/** 会议流程中不展示、不可选的人格阶段（与 PersonaSpec.stageLabel 一致） */
export const EXCLUDED_MEETING_STAGE_LABELS: string[] = [
  '不作逢迎',
  '珠穆朗玛峰',
  '解体',
  '不眠之夜'
]

export function filterAgentsForMeeting(agents: PersonaSpec[]): PersonaSpec[] {
  const excluded = new Set(EXCLUDED_MEETING_STAGE_LABELS)
  return agents.filter((agent: PersonaSpec) => !excluded.has(agent.stageLabel))
}
