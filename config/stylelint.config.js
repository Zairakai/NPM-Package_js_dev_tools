/**
 * Full Stylelint config for @zairakai projects
 */

export default {
  extends: [
    'stylelint-config-standard-scss', // Base SCSS rules
    'stylelint-config-recommended-vue', // Vue SFC support
    'stylelint-config-html', // HTML support
  ],
  plugins: ['stylelint-scss'],

  overrides: [
    // Vue files
    {
      files: ['*.vue', '**/*.vue'],
      rules: {
        'scss/at-rule-no-unknown': true,
      },
    },
    // SCSS files
    {
      files: ['*.scss', '**/*.scss'],
      rules: {
        'scss/at-mixin-argumentless-call-parentheses': 'never',
        'scss/dollar-variable-pattern': '^[_a-z0-9\\-]+$',
        'scss/selector-no-redundant-nesting-selector': true,
      },
    },
  ],

  rules: {
    // SCSS basics
    'declaration-block-no-redundant-longhand-properties': true,
    'length-zero-no-unit': true,

    // SCSS operator & function rules
    'scss/at-rule-no-unknown': true,
    'scss/at-mixin-argumentless-call-parentheses': 'never',

    // Naming conventions
    'scss/dollar-variable-pattern': '^[_a-z0-9\\-]+$',
    'scss/selector-no-redundant-nesting-selector': true,
  },

  ignoreFiles: [
    'node_modules/**/*',
    'dist/**/*',
    'build/**/*',
    'coverage/**/*',
    'public/**/*',
    '.nuxt/**/*',
    '.output/**/*',
    '**/*.min.css',
  ],
}
