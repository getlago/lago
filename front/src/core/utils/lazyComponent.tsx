import { ComponentType, lazy } from 'react'

import { Spinner } from '~/components/designSystem/Spinner'
import { withLazySuspense } from '~/HOC/withLazySuspense'

type ExtractComponentProps<T> = T extends ComponentType<infer P> ? P : never

/**
 * Creates a lazy-loaded component wrapped with Suspense.
 * This is a convenience function that combines React.lazy() with withLazySuspense().
 * The component props type is automatically inferred from the imported component.
 *
 * @param importFn - Function that returns a promise resolving to a component module
 * @param LoadingComponent - Optional component to display while loading (default is Spinner)
 * @returns A component wrapped with lazy loading and Suspense, preserving original props types
 *
 * @example
 * ```tsx
 * const MyComponent = lazyComponent(
 *   () => import('~/components/MyComponent')
 * )
 * ```
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function lazyComponent<T extends ComponentType<any>>(
  importFn: () => Promise<{ default: T }>,
  loadingComponent: JSX.Element | null = <Spinner />,
): ComponentType<ExtractComponentProps<T>> {
  const LazyComponent = lazy(importFn)

  return withLazySuspense<ExtractComponentProps<T>>(LazyComponent, loadingComponent)
}
