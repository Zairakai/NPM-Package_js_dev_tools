// The rules live in @stanislas-poisson/js-dev-tools; this path stays for the projects that use it.
import base from '@stanislas-poisson/js-dev-tools/eslint'

export default [
  ...base,
  // Laravel: the runtime files and the cache are not source
  { ignores: ['storage/**', 'bootstrap/cache/**'] },
]
