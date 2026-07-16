/* eslint-disable no-console */
import { execSync } from 'node:child_process'

try {
  execSync('tsc --noEmit --incremental', { stdio: 'inherit' })
  console.log('\x1b[32m✓ All types are valid!\x1b[0m\n\n')
  process.exit(0)
} catch {
  process.exit(1)
}
