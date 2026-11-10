import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { dirname } from 'node:path'
import { describe, expect, it } from 'vitest'

// This package does not write the rules: it re-exports the ones of @stanislas-poisson/js-dev-tools, and keeps copies of
// the files that cannot be re-exported (the ignore lists) because it publishes them to the projects.
const base = dirname(
  dirname(createRequire(import.meta.url).resolve('@stanislas-poisson/js-dev-tools/config/tsconfig.base.json')),
)
const own = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8')
const fromBase = (path) => readFileSync(`${base}/${path}`, 'utf8')

describe('the base', () => {
  it.each(['.prettierignore', '.stylelintignore', '.markdownlintignore'])('has the same %s', (file) => {
    expect(own(`config/${file}`)).toBe(fromBase(`config/${file}`))
  })

  it.each([
    ['eslint', 'eslint'],
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

  it('pins the same versions as the base: the overrides of a dependency do not apply to this project', () => {
    const wanted = JSON.parse(fromBase('package.json')).overrides ?? {}
    const present = JSON.parse(own('package.json')).overrides ?? {}

    for (const [name, version] of Object.entries(wanted)) {
      expect(present[name], name).toEqual(version)
    }
  })
})
