/**
 * P2-3：Supabase Realtime（Phoenix WebSocket）
 * 他端写库 → postgres_changes 事件 → debounce 触发 SyncScheduler
 * 前台 start / 后台 stop；失败静默降级为 pulse。
 */
import { webSocket } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { SupabaseConfig } from 'common'
import { Logger } from 'common'
import { AuthManager } from '../auth/AuthManager'
import { SyncScheduler } from './SyncScheduler'

/** postgres_changes 订阅项（phx_join config） */
interface RealtimePgChange {
  event: string
  schema: string
  table: string
  filter: string
}

interface RealtimeBroadcastConfig {
  self: boolean
}

interface RealtimePresenceConfig {
  key: string
}

interface RealtimeJoinConfig {
  postgres_changes: RealtimePgChange[]
  broadcast: RealtimeBroadcastConfig
  presence: RealtimePresenceConfig
}

interface RealtimeJoinPayload {
  config: RealtimeJoinConfig
  access_token: string
}

/** heartbeat 空 payload（class 避免空 interface + 字面量问题） */
class RealtimeEmptyPayload {
}

interface RealtimePhxJoinMessage {
  topic: string
  event: string
  payload: RealtimeJoinPayload
  ref: string
  join_ref: string
}

interface RealtimePhxHeartbeatMessage {
  topic: string
  event: string
  payload: RealtimeEmptyPayload
  ref: string
}

export class SyncRealtime {
  private static socket: webSocket.WebSocket | null = null
  private static started: boolean = false
  private static heartbeatTimer: number = -1
  private static refCounter: number = 1
  private static joined: boolean = false

  static isStarted(): boolean {
    return SyncRealtime.started
  }

  /** 前台有云会话时调用（幂等） */
  static async start(): Promise<void> {
    if (!SupabaseConfig.isConfigured()) {
      return
    }
    if (SyncRealtime.started && SyncRealtime.socket !== null) {
      return
    }
    const session = await AuthManager.loadSession()
    if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return
    }
    SyncRealtime.stop()
    SyncRealtime.started = true
    SyncRealtime.joined = false

    try {
      const ws = webSocket.createWebSocket()
      SyncRealtime.socket = ws

      const url = SyncRealtime.buildWsUrl()
      ws.on('open', (_err: BusinessError, _value: Object) => {
        SyncRealtime.sendJoin(session.accessToken, session.userId)
        SyncRealtime.startHeartbeat()
      })
      ws.on('message', (_err: BusinessError, value: string | ArrayBuffer) => {
        SyncRealtime.onMessage(value)
      })
      ws.on('close', () => {
        SyncRealtime.cleanupSocket(false)
      })
      ws.on('error', (err: BusinessError) => {
        Logger.error('SyncRealtime', 'ws error: ' + JSON.stringify(err))
      })

      ws.connect(url, (err: BusinessError) => {
        if (err) {
          Logger.error('SyncRealtime', 'connect fail: ' + JSON.stringify(err))
          SyncRealtime.cleanupSocket(true)
        }
      })
    } catch (e) {
      Logger.error('SyncRealtime', 'start: ' + JSON.stringify(e))
      SyncRealtime.cleanupSocket(true)
    }
  }

  /** 退后台 / 登出 */
  static stop(): void {
    SyncRealtime.cleanupSocket(true)
  }

  private static cleanupSocket(clearStarted: boolean): void {
    SyncRealtime.stopHeartbeat()
    SyncRealtime.joined = false
    if (SyncRealtime.socket !== null) {
      try {
        SyncRealtime.socket.close()
      } catch {
      }
      SyncRealtime.socket = null
    }
    if (clearStarted) {
      SyncRealtime.started = false
    }
  }

  private static buildWsUrl(): string {
    // https://xxx.supabase.co → wss://xxx.supabase.co/realtime/v1/websocket
    let base: string = SupabaseConfig.URL
    if (base.indexOf('https://') === 0) {
      base = 'wss://' + base.substring('https://'.length)
    } else if (base.indexOf('http://') === 0) {
      base = 'ws://' + base.substring('http://'.length)
    }
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1)
    }
    return base + '/realtime/v1/websocket?apikey=' +
      encodeURIComponent(SupabaseConfig.ANON_KEY) + '&vsn=1.0.0'
  }

  private static nextRef(): string {
    SyncRealtime.refCounter = SyncRealtime.refCounter + 1
    return '' + SyncRealtime.refCounter
  }

  private static sendJoin(accessToken: string, userId: string): void {
    const filter = 'user_id=eq.' + userId
    const tables: string[] = [
      'debts', 'payment_records', 'subscriptions', 'credit_accounts',
      'notifications', 'achievement_cards', 'user_settings'
    ]
    const changes: RealtimePgChange[] = []
    for (let i = 0; i < tables.length; i++) {
      const item: RealtimePgChange = {
        event: '*',
        schema: 'public',
        table: tables[i],
        filter: filter
      }
      changes.push(item)
    }
    const ref = SyncRealtime.nextRef()
    const broadcast: RealtimeBroadcastConfig = { self: false }
    const presence: RealtimePresenceConfig = { key: '' }
    const config: RealtimeJoinConfig = {
      postgres_changes: changes,
      broadcast: broadcast,
      presence: presence
    }
    const payload: RealtimeJoinPayload = {
      config: config,
      access_token: accessToken
    }
    const msg: RealtimePhxJoinMessage = {
      topic: 'realtime:goforward-sync',
      event: 'phx_join',
      payload: payload,
      ref: ref,
      join_ref: ref
    }
    SyncRealtime.sendJson(msg)
  }

  private static startHeartbeat(): void {
    SyncRealtime.stopHeartbeat()
    SyncRealtime.heartbeatTimer = setTimeout((): void => {
      SyncRealtime.heartbeatTimer = -1
      if (SyncRealtime.socket === null) {
        return
      }
      const hb: RealtimePhxHeartbeatMessage = {
        topic: 'phoenix',
        event: 'heartbeat',
        payload: new RealtimeEmptyPayload(),
        ref: SyncRealtime.nextRef()
      }
      SyncRealtime.sendJson(hb)
      SyncRealtime.startHeartbeat()
    }, 25000)
  }

  private static stopHeartbeat(): void {
    if (SyncRealtime.heartbeatTimer !== -1) {
      clearTimeout(SyncRealtime.heartbeatTimer)
      SyncRealtime.heartbeatTimer = -1
    }
  }

  private static sendJson(obj: Object): void {
    if (SyncRealtime.socket === null) {
      return
    }
    try {
      SyncRealtime.socket.send(JSON.stringify(obj), (err: BusinessError) => {
        if (err) {
          Logger.error('SyncRealtime', 'send fail: ' + JSON.stringify(err))
        }
      })
    } catch (e) {
      Logger.error('SyncRealtime', 'send: ' + JSON.stringify(e))
    }
  }

  private static onMessage(value: string | ArrayBuffer): void {
    let text = ''
    if (typeof value === 'string') {
      text = value
    } else {
      return
    }
    if (text.length === 0) {
      return
    }
    try {
      const msg = JSON.parse(text) as Record<string, Object>
      const event = '' + (msg['event'] ?? '')
      if (event === 'phx_reply') {
        SyncRealtime.joined = true
        return
      }
      // postgres_changes 推送
      if (event === 'postgres_changes' || event === 'INSERT' || event === 'UPDATE' ||
        event === 'DELETE' || event.indexOf('postgres') >= 0) {
        SyncScheduler.schedule('realtime', 400)
        return
      }
      // 部分版本嵌在 payload 里
      const payload = msg['payload'] as Record<string, Object>
      if (payload !== undefined && payload !== null) {
        const data = payload['data'] as Record<string, Object>
        const type = data !== undefined && data !== null ? ('' + (data['type'] ?? '')) : ''
        if (type === 'INSERT' || type === 'UPDATE' || type === 'DELETE') {
          SyncScheduler.schedule('realtime', 400)
        }
      }
    } catch {
      // 非 JSON 忽略
    }
  }
}
