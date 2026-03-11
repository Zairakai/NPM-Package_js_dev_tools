/**
 * Default Vitest configuration for @zairakai packages.
 * Provides sensible defaults for TypeScript projects.
 *
 * To customize, publish this file to your project:
 *   bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=vitest
 *
 * The published config (config/dev-tools/vitest.config.js) can extend this
 * base config and add project-specific settings (Vue plugin, jsdom, etc.).
 */

import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html', 'cobertura'],
      reportsDirectory: 'build/coverage',
      exclude: ['node_modules/**', 'dist/**', 'build/**', '**/*.config.*', '**/*.d.ts'],
    },
  },
})
