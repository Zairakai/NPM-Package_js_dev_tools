import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

import {
  advisoryIssueBody,
  advisoryLabels,
  advisoryTitle,
  auditAlert,
  cooldownDate,
  detectEcosystem,
  diffDependencies,
  fetchPolicy,
  formatChanges,
  isInherited,
  isLifted,
  isNotable,
  isRefOnlyChange,
  isUrgent,
  latestTag,
  loadConfig,
  nextVersion,
  parseNpmAudit,
  planTag,
  refreshableNames,
  rejectedPackages,
  runtimeChanged,
  signerIdentity,
  validatePolicy,
} from '../../scripts/update-dependencies.mjs'

describe('latestTag', () => {
  it('takes the highest X.Y.Z, comparing numbers and not text', () => {
    expect(latestTag(['1.9.0', '1.10.0', '1.2.0'])).toBe('1.10.0')
  })

  it('ignores the tags with a prefix or a suffix', () => {
    expect(latestTag(['v9.0.0', '1.0.0', '2.0.0-rc.1'])).toBe('1.0.0')
  })

  it('has no tag when there is none', () => {
    expect(latestTag([''])).toBeNull()
  })
})

describe('nextVersion', () => {
  it.each([
    ['1.4.2', 'patch', '1.4.3'],
    ['1.4.2', 'minor', '1.5.0'],
    ['1.4.2', 'major', '2.0.0'],
  ])('%s with a %s change gives %s', (last, level, expected) => {
    expect(nextVersion(last, level)).toBe(expected)
  })
})

describe('runtimeChanged', () => {
  it('ignores the development dependencies', () => {
    const before = { dependencies: { dayjs: '^1.0.0' }, devDependencies: { vitest: '^4.0.0' } }
    const after = { dependencies: { dayjs: '^1.0.0' }, devDependencies: { vitest: '^5.0.0' } }

    expect(runtimeChanged(before, after)).toBe(false)
  })

  it('sees a range of dependencies or of peerDependencies', () => {
    expect(runtimeChanged({ dependencies: { dayjs: '^1.0.0' } }, { dependencies: { dayjs: '^1.1.0' } })).toBe(true)
    expect(
      runtimeChanged({ peerDependencies: { zod: '^3.0.0' } }, { peerDependencies: { zod: '^3.0.0 || ^4.0.0' } })
    ).toBe(true)
  })

  it('does not depend on the order of the keys', () => {
    expect(runtimeChanged({ dependencies: { a: '1', b: '2' } }, { dependencies: { b: '2', a: '1' } })).toBe(false)
  })

  it('sees a dependency that appears', () => {
    expect(runtimeChanged({}, { dependencies: { axios: '^1.0.0' } })).toBe(true)
  })
})

describe('diffDependencies', () => {
  it('lists what changed, sorted, with the section', () => {
    const before = { dependencies: { b: '^1.0.0' }, devDependencies: { a: '^1.0.0', c: '^1.0.0' } }
    const after = { dependencies: { b: '^1.1.0' }, devDependencies: { a: '^1.0.0', c: '^2.0.0', d: '^1.0.0' } }

    expect(diffDependencies(before, after)).toEqual([
      { section: 'dependencies', name: 'b', from: '^1.0.0', to: '^1.1.0' },
      { section: 'devDependencies', name: 'c', from: '^1.0.0', to: '^2.0.0' },
      { section: 'devDependencies', name: 'd', from: null, to: '^1.0.0' },
    ])
  })

  it('formats a Markdown table', () => {
    const table = formatChanges([{ section: 'dependencies', name: 'b', from: '^1.0.0', to: null }])

    expect(table.split('\n')).toEqual([
      '| Section | Package | From | To |',
      '| --- | --- | --- | --- |',
      '| dependencies | b | ^1.0.0 | - |',
    ])
  })
})

describe('planTag', () => {
  const base = { last: '1.0.0', commits: ['chore(deps): update the dependencies'] }
  const runtime = { dependencies: { dayjs: '^1.0.0' } }

  it('does not tag a project that only changed its development dependencies', () => {
    const plan = planTag({
      ...base,
      config: loadConfig('/missing'),
      before: { ...runtime },
      after: { ...runtime, devDependencies: { x: '1' } },
    })

    expect(plan.version).toBeNull()
  })

  it('tags a patch version when a published range changed', () => {
    const plan = planTag({
      ...base,
      config: loadConfig('/missing'),
      before: runtime,
      after: { dependencies: { dayjs: '^1.1.0' } },
    })

    expect(plan.version).toBe('1.0.1')
  })

  it('tags a minor version for a project configured with the level minor', () => {
    const config = { ...loadConfig('/missing'), tag: { when: 'runtime', level: 'minor' } }
    const plan = planTag({ ...base, config, before: runtime, after: { dependencies: { dayjs: '^1.1.0' } } })

    expect(plan.version).toBe('1.1.0')
  })

  it('tags when the configuration says always', () => {
    const config = { ...loadConfig('/missing'), tag: { when: 'always', level: 'patch' } }

    expect(planTag({ ...base, config, before: runtime, after: runtime }).version).toBe('1.0.1')
  })

  it('never tags without an update since the last tag, or when told never', () => {
    const config = loadConfig('/missing')

    expect(
      planTag({ ...base, commits: [], config, before: runtime, after: { dependencies: { dayjs: '^2.0.0' } } }).version
    ).toBeNull()
    expect(
      planTag({
        ...base,
        config: { ...config, tag: { when: 'never', level: 'patch' } },
        before: runtime,
        after: { dependencies: { dayjs: '^2.0.0' } },
      }).version
    ).toBeNull()
  })
})

describe('loadConfig', () => {
  it('has defaults when the file is missing', () => {
    expect(loadConfig('/missing')).toMatchObject({
      reject: [],
      cooldown: '3d',
      tag: { when: 'runtime', level: 'patch' },
    })
  })

  it('completes a partial file', () => {
    const directory = mkdtempSync(join(tmpdir(), 'update-'))
    const path = join(directory, '.dependency-update.json')
    writeFileSync(path, JSON.stringify({ reject: ['vue-tsc'], tag: { level: 'minor' } }))

    expect(loadConfig(path)).toMatchObject({
      reject: ['vue-tsc'],
      cooldown: '3d',
      tag: { when: 'runtime', level: 'minor' },
    })
  })
})

describe('signerIdentity', () => {
  const env = {
    GPG_PRIVATE_KEY_B64: Buffer.from('-----BEGIN PGP PRIVATE KEY BLOCK-----').toString('base64'),
    RELEASE_SIGNER_NAME: 'Stanislas Poisson (autoupdate)',
    RELEASE_SIGNER_EMAIL: 'contact@stanislas-poisson.fr',
  }

  it('reads the identity and decodes the key', () => {
    expect(signerIdentity(env)).toEqual({
      name: 'Stanislas Poisson (autoupdate)',
      email: 'contact@stanislas-poisson.fr',
      key: '-----BEGIN PGP PRIVATE KEY BLOCK-----',
    })
  })

  it('refuses to go on without the key or the identity', () => {
    expect(() => signerIdentity({ ...env, GPG_PRIVATE_KEY_B64: '' })).toThrow('GPG_PRIVATE_KEY_B64')
    expect(() => signerIdentity({})).toThrow('RELEASE_SIGNER_NAME')
  })
})

describe('the PHP ecosystem', () => {
  it('detects the ecosystem from the manifest at the root', () => {
    expect(detectEcosystem(() => true)).toBe('npm')
    expect(detectEcosystem(() => false)).toBe('composer')
  })

  it('looks at the sections that are published in composer.json', () => {
    const before = { require: { 'laravel/framework': '^12.0' }, 'require-dev': { pint: '^1.0' } }

    expect(runtimeChanged(before, { ...before, 'require-dev': { pint: '^2.0' } }, ['require'])).toBe(false)
    expect(runtimeChanged(before, { ...before, require: { 'laravel/framework': '^12.0 || ^13.0' } }, ['require'])).toBe(
      true
    )
  })

  it('lists the changes of the sections it is given', () => {
    const rows = diffDependencies({ 'require-dev': { pint: '^1.0' } }, { 'require-dev': { pint: '^1.1' } }, [
      'require',
      'require-dev',
    ])

    expect(rows).toEqual([{ section: 'require-dev', name: 'pint', from: '^1.0', to: '^1.1' }])
  })

  it('does not tag a PHP project that only changed its development requirements', () => {
    const before = { require: { php: '^8.4' }, 'require-dev': { pint: '^1.0' } }
    const after = { require: { php: '^8.4' }, 'require-dev': { pint: '^1.1' } }
    const plan = planTag({
      config: loadConfig('/missing'),
      last: '1.0.0',
      commits: ['chore(deps): update the dependencies'],
      before,
      after,
      sections: ['require'],
    })

    expect(plan.version).toBeNull()
  })
})

describe('isRefOnlyChange', () => {
  const header = ['--- a/.gitlab-ci.yml', '+++ b/.gitlab-ci.yml', '@@ -6 +6 @@']

  it('accepts the move of the ref of the shared pipeline', () => {
    expect(isRefOnlyChange([...header, '-    ref: 3.7.0', '+    ref: 3.7.1'].join('\n'))).toBe(true)
  })

  it('refuses a change of another line', () => {
    const diff = [...header, '-    file: ".gitlab/a.yml"', '+    file: ".gitlab/b.yml"'].join('\n')

    expect(isRefOnlyChange(diff)).toBe(false)
  })

  it('refuses a ref with another line changed next to it', () => {
    expect(isRefOnlyChange([...header, '-    ref: 3.7.0', '+    ref: 3.7.1', '+  extra: true'].join('\n'))).toBe(false)
  })

  it('has nothing to commit when the file is the same', () => {
    expect(isRefOnlyChange('')).toBe(false)
  })
})

describe('parseNpmAudit', () => {
  const report = {
    vulnerabilities: {
      lodash: {
        name: 'lodash',
        severity: 'high',
        via: [
          {
            source: 1106913,
            name: 'lodash',
            title: 'Prototype Pollution',
            url: 'https://github.com/advisories/GHSA-p6mc-m468-83gw',
            severity: 'high',
            range: '<4.17.21',
          },
        ],
      },
      'consumer-of-lodash': { name: 'consumer-of-lodash', severity: 'high', via: ['lodash'] },
    },
  }

  it('reads one row per advisory, on the package that has it', () => {
    expect(parseNpmAudit(report)).toEqual([
      {
        id: 'GHSA-p6mc-m468-83gw',
        package: 'lodash',
        title: 'Prototype Pollution',
        link: 'https://github.com/advisories/GHSA-p6mc-m468-83gw',
        severity: 'high',
        range: '<4.17.21',
      },
    ])
  })

  it('counts an advisory once when several packages lead to it', () => {
    const twice = { vulnerabilities: { a: report.vulnerabilities.lodash, b: report.vulnerabilities.lodash } }

    expect(parseNpmAudit(twice)).toHaveLength(1)
  })

  it('falls back on the number of the advisory when it has no URL', () => {
    const noUrl = {
      vulnerabilities: { x: { name: 'x', via: [{ source: 42, name: 'x', title: 'T', severity: 'low' }] } },
    }

    expect(parseNpmAudit(noUrl)[0].id).toBe('42')
  })

  it('has nothing for a clean report', () => {
    expect(parseNpmAudit({ vulnerabilities: {} })).toEqual([])
    expect(parseNpmAudit({})).toEqual([])
  })
})

describe('advisories', () => {
  it('titles the issue with a stable key', () => {
    expect(advisoryTitle({ package: 'lodash', id: 'GHSA-1' })).toBe('Security advisory: lodash (GHSA-1)')
  })

  it('fixes without waiting only the serious or unknown severities', () => {
    expect(['critical', 'high', ''].every(isUrgent)).toBe(true)
    expect(['moderate', 'low'].some(isUrgent)).toBe(false)
  })

  it('notifies from moderate up, and for an unknown severity', () => {
    expect(['critical', 'high', 'moderate', ''].every(isNotable)).toBe(true)
    expect(isNotable('low')).toBe(false)
  })

  it('sends one message for the notable advisories and counts the low ones', () => {
    const opened = [
      { row: { package: 'zod', id: 'GHSA-1', severity: 'high' }, url: 'https://x.test/1' },
      { row: { package: 'katex', id: 'GHSA-2', severity: 'low' }, url: 'https://x.test/2' },
    ]
    const alert = auditAlert(opened, 'zairakai/npm-packages/x')

    expect(alert.title).toBe('Security advisories: 1 new in zairakai/npm-packages/x')
    expect(alert.message).toBe('zod (GHSA-1, high): https://x.test/1\n1 more of a low severity, issue only.')
  })

  it('sends nothing when only low advisories were opened', () => {
    expect(auditAlert([{ row: { package: 'katex', id: 'GHSA-2', severity: 'low' }, url: 'u' }], 'p')).toBeNull()
    expect(auditAlert([], 'p')).toBeNull()
  })

  it('sets the priority from the severity, and the status', () => {
    expect(advisoryLabels({ severity: 'critical' })).toContain('Priority::Critical')
    expect(advisoryLabels({ severity: 'high' })).toContain('Priority::High')
    expect(advisoryLabels({ severity: 'moderate' })).toContain('Priority::Low')
    expect(advisoryLabels({ severity: '' })).toBe('Kind::Security,Area::Security,Automated,Priority::Low,Status::Ready')
  })

  it('describes the advisory and the automatic fix in the issue', () => {
    const row = {
      id: 'GHSA-1',
      package: 'lodash',
      title: 'Prototype Pollution',
      link: 'https://x.test/1',
      severity: 'high',
      range: '<4.17.21',
    }

    expect(advisoryIssueBody(row, 'https://ci.test/1', true)).toContain('Automatic fix: started')
    expect(advisoryIssueBody({ ...row, severity: 'low' }, 'https://ci.test/1', true)).toContain('Automatic fix: off')
    expect(advisoryIssueBody(row, 'https://ci.test/1', false)).toContain('`lodash`')
  })
})

describe('dependency policy', () => {
  const entry = {
    package: 'typescript',
    reason: 'Not accepted by typescript-eslint.',
    since: '2026-10-11',
    unblock: { version: '7.0.0', peers: ['typescript-eslint'] },
  }

  it('accepts a valid policy and an empty one', () => {
    expect(validatePolicy({ entries: [entry] })).toEqual([])
    expect(validatePolicy({ entries: [] })).toEqual([])
  })

  it('reports what is wrong, entry by entry', () => {
    expect(validatePolicy({})).toEqual(['"entries" must be a list.'])
    expect(validatePolicy({ entries: [{}] })).toEqual([
      'entries[0]: "package" is missing.',
      'entries[0]: "reason" is missing.',
      'entries[0]: "since" must be a date (YYYY-MM-DD).',
    ])
    expect(validatePolicy({ entries: [entry, entry] })).toEqual(['entries[1]: "typescript" is listed twice.'])
    expect(validatePolicy({ entries: [{ ...entry, unblock: { version: 'seven', peers: [] } }] })).toEqual([
      'entries[0]: "unblock.version" must be a version (X.Y.Z).',
      'entries[0]: "unblock.peers" must be a list of packages.',
    ])
  })

  it('reads the policy of an ecosystem from the base address', async () => {
    const urls = []
    const fetchImpl = async (url) => {
      urls.push(url)

      return { ok: true, json: async () => ({ entries: [entry] }) }
    }

    const policy = await fetchPolicy('npm', fetchImpl, 'https://x.test/raw/main/')

    expect(urls).toEqual(['https://x.test/raw/main/node.json'])
    expect(policy.entries).toHaveLength(1)

    await fetchPolicy('composer', fetchImpl, 'https://x.test/raw/main')
    expect(urls[1]).toBe('https://x.test/raw/main/php.json')
  })

  it('stops when the policy cannot be read or is not valid', async () => {
    const down = async () => ({ ok: false, status: 503 })
    const broken = async () => ({ ok: true, json: async () => ({ entries: 'no' }) })

    await expect(fetchPolicy('npm', down, 'https://x.test')).rejects.toThrow('could not be read')
    await expect(fetchPolicy('npm', broken, 'https://x.test')).rejects.toThrow('is not valid')
  })

  it('never updates the packages of the project and of the policy', () => {
    expect(rejectedPackages({ reject: ['left-pad', 'typescript'] }, { entries: [entry] })).toEqual([
      'left-pad',
      'typescript',
    ])
  })

  it('lifts an entry when every peer accepts the version', () => {
    expect(isLifted(entry, { 'typescript-eslint': '>=4.8.4 <6.1.0' })).toBe(false)
    expect(isLifted(entry, { 'typescript-eslint': '>=4.8.4 <8.0.0' })).toBe(true)
    expect(isLifted(entry, { 'typescript-eslint': null })).toBe(false)
    expect(isLifted(entry, { 'typescript-eslint': 'not a range' })).toBe(false)
    expect(isLifted({ ...entry, unblock: undefined }, {})).toBe(false)
    expect(isLifted({ ...entry, unblock: { version: '7.0.0', peers: ['a', 'b'] } }, { a: '>=7', b: '<7' })).toBe(false)
  })

  it('computes the date from which a version is taken', () => {
    const now = new Date('2026-10-25T12:00:00Z')

    expect(cooldownDate('3d', now).toISOString()).toBe('2026-10-22T12:00:00.000Z')
    expect(cooldownDate('12h', now).toISOString()).toBe('2026-10-25T00:00:00.000Z')
    expect(cooldownDate('soon', now)).toBeNull()
  })
})

describe('isInherited', () => {
  const lock = {
    packages: {
      '': {
        dependencies: { '@zairakai/js-dev-tools': '^3.0.0' },
        devDependencies: { vitest: '^5.0.0' },
      },
      'node_modules/@zairakai/js-dev-tools': { dependencies: { markdownlint: '1', zod: '4' } },
      'node_modules/markdownlint': { dependencies: { katex: '0.16' } },
      'node_modules/katex': {},
      'node_modules/zod': {},
      'node_modules/vitest': { dependencies: { zod: '4' } },
    },
  }

  it('is true for a package that only the group brings', () => {
    expect(isInherited(lock, 'katex')).toBe(true)
  })

  it('is false when the project reaches it by itself too', () => {
    expect(isInherited(lock, 'zod')).toBe(false)
  })

  it('is false for a package that nothing in the group brings', () => {
    expect(isInherited(lock, 'vitest')).toBe(false)
    expect(isInherited({}, 'katex')).toBe(false)
  })
})

describe('refreshableNames', () => {
  it('lists every package once, without the trusted scopes', () => {
    const lock = {
      packages: {
        '': {},
        'node_modules/zod': {},
        'node_modules/a/node_modules/zod': {},
        'node_modules/@zairakai/js-dev-tools': {},
        'node_modules/@stanislas-poisson/js-dev-tools': {},
        'node_modules/@vitest/spy': {},
      },
    }

    expect(refreshableNames(lock)).toEqual(['@vitest/spy', 'zod'])
  })

  it('has nothing for an empty lock', () => {
    expect(refreshableNames({})).toEqual([])
  })
})
