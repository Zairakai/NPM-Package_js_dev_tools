// Generates what is not written by hand, so that it cannot drift from the code:
//   docs/reference/   the public API, by TypeDoc, from the source
//   docs/guide/readme.md   the guide, copied from the README without its badges
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const docs = resolve(here, '..')
const root = resolve(docs, '..')

// A library with an API has its reference generated; a toolkit without one only has the guide.
if (existsSync(join(docs, 'typedoc.json'))) {
  execFileSync('npx', ['typedoc', '--options', join(docs, 'typedoc.json')], { cwd: docs, stdio: 'inherit' })
}

// The README starts with badges and a one line summary, then a first rule: the guide begins after it.
const readme = readFileSync(join(root, 'README.md'), 'utf8')
const [, ...rest] = readme.split(/^---\s*$/m)
const title = /^# (.+)$/m.exec(readme)?.[1] ?? 'Guide'
// The links of the README are relative to the repository (./CONTRIBUTING): point them at the code.
const repository = String(JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).repository?.url ?? '')
  .replace(/^git\+/, '')
  .replace(/\.git$/, '')

const absolute = (target) => {
  if (/^(https?:|mailto:|#|\/)/.test(target) || '' === repository) {
    return target
  }

  let path = target.replace(/^\.\//, '').replace(/#.*$/, '')

  if (!existsSync(join(root, path)) && existsSync(join(root, `${path}.md`))) {
    path = `${path}.md`
  }

  return `${repository}/-/blob/main/${path}`
}

const body = rest
  .join('---')
  // The reference-style links of the badges at the end of the README are not needed.
  .replace(/^\[[^\]]+\]:\s.*$/gm, '')
  .replace(/\]\(([^)\s]+)\)/g, (_match, target) => `](${absolute(target)})`)
  .replace(/\n{3,}/g, '\n\n')
  .trim()

mkdirSync(join(docs, 'guide'), { recursive: true })
writeFileSync(join(docs, 'guide', 'readme.md'), `# ${title}\n\n${body}\n`)
console.log('reference and guide written')
