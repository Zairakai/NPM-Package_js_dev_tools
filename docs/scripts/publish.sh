#!/usr/bin/env bash
# Builds the documentation of every released version and of main, and puts them in one site (./public):
#
#   /            the latest released version
#   /1.4.0/      each released version, built from its own tag (its sources, its docs)
#   /next/       main
#   /versions.json   what the version selector lists
#
# GitLab Pages has one site per project and deploys only from the default branch, so this runs there and
# rebuilds the versions from their tags: nothing has to be kept between two runs.
set -euo pipefail

cd "$(dirname "$0")/../.."

# In CI the checkout belongs to another user than the one of the job: git refuses it otherwise.
if [ -n "${CI:-}" ]; then
  git config --global --add safe.directory "$PWD"
fi

root=$(git rev-parse --show-toplevel)
out="$root/public"
work=$(mktemp -d)
export npm_config_cache="${npm_config_cache:-$root/.npm}"

rm -rf "$out"
mkdir -p "$out"

# What built main, to give back to it at the end.
main_ref="${CI_COMMIT_REF_NAME-}"
main_sha="${CI_COMMIT_SHA-}"
main_short="${CI_COMMIT_SHORT_SHA-}"
main_time="${CI_COMMIT_TIMESTAMP-}"

git fetch --quiet --tags origin 2>/dev/null || true

# Build the docs of a source tree: build <directory> <version> <base> <destination>
build() {
  (
    cd "$1/docs"
    # TypeDoc reads the sources with their tsconfig and their dependencies: install the package too
    # (a version is built outside the repository, in a temporary directory).
    if [ -f "$1/package-lock.json" ]; then
      (cd "$1" && npm ci --ignore-scripts --no-audit --no-fund --silent)
    fi
    npm ci --no-audit --no-fund --silent
    DOCS_VERSION="$2" DOCS_BASE="$3" DOCS_ROOT=/ npm run build --silent
    rm -rf "$4"
    mkdir -p "$4"
    cp -R .vitepress/dist/. "$4/"
  )
}

# The released versions that have a documentation, oldest first.
versions=()
for tag in $(git tag -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V); do
  if git cat-file -e "$tag:docs/package.json" 2>/dev/null; then
    versions+=("$tag")
  fi
done

for tag in "${versions[@]}"; do
  echo "== documentation of $tag"
  mkdir -p "$work/$tag"
  # Only what exists in this tag (a toolkit has no src, an old version has no docs).
  paths=()
  for path in docs src config README.md package.json package-lock.json tsconfig.json tsconfig.test.json; do
    if git cat-file -e "$tag:$path" 2>/dev/null; then
      paths+=("$path")
    fi
  done
  git archive "$tag" "${paths[@]}" | tar -x -C "$work/$tag"

  # What built it: the tag, and this pipeline.
  export CI_COMMIT_REF_NAME="$tag"
  CI_COMMIT_SHA=$(git rev-parse "$tag^{commit}")
  export CI_COMMIT_SHA
  CI_COMMIT_SHORT_SHA=$(git rev-parse --short "$tag^{commit}")
  export CI_COMMIT_SHORT_SHA
  CI_COMMIT_TIMESTAMP=$(git log -1 --format=%cI "$tag")
  export CI_COMMIT_TIMESTAMP

  build "$work/$tag" "$tag" "/$tag/" "$out/$tag"
done

# The latest version is also the root of the site.
latest=""
if [ "${#versions[@]}" -gt 0 ]; then
  latest="${versions[-1]}"
  echo "== root is $latest"
  build "$work/$latest" "$latest" "/" "$work/root"
  cp -R "$work/root/." "$out/"
fi

# main.
for name in CI_COMMIT_REF_NAME CI_COMMIT_SHA CI_COMMIT_SHORT_SHA CI_COMMIT_TIMESTAMP; do
  unset "$name"
done
[ -n "$main_ref" ] && export CI_COMMIT_REF_NAME="$main_ref"
[ -n "$main_sha" ] && export CI_COMMIT_SHA="$main_sha"
[ -n "$main_short" ] && export CI_COMMIT_SHORT_SHA="$main_short"
[ -n "$main_time" ] && export CI_COMMIT_TIMESTAMP="$main_time"
echo "== documentation of main (next)"
build "$root" "next" "/next/" "$out/next"

# Nothing released yet: the root is main.
if [ -z "$latest" ]; then
  build "$root" "next" "/" "$work/root"
  cp -R "$work/root/." "$out/"
fi

# The selector reads this file.
{
  printf '{"latest":%s,"versions":[' "$([ -n "$latest" ] && printf '"%s"' "$latest" || printf 'null')"
  for ((i = ${#versions[@]} - 1; i >= 0; i--)); do
    printf '"%s"' "${versions[$i]}"
    [ "$i" -gt 0 ] && printf ','
  done
  printf '],"next":true}\n'
} >"$out/versions.json"

echo "== site written in $out"
cat "$out/versions.json"
