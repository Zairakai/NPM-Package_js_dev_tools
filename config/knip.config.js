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

  // "Referenced optional peerDependencies" is informational - stylelint is intentionally optional
  exclude: ['optionalPeerDependencies'],

  // The Stylelint rules come with @zairakai/js-dev-tools, which gives their absolute paths in the configuration: a project
  // does not list them, so the plugin of Knip for Stylelint would report each of them as unlisted
  stylelint: false,

  ignoreDependencies: [
    // The binary of Stylelint comes with @zairakai/js-dev-tools too; a project may list it or not
    'stylelint',

    // Optional peer dep bundled for consumers
    'zod',

    // Used in Makefiles/Scripts for normalization
    'sort-package-json',
  ],

  ignoreBinaries: ['make'],
}
