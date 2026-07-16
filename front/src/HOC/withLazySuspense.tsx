import { ComponentType, LazyExoticComponent, Suspense } from 'react'

import { Spinner } from '~/components/designSystem/Spinner'

export const withLazySuspense = <T = Record<string, unknown>,>(
  LazyComponent:
    | ComponentType<T>
    | LazyExoticComponent<ComponentType<T>>
    | LazyExoticComponent<ComponentType<unknown>>,
  loadingComponent: JSX.Element | null = <Spinner />,
): ComponentType<T> => {
  const WrappedComponent = (props: T) => {
    const Component = LazyComponent as ComponentType<T>

    return (
      <Suspense fallback={loadingComponent}>
        {/* @ts-expect-error - LazyExoticComponent types are complex, but runtime behavior is correct */}
        <Component {...props} />
      </Suspense>
    )
  }

  return WrappedComponent
}
