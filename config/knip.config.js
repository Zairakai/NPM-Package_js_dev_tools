/**
 * Knip configuration for @zairakai/js-dev-tools
 *
 * This package ships bundled configs for consumer projects.
 * Many dependencies are referenced as strings (prettier plugins, stylelint configs)
 * rather than ES imports — knip cannot trace those automatically.
 */

export default {
  entry: ['config/**/*.js'],

  // "Referenced optional peerDependencies" is informational — stylelint is intentionally optional
  exclude: ['optionalPeerDependencies'],

  ignoreDependencies: [
    // Prettier plugins — referenced as strings in config/prettier.config.js
    '@prettier/plugin-php',
    'prettier-plugin-blade',
    'prettier-plugin-organize-imports',

    // Stylelint configs/plugins — referenced as strings in config/stylelint.config.js
    'stylelint-config-html',
    'stylelint-config-recommended-vue',
    'stylelint-config-standard',
    'stylelint-config-standard-scss',
    'stylelint-order',
    'stylelint-scss',

    // Coverage provider — referenced as string in config/vitest.config.js (provider: 'v8')
    '@vitest/coverage-v8',

    // Optional peer dep bundled for consumers
    'zod',

    // Used in Makefiles/Scripts for normalization
    'sort-package-json',
  ],

  ignoreBinaries: ['make'],
}
