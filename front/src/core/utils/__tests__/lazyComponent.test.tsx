/* eslint-disable react/prop-types */
import '@testing-library/jest-dom'
import { screen, waitFor } from '@testing-library/react'
import { ComponentType } from 'react'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { render } from '~/test-utils'

import { lazyComponent } from '../lazyComponent'

jest.mock('~/components/designSystem/Skeleton', () => ({
  Skeleton: () => <div data-test="skeleton">Loading...</div>,
}))

jest.mock('~/components/designSystem/Spinner', () => ({
  Spinner: () => <div data-test="spinner">Loading...</div>,
}))

describe('lazyComponent', () => {
  it('should create a lazy-loaded component wrapped with Suspense', async () => {
    const TestComponent: ComponentType<{ title: string }> = ({ title }) => (
      <div data-test="test-component">{title}</div>
    )

    const LazyTestComponent = lazyComponent(() =>
      Promise.resolve({
        default: TestComponent,
      }),
    )

    render(<LazyTestComponent title="Test Title" />)

    expect(screen.getByTestId('spinner')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByTestId('test-component')).toBeInTheDocument()
    })

    expect(screen.getByText('Test Title')).toBeInTheDocument()
  })

  it('should preserve component props types', async () => {
    interface ComplexProps {
      id: number
      name: string
      items: string[]
    }

    const ComplexComponent: ComponentType<ComplexProps> = ({ id, name, items }) => (
      <div data-test="complex-component">
        <div>ID: {id}</div>
        <div>Name: {name}</div>
        <div>Items: {items.join(', ')}</div>
      </div>
    )

    const LazyComplexComponent = lazyComponent(() =>
      Promise.resolve({
        default: ComplexComponent,
      }),
    )

    render(<LazyComplexComponent id={1} name="Test" items={['item1', 'item2']} />)

    await waitFor(() => {
      expect(screen.getByTestId('complex-component')).toBeInTheDocument()
    })

    expect(screen.getByText('ID: 1')).toBeInTheDocument()
    expect(screen.getByText('Name: Test')).toBeInTheDocument()
    expect(screen.getByText('Items: item1, item2')).toBeInTheDocument()
  })

  it('should handle multiple instances of the same lazy component', async () => {
    const MultiComponent: ComponentType<{ index: number }> = ({ index }) => (
      <div data-test={`multi-component-${index}`}>Component {index}</div>
    )

    const LazyMultiComponent = lazyComponent(() =>
      Promise.resolve({
        default: MultiComponent,
      }),
    )

    render(
      <div>
        <LazyMultiComponent index={1} />
        <LazyMultiComponent index={2} />
        <LazyMultiComponent index={3} />
      </div>,
    )

    await waitFor(() => {
      expect(screen.getByTestId('multi-component-1')).toBeInTheDocument()
      expect(screen.getByTestId('multi-component-2')).toBeInTheDocument()
      expect(screen.getByTestId('multi-component-3')).toBeInTheDocument()
    })

    expect(screen.getByText('Component 1')).toBeInTheDocument()
    expect(screen.getByText('Component 2')).toBeInTheDocument()
    expect(screen.getByText('Component 3')).toBeInTheDocument()
  })

  it('should display Skeleton when specified', async () => {
    const TestComponent: ComponentType<{ title: string }> = ({ title }) => (
      <div data-test="test-component">{title}</div>
    )

    const LazyTestComponent = lazyComponent(
      () =>
        Promise.resolve({
          default: TestComponent,
        }),
      <Skeleton className="w-22" variant="text" />,
    )

    render(<LazyTestComponent title="Test Title" />)

    expect(screen.getByTestId('skeleton')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByTestId('test-component')).toBeInTheDocument()
    })

    expect(screen.getByText('Test Title')).toBeInTheDocument()
  })
})
