// 测试注册修复 v2：把存在但未登记进 List.test.ets 的用例全部注册
// Run: node scripts/fix-test-registration.mjs
import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()

// 统一归一化：'ui/DebtCard.ui.test.ets' -> 'ui/debtcard.ui.test'
function normStem(relFromTestDir) {
  return relFromTestDir.replace(/\\/g, '/').replace(/\.ets$/, '').toLowerCase()
}

function walkTests(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc
  for (const n of fs.readdirSync(dir)) {
    const p = path.join(dir, n)
    const st = fs.statSync(p)
    if (st.isDirectory()) {
      walkTests(p, acc)
    } else if (n.endsWith('.test.ets') && n !== 'List.test.ets' && n !== 'Ability.test.ets') {
      acc.push(p)
    }
  }
  return acc
}

function importNameFor(base) {
  // 'AILiveOverlay.ui.test.ets' -> ailiveOverlayUiTest ; 'DebtService.test.ets' -> debtServiceTest
  const stem = base.replace(/\.ets$/, '').replace(/\.ui\.test$/, '').replace(/\.test$/, '')
  const isUi = base.includes('.ui.test')
  const camel = stem.replace(/[-_](\w)/g, (_, c) => c.toUpperCase())
  const suffix = isUi ? 'UiTest' : 'Test'
  return camel.charAt(0).toLowerCase() + camel.slice(1) + suffix
}

for (const mod of ['entry', 'service', 'common', 'components']) {
  const testDir = path.join(root, mod, 'src', 'ohosTest', 'ets', 'test')
  const listPath = path.join(testDir, 'List.test.ets')
  if (!fs.existsSync(listPath)) continue
  const listText = fs.readFileSync(listPath, 'utf8')

  // 已注册：导入说明符整体（去 ./ 与 .ets 后缀，保留 .test/.ui.test 段）
  const registered = new Set()
  const re = /from '([^']+)'/g
  let m
  while ((m = re.exec(listText)) !== null) {
    registered.add(m[1].replace(/^\.\//, '').replace(/\.ets$/, '').toLowerCase())
  }

  const orphans = walkTests(testDir).filter((f) => {
    const stem = normStem(path.relative(testDir, f).replace(/\.ets$/, ''))
    return !registered.has(stem)
  })

  if (orphans.length === 0) continue

  let text = listText
  const imports = []
  const calls = []
  const usedNames = new Set()
  for (const f of orphans) {
    const relSpec = './' + path.relative(testDir, f).replace(/\\/g, '/').replace(/\.ets$/, '')
    let name = importNameFor(path.basename(f))
    while (usedNames.has(name)) {
      name = '_' + name
    }
    usedNames.add(name)
    imports.push(`import ${name} from '${relSpec}'`)
    calls.push(`  ${name}()`)
  }
  const lastImportEnd = text.lastIndexOf('import ')
  const lineEnd = text.indexOf('\n', text.indexOf("'", lastImportEnd))
  text = text.slice(0, lineEnd + 1) + imports.join('\n') + '\n' + text.slice(lineEnd + 1)
  const closeIdx = text.lastIndexOf('}')
  text = text.slice(0, closeIdx) + calls.join('\n') + '\n' + text.slice(closeIdx)

  fs.writeFileSync(listPath, text)
  console.log(`${mod}: 注册 ${orphans.length} 个`)
}
console.log('OK')
