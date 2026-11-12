#!/usr/bin/env bats
#
# Unit Tests - Repository Structure
# The files of the repository itself (not of the npm package) and the contents that must stay, or be corrected with the
# test that names them. They run against the source tree.
#

load '../helpers/test_helper'

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

# Files of the root
# ================

@test "the files of the repository are at the root" {
  for file in LICENSE README.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md package.json package-lock.json \
    .editorconfig .gitattributes .gitignore .npmrc .gitlab-ci.yml Makefile knip.config.js; do
    assert_file_exists "${PROJECT_ROOT}/${file}"
  done
}

@test "the thin files for the editor are at the root and re-export config/" {
  for tool in eslint prettier stylelint vitest; do
    assert_file_exists "${PROJECT_ROOT}/${tool}.config.mjs"
    assert_file_contains "${PROJECT_ROOT}/${tool}.config.mjs" "export { default } from './config/${tool}.config.js'"
  done
}

@test "the root markdownlint file and tsconfig.json extend config/" {
  assert_file_contains "${PROJECT_ROOT}/.markdownlint.json" "./config/.markdownlint.json"
  assert_file_contains "${PROJECT_ROOT}/tsconfig.json" "./config/tsconfig.base.json"
}

@test "the ignore files at the root are copies of the ones in config/" {
  for file in .markdownlintignore .prettierignore .stylelintignore; do
    assert_same_file "${PROJECT_ROOT}/${file}" "${PROJECT_ROOT}/config/${file}"
  done
}

@test "the ignore files hold the folders of Laravel" {
  for file in .markdownlintignore .prettierignore .stylelintignore; do
    assert_file_contains "${PROJECT_ROOT}/config/${file}" "storage/"
    assert_file_contains "${PROJECT_ROOT}/config/${file}" "bootstrap/cache/"
  done
}

@test "the assets hold the icon and the banner, in both formats" {
  for file in icon.png icon.svg banner.png banner.svg; do
    assert_file_exists "${PROJECT_ROOT}/assets/${file}"
  done
}

# The base
# ================

@test "package.json requires the base 3" {
  assert_file_contains "${PROJECT_ROOT}/package.json" '"@stanislas-poisson/js-dev-tools": "^3.'
}

@test "config/ re-exports or extends the base, which holds the rules" {
  for tool in eslint prettier stylelint vitest; do
    assert_file_contains "${PROJECT_ROOT}/config/${tool}.config.js" "@stanislas-poisson/js-dev-tools"
  done
  assert_file_contains "${PROJECT_ROOT}/config/tsconfig.base.json" "@stanislas-poisson/js-dev-tools/config/tsconfig.base.json"
  assert_file_contains "${PROJECT_ROOT}/config/.markdownlint.json" "@stanislas-poisson/js-dev-tools/config/.markdownlint.json"
}

@test "config/stylelint.config.js re-exports the names of the base, for createStylelintConfig" {
  assert_file_contains "${PROJECT_ROOT}/config/stylelint.config.js" "export * from '@stanislas-poisson/js-dev-tools/stylelint'"
}

# Documentation
# ================

@test "the README shows the icon, not the banner" {
  assert_file_contains "${PROJECT_ROOT}/README.md" "assets/icon.png"
  assert_file_not_contains "${PROJECT_ROOT}/README.md" "banner"
}

@test "the title of the README is the name of the project, without code" {
  run grep -m1 '^# ' "${PROJECT_ROOT}/README.md"
  [ "$status" -eq 0 ]
  [ "$output" = "# JS Dev Tools" ]
}

@test "the README folds its long sections in details" {
  assert_file_contains "${PROJECT_ROOT}/README.md" "<details>"
  assert_file_contains "${PROJECT_ROOT}/README.md" "<summary>"
}

# The site of documentation takes the guide after the first horizontal rule of the README
@test "the README has the horizontal rule that starts the guide of the documentation site" {
  run grep -c '^---$' "${PROJECT_ROOT}/README.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "the documentation site keeps its sources" {
  for file in package.json index.md scripts/generate.mjs scripts/publish.sh .vitepress/config.ts; do
    assert_file_exists "${PROJECT_ROOT}/docs/${file}"
  done
}

# Git
# ================

@test ".gitignore starts with the standard block of the handbook" {
  for text in "# JetBrains (PhpStorm, WebStorm)" "# Visual Studio Code and derivatives" "# Other editors" \
    "# AI assistants" "AGENTS.md" "CLAUDE.md" "GEMINI.md" "*.local.md"; do
    assert_file_contains "${PROJECT_ROOT}/.gitignore" "$text"
  done
}

@test ".gitattributes normalizes the line endings and keeps the Markdown diffs" {
  assert_file_contains "${PROJECT_ROOT}/.gitattributes" "* text=auto eol=lf"
  assert_file_contains "${PROJECT_ROOT}/.gitattributes" "*.md diff=markdown"
}

@test ".npmrc keeps the engine and audit settings" {
  assert_file_contains "${PROJECT_ROOT}/.npmrc" "engine-strict=true"
}

# Settings that must stay
# ================

@test ".editorconfig has the 80 columns of the style guides for JavaScript and the shell" {
  assert_file_contains "${PROJECT_ROOT}/.editorconfig" "[*.{cjs,cts,js,mjs,mts,ts}]"
  assert_file_contains "${PROJECT_ROOT}/.editorconfig" "[*.{bash,bats,sh}]"
  assert_file_contains "${PROJECT_ROOT}/.editorconfig" "max_line_length = 80"
  assert_file_not_contains "${PROJECT_ROOT}/.editorconfig" "max_line_length = 120"
}

@test "the commit-msg stub limits the subject to 50 characters" {
  assert_file_contains "${PROJECT_ROOT}/stubs/githooks/commit-msg" "-gt 50"
  assert_file_not_contains "${PROJECT_ROOT}/stubs/githooks/commit-msg" "-gt 72"
}

# Writing rules
# ================

# The long dashes are written with their bytes: this file does not hold them. Only the titles of the sections of the
# Makefiles (## -- title --) keep them: make help recognizes them.
@test "no long dash (em or en) outside of the titles of the Makefile sections" {
  cd "${PROJECT_ROOT}"
  local em en
  em="$(printf '\xe2\x80\x94')"
  en="$(printf '\xe2\x80\x93')"

  run bash -c "git grep -nIF -e '${em}' -e '${en}' -- . ':!package-lock.json' ':!docs/package-lock.json' | grep -vF ':## ${em}${em} '"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
