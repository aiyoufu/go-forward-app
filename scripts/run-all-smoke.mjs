/**
 * 本地冒烟聚合：白盒 + 架构 + UI 门禁 + 模块覆盖率
 * Run: node scripts/run-all-smoke.mjs
 */
import { spawnSync } from 'child_process'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')

const steps = [
  ['service-cycles', 'scripts/check-service-cycles.mjs'],
  ['whitebox', 'scripts/test-core-whitebox.mjs'],
  ['architecture', 'scripts/test-architecture-remediation.mjs'],
  ['ui-craft', 'scripts/check-ui-craft.mjs'],
  ['typescale', 'scripts/check-typescale-mainpath.mjs'],
  ['module-coverage', 'scripts/test-module-coverage.mjs']
]

let failed = 0
console.log('=== Go-Forward local smoke suite ===\n')
for (const [name, script] of steps) {
  console.log('▶ ' + name + ' (' + script + ')')
  const r = spawnSync(process.execPath, [path.join(root, script)], {
    cwd: root,
    encoding: 'utf8',
    env: process.env
  })
  if (r.stdout) process.stdout.write(r.stdout)
  if (r.stderr) process.stderr.write(r.stderr)
  if (r.status !== 0) {
    console.error('✗ ' + name + ' exit ' + r.status + '\n')
    failed++
  } else {
    console.log('✓ ' + name + '\n')
  }
}

if (failed > 0) {
  console.error('SMOKE FAIL: ' + failed + '/' + steps.length + ' suites failed')
  process.exit(1)
}
console.log('SMOKE PASS: all ' + steps.length + ' local suites green')
console.log('Note: Hypium ohosTest/E2E need device — not executed here.')
