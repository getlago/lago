// Console suppression is handled in jest-setup-early.ts (runs before imports)
import '@testing-library/jest-dom'

import muiSnapshotSerializer from './src/test-utils/snapshotSerializer'

// jsdom has no ResizeObserver; components that observe layout (virtualized lists, the
// plan-details sidebar) reference it on mount. Provide a global no-op so any test that
// renders them does not crash. Individual suites can still override it to assert calls.
if (typeof globalThis.ResizeObserver === 'undefined') {
  globalThis.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  }
}

const mockNavigate = jest.fn()

;(globalThis as unknown as { __testRouterMocks: unknown }).__testRouterMocks = {
  mockNavigate,
}

jest.mock('react-router-dom', () => {
  const actual = jest.requireActual('react-router-dom')
  const mockUseParams = jest.fn(actual.useParams)

  return {
    ...actual,
    useNavigate: () => mockNavigate,
    useParams: mockUseParams,
  }
})

expect.addSnapshotSerializer(muiSnapshotSerializer)
