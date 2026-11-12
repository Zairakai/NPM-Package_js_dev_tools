import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { dirname } from 'node:path'
import { describe, expect, it } from 'vitest'

// This package does not write the rules: it re-exports the ones of @stanislas-poisson/js-dev-tools, and keeps copies of
// the files that cannot be re-exported (the ignore lists) because it publishes them to the projects. The only additions
// are the folders of Laravel (storage and the cache), which the base does not know.
const base = dirname(
  dirname(
    createRequire(import.meta.url).resolve(
      '@stanislas-poisson/js-dev-tools/config/tsconfig.base.json',
    ),
  ),
)
const own = (path) =>
  readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8')
const fromBase = (path) => readFileSync(`${base}/${path}`, 'utf8')

describe('the base', () => {
  it.each(['.prettierignore', '.stylelintignore', '.markdownlintignore'])(
    'has the %s of the base, and the folders of Laravel',
    (file) => {
      const lines = own(`config/${file}`).split('\n')

      for (const line of fromBase(`config/${file}`)
        .split('\n')
        .filter(Boolean)) {
        expect(lines, line).toContain(line)
      }

      expect(lines).toEqual(
        expect.arrayContaining(['storage/', 'bootstrap/cache/']),
      )
    },
  )

  it('ignores the folders of Laravel in ESLint, after the rules of the base', async () => {
    const { default: config } = await import('../../config/eslint.config.js')
    const { default: baseConfig } =
      await import('@stanislas-poisson/js-dev-tools/eslint')

    expect(config.slice(0, -1)).toEqual(baseConfig)
    expect(config.at(-1)).toEqual({
      ignores: ['storage/**', 'bootstrap/cache/**'],
    })
  })

  it.each([
    ['prettier', 'prettier'],
    ['stylelint', 'stylelint'],
    ['vitest', 'vitest'],
  ])('re-exports the %s configuration', (file, entry) => {
    expect(own(`config/${file}.config.js`)).toContain(
      `export { default } from '@stanislas-poisson/js-dev-tools/${entry}'`,
    )
  })

  it('extends the TypeScript and markdownlint configurations', () => {
    expect(JSON.parse(own('config/tsconfig.base.json')).extends).toBe(
      '@stanislas-poisson/js-dev-tools/config/tsconfig.base.json',
    )
    expect(JSON.parse(own('config/.markdownlint.json')).extends).toBe(
      '@stanislas-poisson/js-dev-tools/config/.markdownlint.json',
    )
  })

  it('gives a Knip configuration that does not report the Stylelint rules of the base as unlisted', async () => {
    const { default: knip } = await import('../../config/knip.config.js')

    expect(knip.stylelint).toBe(false)
    expect(knip.ignoreDependencies).toContain('stylelint')
  })

  it('declares the tools it re-exports but does not install as optional peers, with the ranges of the base', () => {
    const wanted = JSON.parse(fromBase('package.json'))
    const present = JSON.parse(own('package.json'))

    for (const name of ['vitest', '@vitest/coverage-v8', 'typescript']) {
      expect(present.peerDependencies[name], name).toBe(
        wanted.peerDependencies[name],
      )
      expect(present.peerDependenciesMeta[name], name).toEqual({
        optional: true,
      })
    }
  })

  it('has no optional peer that is not a peer', () => {
    const { peerDependencies, peerDependenciesMeta } = JSON.parse(
      own('package.json'),
    )

    for (const name of Object.keys(peerDependenciesMeta)) {
      expect(peerDependencies[name], name).toBeDefined()
    }
  })

  it('pins the same versions as the base: the overrides of a dependency do not apply to this project', () => {
    const wanted = JSON.parse(fromBase('package.json')).overrides ?? {}
    const present = JSON.parse(own('package.json')).overrides ?? {}

    for (const [name, version] of Object.entries(wanted)) {
      expect(present[name], name).toEqual(version)
    }
  })
})
