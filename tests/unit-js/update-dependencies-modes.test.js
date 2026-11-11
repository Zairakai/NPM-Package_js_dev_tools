import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

// The modes of the script talk to Git, npm, GPG and the GitLab API. Here they run against a fake of each of them: the
// commands that are run, the files that exist and the answers of the API are all in `world`.
const world = vi.hoisted(() => ({
  files: new Map(),
  commands: [],
  requests: [],
  exec: () => '',
  route: () => null,
}))

vi.mock('node:child_process', () => ({
  execFileSync: (command, args = [], options = {}) => {
    world.commands.push([command, ...args].join(' '))

    return world.exec(command, args, options)
  },
}))

vi.mock('node:fs', () => ({
  existsSync: (path) => world.files.has(path),
  readFileSync: (path) => {
    if (!world.files.has(path)) throw new Error(`ENOENT: ${path}`)

    return world.files.get(path)
  },
  writeFileSync: (path, data) => world.files.set(path, String(data)),
}))

const { main } = await import('../../scripts/update-dependencies.mjs')

const POLICY_URL = '/-/raw/main/node.json'
const ENV = {
  GITLAB_TOKEN: 'secret-token',
  CI_PROJECT_ID: '1',
  CI_PROJECT_PATH: 'zairakai/npm-packages/demo',
  CI_SERVER_HOST: 'gitlab.com',
  CI_COMMIT_SHA: 'abc123',
  CI_PIPELINE_URL: 'https://gitlab.com/p/1',
  GPG_PRIVATE_KEY_B64: Buffer.from('KEY').toString('base64'),
  RELEASE_SIGNER_NAME: 'Signer',
  RELEASE_SIGNER_EMAIL: 'signer@example.com',
}
const POLICY = { entries: [{ package: 'typescript', reason: 'peer', since: '2026-10-11' }] }

const defaultExec = (command, args) => {
  if (command === 'gpg' && args[0] === '--list-secret-keys') return 'sec\nfpr:::::::::ABCDEF:'

  return ''
}

// A route that answers the policy and the calls that every mode makes; `extra` answers the others.
const routes =
  (extra = () => null) =>
  (method, url, body) => {
    if (url.endsWith(POLICY_URL)) return { status: 200, body: POLICY }
    if (url.endsWith('/user')) return { status: 200, body: { id: 7 } }
    if (url.includes('/milestones')) return { status: 200, body: [{ id: 3, title: 'Maintenance' }] }

    return extra(method, url, body)
  }

// The API sends JSON; a notification sends a plain message.
const parseBody = (text) => {
  try {
    return text ? JSON.parse(text) : undefined
  } catch {
    return text
  }
}

const requested = (method, fragment) =>
  world.requests.filter((request) => request.method === method && request.url.includes(fragment))
const ran = (fragment) => world.commands.some((command) => command.includes(fragment))

let info
let error

beforeEach(() => {
  world.files.clear()
  world.commands.length = 0
  world.requests.length = 0
  world.exec = defaultExec
  world.route = routes()
  Object.assign(process.env, ENV)
  // A pipeline of a tag defines it: the tests that need a tag set it themselves
  delete process.env.CI_COMMIT_TAG
  process.exitCode = undefined

  vi.stubGlobal(
    'fetch',
    vi.fn(async (url, init = {}) => {
      const method = init.method ?? 'GET'
      const body = parseBody(init.body)
      world.requests.push({ method, url: String(url), body })
      const reply = world.route(method, String(url), body) ?? { status: 404, body: null }
      const text = reply.body === null || reply.body === undefined ? '' : JSON.stringify(reply.body)

      return { ok: reply.status < 400, status: reply.status, text: async () => text, json: async () => reply.body }
    }),
  )
  // The waits of the script (10 s, 30 s) are not waited for.
  vi.stubGlobal('setTimeout', (callback) => {
    callback()

    return 0
  })
  info = vi.spyOn(console, 'info').mockImplementation(() => {})
  error = vi.spyOn(console, 'error').mockImplementation(() => {})
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()

  for (const name of [
    ...Object.keys(ENV),
    'UPDATE_URGENT',
    'AUTO_FIX',
    'FRESHNESS_TOKEN',
    'NTFY_URL',
    'ISSUE_ASSIGNEE_ID',
  ]) {
    delete process.env[name]
  }
})

const said = (text) => info.mock.calls.some(([message]) => String(message).includes(text))
const failed = (text) => error.mock.calls.some(([message]) => String(message).includes(text))

describe('main', () => {
  it('refuses an unknown mode', async () => {
    await main('nothing')

    expect(process.exitCode).toBe(1)
    expect(failed('Usage')).toBe(true)
  })

  it('prints the error of a mode, without the token', async () => {
    delete process.env.CI_PROJECT_ID

    await main('release')

    expect(process.exitCode).toBe(1)
    expect(failed('CI_PROJECT_ID is not set')).toBe(true)
  })

  it('masks the token in a failed command', async () => {
    world.exec = () => {
      throw Object.assign(new Error('x'), { stderr: 'fatal: secret-token leaked' })
    }

    await main('tag')

    expect(error.mock.calls.flat().join('')).not.toContain('secret-token')
    expect(failed('***')).toBe(true)
  })
})

describe('policy-validate', () => {
  it('accepts a valid policy', async () => {
    world.files.set('node.json', JSON.stringify(POLICY))
    world.files.set('php.json', JSON.stringify({ entries: [] }))

    await main('policy-validate')

    expect(said('The dependency policy is valid.')).toBe(true)
    expect(process.exitCode).toBeUndefined()
  })

  it('reports a file that is not JSON and a file that is not valid', async () => {
    world.files.set('node.json', '{')
    world.files.set('php.json', JSON.stringify({ entries: [{}] }))

    await main('policy-validate')

    expect(process.exitCode).toBe(1)
    expect(failed('node.json: not valid JSON')).toBe(true)
    expect(failed('php.json: entries[0]')).toBe(true)
  })
})

describe('policy-check', () => {
  it('needs a reference', async () => {
    await main('policy-check')

    expect(failed('Usage')).toBe(true)
  })

  it('passes when no package of the policy changes', async () => {
    world.files.set('package.json', JSON.stringify({ devDependencies: { typescript: '^6.0.0' } }))
    world.exec = (command, args) =>
      command === 'git' && args[1] === 'origin/develop:package.json'
        ? JSON.stringify({ devDependencies: { typescript: '^6.0.0' } })
        : ''

    await main('policy-check', 'origin/develop')

    expect(said('No package of the dependency policy is updated.')).toBe(true)
  })

  it('fails when a package of the policy is updated', async () => {
    world.files.set('package.json', JSON.stringify({ devDependencies: { typescript: '^7.0.0' } }))
    world.exec = (command, args) =>
      command === 'git' && args[1] === 'origin/develop:package.json'
        ? JSON.stringify({ devDependencies: { typescript: '^6.0.0' } })
        : ''

    await main('policy-check', 'origin/develop')

    expect(process.exitCode).toBe(1)
    expect(failed('holds back')).toBe(true)
  })

  it('stops when the policy cannot be read, and sends an alert when NTFY_URL is set', async () => {
    process.env.NTFY_URL = 'https://ntfy.example/topic'
    world.route = (method, url) => (url.endsWith(POLICY_URL) ? { status: 500, body: null } : { status: 200, body: {} })

    await main('policy-check', 'origin/develop')

    expect(process.exitCode).toBe(1)
    expect(requested('POST', 'ntfy.example')).toHaveLength(1)
  })
})

describe('dependabot-sync', () => {
  const block = (names) =>
    [
      'updates:',
      '    # BEGIN dependency-policy (npm)',
      ...(names.length > 0 ? ['    ignore:', ...names.map((name) => `      - dependency-name: '${name}'`)] : []),
      '    # END dependency-policy (npm)',
    ].join('\n')

  it('needs the file', async () => {
    await main('dependabot-sync')

    expect(failed('.github/dependabot.yml does not exist.')).toBe(true)
  })

  it('needs the markers', async () => {
    world.files.set('.github/dependabot.yml', 'updates: []\n')

    await main('dependabot-sync')

    expect(failed('has no block')).toBe(true)
  })

  it('leaves a file that is in sync, with single quotes', async () => {
    world.files.set('.github/dependabot.yml', block(['typescript']))

    await main('dependabot-sync')

    expect(said('in sync')).toBe(true)
  })

  it('writes the rules of the policy', async () => {
    world.files.set('.github/dependabot.yml', block([]))

    await main('dependabot-sync')

    expect(world.files.get('.github/dependabot.yml')).toBe(block(['typescript']))
    expect(said('are updated: typescript')).toBe(true)
  })
})

describe('cascade', () => {
  const config = JSON.stringify({ cascade: { groups: ['zairakai/npm-packages'] } })

  beforeEach(() => {
    world.files.set('package.json', JSON.stringify({ name: '@zairakai/demo' }))
  })

  it('does nothing without a cascade', async () => {
    await main('cascade')

    expect(said('No cascade configured.')).toBe(true)
  })

  it('runs on the pipeline of a tag', async () => {
    world.files.set('.dependency-update.json', config)

    await main('cascade')

    expect(failed('pipeline of a tag')).toBe(true)
  })

  it('starts the update of the projects that opted in', async () => {
    process.env.CI_COMMIT_TAG = '2.0.0'
    world.files.set('.dependency-update.json', config)
    world.exec = () => '2.0.0'
    world.route = routes((method, url) => {
      if (url.includes('/groups/')) {
        return {
          status: 200,
          body: [
            { id: 1, path_with_namespace: 'self' },
            { id: 2, path_with_namespace: 'opted' },
            { id: 3, path_with_namespace: 'not-opted' },
            { id: 4, path_with_namespace: 'broken' },
          ],
        }
      }
      if (url.includes('/projects/3/repository/files')) return { status: 404, body: null }
      if (url.includes('/repository/files')) return { status: 200, body: {} }
      if (url.endsWith('/projects/4/pipeline')) return { status: 400, body: null }
      if (url.endsWith('/pipeline')) return { status: 201, body: {} }

      return null
    })

    await main('cascade')

    expect(said('opted: update started.')).toBe(true)
    expect(said('not-opted: no .dependency-update.json, skipped.')).toBe(true)
    expect(said('broken: not started (400).')).toBe(true)
    expect(requested('POST', '/projects/2/pipeline')[0].body.variables[0]).toEqual({
      key: 'UPDATE_DEPENDENCIES',
      value: 'true',
    })
    delete process.env.CI_COMMIT_TAG
  })

  it('waits for the registry, then gives up', async () => {
    process.env.CI_COMMIT_TAG = '2.0.0'
    world.files.set('.dependency-update.json', config)
    world.exec = () => '1.0.0'

    await main('cascade')

    expect(failed('is not on the registry')).toBe(true)
    delete process.env.CI_COMMIT_TAG
  })

  it('looks at Packagist for a Composer project', async () => {
    process.env.CI_COMMIT_TAG = '2.0.0'
    world.files.delete('package.json')
    world.files.set('composer.json', JSON.stringify({ name: 'zairakai/demo' }))
    world.files.set('.dependency-update.json', config)
    world.route = (method, url) => {
      if (url.includes('packagist'))
        return { status: 200, body: { packages: { 'zairakai/demo': [{ version: '2.0.0' }] } } }

      return { status: 200, body: [] }
    }

    await main('cascade')

    expect(requested('GET', 'packagist')).toHaveLength(1)
    expect(failed('')).toBe(false)
    delete process.env.CI_COMMIT_TAG
  })

  it('treats a missing Packagist page as not available', async () => {
    process.env.CI_COMMIT_TAG = '2.0.0'
    world.files.delete('package.json')
    world.files.set('composer.json', JSON.stringify({ name: 'zairakai/demo' }))
    world.files.set('.dependency-update.json', config)
    world.route = () => ({ status: 404, body: null })

    await main('cascade')

    expect(failed('is not on the registry')).toBe(true)
    delete process.env.CI_COMMIT_TAG
  })
})

describe('release', () => {
  it('opens a merge request from develop into main and sets it to merge', async () => {
    world.route = routes((method, url) => {
      if (method === 'GET' && url.includes('/merge_requests')) return { status: 200, body: [] }
      if (method === 'POST' && url.endsWith('/merge_requests')) return { status: 201, body: { iid: 12 } }
      if (method === 'PUT' && url.endsWith('/12/merge')) return { status: 200, body: {} }

      return { status: 200, body: [] }
    })

    await main('release')

    expect(said('Merge request !12 created.')).toBe(true)
    expect(said('it is merged when its pipeline succeeds')).toBe(true)
  })

  it('sets the open merge request to merge', async () => {
    world.route = routes((method, url) => {
      if (method === 'GET' && url.includes('source_branch=develop')) return { status: 200, body: [{ iid: 9 }] }
      if (method === 'PUT') return { status: 200, body: {} }

      return { status: 200, body: [] }
    })

    await main('release')

    expect(requested('PUT', '/9/merge')).toHaveLength(1)
  })

  it('leaves the request open when it cannot be set to merge', async () => {
    world.route = routes((method, url) => {
      if (method === 'GET' && url.includes('source_branch=develop')) return { status: 200, body: [{ iid: 9 }] }
      if (method === 'PUT') return { status: 405, body: null }

      return { status: 200, body: [] }
    })

    await main('release')

    expect(said('it stays open')).toBe(true)
  })

  it('fails when the request cannot be created', async () => {
    world.route = routes((method) =>
      method === 'POST' ? { status: 409, body: { message: 'x' } } : { status: 200, body: [] },
    )

    await main('release')

    expect(failed('could not be created')).toBe(true)
  })

  it('closes the issues whose advisory is gone', async () => {
    world.exec = (command, args) =>
      command === 'npm' && args[0] === 'audit' ? JSON.stringify({ vulnerabilities: {} }) : ''
    world.route = routes((method, url) => {
      if (method === 'GET' && url.includes('/issues')) {
        return {
          status: 200,
          body: [
            { iid: 4, title: 'Security advisory: old (GHSA-1)' },
            { iid: 5, title: 'Other' },
          ],
        }
      }
      if (method === 'GET') return { status: 200, body: [{ iid: 9 }] }

      return { status: 200, body: {} }
    })

    await main('release')

    expect(said('Issue closed: Security advisory: old (GHSA-1)')).toBe(true)
    expect(requested('PUT', '/issues/5')).toHaveLength(0)
  })

  it('does not stop a release when the audit cannot be read', async () => {
    world.exec = (command, args) => {
      if (command === 'npm' && args[0] === 'audit') throw new Error('offline')

      return ''
    }
    world.route = routes((method, url) =>
      method === 'GET' && url.includes('source_branch=develop')
        ? { status: 200, body: [{ iid: 9 }] }
        : { status: 200, body: {} },
    )

    await main('release')

    expect(said('could not be checked')).toBe(true)
  })
})

describe('tag', () => {
  const manifest = (range) =>
    JSON.stringify({ name: 'demo', dependencies: { a: range }, devDependencies: { b: '^1.0.0' } })
  const git =
    ({ tags = '1.0.0\n1.1.0', commits = 'chore(deps): update the dependencies', before = manifest('^1.0.0') } = {}) =>
    (command, args) => {
      const line = [command, ...args].join(' ')

      if (line === 'git tag --list') return tags
      if (line.startsWith('git log')) return commits
      if (line.startsWith('git show')) return before
      if (command === 'gpg' && args[0] === '--list-secret-keys') return 'fpr:::::::::ABCDEF:'

      return ''
    }

  it('signs and pushes the next tag when a published range changed', async () => {
    world.files.set('package.json', manifest('^1.1.0'))
    world.exec = git()

    await main('tag')

    expect(ran('git tag -s 1.1.1 -m 1.1.1 abc123')).toBe(true)
    expect(ran('git push https://oauth2:secret-token@gitlab.com/zairakai/npm-packages/demo.git refs/tags/1.1.1')).toBe(
      true,
    )
    expect(ran('git config user.signingkey ABCDEF')).toBe(true)
    expect(said('Tag 1.1.1 signed and pushed')).toBe(true)
  })

  it('makes no tag when there is none yet', async () => {
    world.files.set('package.json', manifest('^1.1.0'))
    world.exec = git({ tags: '' })

    await main('tag')

    expect(said('No tag: there is no tag yet.')).toBe(true)
    expect(ran('git tag -s')).toBe(false)
  })

  it('makes no tag when only a development dependency changed', async () => {
    world.files.set('package.json', manifest('^1.0.0'))
    world.exec = git()

    await main('tag')

    expect(said('only the development dependencies changed')).toBe(true)
  })

  it('refuses to tag without the signing key', async () => {
    delete process.env.GPG_PRIVATE_KEY_B64
    world.files.set('package.json', manifest('^1.1.0'))
    world.exec = git()

    await main('tag')

    expect(failed('GPG_PRIVATE_KEY_B64 not set')).toBe(true)
  })

  describe('when GPG is not in the image', () => {
    const withoutGpg = (installers) => {
      let installed = false

      return (command, args) => {
        if (command === 'gpg' && args[0] === '--version' && !installed) throw new Error('gpg: not found')
        if (installers.includes(command)) {
          installed = true

          return ''
        }
        if (command === 'apk' || command === 'apt-get') throw new Error(`${command}: not found`)

        return git()(command, args)
      }
    }

    it('adds it with apk, or with apt-get', async () => {
      for (const installer of ['apk', 'apt-get']) {
        world.commands.length = 0
        world.files.set('package.json', manifest('^1.1.0'))
        world.exec = withoutGpg([installer])

        await main('tag')

        expect(ran(`${installer} `)).toBe(true)
        expect(ran('git tag -s 1.1.1')).toBe(true)
      }
    })

    it('fails when it cannot be added', async () => {
      world.files.set('package.json', manifest('^1.1.0'))
      world.exec = withoutGpg([])

      await main('tag')

      expect(failed('gpg is not installed')).toBe(true)
    })

    it('fails when it is still missing after the install', async () => {
      world.files.set('package.json', manifest('^1.1.0'))
      world.exec = (command, args) => {
        if (command === 'gpg' && args[0] === '--version') throw new Error('gpg: not found')

        return git()(command, args)
      }

      await main('tag')

      expect(failed('gpg is not installed')).toBe(true)
    })
  })
})

describe('audit', () => {
  const report = (severity) =>
    JSON.stringify({
      vulnerabilities: {
        minimatch: {
          name: 'minimatch',
          severity,
          via: [
            {
              source: 1,
              name: 'minimatch',
              title: 'Denial of service',
              url: 'https://github.com/advisories/GHSA-aaaa',
              severity,
            },
          ],
        },
      },
    })
  const TITLE = 'Security advisory: minimatch (GHSA-aaaa)'
  const answering =
    ({
      issues = [],
      created = { status: 201, body: { web_url: 'https://gitlab.com/i/1' } },
      mergeRequests = [],
      pipeline = 201,
    } = {}) =>
    (method, url) => {
      if (method === 'GET' && url.includes('/issues')) return { status: 200, body: issues }
      if (method === 'POST' && url.endsWith('/issues')) return created
      if (method === 'GET' && url.includes('/merge_requests')) return { status: 200, body: mergeRequests }
      if (method === 'POST' && url.endsWith('/pipeline')) return { status: pipeline, body: {} }

      return { status: 200, body: {} }
    }

  beforeEach(() => {
    world.exec = (command, args) => (command === 'npm' && args[0] === 'audit' ? report('high') : '')
  })

  it('opens an issue for an advisory, alerts, and says that the update is by hand', async () => {
    process.env.NTFY_URL = 'https://ntfy.example/topic'
    world.route = routes(answering())

    await main('audit')

    expect(said('1 security advisory(ies) found.')).toBe(true)
    expect(said('Issue created: https://gitlab.com/i/1')).toBe(true)
    expect(requested('POST', '/issues')[0].body).toMatchObject({ title: TITLE, assignee_ids: [7] })
    expect(requested('POST', 'ntfy.example')).toHaveLength(1)
    expect(said('AUTO_FIX is off')).toBe(true)
  })

  it('uses the assignee of the variable, and the token of the freshness', async () => {
    process.env.ISSUE_ASSIGNEE_ID = '42'
    process.env.FRESHNESS_TOKEN = 'fresh'
    world.route = routes(answering())

    await main('audit')

    expect(requested('POST', '/issues')[0].body.assignee_ids).toEqual([42])
  })

  it('creates an issue without assignee when the user is unknown', async () => {
    world.route = (method, url) => {
      if (url.endsWith(POLICY_URL)) return { status: 200, body: POLICY }
      if (url.endsWith('/user')) return { status: 401, body: null }

      return answering()(method, url)
    }

    await main('audit')

    expect(requested('POST', '/issues')[0].body.assignee_ids).toEqual([])
  })

  it('does not open an issue twice', async () => {
    world.route = routes(answering({ issues: [{ title: TITLE }] }))

    await main('audit')

    expect(said(`Issue already open: ${TITLE}`)).toBe(true)
    expect(requested('POST', '/issues')).toHaveLength(0)
  })

  it('leaves an advisory that comes from a package of the group', async () => {
    world.files.set(
      'package-lock.json',
      JSON.stringify({
        packages: {
          '': { dependencies: { '@zairakai/other': '^1.0.0' } },
          'node_modules/@zairakai/other': { dependencies: { minimatch: '^1.0.0' } },
          'node_modules/minimatch': { version: '1.0.0' },
        },
      }),
    )
    world.route = routes(answering())

    await main('audit')

    expect(said('Inherited from the group')).toBe(true)
    expect(requested('POST', '/issues')).toHaveLength(0)
  })

  it('fails when the issue cannot be created', async () => {
    world.route = routes(answering({ created: { status: 500, body: { message: 'x' } } }))

    await main('audit')

    expect(failed('The issue could not be created')).toBe(true)
  })

  it('does not alert for an advisory of a low severity, which only gets its issue', async () => {
    process.env.NTFY_URL = 'https://ntfy.example/topic'
    world.exec = (command, args) => (command === 'npm' && args[0] === 'audit' ? report('low') : '')
    world.route = routes(answering())

    await main('audit')

    expect(requested('POST', '/issues')).toHaveLength(1)
    expect(requested('POST', 'ntfy.example')).toHaveLength(0)
  })

  it('counts the advisories of a low severity in the alert of the others', async () => {
    process.env.NTFY_URL = 'https://ntfy.example/topic'
    const both = JSON.stringify({
      vulnerabilities: {
        minimatch: {
          name: 'minimatch',
          severity: 'high',
          via: [{ source: 1, name: 'minimatch', url: 'https://github.com/advisories/GHSA-aaaa', severity: 'high' }],
        },
        nanoid: {
          name: 'nanoid',
          severity: 'low',
          via: [{ source: 2, name: 'nanoid', url: 'https://github.com/advisories/GHSA-bbbb', severity: 'low' }],
        },
      },
    })
    world.exec = (command, args) => (command === 'npm' && args[0] === 'audit' ? both : '')
    world.route = routes(answering())

    await main('audit')

    expect(requested('POST', 'ntfy.example')[0].body).toContain('1 more of a low severity')
  })

  it('starts the urgent update when AUTO_FIX is on', async () => {
    process.env.AUTO_FIX = 'true'
    world.route = routes(answering())

    await main('audit')

    expect(said('Update started.')).toBe(true)
    expect(requested('POST', '/pipeline')[0].body.variables).toContainEqual({ key: 'UPDATE_URGENT', value: 'true' })
  })

  it('says when the update could not be started', async () => {
    process.env.AUTO_FIX = 'true'
    world.route = routes(answering({ pipeline: 403 }))

    await main('audit')

    expect(said('The update could not be started (403).')).toBe(true)
  })

  it('does not start an update when one is open', async () => {
    process.env.AUTO_FIX = 'true'
    world.route = routes(answering({ mergeRequests: [{ source_branch: 'chore/update-dependencies-20261110' }] }))

    await main('audit')

    expect(said('nothing to start')).toBe(true)
  })

  it('leaves the rest to the weekly update when nothing is urgent', async () => {
    process.env.AUTO_FIX = 'true'
    world.exec = (command, args) => (command === 'npm' && args[0] === 'audit' ? report('moderate') : '')
    world.route = routes(answering())

    await main('audit')

    expect(said('Nothing urgent')).toBe(true)
  })
})

describe('policy', () => {
  const entry = {
    package: 'typescript',
    reason: 'peer',
    since: '2026-10-11',
    unblock: { version: '7.0.0', peers: ['typescript-eslint'] },
  }
  const peers = (range) => (command, args) =>
    command === 'npm' && args[0] === 'view' ? JSON.stringify({ typescript: range }) : defaultExec(command, args)
  const answering =
    ({ mergeRequests = [], created = { status: 201, body: { iid: 30, web_url: 'https://gitlab.com/mr/30' } } } = {}) =>
    (method, url) => {
      if (method === 'GET' && url.includes('/merge_requests')) return { status: 200, body: mergeRequests }
      if (method === 'POST' && url.endsWith('/merge_requests')) return created

      return { status: 200, body: {} }
    }

  beforeEach(() => {
    world.files.set(
      'node.json',
      JSON.stringify({ entries: [entry, { package: 'other', reason: 'x', since: '2026-10-11' }] }),
    )
  })

  it('refuses a policy that is not valid', async () => {
    world.files.set('node.json', JSON.stringify({ entries: [{}] }))

    await main('policy')

    expect(failed('node.json is not valid')).toBe(true)
  })

  it('lifts nothing while a peer does not accept the version', async () => {
    world.exec = peers('>=4.8.4 <6.1.0')

    await main('policy')

    expect(said('No entry can be lifted.')).toBe(true)
  })

  it('lifts nothing when the peer range cannot be read', async () => {
    world.exec = (command, args) => {
      if (command === 'npm') throw new Error('offline')

      return defaultExec(command, args)
    }

    await main('policy')

    expect(said('No entry can be lifted.')).toBe(true)
  })

  it('does not open a second merge request', async () => {
    world.exec = peers('>=4.8.4 <8')
    world.route = routes(answering({ mergeRequests: [{ source_branch: 'chore/unblock-20261110' }] }))

    await main('policy')

    expect(said('already open')).toBe(true)
  })

  it('opens a merge request that removes the entry and sets it to merge', async () => {
    world.exec = peers('>=4.8.4 <8')
    world.route = routes(answering())

    await main('policy')

    expect(JSON.parse(world.files.get('node.json')).entries.map((item) => item.package)).toEqual(['other'])
    expect(ran('git commit -m chore(policy): unblock typescript')).toBe(true)
    expect(requested('POST', '/merge_requests')[0].body).toMatchObject({ target_branch: 'main' })
    expect(said('Merge request !30 created.')).toBe(true)
  })

  it('fails when the merge request cannot be created', async () => {
    world.exec = peers('>=4.8.4 <8')
    world.route = routes(answering({ created: { status: 409, body: { message: 'x' } } }))

    await main('policy')

    expect(failed('could not be created')).toBe(true)
  })
})

describe('update', () => {
  const before = {
    name: 'demo',
    dependencies: { a: '^1.0.0' },
    devDependencies: { b: '^1.0.0' },
    overrides: { minimatch: '10.2.6' },
  }
  const after = { ...before, dependencies: { a: '^1.1.0' } }
  const lock = JSON.stringify({
    packages: { '': {}, 'node_modules/a': { version: '1.1.0' }, 'node_modules/@zairakai/x': { version: '1.0.0' } },
  })
  const answering =
    ({ mergeRequests = [], created = { status: 201, body: { iid: 20 } }, merge = 200 } = {}) =>
    (method, url) => {
      if (method === 'GET' && url.includes('/merge_requests')) return { status: 200, body: mergeRequests }
      if (method === 'POST' && url.endsWith('/merge_requests')) return created
      if (method === 'PUT' && url.endsWith('/merge')) return { status: merge, body: {} }

      return { status: 200, body: {} }
    }
  const git =
    ({ status = ' M package.json', diff = '', manifest = before } = {}) =>
    (command, args) => {
      const line = [command, ...args].join(' ')

      if (line.startsWith('git show HEAD:')) return JSON.stringify(manifest)
      if (line.startsWith('git status --porcelain')) return status
      if (line.startsWith('git diff -U0')) return diff
      if (command === 'npm' && args[0] === 'audit' && args[1] === '--json')
        return JSON.stringify({ vulnerabilities: {} })

      return defaultExec(command, args)
    }

  beforeEach(() => {
    world.files.set('package.json', JSON.stringify(after))
    world.files.set('package-lock.json', lock)
    world.exec = git()
    world.route = routes(answering())
  })

  it('does nothing when an update is already open', async () => {
    world.route = routes(answering({ mergeRequests: [{ source_branch: 'chore/update-dependencies-20261110' }] }))

    await main('update')

    expect(said('An update is already open: nothing to do.')).toBe(true)
    expect(ran('git switch')).toBe(false)
  })

  it('updates in the ranges, with the cooling period and without the packages of the policy', async () => {
    await main('update')

    expect(ran('npm-check-updates --target minor --cooldown 3d --reject typescript -u')).toBe(true)
    expect(ran('npm-check-updates --target minor --filter @zairakai/* --reject typescript -u')).toBe(true)
    expect(ran('npm update --no-audit --no-fund --before=')).toBe(true)
    expect(ran('git commit -m chore(deps): update the dependencies')).toBe(true)
    expect(requested('POST', '/merge_requests')[0].body).toMatchObject({ target_branch: 'develop', milestone_id: 3 })
    expect(said('Merge request !20 created.')).toBe(true)
  })

  it('commits the pipeline file when only its ref changed', async () => {
    world.files.set('.gitlab-ci.yml', 'ref: 1.0.0')
    world.exec = git({ diff: '-    ref: 1.0.0\n+    ref: 1.1.0' })

    await main('update')

    expect(ran('git add package.json package-lock.json .gitlab-ci.yml')).toBe(true)
  })

  it('does not commit the pipeline file when more than its ref changed', async () => {
    world.files.set('.gitlab-ci.yml', 'x')
    world.exec = git({ diff: '-    ref: 1.0.0\n+    ref: 1.1.0\n+    other: 1' })

    await main('update')

    expect(ran('git add package.json package-lock.json')).toBe(true)
    expect(world.commands.some((command) => command.startsWith('git add') && command.includes('.gitlab-ci.yml'))).toBe(
      false,
    )
  })

  it('says when everything is up to date', async () => {
    world.exec = git({ status: '' })

    await main('update')

    expect(said('Everything is up to date.')).toBe(true)
    expect(ran('git commit')).toBe(false)
  })

  it('refreshes the whole lock file when the cooling period is not a duration', async () => {
    world.files.set('.dependency-update.json', JSON.stringify({ cooldown: 'soon', reject: ['left'] }))

    await main('update')

    expect(ran('npm update --no-audit --no-fund')).toBe(true)
    expect(ran('--before=')).toBe(false)
    expect(ran('--reject left,typescript')).toBe(true)
  })

  it('goes on when the lock file cannot be refreshed', async () => {
    const base = world.exec
    world.exec = (command, args) => {
      if (command === 'npm' && args[0] === 'update') throw new Error('ETARGET\nmore')

      return base(command, args)
    }

    await main('update')

    expect(said('The lock file is not refreshed this time')).toBe(true)
    expect(said('failed: ETARGET')).toBe(true)
    expect(said('Merge request !20 created.')).toBe(true)
  })

  it('fixes an advisory without waiting, and raises an override that pins a vulnerable version', async () => {
    process.env.UPDATE_URGENT = 'true'
    const base = world.exec
    world.exec = (command, args) => {
      if (command === 'npm' && args[0] === 'audit' && args[1] === '--json') {
        return JSON.stringify({ vulnerabilities: { minimatch: { range: '>=10.0.0 <10.2.7' } } })
      }
      if (command === 'npm' && args[0] === 'view') return JSON.stringify(['10.2.6', '10.2.7', '11.0.0'])

      return base(command, args)
    }

    await main('update')

    expect(ran('--cooldown')).toBe(false)
    expect(ran('npm audit fix --no-fund')).toBe(true)
    expect(JSON.parse(world.files.get('package.json')).overrides.minimatch).toBe('10.2.7')
    expect(said('The override of minimatch is raised to 10.2.7.')).toBe(true)
  })

  it('raises an override that is written as an object', async () => {
    process.env.UPDATE_URGENT = 'true'
    world.files.set('package.json', JSON.stringify({ ...after, overrides: { 'js-yaml': { '.': '4.3.1' } } }))
    const base = world.exec
    world.exec = (command, args) => {
      if (command === 'npm' && args[0] === 'audit' && args[1] === '--json') {
        return JSON.stringify({ vulnerabilities: { 'js-yaml': { range: '<4.3.2' } } })
      }
      if (command === 'npm' && args[0] === 'view') return JSON.stringify(['4.3.1', '4.3.2'])

      return base(command, args)
    }

    await main('update')

    expect(JSON.parse(world.files.get('package.json')).overrides['js-yaml']['.']).toBe('4.3.2')
  })

  it('goes on when the fix of the advisory fails', async () => {
    process.env.UPDATE_URGENT = 'true'
    const base = world.exec
    world.exec = (command, args) => {
      if (command === 'npm' && args[0] === 'audit' && args[1] === 'fix') throw new Error('no fix\nmore')
      if (command === 'npm' && args[0] === 'audit') throw new Error('audit down\nmore')

      return base(command, args)
    }

    await main('update')

    expect(said('npm audit fix did not apply')).toBe(true)
    expect(said('failed: no fix')).toBe(true)
    expect(said('The overrides are not raised this time')).toBe(true)
    expect(said('Merge request !20 created.')).toBe(true)
  })

  it('has nothing to raise without overrides', async () => {
    process.env.UPDATE_URGENT = 'true'
    world.files.set('package.json', JSON.stringify({ ...after, overrides: undefined }))

    await main('update')

    expect(said('Merge request !20 created.')).toBe(true)
  })

  it('stops when the policy cannot be read', async () => {
    world.route = (method, url) => (url.endsWith(POLICY_URL) ? { status: 503, body: null } : { status: 200, body: [] })

    await main('update')

    expect(failed('The dependency policy could not be read')).toBe(true)
    expect(ran('npm-check-updates')).toBe(false)
  })

  it('fails when the merge request cannot be created', async () => {
    world.route = routes(answering({ created: { status: 422, body: { message: 'x' } } }))

    await main('update')

    expect(failed('The merge request could not be created')).toBe(true)
  })

  it('leaves the request open when it cannot be set to merge', async () => {
    world.route = routes(answering({ merge: 405 }))

    await main('update')

    expect(said('it stays open')).toBe(true)
  })

  it('updates a Composer project from its manifest, without npm', async () => {
    world.files.delete('package.json')
    world.files.delete('package-lock.json')
    world.files.set('composer.json', JSON.stringify({ require: { a: '^1.1' } }))
    world.exec = git({ manifest: { require: { a: '^1.0' } } })

    await main('update')

    expect(ran('npm-check-updates')).toBe(false)
    expect(ran('git add composer.json')).toBe(true)
    expect(said('Merge request !20 created.')).toBe(true)
  })

  it('sets no milestone when the project has none', async () => {
    world.route = (method, url) => {
      if (url.includes('/milestones')) return { status: 200, body: [] }

      return routes(answering())(method, url)
    }

    await main('update')

    expect(requested('POST', '/merge_requests')[0].body).not.toHaveProperty('milestone_id')
  })
})
