import { ThemeMode } from '../common/ThemeMode'

export type AiApiFormat = 'auto' | 'openai' | 'anthropic'

export class UserSettings {
  user_id: string = ''
  app_lock_enabled: boolean = false
  app_lock_hash: string = ''
  email_reminders: boolean = false
  remind_before_due: boolean = true
  remind_on_due_day: boolean = true
  app_lock_timeout_mins: number = 5
  ai_text_enabled: boolean = false
  ai_text_key: string = ''
  ai_text_base_url: string = ''
  ai_text_model: string = ''
  ai_text_api_format: AiApiFormat = 'auto'
  /** 测通指纹：与 key|url|model 一致时视为已接通 */
  ai_text_test_fp: string = ''
  ai_vision_enabled: boolean = false
  ai_vision_key: string = ''
  ai_vision_base_url: string = ''
  ai_vision_model: string = ''
  ai_vision_api_format: AiApiFormat = 'auto'
  ai_vision_test_fp: string = ''
  key_backup_encrypted: string = ''
  recovery_backup_encrypted: string = ''
  light_sense_enabled: boolean = false
  eye_care_enabled: boolean = false
  /** 智感握姿：是否让 AI 录入条等布局自动跟随握持手 */
  hand_awareness_enabled: boolean = true
  /** 列表页标题栏是否显示分享按钮 */
  share_enabled: boolean = true
  theme_mode: ThemeMode = 'system'
  cloud_sync_enabled: boolean = true
  /** 月度还款安全阈值（单位：分），0 = 未设置，使用 AI 自动推导 */
  monthly_budget_limit: number = 0
  /** 压力预警总开关 */
  pressure_alert_enabled: boolean = true
  /** 创始会员编号：0 = 未分配；大于 0 时按购买会员顺序分配的创始序号 */
  founding_member_no: number = 0
  /** 昵称，最长 20 字，空 = 未设置 */
  profile_nickname: string = ''
  /** 个性签名，最长 50 字，空 = 未设置 */
  profile_signature: string = ''
  /** 头像文件名（相对 filesDir，如 avatar_<userId>.jpg），空 = 未设置 */
  profile_avatar_path: string = ''
  updated_at: string = ''
}

export class AIChannelConfig {
  enabled: boolean = false
  key: string = ''
  baseUrl: string = ''
  model: string = ''
  apiFormat: AiApiFormat = 'auto'
}
