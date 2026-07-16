import { renderHook } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { useIframeConfig } from '../useIframeConfig'

function createWrapper(initialEntries: string[] = ['/']) {
  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <MemoryRouter initialEntries={initialEntries}>{children}</MemoryRouter>
  )

  Wrapper.displayName = 'TestWrapper'

  return Wrapper
}

describe('useIframeConfig', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no iframe-related search params', () => {
    describe('WHEN the hook is rendered', () => {
      it('THEN should return isRunningInSalesForceIframe as false', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/']),
        })

        expect(result.current.isRunningInSalesForceIframe).toBe(false)
      })

      it('THEN should return isRunningInIframeContext as false', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/']),
        })

        expect(result.current.isRunningInIframeContext).toBe(false)
      })
    })
  })

  describe('GIVEN the sfdc search param is present', () => {
    describe('WHEN the hook is rendered', () => {
      it('THEN should return isRunningInSalesForceIframe as true', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/?sfdc=true']),
        })

        expect(result.current.isRunningInSalesForceIframe).toBe(true)
      })

      it('THEN should return isRunningInIframeContext as false', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/?sfdc=true']),
        })

        expect(result.current.isRunningInIframeContext).toBe(false)
      })
    })
  })

  describe('GIVEN the ifrm search param is present', () => {
    describe('WHEN the hook is rendered', () => {
      it('THEN should return isRunningInIframeContext as true', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/?ifrm=true']),
        })

        expect(result.current.isRunningInIframeContext).toBe(true)
      })

      it('THEN should return isRunningInSalesForceIframe as false', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/?ifrm=true']),
        })

        expect(result.current.isRunningInSalesForceIframe).toBe(false)
      })
    })
  })

  describe('GIVEN both sfdc and ifrm search params are present', () => {
    describe('WHEN the hook is rendered', () => {
      it('THEN should return both flags as true', () => {
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/?sfdc=true&ifrm=true']),
        })

        expect(result.current.isRunningInSalesForceIframe).toBe(true)
        expect(result.current.isRunningInIframeContext).toBe(true)
      })
    })
  })

  describe('GIVEN the emitSalesForceEvent function', () => {
    describe('WHEN called with event data', () => {
      it('THEN should post a stringified message to the parent window', () => {
        const postMessageSpy = jest.spyOn(window.parent, 'postMessage')
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/']),
        })

        const eventData = { action: 'DONE', rel: 'create-subscription', subscriptionId: 'sub-1' }

        result.current.emitSalesForceEvent(eventData)

        expect(postMessageSpy).toHaveBeenCalledWith(JSON.stringify(eventData), '*')

        postMessageSpy.mockRestore()
      })
    })
  })

  describe('GIVEN the emitIframeMessage function', () => {
    describe('WHEN called with event data', () => {
      it('THEN should post a stringified message to the current window', () => {
        const postMessageSpy = jest.spyOn(window, 'postMessage')
        const { result } = renderHook(() => useIframeConfig(), {
          wrapper: createWrapper(['/']),
        })

        const eventData = { action: 'DONE', rel: 'create-invoice', invoiceId: 'inv-1' }

        result.current.emitIframeMessage(eventData)

        expect(postMessageSpy).toHaveBeenCalledWith(JSON.stringify(eventData), '*')

        postMessageSpy.mockRestore()
      })
    })
  })
})
