import { existsSync, readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

// An editor extension looks for the configuration at the root of the project, never in config/. The root holds one thin
// file for each tool, and a copy of the ignore files (they cannot extend another file). config/ stays the source.
const own = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8')

describe('the files of the root, for the editor', () => {
  it.each(['eslint', 'prettier', 'stylelint', 'vitest'])(
    'has a thin %s file that only re-exports its config',
    (tool) => {
      const [, from] = own(`${tool}.config.mjs`).match(/^export \{ default \} from '(.+)'\n$/m)

      expect(from).toBe(`./config/${tool}.config.js`)
      expect(existsSync(new URL(`../../${from}`, import.meta.url))).toBe(true)
    },
  )

  it('extends the markdownlint file of config/', () => {
    expect(JSON.parse(own('.markdownlint.json'))).toEqual({ extends: './config/.markdownlint.json' })
  })

  it('does not publish the files of the root: they are for the editor of this repository', () => {
    const { files } = JSON.parse(own('package.json'))
    const root = [
      'eslint.config.mjs',
      'prettier.config.mjs',
      'stylelint.config.mjs',
      'vitest.config.mjs',
      '.markdownlint.json',
      '.prettierignore',
      '.stylelintignore',
      '.markdownlintignore',
    ]

    expect(files.filter((file) => root.includes(file))).toEqual([])
  })

  it.each(['.prettierignore', '.stylelintignore', '.markdownlintignore'])('has a copy of the %s of config/', (file) => {
    expect(own(file)).toBe(own(`config/${file}`))
  })
})
