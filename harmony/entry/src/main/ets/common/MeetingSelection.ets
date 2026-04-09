import { RouteParams } from './Models'

/**
 * 会议选择状态接口
 */
export interface MeetingSelectionState {
  profileIds: string[]
  selectedAgentIds: string[]
}

export const MAX_MEETING_PARTICIPANTS: number = 3

function normalizeStringArray(values: string[]): string[] {
  const unique: string[] = []
  for (const value of values) {
    const normalized = value.trim()
    if (normalized.length > 0 && !unique.includes(normalized)) {
      unique.push(normalized)
    }
  }
  return unique
}

export function encodeRouteStringArray(values: string[]): string {
  return encodeURIComponent(JSON.stringify(normalizeStringArray(values)))
}

export function parseRouteStringArray(raw?: string): string[] {
  if (!raw || raw.trim().length === 0) {
    return []
  }

  try {
    const decoded = decodeURIComponent(raw)
    const parsed = JSON.parse(decoded) as Object
    if (Array.isArray(parsed)) {
      return normalizeStringArray(parsed as string[])
    }
  } catch (_error) {
    // Fallback for legacy comma-separated params
  }

  return normalizeStringArray(raw.split(','))
}

export function mergeUniqueStrings(...groups: string[][]): string[] {
  let merged: string[] = []
  for (const group of groups) {
    merged = normalizeStringArray([...merged, ...group])
  }
  return merged
}

export function parseMeetingSelection(params: RouteParams): MeetingSelectionState {
  return {
    profileIds: parseRouteStringArray(params.profileIds),
    selectedAgentIds: parseRouteStringArray(params.selectedAgentIds)
  }
}

export function buildMeetingRouteParams(
  selection: MeetingSelectionState,
  extras?: RouteParams
): RouteParams {
  const nextParams: RouteParams = {}
  if (extras) {
    nextParams.profileIds = extras.profileIds
    nextParams.selectedAgentIds = extras.selectedAgentIds
    nextParams.topic = extras.topic
    nextParams.roundCount = extras.roundCount
    nextParams.arenaRunId = extras.arenaRunId
    nextParams.debateTopic = extras.debateTopic
    nextParams.returnToMeeting = extras.returnToMeeting
    nextParams.mergedAgentsJson = extras.mergedAgentsJson
    nextParams.workbenchJson = extras.workbenchJson
  }
  nextParams.profileIds = encodeRouteStringArray(selection.profileIds)
  nextParams.selectedAgentIds = encodeRouteStringArray(selection.selectedAgentIds)
  return nextParams
}