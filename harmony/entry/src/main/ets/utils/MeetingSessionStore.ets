/**
 * MeetingSessionStore - 页面间传递会议相关数据
 * 支持单场会议关联多个人物（多个 profileId），每人可有多个阶段人格 agent
 */
export class MeetingSessionStore {
  private static _profileId: string = ''
  private static _profileIds: string[] = []
  private static _selectedAgentIds: string[] = []
  private static _topic: string = ''
  /** 会议对话轮数，0 表示未设置（页面用默认） */
  private static _roundCount: number = 0
  /** 从「添加人物」页返回时写入，参会页 onPageShow 消费后清空 */
  private static _pendingAddProfileId: string = ''

  static setProfileId(profileId: string): void {
    MeetingSessionStore._profileId = profileId
  }

  static getProfileId(): string {
    return MeetingSessionStore._profileId
  }

  static setProfileIds(ids: string[]): void {
    MeetingSessionStore._profileIds = [...ids]
    if (ids.length > 0) {
      MeetingSessionStore._profileId = ids[0]
    }
  }

  static getProfileIds(): string[] {
    return [...MeetingSessionStore._profileIds]
  }

  static setPendingAddProfileId(profileId: string): void {
    MeetingSessionStore._pendingAddProfileId = profileId
  }

  static takePendingAddProfileId(): string {
    const v = MeetingSessionStore._pendingAddProfileId
    MeetingSessionStore._pendingAddProfileId = ''
    return v
  }

  static setSelectedAgents(ids: string[]): void {
    MeetingSessionStore._selectedAgentIds = [...ids]
  }

  static getSelectedAgents(): string[] {
    return [...MeetingSessionStore._selectedAgentIds]
  }

  static setTopic(topic: string): void {
    MeetingSessionStore._topic = topic
  }

  static getTopic(): string {
    return MeetingSessionStore._topic
  }

  static setRoundCount(count: number): void {
    const n = Math.floor(count)
    if (n >= 5 && n <= 25) {
      MeetingSessionStore._roundCount = n
    }
  }

  static getRoundCount(): number {
    return MeetingSessionStore._roundCount
  }

  static clear(): void {
    MeetingSessionStore._profileId = ''
    MeetingSessionStore._profileIds = []
    MeetingSessionStore._selectedAgentIds = []
    MeetingSessionStore._topic = ''
    MeetingSessionStore._roundCount = 0
    MeetingSessionStore._pendingAddProfileId = ''
  }
}