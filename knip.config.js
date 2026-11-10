// The configuration of this repository: the one of the package, which the projects inherit, plus what only this
// repository needs. It is not published (see `files` in package.json).
import baseConfig from './config/knip.config.js'

export default {
  ...baseConfig,
  ignoreDependencies: [
    ...baseConfig.ignoreDependencies,
    // The tools are run by the shell scripts of the package (scripts/*.sh), which Knip does not read
    'eslint',
    'markdownlint-cli2',
    'prettier',
    'stylelint',
  ],
}
