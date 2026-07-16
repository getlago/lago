import { ComponentType, lazy, LazyExoticComponent } from 'react'

const CHUNK_RELOAD_KEY = 'lago_chunk_reload'
const RELOAD_COOLDOWN_MS = 10_000

function hasReloadedRecently(): boolean {
  try {
    const timestamp = sessionStorage.getItem(CHUNK_RELOAD_KEY)

    if (!timestamp) return false

    return Date.now() - parseInt(timestamp, 10) < RELOAD_COOLDOWN_MS
  } catch {
    // Storage unavailable (blocked, partitioned, sandboxed iframe)
    // Assume already reloaded to avoid infinite reload loop
    return true
  }
}

function markReloaded(): void {
  try {
    sessionStorage.setItem(CHUNK_RELOAD_KEY, Date.now().toString())
  } catch {
    // Storage became unavailable after hasAlreadyReloaded() check.
    // In environments where sessionStorage is always unavailable,
    // hasAlreadyReloaded() returns true and we never reach the reload path,
    // so users see the fallback toast instead of an automatic reload.
  }
}

const retry = (
  fn: () => Promise<{ default: ComponentType<Record<string, never>> }>,
  retriesLeft = 2,
  interval = 1000,
): Promise<{ default: ComponentType<Record<string, never>> }> => {
  return new Promise((resolve) => {
    fn()
      .then(resolve)
      .catch(() => {
        if (retriesLeft > 0) {
          setTimeout(() => {
            retry(fn, retriesLeft - 1, interval).then(resolve)
          }, interval)
        } else if (!hasReloadedRecently()) {
          // All retries exhausted — reload silently to get fresh HTML
          markReloaded()
          window.location.reload()
        } else {
          // Already reloaded recently and still failing — show persistent toast.
          // Promise stays pending so Suspense keeps showing <Spinner />
          // while the rest of the app (sidebar, header) remains usable.
          import('~/core/apolloClient/reactiveVars/toastVar')
            .then(({ addToast }) => {
              addToast({
                severity: 'info',
                message:
                  'Something went wrong while loading the page. Please try refreshing or clearing your cache.',
                autoDismiss: false,
              })
            })
            .catch((error) => {
              // Toast module also failed to load — nothing more we can do.
              // User still sees <Spinner /> from Suspense.
              // eslint-disable-next-line no-console
              console.error('Failed to load fallback toast module', error)
            })
        }
      })
  })
}

export const lazyLoad = (
  fn: () => Promise<{ default: ComponentType<Record<string, never>> }>,
): LazyExoticComponent<ComponentType<Record<string, never>>> => lazy(() => retry(fn))
