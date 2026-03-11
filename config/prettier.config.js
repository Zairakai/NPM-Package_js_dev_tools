/**
 * Default Prettier configuration for @zairakai projects.
 */

const config = {
  // Core formatting
  printWidth: 120,
  tabWidth: 2,
  useTabs: false,
  semi: false,
  singleQuote: true,
  quoteProps: 'as-needed',
  trailingComma: 'es5',
  bracketSpacing: true,
  bracketSameLine: false,
  arrowParens: 'always',
  endOfLine: 'lf',

  // HTML & Vue specific
  htmlWhitespaceSensitivity: 'css',
  vueIndentScriptAndStyle: true,
  singleAttributePerLine: false,

  // JSX specific
  jsxSingleQuote: true,

  // Prose formatting
  proseWrap: 'preserve',
  embeddedLanguageFormatting: 'auto',

  // Plugin configuration
  plugins: ['prettier-plugin-blade', '@prettier/plugin-php', 'prettier-plugin-organize-imports'],

  // File-specific overrides
  overrides: [
    // TypeScript/JavaScript files
    {
      files: ['*.ts', '*.tsx', '*.js', '*.jsx', '*.vue'],
      options: {
        semi: false,
        singleQuote: true,
        trailingComma: 'es5',
      },
    },

    // Vue files
    {
      files: '*.vue',
      options: {
        vueIndentScriptAndStyle: true,
        singleAttributePerLine: true,
      },
    },

    // SCSS/CSS files
    {
      files: ['*.scss', '*.css'],
      options: {
        tabWidth: 2,
        singleQuote: false,
        trailingComma: 'es5',
        semi: false,
      },
    },

    // PHP/Blade files
    {
      files: ['*.blade.php'],
      options: {
        tabWidth: 4,
        useTabs: false,
        phpVersion: '8.3',
        trailingCommaPHP: true,
        semi: false,
      },
    },

    // JSON files
    {
      files: ['*.json', '*.jsonc'],
      options: {
        tabWidth: 2,
        trailingComma: 'none',
        semi: false,
      },
    },

    // YAML files
    {
      files: ['*.yml', '*.yaml'],
      options: {
        tabWidth: 2,
        singleQuote: false,
        bracketSpacing: false,
        semi: false,
      },
    },

    // Package.json files
    {
      files: 'package.json',
      options: {
        tabWidth: 2,
        trailingComma: 'none',
        semi: false,
      },
    },

    // Configuration files
    {
      files: ['*.config.js', '*.config.ts', '.*rc.js', '.*rc.ts'],
      options: {
        tabWidth: 2,
        singleQuote: true,
        semi: false,
      },
    },
  ],
}

export default config
