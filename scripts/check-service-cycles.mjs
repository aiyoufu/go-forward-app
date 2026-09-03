// service 模块内部相对导入环检测：node scripts/check-service-cycles.mjs
// 退出码 0 = 无环；1 = 存在环或解析失败
import path from 'node:path'
import fs from 'node:fs'

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..')
const dir = path.join(root, 'service', 'src', 'main', 'ets', 'service')

function walk(d, out = []) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name)
    if (e.isDirectory()) walk(p, out)
    else if (e.name.endsWith('.ets')) out.push(p)
  }
  return out
}

const files = walk(dir)
const graph = new Map()
const fileNames = new Map()

for (const f of files) {
  const base = path.basename(f, '.ets')
  if (fileNames.has(base)) {
    console.error('FAIL: 重名文件', base)
    process.exit(1)
  }
  fileNames.set(base, f)
}

let broken = 0
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8')
  const deps = []
  const re = /from\s+'(\.[^']+)'/g
  let m
  while ((m = re.exec(src)) !== null) {
    const resolved = path.normalize(path.join(path.dirname(f), m[1]))
    const target = resolved.endsWith('.ets') ? resolved : resolved + '.ets'
    if (!fs.existsSync(target)) {
      console.error(`FAIL: ${path.relative(root, f)} -> ${m[1]} 无法解析`)
      broken++
      continue
    }
    deps.push(path.basename(target, '.ets'))
  }
  graph.set(path.basename(f, '.ets'), deps)
}

if (broken > 0) process.exit(1)

// Tarjan 简化版：DFS 找回边
const WHITE = 0, GRAY = 1, BLACK = 2
const color = new Map()
for (const n of graph.keys()) color.set(n, WHITE)
const cycles = []

function dfs(n, stack) {
  color.set(n, GRAY)
  stack.push(n)
  for (const d of graph.get(n)) {
    if (!graph.has(d)) continue
    if (color.get(d) === GRAY) {
      const i = stack.indexOf(d)
      cycles.push(stack.slice(i).concat(d).join(' -> '))
    } else if (color.get(d) === WHITE) {
      dfs(d, stack)
    }
  }
  stack.pop()
  color.set(n, BLACK)
}

for (const n of graph.keys()) {
  if (color.get(n) === WHITE) dfs(n, [])
}

if (cycles.length > 0) {
  console.error('FAIL: 检测到循环依赖:')
  for (const c of cycles) console.error('  ' + c)
  process.exit(1)
}
console.log('OK: service 模块 ' + graph.size + ' 个文件，相对导入全部可解析，零循环依赖')
