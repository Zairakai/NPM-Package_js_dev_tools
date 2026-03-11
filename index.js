/**
 * @zairakai/js-dev-tools
 * Development toolkit - ESLint, Prettier, Stylelint, TypeScript, and Vitest.
 */

import eslint from './config/eslint.config.js'
import knip from './config/knip.config.js'
import prettier from './config/prettier.config.js'
import stylelint from './config/stylelint.config.js'
import tsconfig from './config/tsconfig.base.json' with { type: 'json' }
import vitest from './config/vitest.config.js'

// Named exports
export { eslint, knip, prettier, stylelint, tsconfig, vitest }

// Named paths for consumers
export const configs = {
  eslint: '@zairakai/js-dev-tools/config/eslint.config.js',
  prettier: '@zairakai/js-dev-tools/config/prettier.config.js',
  stylelint: '@zairakai/js-dev-tools/config/stylelint.config.js',
  vitest: '@zairakai/js-dev-tools/config/vitest.config.js',
  knip: '@zairakai/js-dev-tools/config/knip.config.js',
  tsconfig: '@zairakai/js-dev-tools/config/tsconfig.base.json',
}
