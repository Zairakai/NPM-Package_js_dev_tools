// The configuration of this repository: the one of the package, which the projects inherit, plus what only this
// repository needs. It is not published (see `files` in package.json).
import baseConfig from './config/knip.config.js'

export default {
  ...baseConfig,
  // The root stylelint.config.mjs only re-exports config/ for the editor: the plugins of its rules belong to the base,
  // and nothing in this package imports the file
  stylelint: false,
  ignore: [...(baseConfig.ignore ?? []), 'stylelint.config.mjs'],
  ignoreDependencies: [
    ...baseConfig.ignoreDependencies,
    // The tools are run by the shell scripts of the package (scripts/*.sh), which Knip does not read
    'eslint',
    'markdownlint-cli2',
    'prettier',
    'stylelint',
  ],
}
