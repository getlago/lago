/* eslint-disable react/prop-types */
import '@testing-library/jest-dom'
import { screen, waitFor } from '@testing-library/react'
import { ComponentType, lazy } from 'react'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { render } from '~/test-utils'

import { withLazySuspense } from '../withLazySuspense'

jest.mock('~/components/designSystem/Skeleton', () => ({
  Skeleton: () => <div data-test="skeleton">Loading...</div>,
}))

jest.mock('~/components/designSystem/Spinner', () => ({
  Spinner: () => <div data-test="spinner">Loading...</div>,
}))

describe('withLazySuspense', () => {
  it('should wrap component with Suspense and show fallback during loading', async () => {
    const TestComponent: ComponentType<{ message: string }> = ({ message }) => (
      <div data-test="test-component">{message}</div>
    )

    const LazyTestComponent = lazy(() =>
      Promise.resolve({
        default: TestComponent,
      }),
    )

    const WrappedComponent = withLazySuspense(LazyTestComponent)

    render(<WrappedComponent message="Hello World" />)

    expect(screen.getByTestId('spinner')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByTestId('test-component')).toBeInTheDocument()
    })

    expect(screen.getByText('Hello World')).toBeInTheDocument()
  })

  it('should wrap component with Suspense and show specified fallback during loading', async () => {
    const TestComponent: ComponentType<{ message: string }> = ({ message }) => (
      <div data-test="test-component">{message}</div>
    )

    const LazyTestComponent = lazy(() =>
      Promise.resolve({
        default: TestComponent,
      }),
    )

    const WrappedComponent = withLazySuspense(
      LazyTestComponent,
      <Skeleton className="w-22" variant="text" />,
    )

    render(<WrappedComponent message="Hello World" />)

    expect(screen.getByTestId('skeleton')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByTestId('test-component')).toBeInTheDocument()
    })

    expect(screen.getByText('Hello World')).toBeInTheDocument()
  })
})
