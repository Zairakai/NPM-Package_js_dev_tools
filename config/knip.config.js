/**
 * Knip configuration for @zairakai/js-dev-tools
 *
 * This package re-exports the configs of @stanislas-poisson/js-dev-tools, whose dependencies are referenced as strings
 * by the tools; knip cannot trace those automatically, so the base package is the one that lists them.
 */

export default {
  entry: ['config/**/*.js'],

  // The documentation site (VitePress) has its own tools and is not part of the package.
  ignore: ['docs/**'],

  // "Referenced optional peerDependencies" is informational — stylelint is intentionally optional
  exclude: ['optionalPeerDependencies'],

  ignoreDependencies: [
    // Coverage provider — referenced as string in config/vitest.config.js (provider: 'v8')
    '@vitest/coverage-v8',

    // Optional peer dep bundled for consumers
    'zod',

    // Used in Makefiles/Scripts for normalization
    'sort-package-json',
  ],

  ignoreBinaries: ['make'],
}
