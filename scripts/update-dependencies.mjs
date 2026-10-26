#!/usr/bin/env node
/**
 * Automatic updates of the dependencies of a package of the zairakai group.
 *
 * Usage: node update-dependencies.mjs update | release | tag | cascade | audit | policy | policy-validate | policy-check <ref> | dependabot-sync
 *
 * - update: prepare a branch with the minor and patch updates, open a merge request into develop and merge it when its
 *   pipeline succeeds. The pipeline of the merge request is the gate: nothing is tested here.
 * - release: open the merge request of develop into main after an update, and merge it when its pipeline succeeds.
 * - tag: tag main when a runtime range changed since the last tag (see `tag` in .dependency-update.json).
 * - cascade: after the publication of this package, start the update of the projects that use it.
 * - audit: look for security advisories, open one issue per advisory and, with AUTO_FIX=true, start an update to fix them
 *   (UPDATE_URGENT=true: the new versions are taken without waiting, `npm audit fix` is run and an override that pins a
 *   vulnerable version is raised).
 * - policy: in the repository dependency-policy, lift the entries whose condition is met (merge request).
 * - policy-validate: in the repository dependency-policy, check the shape of the files.
 * - policy-check: fail when the change since a ref updates a package of the policy (GitLab or GitHub, it only reads).
 * - dependabot-sync: rewrite the ignore rules of .github/dependabot.yml (between the markers of the ecosystem) from the policy.
 *
 * The packages listed in the dependency policy (https://gitlab.com/zairakai/dependency-policy) are never updated, whatever
 * the project. DEPENDENCY_POLICY_URL replaces the address of the files.
 *
 * It reads `.dependency-update.json` at the root of the project (everything is optional):
 *
 *   {
 *     "reject": ["some-package"],               packages of this project that are never updated
 *     "cooldown": "3d",                         minimum age of a new version
 *     "tag": { "when": "runtime", "level": "patch" },   when: runtime | always | never, level: patch | minor
 *     "cascade": { "groups": ["zairakai/npm-packages"] }   projects to start (opt-in: they have the same file)
 *   }
 *
 * Environment: GITLAB_TOKEN (group variable), and the variables of GitLab CI. The audit also reads FRESHNESS_TOKEN (else
 * GITLAB_TOKEN), NTFY_URL and AUTO_FIX.
 */
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

import semver from 'semver'

const CONFIG_FILE = '.dependency-update.json'
const PIPELINE_FILE = '.gitlab-ci.yml'
const COMMIT_SUBJECT = 'chore(deps): update the dependencies'
const BRANCH_PREFIX = 'chore/update-dependencies'
const ADVISORY_TITLE_PREFIX = 'Security advisory: '
const ISSUE_LABELS = ['Kind::Security', 'Area::Security', 'Automated']
const POLICY_URL = 'https://gitlab.com/zairakai/dependency-policy/-/raw/main'
const POLICY_FILES = { npm: 'node.json', composer: 'php.json' }
const POLICY_BRANCH_PREFIX = 'chore/unblock'
const DEPENDABOT_FILE = '.github/dependabot.yml'
const GROUP_SCOPE = '@zairakai/'
const TRUSTED_SCOPES = [GROUP_SCOPE, '@stanislas-poisson/']

const DEFAULTS = {
  reject: [],
  cooldown: '3d',
  tag: { when: 'runtime', level: 'patch' },
  cascade: null,
}

const RUNTIME_SECTIONS = ['dependencies', 'peerDependencies', 'optionalDependencies']
const ALL_SECTIONS = ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies']

/** The manifest of each ecosystem, with the sections that are published and all of them. */
const ECOSYSTEMS = {
  npm: { file: 'package.json', runtime: RUNTIME_SECTIONS, all: ALL_SECTIONS },
  composer: { file: 'composer.json', runtime: ['require'], all: ['require', 'require-dev'] },
}

/** The ecosystem of the project: a package.json at its root, otherwise a composer.json. */
export function detectEcosystem(exists = existsSync) {
  return exists('package.json') ? 'npm' : 'composer'
}

/** The configuration of the project, completed with the defaults. */
export function loadConfig(path = CONFIG_FILE) {
  const user = existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : {}

  return { ...DEFAULTS, ...user, tag: { ...DEFAULTS.tag, ...user.tag } }
}

function compareVersions(a, b) {
  const left = a.split('.').map(Number)
  const right = b.split('.').map(Number)

  return left[0] - right[0] || left[1] - right[1] || left[2] - right[2]
}

/** The highest tag of the form X.Y.Z (a tag with a prefix or a suffix is ignored), or null. */
export function latestTag(tags) {
  return (
    tags
      .filter((tag) => /^\d+\.\d+\.\d+$/.test(tag))
      .sort(compareVersions)
      .at(-1) ?? null
  )
}

/** The version after `last` for a level of change (major, minor or patch). */
export function nextVersion(last, level) {
  const [major, minor, patch] = last.split('.').map(Number)

  if ('major' === level) return `${major + 1}.0.0`
  if ('minor' === level) return `${major}.${minor + 1}.0`

  return `${major}.${minor}.${patch + 1}`
}

function sorted(section) {
  return JSON.stringify(Object.entries(section ?? {}).sort(([a], [b]) => a.localeCompare(b)))
}

/** True when a range that is published (dependencies, peerDependencies, optionalDependencies) is not the same. */
export function runtimeChanged(before, after, sections = RUNTIME_SECTIONS) {
  return sections.some((section) => sorted(before?.[section]) !== sorted(after?.[section]))
}

/** The dependencies whose range changed, with the section, the old range and the new one. */
export function diffDependencies(before, after, sections = ALL_SECTIONS) {
  const rows = []

  for (const section of sections) {
    const old = before?.[section] ?? {}
    const current = after?.[section] ?? {}

    for (const name of new Set([...Object.keys(old), ...Object.keys(current)])) {
      if (old[name] !== current[name]) {
        rows.push({ section, name, from: old[name] ?? null, to: current[name] ?? null })
      }
    }
  }

  return rows.sort((a, b) => a.section.localeCompare(b.section) || a.name.localeCompare(b.name))
}

/** The changes as a Markdown table, for the merge request and the commit. */
export function formatChanges(rows) {
  const lines = ['| Section | Package | From | To |', '| --- | --- | --- | --- |']

  for (const row of rows) {
    lines.push(`| ${row.section} | ${row.name} | ${row.from ?? '-'} | ${row.to ?? '-'} |`)
  }

  return lines.join('\n')
}

/** The identity and the key used to sign, from the group variables. It fails when one is missing: no unsigned tag. */
export function signerIdentity(env) {
  const missing = ['GPG_PRIVATE_KEY_B64', 'RELEASE_SIGNER_NAME', 'RELEASE_SIGNER_EMAIL'].filter((name) => !env[name])

  if (0 < missing.length) {
    throw new Error(
      `${missing.join(', ')} not set: the commits and the tags are signed, see the handbook (versioning).`
    )
  }

  return {
    name: env.RELEASE_SIGNER_NAME,
    email: env.RELEASE_SIGNER_EMAIL,
    key: Buffer.from(env.GPG_PRIVATE_KEY_B64, 'base64').toString('utf8'),
  }
}

/** What `tag` has to do: the version to create, or null (and why). */
export function planTag({ config, last, commits, before, after, sections = RUNTIME_SECTIONS }) {
  if ('never' === config.tag.when) return { version: null, reason: 'the project is never tagged by the update' }
  if (!last) return { version: null, reason: 'there is no tag yet' }
  if (0 === commits.length) return { version: null, reason: 'no update since the last tag' }

  if ('runtime' === config.tag.when && !runtimeChanged(before, after, sections)) {
    return { version: null, reason: 'only the development dependencies changed: the published archive is the same' }
  }

  return { version: nextVersion(last, config.tag.level), reason: 'a published range changed' }
}

/**
 * True when a diff changes one `ref:` line and nothing else. The install of the tools moves the `ref:` of the shared
 * pipeline to the installed version: that is the only change of the pipeline file an update may commit.
 */
export function isRefOnlyChange(diff) {
  const changed = diff.split('\n').filter((line) => /^[+-]/.test(line) && !/^(\+\+\+|---)/.test(line))

  return 2 === changed.length && changed.every((line) => /^[+-]\s*ref:\s*\S+\s*$/.test(line))
}

/** The problems of a policy document, as a list of sentences (empty when it is valid). */
export function validatePolicy(doc) {
  if (!Array.isArray(doc?.entries)) return ['"entries" must be a list.']

  const errors = []
  const seen = new Set()

  doc.entries.forEach((entry, index) => {
    const where = `entries[${index}]`
    const name = 'string' === typeof entry?.package ? entry.package : ''

    if ('' === name) errors.push(`${where}: "package" is missing.`)
    else if (seen.has(name)) errors.push(`${where}: "${name}" is listed twice.`)
    seen.add(name)

    if ('string' !== typeof entry?.reason || '' === entry.reason.trim()) errors.push(`${where}: "reason" is missing.`)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(entry?.since ?? '')) errors.push(`${where}: "since" must be a date (YYYY-MM-DD).`)

    if (undefined !== entry?.unblock) {
      const { version, peers } = entry.unblock ?? {}

      if (null === semver.valid(version)) errors.push(`${where}: "unblock.version" must be a version (X.Y.Z).`)
      if (!Array.isArray(peers) || 0 === peers.length || !peers.every((peer) => 'string' === typeof peer && peer)) {
        errors.push(`${where}: "unblock.peers" must be a list of packages.`)
      }
    }
  })

  return errors
}

/** The policy of an ecosystem, read from the repository dependency-policy. Anything wrong stops the update. */
export async function fetchPolicy(
  ecosystem,
  fetchImpl = fetch,
  base = process.env.DEPENDENCY_POLICY_URL || POLICY_URL
) {
  const url = `${base.replace(/\/$/, '')}/${POLICY_FILES[ecosystem]}`
  let doc

  try {
    const response = await fetchImpl(url, { signal: AbortSignal.timeout(20000) })
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    doc = await response.json()
  } catch (error) {
    throw new Error(`The dependency policy could not be read (${url}): ${error.message}`, { cause: error })
  }

  const errors = validatePolicy(doc)
  if (0 < errors.length) throw new Error(`The dependency policy is not valid (${url}): ${errors.join(' ')}`)

  return doc
}

/** The packages that the project never updates: its own `reject` and the packages of the policy. */
export function rejectedPackages(config, policy) {
  return [...new Set([...config.reject, ...policy.entries.map((entry) => entry.package)])]
}

/** Whether the condition of an entry is met: every package of `peers` accepts the version in its peer range. */
export function isLifted(entry, ranges) {
  if (!entry.unblock) return false

  return entry.unblock.peers.every((peer) => {
    const range = ranges[peer]

    return (
      'string' === typeof range && null !== semver.validRange(range) && semver.satisfies(entry.unblock.version, range)
    )
  })
}

/** The versions of every package of a package-lock.json, by name (a package installed twice has several). */
export function lockedVersions(lock) {
  const versions = {}

  for (const [path, info] of Object.entries(lock?.packages ?? {})) {
    if ('' === path || !info?.version) continue

    const name = path.slice(path.lastIndexOf('node_modules/') + 'node_modules/'.length)
    versions[name] = [...new Set([...(versions[name] ?? []), info.version])].sort()
  }

  return versions
}

/**
 * The packages of the policy whose version changes: a range of package.json or a locked version. A package that is
 * added or removed is not an update.
 */
export function policyViolations({ blocked, beforeManifest, afterManifest, beforeLock, afterLock }) {
  const problems = []

  for (const row of diffDependencies(beforeManifest, afterManifest)) {
    if (blocked.includes(row.name) && null !== row.from && null !== row.to) {
      problems.push(`package.json: ${row.name} moves from ${row.from} to ${row.to}.`)
    }
  }

  const before = lockedVersions(beforeLock)
  const after = lockedVersions(afterLock)

  for (const name of blocked) {
    if (before[name] && after[name] && before[name].join(', ') !== after[name].join(', ')) {
      problems.push(`package-lock.json: ${name} moves from ${before[name].join(', ')} to ${after[name].join(', ')}.`)
    }
  }

  return problems
}

/**
 * The text of dependabot.yml with the block of the ecosystem rewritten: between `# BEGIN dependency-policy (npm)` and
 * `# END dependency-policy (npm)`, one ignore rule per package of the policy (nothing when none). Null without markers.
 */
export function syncDependabot(text, names, ecosystem) {
  const begin = `# BEGIN dependency-policy (${ecosystem})`
  const end = `# END dependency-policy (${ecosystem})`
  const pattern = new RegExp(
    `^([ \\t]*)${begin.replaceAll(/[()]/g, '\\$&')}\\n[\\s\\S]*?^[ \\t]*${end.replaceAll(/[()]/g, '\\$&')}$`,
    'm'
  )
  const match = pattern.exec(text)

  if (null === match) return null

  const indent = match[1]
  const rules =
    0 === names.length ? [] : [`${indent}ignore:`, ...names.map((name) => `${indent}  - dependency-name: "${name}"`)]

  return text.replace(pattern, () => [`${indent}${begin}`, ...rules, `${indent}${end}`].join('\n'))
}

/**
 * The overrides that pin a version inside the vulnerable range of an advisory (`npm audit` never changes an override), with
 * the newest stable version of the same major that is outside of that range. `versionsOf(name)` lists the published versions.
 */
export function fixedOverrides(overrides, vulnerabilities, versionsOf) {
  const fixes = {}

  for (const [name, pin] of Object.entries(overrides ?? {})) {
    const pinned = 'string' === typeof pin ? pin : pin?.['.']
    const range = vulnerabilities?.[name]?.range

    if (null === semver.valid(pinned) || 'string' !== typeof range || null === semver.validRange(range)) continue
    if (!semver.satisfies(pinned, range)) continue

    const candidates = (versionsOf(name) ?? []).filter(
      (version) =>
        null !== semver.valid(version) &&
        null === semver.prerelease(version) &&
        semver.major(version) === semver.major(pinned) &&
        !semver.satisfies(version, range)
    )
    const best = semver.maxSatisfying(candidates, '*')

    if (best && semver.gt(best, pinned)) fixes[name] = best
  }

  return fixes
}

/**
 * The packages of a lock file that the refresh may update: the ones of the group are left out, because they are trusted
 * and not made to wait, and the cooling date would refuse a version that was just published.
 */
export function refreshableNames(lock, scopes = TRUSTED_SCOPES) {
  const names = Object.keys(lock?.packages ?? {})
    .filter((path) => '' !== path)
    .map((path) => path.slice(path.lastIndexOf('node_modules/') + 'node_modules/'.length))
    .filter((name) => !scopes.some((scope) => name.startsWith(scope)))

  return [...new Set(names)].sort()
}

/** The age, as a date, from which a version is taken: now minus the cooling period ("3d", "12h"). */
export function cooldownDate(cooldown, now = new Date()) {
  const match = /^(\d+)\s*([dhm])$/.exec(cooldown)
  if (!match) return null

  const unit = { d: 86_400_000, h: 3_600_000, m: 60_000 }[match[2]]

  return new Date(now.getTime() - Number(match[1]) * unit)
}

/**
 * Whether a package is only reached through the packages of the group (@zairakai/*), in a lock file of version 2 or 3.
 * The graph is read by name, which is enough here: a package that is also reached through a dependency of the project
 * itself is not inherited.
 */
export function isInherited(lock, name, scope = GROUP_SCOPE) {
  const packages = lock?.packages ?? {}
  const edges = new Map()

  for (const [path, node] of Object.entries(packages)) {
    if ('' === path) continue

    const key = path.slice(path.lastIndexOf('node_modules/') + 'node_modules/'.length)
    const next = edges.get(key) ?? new Set()

    for (const section of ['dependencies', 'optionalDependencies', 'peerDependencies']) {
      Object.keys(node[section] ?? {}).forEach((dependency) => next.add(dependency))
    }
    edges.set(key, next)
  }

  const root = packages['']
  const direct = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'].flatMap((section) =>
    Object.keys(root?.[section] ?? {})
  )
  const reaches = (starts) => {
    const seen = new Set(starts)
    const queue = [...starts]

    while (0 < queue.length) {
      for (const next of edges.get(queue.shift()) ?? []) {
        if (!seen.has(next)) {
          seen.add(next)
          queue.push(next)
        }
      }
    }

    return seen
  }

  const ours = reaches(direct.filter((dependency) => !dependency.startsWith(scope)))
  const theirs = reaches(direct.filter((dependency) => dependency.startsWith(scope)))

  return theirs.has(name) && !ours.has(name)
}

/** The id of an advisory: the last part of its URL (GHSA-xxxx-xxxx-xxxx), else the number npm gives it. */
function advisoryId(via) {
  const fromUrl = 'string' === typeof via.url ? via.url.split('/').filter(Boolean).pop() : ''

  return fromUrl || String(via.source ?? '')
}

/** The advisories of the JSON report of `npm audit`, one row per advisory and package, sorted. */
export function parseNpmAudit(report) {
  const rows = new Map()

  for (const entry of Object.values(report?.vulnerabilities ?? {})) {
    for (const via of entry.via ?? []) {
      // A string only names another vulnerable package: the advisory itself is on that one.
      if ('object' !== typeof via || null === via) continue

      const row = {
        id: advisoryId(via),
        package: via.name ?? entry.name,
        title: via.title ?? '',
        link: via.url ?? '',
        severity: String(via.severity ?? entry.severity ?? '').toLowerCase(),
        range: via.range ?? '',
      }

      rows.set(`${row.package}|${row.id}`, row)
    }
  }

  return [...rows.values()].sort((a, b) => `${a.package}|${a.id}`.localeCompare(`${b.package}|${b.id}`))
}

/** The title of the issue of an advisory. It is also the key that keeps the issue from being opened twice. */
export function advisoryTitle(row) {
  return `${ADVISORY_TITLE_PREFIX}${row.package} (${row.id})`
}

/** Whether an advisory is fixed without waiting for the next weekly update. An unknown severity counts as urgent. */
export function isUrgent(severity) {
  return ['', 'high', 'critical'].includes(severity)
}

/** Whether an advisory is worth a push notification: moderate and above. An unknown severity counts as notable. */
export function isNotable(severity) {
  return ['', 'moderate', 'high', 'critical'].includes(severity)
}

/**
 * The one notification of an audit, or null when nothing notable was opened. The advisories of a low severity only
 * get their issue: they are counted, not listed.
 */
export function auditAlert(opened, project) {
  const notable = opened.filter(({ row }) => isNotable(row.severity))
  if (0 === notable.length) return null

  const silent = opened.length - notable.length
  const lines = notable.map(({ row, url }) => `${row.package} (${row.id}, ${row.severity || 'unknown'}): ${url}`)
  if (0 < silent) lines.push(`${silent} more of a low severity, issue only.`)

  return { title: `Security advisories: ${notable.length} new in ${project}`, message: lines.join('\n') }
}

/** The labels of the issue of an advisory: the kind and the area, the priority from the severity, and Status::Ready. */
export function advisoryLabels(row) {
  const priority = { critical: 'Priority::Critical', high: 'Priority::High' }[row.severity] ?? 'Priority::Low'

  return [...ISSUE_LABELS, priority, 'Status::Ready'].join(',')
}

/** The body of the issue opened for an advisory. */
export function advisoryIssueBody(row, pipelineUrl, autoFix) {
  return [
    `${row.title}.`,
    '',
    `- Package: \`${row.package}\``,
    `- Affected versions: \`${row.range || 'unknown'}\``,
    `- Severity: ${row.severity || 'not given'}`,
    `- Advisory: ${row.link || row.id}`,
    `- Automatic fix: ${autoFix && isUrgent(row.severity) ? 'started (an update of the dependencies, taken without waiting)' : 'off for this advisory: update by hand'}`,
    '',
    `Pipeline: ${pipelineUrl}`,
    '',
    'The issue is closed by the next audit that no longer finds this advisory.',
  ].join('\n')
}

// ---------------------------------------------------------------------------------------------------------------------

const log = (message) => console.info(message)

function secret(text) {
  return ['GITLAB_TOKEN', 'FRESHNESS_TOKEN'].reduce((masked, name) => {
    const token = process.env[name]

    return token ? masked.split(token).join('***') : masked
  }, String(text))
}

function run(command, args = [], options = {}) {
  try {
    return execFileSync(command, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...options }).trim()
  } catch (error) {
    throw new Error(secret(`${command} ${args.join(' ')} failed: ${error.stderr || error.message}`), { cause: error })
  }
}

/** The output of a command that exits with 1 when it finds something (npm audit): only a missing output is a failure. */
function capture(command, args = []) {
  try {
    return execFileSync(command, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 64 * 1024 * 1024,
    })
  } catch (error) {
    if (error.stdout) return error.stdout

    throw new Error(secret(`${command} ${args.join(' ')} failed: ${error.stderr || error.message}`), { cause: error })
  }
}

async function api(method, path, body, token = process.env.GITLAB_TOKEN) {
  const response = await fetch(`${process.env.CI_API_V4_URL ?? 'https://gitlab.com/api/v4'}${path}`, {
    method,
    headers: { 'PRIVATE-TOKEN': token ?? '', 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const text = await response.text()

  return { status: response.status, ok: response.ok, data: parseBody(text) }
}

function parseBody(text) {
  if (!text) return null

  try {
    return JSON.parse(text)
  } catch {
    return text
  }
}

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds))

function projectId() {
  return process.env.CI_PROJECT_ID
}

function assertEnvironment() {
  for (const name of ['GITLAB_TOKEN', 'CI_PROJECT_ID', 'CI_PROJECT_PATH', 'CI_SERVER_HOST']) {
    if (!process.env[name])
      throw new Error(`${name} is not set: run this in GitLab CI, with the group variable GITLAB_TOKEN.`)
  }

  // The runner clones the project with another user than the one of the job: Git refuses it otherwise.
  run('git', ['config', '--global', '--add', 'safe.directory', process.cwd()])
}

/** GPG is not in the image of the CI: add it with the package manager of the image (Alpine or Debian). */
function ensureGpg() {
  const available = () => {
    try {
      run('gpg', ['--version'])
      return true
    } catch {
      return false
    }
  }

  if (available()) return

  for (const [command, args] of [
    ['apk', ['add', '--no-cache', 'gnupg']],
    ['apt-get', ['install', '-y', '--no-install-recommends', 'gnupg']],
  ]) {
    try {
      run(command, args)
    } catch {
      continue
    }

    if (available()) return
  }

  throw new Error('gpg is not installed and could not be added: add gnupg to the image of the job.')
}

/** Import the signing key and make Git sign the commits and the tags with it. */
function configureSigning() {
  const signer = signerIdentity(process.env)

  ensureGpg()

  run('gpg', ['--batch', '--import'], { input: signer.key, stdio: ['pipe', 'pipe', 'pipe'] })
  const fingerprint = run('gpg', ['--list-secret-keys', '--with-colons'])
    .split('\n')
    .find((line) => line.startsWith('fpr'))
    .split(':')[9]

  run('git', ['config', 'user.name', signer.name])
  run('git', ['config', 'user.email', signer.email])
  run('git', ['config', 'user.signingkey', fingerprint])
  run('git', ['config', 'commit.gpgsign', 'true'])
  run('git', ['config', 'tag.gpgsign', 'true'])
}

function remoteUrl() {
  return `https://oauth2:${process.env.GITLAB_TOKEN}@${process.env.CI_SERVER_HOST}/${process.env.CI_PROJECT_PATH}.git`
}

async function mergeRequestOptions() {
  const user = await api('GET', '/user')
  const milestones = await api('GET', `/projects/${projectId()}/milestones?state=active`)
  const milestone = Array.isArray(milestones.data)
    ? (milestones.data.find((item) => 'Maintenance' === item.title) ?? milestones.data[0])
    : null

  return {
    assignee_id: user.data.id,
    reviewer_ids: [user.data.id],
    labels: 'Kind::Chore',
    ...(milestone ? { milestone_id: milestone.id } : {}),
  }
}

/** Merge the request when its pipeline succeeds. GitLab needs a moment to create the pipeline of a new request. */
async function mergeWhenGreen(iid) {
  for (let attempt = 0; 18 > attempt; attempt++) {
    const result = await api('PUT', `/projects/${projectId()}/merge_requests/${iid}/merge`, {
      merge_when_pipeline_succeeds: true,
      should_remove_source_branch: true,
    })

    if (result.ok) {
      log(`Merge request !${iid}: it is merged when its pipeline succeeds.`)
      return true
    }

    await sleep(10_000)
  }

  log(`Merge request !${iid}: it could not be set to merge by itself, it stays open.`)

  return false
}

async function openMergeRequests(query = '') {
  const result = await api('GET', `/projects/${projectId()}/merge_requests?state=opened&per_page=100${query}`)

  return Array.isArray(result.data) ? result.data : []
}

function ncu(args) {
  return run('npx', ['--yes', 'npm-check-updates', '--target', 'minor', ...args, '-u'])
}

// ---------------------------------------------------------------------------------------------------------------------

/** Raise the overrides that pin a vulnerable version, then install. Returns the raised ones. */
function raiseVulnerableOverrides() {
  const manifest = JSON.parse(readFileSync('package.json', 'utf8'))
  if (!manifest.overrides) return {}

  const report = JSON.parse(capture('npm', ['audit', '--json']) || '{}')
  const fixes = fixedOverrides(manifest.overrides, report.vulnerabilities, (name) =>
    JSON.parse(capture('npm', ['view', name, 'versions', '--json']) || '[]')
  )

  for (const [name, version] of Object.entries(fixes)) {
    if ('string' === typeof manifest.overrides[name]) manifest.overrides[name] = version
    else manifest.overrides[name]['.'] = version
  }

  if (0 < Object.keys(fixes).length) {
    writeFileSync('package.json', `${JSON.stringify(manifest, null, 2)}\n`)
    run('npm', ['install', '--no-audit', '--no-fund'])
  }

  return fixes
}

async function update(config) {
  assertEnvironment()

  if ((await openMergeRequests()).some((request) => request.source_branch.startsWith(BRANCH_PREFIX))) {
    log('An update is already open: nothing to do.')
    return
  }

  configureSigning()
  const ecosystem = ECOSYSTEMS[detectEcosystem()]
  const before = JSON.parse(run('git', ['show', `HEAD:${ecosystem.file}`]))
  const branch = `${BRANCH_PREFIX}-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}`
  run('git', ['switch', '-C', branch])

  // A PHP project was prepared by the job before this one, in its own image: only npm is updated here.
  if ('package.json' === ecosystem.file) {
    // The new versions wait for the cooling period. The packages of the group are trusted: no waiting for them.
    const rejected = rejectedPackages(config, await readPolicy('npm'))
    const reject = 0 < rejected.length ? ['--reject', rejected.join(',')] : []
    // An update started by the audit (UPDATE_URGENT=true) fixes an advisory: the fix is not made to wait.
    const urgent = 'true' === process.env.UPDATE_URGENT
    ncu([...(urgent ? [] : ['--cooldown', config.cooldown]), ...reject])
    ncu(['--filter', '@zairakai/*', ...reject])
    run('npm', ['install', '--no-audit', '--no-fund'])

    // The lock file is refreshed inside the ranges, so that a fix of a package that this project only inherits arrives
    // (overrides of a dependency do not apply here). The new versions wait for the cooling period, except for a fix.
    const before = cooldownDate(config.cooldown)
    const names = refreshableNames(JSON.parse(readFileSync('package-lock.json', 'utf8')))

    // The refresh is a bonus: when npm cannot respect the cooling date (a range that starts at a version younger than
    // the period, after an urgent update), it waits for the next run and the update goes on.
    try {
      if (urgent || null === before) {
        run('npm', ['update', '--no-audit', '--no-fund'])
      } else if (0 < names.length) {
        run('npm', ['update', '--no-audit', '--no-fund', `--before=${before.toISOString()}`, ...names])
      }
    } catch (error) {
      log(`The lock file is not refreshed this time: ${secret(error.message).split('\n')[0]}`)
    }

    if (urgent) {
      try {
        run('npm', ['audit', 'fix', '--no-fund'])
      } catch (error) {
        log(`npm audit fix did not apply: ${secret(error.message).split('\n')[0]}`)
      }

      // npm audit fix leaves the overrides alone: one that pins a vulnerable version is raised here.
      try {
        const raised = raiseVulnerableOverrides()
        for (const [name, version] of Object.entries(raised)) log(`The override of ${name} is raised to ${version}.`)
      } catch (error) {
        log(`The overrides are not raised this time: ${secret(error.message).split('\n')[0]}`)
      }
    }
  }

  const after = JSON.parse(readFileSync(ecosystem.file, 'utf8'))
  const rows = diffDependencies(before, after, ecosystem.all)

  // Only the manifest and the lock file: the postinstall of the tools can rewrite other files of the project in CI.
  const files = [ecosystem.file, ...['package-lock.json', 'composer.lock'].filter((file) => existsSync(file))]

  // The one exception: the `ref:` of the shared pipeline follows the installed version of the tools.
  if (existsSync(PIPELINE_FILE) && isRefOnlyChange(run('git', ['diff', '-U0', '--', PIPELINE_FILE]))) {
    files.push(PIPELINE_FILE)
  }

  if ('' === run('git', ['status', '--porcelain', '--', ...files])) {
    log('Everything is up to date.')
    return
  }

  const table = formatChanges(rows)
  run('git', ['add', ...files])
  run('git', [
    'commit',
    '-m',
    COMMIT_SUBJECT,
    '-m',
    `Minor and patch updates, taken after ${config.cooldown} of age.\n\n${table}`,
  ])
  run('git', ['push', remoteUrl(), `HEAD:refs/heads/${branch}`])

  const request = await api('POST', `/projects/${projectId()}/merge_requests`, {
    source_branch: branch,
    target_branch: 'develop',
    title: COMMIT_SUBJECT,
    description: `Automatic update. The pipeline of this merge request is the gate: it is merged when it succeeds, and stays open otherwise. Major versions are never applied here.\n\n${table}`,
    remove_source_branch: true,
    ...(await mergeRequestOptions()),
  })

  if (!request.ok) throw new Error(`The merge request could not be created: ${secret(JSON.stringify(request.data))}`)

  log(`Merge request !${request.data.iid} created.`)
  await mergeWhenGreen(request.data.iid)
}

/** Close the issues whose advisory is gone from the merged tree. It never stops a release. */
async function closeObsolete() {
  try {
    const found = parseNpmAudit(JSON.parse(capture('npm', ['audit', '--json'])))

    await closeResolved(found.map(advisoryTitle), process.env.FRESHNESS_TOKEN || process.env.GITLAB_TOKEN)
  } catch (error) {
    log(`The obsolete issues could not be checked: ${secret(error.message).split('\n')[0]}`)
  }
}

async function release() {
  assertEnvironment()

  // The update that was just merged into develop may fix advisories: their issues have no reason to stay open.
  await closeObsolete()

  const existing = await openMergeRequests('&source_branch=develop&target_branch=main')

  if (0 < existing.length) {
    await mergeWhenGreen(existing[0].iid)
    return
  }

  const request = await api('POST', `/projects/${projectId()}/merge_requests`, {
    source_branch: 'develop',
    target_branch: 'main',
    title: COMMIT_SUBJECT,
    description: 'Brings the automatic update of the dependencies into main. It is merged when its pipeline succeeds.',
    ...(await mergeRequestOptions()),
  })

  if (!request.ok) throw new Error(`The merge request could not be created: ${secret(JSON.stringify(request.data))}`)

  log(`Merge request !${request.data.iid} created.`)
  await mergeWhenGreen(request.data.iid)
}

async function tag(config) {
  assertEnvironment()

  run('git', ['fetch', '--tags', '--quiet'])
  const last = latestTag(run('git', ['tag', '--list']).split('\n'))
  // git reads a basic regular expression: the parentheses of the subject are literal.
  const commits = last
    ? run('git', ['log', `${last}..HEAD`, '--format=%s', `--grep=^${COMMIT_SUBJECT}`])
        .split('\n')
        .filter(Boolean)
    : []
  const ecosystem = ECOSYSTEMS[detectEcosystem()]
  const before = last ? JSON.parse(run('git', ['show', `${last}:${ecosystem.file}`])) : null
  const after = JSON.parse(readFileSync(ecosystem.file, 'utf8'))

  const plan = planTag({ config, last, commits, before, after, sections: ecosystem.runtime })

  if (!plan.version) {
    log(`No tag: ${plan.reason}.`)
    return
  }

  configureSigning()
  run('git', ['tag', '-s', plan.version, '-m', plan.version, process.env.CI_COMMIT_SHA])
  run('git', ['push', remoteUrl(), `refs/tags/${plan.version}`])

  log(`Tag ${plan.version} signed and pushed (last tag ${last}): ${plan.reason}. Its pipeline publishes the package.`)
}

/** True when the registry of the ecosystem (npm or Packagist) lists the version. */
async function isAvailable(ecosystem, name, version) {
  if ('npm' === ecosystem) {
    return run('npm', ['view', `${name}@${version}`, 'version', '--prefer-online']) === version
  }

  const response = await fetch(`https://repo.packagist.org/p2/${name}.json`)

  if (!response.ok) return false

  const data = await response.json()

  return (data.packages?.[name] ?? []).some((release) => release.version === version)
}

async function cascade(config) {
  assertEnvironment()

  if (!config.cascade) {
    log('No cascade configured.')
    return
  }

  const ecosystem = detectEcosystem()
  const name = JSON.parse(readFileSync(ECOSYSTEMS[ecosystem].file, 'utf8')).name
  const version = process.env.CI_COMMIT_TAG

  if (!version) throw new Error('The cascade runs on the pipeline of a tag.')

  // The registry needs a few minutes to list a new version: wait for it instead of waiting for a fixed hour.
  let available = false

  for (let attempt = 0; 60 > attempt && !available; attempt++) {
    try {
      available = await isAvailable(ecosystem, name, version)
    } catch {
      available = false
    }

    if (!available) await sleep(30_000)
  }

  if (!available) throw new Error(`${name}@${version} is not on the registry after 30 minutes.`)

  for (const group of config.cascade.groups ?? []) {
    const projects = await api(
      'GET',
      `/groups/${encodeURIComponent(group)}/projects?include_subgroups=true&archived=false&per_page=100`
    )

    for (const project of Array.isArray(projects.data) ? projects.data : []) {
      if (String(project.id) === String(projectId())) continue

      // Opt-in: a project is updated only if it has the same file.
      const file = await api(
        'GET',
        `/projects/${project.id}/repository/files/${encodeURIComponent(CONFIG_FILE)}?ref=develop`
      )

      if (!file.ok) {
        log(`${project.path_with_namespace}: no ${CONFIG_FILE}, skipped.`)
        continue
      }

      const started = await api('POST', `/projects/${project.id}/pipeline`, {
        ref: 'develop',
        variables: [{ key: 'UPDATE_DEPENDENCIES', value: 'true' }],
      })

      log(`${project.path_with_namespace}: ${started.ok ? 'update started' : `not started (${started.status})`}.`)
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------------

async function issueExists(title, token) {
  const query = new URLSearchParams({ state: 'opened', search: title, in: 'title' })
  const result = await api('GET', `/projects/${projectId()}/issues?${query}`, undefined, token)

  return (Array.isArray(result.data) ? result.data : []).some((issue) => issue.title === title)
}

async function createIssue(title, description, labels, token) {
  // The assignee is given by the variable ISSUE_ASSIGNEE_ID; without it, the user of the token.
  let assignee = Number(process.env.ISSUE_ASSIGNEE_ID) || 0

  if (0 === assignee) assignee = (await api('GET', '/user', undefined, token)).data?.id ?? 0

  const issue = await api(
    'POST',
    `/projects/${projectId()}/issues`,
    { title, description, labels, assignee_ids: 0 < assignee ? [assignee] : [] },
    token
  )

  if (!issue.ok) throw new Error(`The issue could not be created: ${secret(JSON.stringify(issue.data))}`)

  return issue.data.web_url
}

/** Close the open issues of the audit whose advisory is not found any more. */
async function closeResolved(titles, token) {
  const query = new URLSearchParams({
    state: 'opened',
    labels: 'Automated',
    search: ADVISORY_TITLE_PREFIX,
    in: 'title',
    per_page: '100',
  })
  const result = await api('GET', `/projects/${projectId()}/issues?${query}`, undefined, token)

  for (const issue of Array.isArray(result.data) ? result.data : []) {
    if (!issue.title.startsWith(ADVISORY_TITLE_PREFIX) || titles.includes(issue.title)) continue

    const path = `/projects/${projectId()}/issues/${issue.iid}`
    await api(
      'POST',
      `${path}/notes`,
      { body: `The audit of ${process.env.CI_PIPELINE_URL} no longer finds this advisory.` },
      token
    )
    const closed = await api('PUT', path, { state_event: 'close' }, token)
    log(closed.ok ? `Issue closed: ${issue.title}` : `Issue not closed (${closed.status}): ${issue.title}`)
  }
}

/** A push notification through ntfy, when NTFY_URL is set. A failure never stops the audit. */
async function notify(title, message) {
  if (!process.env.NTFY_URL) return

  try {
    await fetch(process.env.NTFY_URL, {
      method: 'POST',
      headers: { Title: title },
      body: message,
      signal: AbortSignal.timeout(15000),
    })
  } catch {
    log('The ntfy alert could not be sent.')
  }
}

/** The policy of the ecosystem. When it cannot be read, the update stops (with an alert) instead of going blind. */
async function readPolicy(ecosystem) {
  try {
    const policy = await fetchPolicy(ecosystem)
    log(`Dependency policy: ${policy.entries.map((entry) => entry.package).join(', ') || 'nothing is held back'}.`)

    return policy
  } catch (error) {
    await notify('Dependency policy unreachable', `${process.env.CI_PROJECT_PATH}: ${secret(error.message)}`)
    throw error
  }
}

/** Open one issue per advisory that does not have one, and close the issues whose advisory is gone. */
async function audit() {
  assertEnvironment()

  const found = parseNpmAudit(JSON.parse(capture('npm', ['audit', '--json'])))
  const lock = existsSync('package-lock.json') ? JSON.parse(readFileSync('package-lock.json', 'utf8')) : null
  const auto = 'true' === process.env.AUTO_FIX
  const token = process.env.FRESHNESS_TOKEN || process.env.GITLAB_TOKEN
  const titles = []
  const opened = []
  let urgent = false

  log(`${found.length} security advisory(ies) found.`)

  for (const row of found) {
    const title = advisoryTitle(row)
    titles.push(title)
    urgent ||= isUrgent(row.severity)

    if (await issueExists(title, token)) {
      log(`Issue already open: ${title}`)
      continue
    }

    // Inherited from a package of the group: the issue is in the package that brings it, and the update of this project
    // takes the fix when there is one.
    if (isInherited(lock, row.package)) {
      log(`Inherited from the group, followed in the package that brings it: ${title}`)
      continue
    }

    const body = advisoryIssueBody(row, process.env.CI_PIPELINE_URL ?? '', auto)
    const url = await createIssue(title, body, advisoryLabels(row), token)
    log(`Issue created: ${url}`)
    opened.push({ row, url })
  }

  // One message per audit, whatever the number of new advisories.
  const alert = auditAlert(opened, process.env.CI_PROJECT_PATH)
  if (alert) await notify(alert.title, alert.message)

  await closeResolved(titles, token)

  if (!auto || !urgent) {
    log(auto ? 'Nothing urgent: the weekly update takes the rest.' : 'AUTO_FIX is off: update by hand.')
    return
  }

  if ((await openMergeRequests()).some((request) => request.source_branch.startsWith(BRANCH_PREFIX))) {
    log('An update is already open: nothing to start.')
    return
  }

  const started = await api(
    'POST',
    `/projects/${projectId()}/pipeline`,
    {
      ref: 'develop',
      variables: [
        { key: 'UPDATE_DEPENDENCIES', value: 'true' },
        { key: 'UPDATE_URGENT', value: 'true' },
      ],
    },
    token
  )
  log(started.ok ? 'Update started.' : `The update could not be started (${started.status}).`)
}

/** The peer range of `name` in the latest release of `peer`, or null. */
function peerRange(peer, name) {
  try {
    return JSON.parse(run('npm', ['view', peer, 'peerDependencies', '--json']) || '{}')?.[name] ?? null
  } catch {
    return null
  }
}

/** In the repository dependency-policy: check the shape of the files. */
async function policyValidate() {
  let failed = false

  for (const file of Object.values(POLICY_FILES)) {
    if (!existsSync(file)) continue

    let errors
    try {
      errors = validatePolicy(JSON.parse(readFileSync(file, 'utf8')))
    } catch (error) {
      errors = [`not valid JSON (${error.message}).`]
    }

    for (const message of errors) console.error(`${file}: ${message}`)
    failed ||= 0 < errors.length
  }

  if (failed) throw new Error('The dependency policy is not valid.')
  log('The dependency policy is valid.')
}

/** In the repository dependency-policy: lift the entries whose condition is met, with a merge request into main. */
async function policyWatch() {
  assertEnvironment()

  const file = POLICY_FILES.npm
  const doc = JSON.parse(readFileSync(file, 'utf8'))
  const errors = validatePolicy(doc)
  if (0 < errors.length) throw new Error(`${file} is not valid: ${errors.join(' ')}`)

  const lifted = doc.entries.filter((entry) => {
    if (!entry.unblock) return false

    const ranges = Object.fromEntries(entry.unblock.peers.map((peer) => [peer, peerRange(peer, entry.package)]))

    return isLifted(entry, ranges)
  })

  if (0 === lifted.length) {
    log('No entry can be lifted.')
    return
  }

  if ((await openMergeRequests()).some((request) => request.source_branch.startsWith(POLICY_BRANCH_PREFIX))) {
    log('A merge request that lifts an entry is already open.')
    return
  }

  const names = lifted.map((entry) => entry.package).join(', ')
  const branch = `${POLICY_BRANCH_PREFIX}-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}`
  const subject = `chore(policy): unblock ${names}`

  configureSigning()
  run('git', ['switch', '-C', branch])
  writeFileSync(
    file,
    `${JSON.stringify({ ...doc, entries: doc.entries.filter((entry) => !lifted.includes(entry)) }, null, 2)}\n`
  )
  run('git', ['add', file])
  run('git', ['commit', '-m', subject, '-m', 'The peer ranges of the packages that held it back now accept it.'])
  run('git', ['push', remoteUrl(), `HEAD:refs/heads/${branch}`])

  const request = await api('POST', `/projects/${projectId()}/merge_requests`, {
    source_branch: branch,
    target_branch: 'main',
    title: subject,
    description: `The condition of the entry is met: ${lifted.map((entry) => `${entry.package} ${entry.unblock.version} (${entry.unblock.peers.join(', ')})`).join('; ')}. It is merged when its pipeline succeeds, and the update tools take the package at their next run.`,
    remove_source_branch: true,
    ...(await mergeRequestOptions()),
  })

  if (!request.ok) throw new Error(`The merge request could not be created: ${secret(JSON.stringify(request.data))}`)

  log(`Merge request !${request.data.iid} created.`)
  await notify('Dependency policy: block lifted', `${names}: ${request.data.web_url}`)
  await mergeWhenGreen(request.data.iid)
}

/** Fail when the working tree updates a package of the policy compared with `base`: a range or a locked version. */
async function policyCheck(_config, base) {
  if (!base) throw new Error('Usage: node update-dependencies.mjs policy-check <ref>')

  const blocked = (await readPolicy('npm')).entries.map((entry) => entry.package)
  const atBase = (file) => {
    try {
      return JSON.parse(capture('git', ['show', `${base}:${file}`]))
    } catch {
      return null
    }
  }
  const now = (file) => (existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : null)

  const problems = policyViolations({
    blocked,
    beforeManifest: atBase('package.json'),
    afterManifest: now('package.json'),
    beforeLock: atBase('package-lock.json'),
    afterLock: now('package-lock.json'),
  })

  for (const problem of problems) console.error(problem)
  if (0 < problems.length) throw new Error('The change updates a package that the dependency policy holds back.')

  log('No package of the dependency policy is updated.')
}

/** Rewrite the ignore rules of .github/dependabot.yml from the policy. The workflow of the repository commits the result. */
async function dependabotSync() {
  if (!existsSync(DEPENDABOT_FILE)) throw new Error(`${DEPENDABOT_FILE} does not exist.`)

  const names = (await readPolicy('npm')).entries.map((entry) => entry.package)
  const text = readFileSync(DEPENDABOT_FILE, 'utf8')
  const synced = syncDependabot(text, names, 'npm')

  if (null === synced) {
    throw new Error(
      `${DEPENDABOT_FILE} has no block "# BEGIN dependency-policy (npm)" ... "# END dependency-policy (npm)".`
    )
  }

  if (synced === text) {
    log('The ignore rules of Dependabot are in sync with the policy.')
    return
  }

  writeFileSync(DEPENDABOT_FILE, synced)
  log(`The ignore rules of Dependabot are updated: ${names.join(', ') || 'none'}.`)
}

const modes = {
  update,
  release,
  tag,
  cascade,
  audit,
  policy: policyWatch,
  'policy-validate': policyValidate,
  'policy-check': policyCheck,
  'dependabot-sync': dependabotSync,
}

async function main(mode, argument) {
  if (!modes[mode]) {
    console.error(
      'Usage: node update-dependencies.mjs update | release | tag | cascade | audit | policy | policy-validate'
    )
    process.exitCode = 1
    return
  }

  try {
    await modes[mode](loadConfig(), argument)
  } catch (error) {
    console.error(secret(error.message))
    process.exitCode = 1
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(process.argv[2], process.argv[3])
}
