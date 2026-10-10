import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

import {
  detectEcosystem,
  diffDependencies,
  formatChanges,
  latestTag,
  loadConfig,
  nextVersion,
  planTag,
  runtimeChanged,
  signerIdentity,
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
      reject: ['typescript'],
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
