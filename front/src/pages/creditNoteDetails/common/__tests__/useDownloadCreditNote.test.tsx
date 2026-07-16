import { renderHook } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { useDownloadCreditNote } from '../useDownloadCreditNote'

const mockHandleDownloadFile = jest.fn()
const mockHandleDownloadFileWithCors = jest.fn()

jest.mock('~/hooks/useDownloadFile', () => ({
  useDownloadFile: () => ({
    handleDownloadFile: mockHandleDownloadFile,
    handleDownloadFileWithCors: mockHandleDownloadFileWithCors,
  }),
}))

const renderUseDownloadCreditNote = () => {
  return renderHook(() => useDownloadCreditNote(), {
    wrapper: ({ children }) => <AllTheProviders>{children}</AllTheProviders>,
  })
}

describe('useDownloadCreditNote', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('initial state', () => {
    it('returns all expected properties', () => {
      const { result } = renderUseDownloadCreditNote()

      expect(result.current).toHaveProperty('downloadCreditNote')
      expect(result.current).toHaveProperty('loadingCreditNoteDownload')
      expect(result.current).toHaveProperty('downloadCreditNoteXml')
      expect(result.current).toHaveProperty('loadingCreditNoteXmlDownload')
    })

    it('has loading states initially set to false', () => {
      const { result } = renderUseDownloadCreditNote()

      expect(result.current.loadingCreditNoteDownload).toBe(false)
      expect(result.current.loadingCreditNoteXmlDownload).toBe(false)
    })

    it('returns downloadCreditNote as a function', () => {
      const { result } = renderUseDownloadCreditNote()

      expect(typeof result.current.downloadCreditNote).toBe('function')
    })

    it('returns downloadCreditNoteXml as a function', () => {
      const { result } = renderUseDownloadCreditNote()

      expect(typeof result.current.downloadCreditNoteXml).toBe('function')
    })
  })

  describe('return type', () => {
    it('returns the correct shape', () => {
      const { result } = renderUseDownloadCreditNote()

      const returnValue = result.current

      expect(Object.keys(returnValue)).toEqual([
        'downloadCreditNote',
        'loadingCreditNoteDownload',
        'downloadCreditNoteXml',
        'loadingCreditNoteXmlDownload',
      ])
    })
  })
})
