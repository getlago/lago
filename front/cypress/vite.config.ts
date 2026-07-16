import type { UserConfig, UserConfigFn } from 'vite'

import mainConfig from '../vite.config'

export default (async (env) => {
  const resolved =
    typeof mainConfig === 'function'
      ? await (mainConfig as UserConfigFn)(env)
      : (mainConfig as UserConfig)

  // cypress-vite controls entry/output for spec bundling — keep the plugins,
  // resolve aliases, and define replacements from the main config but drop
  // `build`/`server`/`preview` so cypress can manage them.
  const { build: _build, server: _server, preview: _preview, ...rest } = resolved

  return rest
}) satisfies UserConfigFn
