# @zairakai/js-dev-tools

[![Main][pipeline-main-badge]][pipeline-main-link]
[![Develop][pipeline-develop-badge]][pipeline-develop-link]

[![npm][npm-badge]][npm-link]
[![GitLab Release][gitlab-release-badge]][gitlab-release]
[![License][license-badge]][license]

[![Node.js][node-badge]][node]
[![ESLint][eslint-badge]][eslint]
[![Prettier][prettier-badge]][prettier]
[![Stylelint][stylelint-badge]][stylelint]

One unified toolkit to set up JavaScript/TypeScript quality tooling. Context-aware by default — it adapts to both standalone packages and full-stack applications.

---

## Why @zairakai/js-dev-tools?

| Concept | Benefit |
| :--- | :--- |
| **Unified Logic** | The same quality gate for all your projects. Only the target (package or app) changes, not the rigor. |
| **Concentrated Configs** | Centralized, opinionated configurations for all your tools. Avoid configuration drift across projects. |
| **Unified Workflow** | One set of `make` commands to rule them all. Whether it's a small library or a large application, the quality gate remains the same. |
| **Auto-Syncing CI** | Automatically updates GitLab CI ref tags in your `.gitlab-ci.yml` when you update the package. Keep your pipelines current without manual effort. |
| **Zero Friction** | Automated setup script handles the heavy lifting on install. |

---

## Features

| Tool | Responsibility |
| :--- | :--- |
| **ESLint** | Flat config with TypeScript, Vue 3, and import rules. |
| **Prettier** | Opinionated formatter with SCSS and Tailwind support. |
| **Stylelint** | SCSS linting with modern property ordering. |
| **Markdownlint** | Consistent Markdown across all documentation. |
| **Vitest** | Unit testing with v8 coverage. |
| **Knip** | Dead code and unused dependency detection. |
| **TypeScript** | Shared `tsconfig.base.json` for strict mode builds. |
| **GitLab CI** | Reusable pipeline templates for npm packages and Laravel full-stack. |
| **Git Hooks** | Automated quality checks and ticket prefixing. |
| **Makefile** | Unified `make quality`, `make test`, `make ci` targets (delegated to core). |
| **Shell Scripts** | Automated setup and config publishing. |

On install, the `postinstall` script:

- creates `Makefile` if missing (delegating to `node_modules/@zairakai/js-dev-tools/tools/make/core.mk`)
- creates `.editorconfig`
- creates `config/dev-tools/eslint.config.js` baseline
- reports optional packages not yet installed

---

## Install

```bash
npm install --save-dev @zairakai/js-dev-tools
```

For Laravel full-stack projects, pair with `zairakai/laravel-dev-tools`:

```bash
composer require --dev zairakai/laravel-dev-tools
npm install --save-dev @zairakai/js-dev-tools
php artisan dev-tools:publish --fullstack
```

---

## Usage

```bash
make quality       # eslint + prettier + stylelint + knip + markdownlint + shellcheck
make quality-fix   # auto-fix all fixable issues
make test          # vitest
make test-all      # vitest + bats
make test-coverage # vitest with coverage report
make typecheck     # tsc --noEmit
make build         # tsup or tsc
make ci            # full pipeline simulation
make doctor        # environment diagnostics
```

---

## Configuration

Extend the shared configs in your project files:

```js
// eslint.config.js
export { default } from '@zairakai/js-dev-tools/eslint'

// prettier.config.js
export { default } from '@zairakai/js-dev-tools/prettier'

// stylelint.config.js
export { default } from '@zairakai/js-dev-tools/stylelint'

// vitest.config.js
import baseConfig from '@zairakai/js-dev-tools/vitest'
import { defineConfig } from 'vitest/config'
export default defineConfig({ ...baseConfig, test: { ...baseConfig.test } })
```

```json
// tsconfig.json
{ "extends": "@zairakai/js-dev-tools/tsconfig" }
```

---

## Publishing configs

Publish individual config files to `config/dev-tools/` (never overwritten unless `--force`):

```bash
# All at once
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish

# By group
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=quality
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=style
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=testing
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=hooks
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=gitlab-ci
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=typescript

# Single files
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=eslint
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=prettier
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=stylelint
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=vitest
bash node_modules/@zairakai/js-dev-tools/scripts/setup-project.sh --publish=tsconfig
```

---

## GitLab CI pipeline templates

Include in your consumer project's `.gitlab-ci.yml`:

```yaml
# npm package pipeline
include:
  - project: 'zairakai/npm-packages/js-dev-tools'
    ref: v1.0.0          # pin to a release tag for reproducible builds
    file: '.gitlab/ci/pipeline-js-package.yml'

variables:
  CACHE_KEY: "my-package-v1"
  NPM_PACKAGE_NAME: "@myorg/my-package"
```

Available templates:

- `.gitlab/ci/pipeline-js-package.yml` — security → install → validate → quality → test → build → publish → release
- `.gitlab/ci/pipeline-js-app.yml` — JS quality + test jobs for Laravel full-stack apps

---

## Development

```bash
make quality          # full quality check
make test-all         # vitest + bats
make bats             # shell script tests only
make doctor           # environment diagnostics
```

---

## Getting Help

[![License][license-badge]][license]
[![Security Policy][security-badge]][security]
[![Issues][issues-badge]][issues]

**Made with ❤️ by [Zairakai][ecosystem]**

<!-- Reference Links -->
[pipeline-main-badge]: https://gitlab.com/zairakai/npm-packages/js-dev-tools/badges/main/pipeline.svg?ignore_skipped=true&key_text=Main
[pipeline-main-link]: https://gitlab.com/zairakai/npm-packages/js-dev-tools/-/commits/main
[pipeline-develop-badge]: https://gitlab.com/zairakai/npm-packages/js-dev-tools/badges/develop/pipeline.svg?ignore_skipped=true&key_text=Develop
[pipeline-develop-link]: https://gitlab.com/zairakai/npm-packages/js-dev-tools/-/commits/develop
[npm-badge]: https://img.shields.io/npm/v/@zairakai/js-dev-tools
[npm-link]: https://www.npmjs.com/package/@zairakai/js-dev-tools
[gitlab-release-badge]: https://img.shields.io/gitlab/v/release/zairakai/npm-packages/js-dev-tools?logo=gitlab
[gitlab-release]: https://gitlab.com/zairakai/npm-packages/js-dev-tools/-/releases
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: ./LICENSE
[security-badge]: https://img.shields.io/badge/security-scanned-green.svg
[security]: ./SECURITY.md
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fnpm-packages%2Fdev-tools?logo=gitlab&label=Issues
[issues]: https://gitlab.com/zairakai/npm-packages/js-dev-tools/-/issues
[node-badge]: https://img.shields.io/badge/node.js-%3E%3D22-green.svg?logo=node.js
[node]: https://nodejs.org
[eslint-badge]: https://img.shields.io/badge/code%20style-eslint-4B32C3.svg?logo=eslint
[eslint]: https://eslint.org
[prettier-badge]: https://img.shields.io/badge/formatter-prettier-F7B93E.svg?logo=prettier
[prettier]: https://prettier.io
[stylelint-badge]: https://img.shields.io/badge/css-stylelint-263238.svg?logo=stylelint
[stylelint]: https://stylelint.io
[ecosystem]: https://gitlab.com/zairakai
