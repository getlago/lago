import { act, renderHook } from '@testing-library/react'
import { FC, PropsWithChildren } from 'react'

import { MainHeaderProvider, useMainHeaderReader, useMainHeaderWriter } from '../MainHeaderContext'
import { MainHeaderConfig } from '../types'

const wrapper: FC<PropsWithChildren> = ({ children }) => (
  <MainHeaderProvider>{children}</MainHeaderProvider>
)

const mockConfig: MainHeaderConfig = {
  breadcrumb: [{ label: 'Test', path: '/test' }],
}

describe('MainHeaderContext', () => {
  describe('GIVEN useMainHeaderWriter is used outside MainHeaderProvider', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should throw an error', () => {
        // Suppress React error boundary console.error for this test
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation()

        expect(() => {
          renderHook(() => useMainHeaderWriter())
        }).toThrow('useMainHeaderWriter must be used within a MainHeaderProvider')

        consoleSpy.mockRestore()
      })
    })
  })

  describe('GIVEN useMainHeaderReader is used outside MainHeaderProvider', () => {
    describe('WHEN the hook is called', () => {
      it('THEN should throw an error', () => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation()

        expect(() => {
          renderHook(() => useMainHeaderReader())
        }).toThrow('useMainHeaderReader must be used within a MainHeaderProvider')

        consoleSpy.mockRestore()
      })
    })
  })

  describe('GIVEN the provider is mounted', () => {
    describe('WHEN reading config initially', () => {
      it('THEN should return null config', () => {
        const { result } = renderHook(() => useMainHeaderReader(), { wrapper })

        expect(result.current.config).toBeNull()
      })
    })

    describe('WHEN setConfig is called', () => {
      it('THEN should update the config in the reader', () => {
        const { result } = renderHook(
          () => ({
            writer: useMainHeaderWriter(),
            reader: useMainHeaderReader(),
          }),
          { wrapper },
        )

        act(() => {
          result.current.writer.setConfig(mockConfig)
        })

        expect(result.current.reader.config).toEqual(mockConfig)
      })
    })

    describe('WHEN resetConfig is called', () => {
      it('THEN should set config back to null', () => {
        const { result } = renderHook(
          () => ({
            writer: useMainHeaderWriter(),
            reader: useMainHeaderReader(),
          }),
          { wrapper },
        )

        act(() => {
          result.current.writer.setConfig(mockConfig)
        })

        expect(result.current.reader.config).toEqual(mockConfig)

        act(() => {
          result.current.writer.resetConfig()
        })

        expect(result.current.reader.config).toBeNull()
      })
    })

    describe('WHEN registerConfigure and unregisterConfigure are called', () => {
      it('THEN should track mount count without errors', () => {
        const { result } = renderHook(() => useMainHeaderWriter(), { wrapper })

        // Should not throw when registering/unregistering
        act(() => {
          result.current.registerConfigure()
        })

        act(() => {
          result.current.unregisterConfigure()
        })

        // Verify functions are callable and stable
        expect(result.current.registerConfigure).toBeDefined()
        expect(result.current.unregisterConfigure).toBeDefined()
      })
    })
  })
})
