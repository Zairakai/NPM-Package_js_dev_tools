#!/usr/bin/env node
/**
 * Automatic updates of the dependencies of a package of the zairakai group.
 *
 * Usage: node update-dependencies.mjs update | release | tag | cascade
 *
 * - update: prepare a branch with the minor and patch updates, open a merge request into develop and merge it when its
 *   pipeline succeeds. The pipeline of the merge request is the gate: nothing is tested here.
 * - release: open the merge request of develop into main after an update, and merge it when its pipeline succeeds.
 * - tag: tag main when a runtime range changed since the last tag (see `tag` in .dependency-update.json).
 * - cascade: after the publication of this package, start the update of the projects that use it.
 *
 * It reads `.dependency-update.json` at the root of the project (everything is optional):
 *
 *   {
 *     "reject": ["typescript"],                 packages that are never updated
 *     "cooldown": "3d",                         minimum age of a new version
 *     "tag": { "when": "runtime", "level": "patch" },   when: runtime | always | never, level: patch | minor
 *     "cascade": { "groups": ["zairakai/npm-packages"] }   projects to start (opt-in: they have the same file)
 *   }
 *
 * Environment: GITLAB_TOKEN (group variable), and the variables of GitLab CI.
 */
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const CONFIG_FILE = '.dependency-update.json'
const COMMIT_SUBJECT = 'chore(deps): update the dependencies'
const BRANCH_PREFIX = 'chore/update-dependencies'

const DEFAULTS = {
  reject: ['typescript'],
  cooldown: '3d',
  tag: { when: 'runtime', level: 'patch' },
  cascade: null,
}

const RUNTIME_SECTIONS = ['dependencies', 'peerDependencies', 'optionalDependencies']
const ALL_SECTIONS = ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies']

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
export function runtimeChanged(before, after) {
  return RUNTIME_SECTIONS.some((section) => sorted(before?.[section]) !== sorted(after?.[section]))
}

/** The dependencies whose range changed, with the section, the old range and the new one. */
export function diffDependencies(before, after) {
  const rows = []

  for (const section of ALL_SECTIONS) {
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
export function planTag({ config, last, commits, before, after }) {
  if ('never' === config.tag.when) return { version: null, reason: 'the project is never tagged by the update' }
  if (!last) return { version: null, reason: 'there is no tag yet' }
  if (0 === commits.length) return { version: null, reason: 'no update since the last tag' }

  if ('runtime' === config.tag.when && !runtimeChanged(before, after)) {
    return { version: null, reason: 'only the development dependencies changed: the published archive is the same' }
  }

  return { version: nextVersion(last, config.tag.level), reason: 'a published range changed' }
}

// ---------------------------------------------------------------------------------------------------------------------

const log = (message) => console.info(message)

function secret(text) {
  const token = process.env.GITLAB_TOKEN

  return token ? String(text).split(token).join('***') : String(text)
}

function run(command, args = [], options = {}) {
  try {
    return execFileSync(command, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...options }).trim()
  } catch (error) {
    throw new Error(secret(`${command} ${args.join(' ')} failed: ${error.stderr || error.message}`), { cause: error })
  }
}

async function api(method, path, body) {
  const response = await fetch(`${process.env.CI_API_V4_URL ?? 'https://gitlab.com/api/v4'}${path}`, {
    method,
    headers: { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN ?? '', 'Content-Type': 'application/json' },
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

async function update(config) {
  assertEnvironment()

  if ((await openMergeRequests()).some((request) => request.source_branch.startsWith(BRANCH_PREFIX))) {
    log('An update is already open: nothing to do.')
    return
  }

  configureSigning()
  const before = JSON.parse(readFileSync('package.json', 'utf8'))
  const branch = `${BRANCH_PREFIX}-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}`
  run('git', ['switch', '-c', branch])

  // The new versions wait for the cooling period. The packages of the group are trusted: no waiting for them.
  const reject = 0 < config.reject.length ? ['--reject', config.reject.join(',')] : []
  ncu(['--cooldown', config.cooldown, ...reject])
  ncu(['--filter', '@zairakai/*', ...reject])
  run('npm', ['install', '--no-audit', '--no-fund'])

  const after = JSON.parse(readFileSync('package.json', 'utf8'))
  const rows = diffDependencies(before, after)

  if ('' === run('git', ['status', '--porcelain'])) {
    log('Everything is up to date.')
    return
  }

  const table = formatChanges(rows)
  run('git', ['add', '-A'])
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

async function release() {
  assertEnvironment()

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
  const commits = last
    ? run('git', ['log', `${last}..HEAD`, '--format=%s', `--grep=^${COMMIT_SUBJECT.replace(/[()]/g, '\\$&')}`])
        .split('\n')
        .filter(Boolean)
    : []
  const before = last ? JSON.parse(run('git', ['show', `${last}:package.json`])) : null
  const after = JSON.parse(readFileSync('package.json', 'utf8'))

  const plan = planTag({ config, last, commits, before, after })

  if (!plan.version) {
    log(`No tag: ${plan.reason}.`)
    return
  }

  configureSigning()
  run('git', ['tag', '-s', plan.version, '-m', plan.version, process.env.CI_COMMIT_SHA])
  run('git', ['push', remoteUrl(), `refs/tags/${plan.version}`])

  log(`Tag ${plan.version} signed and pushed (last tag ${last}): ${plan.reason}. Its pipeline publishes the package.`)
}

async function cascade(config) {
  assertEnvironment()

  if (!config.cascade) {
    log('No cascade configured.')
    return
  }

  const name = JSON.parse(readFileSync('package.json', 'utf8')).name
  const version = process.env.CI_COMMIT_TAG

  if (!version) throw new Error('The cascade runs on the pipeline of a tag.')

  // The registry needs a few minutes to list a new version: wait for it instead of waiting for a fixed hour.
  let available = false

  for (let attempt = 0; 60 > attempt && !available; attempt++) {
    try {
      available = run('npm', ['view', `${name}@${version}`, 'version', '--prefer-online']) === version
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

const modes = { update, release, tag, cascade }

async function main(mode) {
  if (!modes[mode]) {
    console.error('Usage: node update-dependencies.mjs update | release | tag | cascade')
    process.exitCode = 1
    return
  }

  try {
    await modes[mode](loadConfig())
  } catch (error) {
    console.error(secret(error.message))
    process.exitCode = 1
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(process.argv[2])
}
