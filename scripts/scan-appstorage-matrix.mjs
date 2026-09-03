// P3-9 辅助：扫描 AppStorageKeys 各键的写入方/读取方，输出注释矩阵素材
import path from 'node:path'
import fs from 'node:fs'

const scriptDir = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'))
const root = path.resolve(scriptDir, '..')

const keysFile = path.join(root, 'common', 'src', 'main', 'ets', 'common', 'AppStorageKeys.ets')
const src = fs.readFileSync(keysFile, 'utf8')
const keys = []
const kre = /static\s+readonly\s+([A-Z_0-9]+):\s*string\s*=\s*'([^']+)'/g
let m
while ((m = kre.exec(src)) !== null) keys.push({ name: m[1], value: m[2] })

function walk(d, out = []) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name)
    if (e.isDirectory()) {
      if (e.name === 'ohosTest' || e.name === 'test' || e.name === 'mock') continue
      walk(p, out)
    } else if (e.name.endsWith('.ets')) out.push(p)
  }
  return out
}

const files = ['entry', 'service', 'components', 'common']
  .flatMap((mod) => walk(path.join(root, mod, 'src', 'main')))
  .filter((f) => !f.endsWith('AppStorageKeys.ets'))

function shortName(f) {
  return path.basename(f, '.ets')
}

/** 键常量之外的别名（AILiveDraftKeys 等） */
const ALIASES = {
  AI_LIVE_DEBT_DRAFT: ['AILiveDraftKeys.DEBT'],
  AI_LIVE_SUBSCRIPTION_DRAFT: ['AILiveDraftKeys.SUBSCRIPTION'],
  AI_LIVE_CREDIT_ACCOUNT_DRAFT: ['AILiveDraftKeys.CREDIT_ACCOUNT'],
}

const rows = keys.map(({ name, value }) => {
  const writers = new Set()
  const readers = new Set()
  const links = new Set()
  const aliases = ALIASES[name] ?? []
  for (const f of files) {
    const t = fs.readFileSync(f, 'utf8')
    const tag = shortName(f)
    const wRe = new RegExp('AppStorage\\.(setOrCreate|set)\\([\\s\\S]*?AppStorageKeys\\.' + name + '\\b', 'g')
    if (wRe.test(t)) writers.add(tag)
    const rRe = new RegExp('AppStorage\\.(get(?:Sync)?(?:<[^>]*>)?|delete)\\([\\s\\S]*?AppStorageKeys\\.' + name + '\\b', 'g')
    if (rRe.test(t)) readers.add(tag)
    const lRe = new RegExp('@Storage(?:Link|Prop)\\(AppStorageKeys\\.' + name + '\\)', 'g')
    if (lRe.test(t)) links.add(tag)
    for (const alias of aliases) {
      if (t.includes('AppStorage.setOrCreate') && t.includes(alias)) writers.add(tag)
      if ((t.includes('AppStorage.get') || t.includes('AppStorage.delete')) && t.includes(alias)) {
        readers.add(tag)
      }
    }
  }
  return { name, value, writers: [...writers], readers: [...readers], links: [...links] }
})

for (const r of rows) {
  const parts = []
  if (r.writers.length) parts.push('写:' + r.writers.join(','))
  if (r.links.length) parts.push('链:' + r.links.join(','))
  if (r.readers.length) parts.push('读:' + r.readers.join(','))
  console.log(r.name.padEnd(32) + (parts.join('  ') || '(无引用)'))
}
