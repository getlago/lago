import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Editor } from '@tiptap/react'

import { DOCUMENT_UPLOADER_INPUT_TEST_ID } from '~/components/form/DocumentUploader/DocumentUploader'
import { render } from '~/test-utils'

import { RichTextEditorProvider } from '../../common/RichTextEditorContext'
import ImagePopperForm, { TOOLBAR_IMAGE_ERROR_TEST_ID } from '../ImagePopperForm'

const createMockChain = () => {
  const chainMethods: Record<string, jest.Mock> = {}
  const runMock = jest.fn()
  const handler: ProxyHandler<Record<string, jest.Mock>> = {
    get: (_t, prop: string) => {
      if (prop === 'run') return runMock
      if (!chainMethods[prop])
        chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
      return chainMethods[prop]
    },
  }

  return { proxy: new Proxy({}, handler), runMock }
}

const createMockEditor = () => {
  const { proxy, runMock } = createMockChain()

  return {
    editor: {
      isActive: jest.fn(() => false),
      chain: jest.fn().mockReturnValue(proxy),
    } as unknown as Editor,
    runMock,
  }
}

const renderForm = (
  onImageUpload: (b: string) => Promise<string>,
  editor: Editor,
  closePopper: () => void,
) =>
  render(
    <RichTextEditorProvider
      value={{ mode: 'edit', mentionValues: {}, entities: {}, images: {}, onImageUpload }}
    >
      <ImagePopperForm editor={editor} closePopper={closePopper} />
    </RichTextEditorProvider>,
  )

const pngFile = () => new File(['data'], 'pic.png', { type: 'image/png' })

describe('ImagePopperForm', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  it('uploads the selected file and inserts the returned id, then closes', async () => {
    const user = userEvent.setup()
    const { editor, runMock } = createMockEditor()
    const closePopper = jest.fn()
    const onImageUpload = jest.fn().mockResolvedValue('blob-42')

    await act(() => renderForm(onImageUpload, editor, closePopper))
    await user.upload(screen.getByTestId(DOCUMENT_UPLOADER_INPUT_TEST_ID), pngFile())

    await waitFor(() => {
      expect(onImageUpload).toHaveBeenCalledWith(expect.stringContaining('data:'))
      expect(editor.chain).toHaveBeenCalled()
      expect(runMock).toHaveBeenCalled()
      expect(closePopper).toHaveBeenCalled()
    })
  })

  it('shows an error and does not close when the upload fails', async () => {
    const user = userEvent.setup()
    const { editor, runMock } = createMockEditor()
    const closePopper = jest.fn()
    const onImageUpload = jest.fn().mockRejectedValue(new Error('boom'))

    await act(() => renderForm(onImageUpload, editor, closePopper))
    await user.upload(screen.getByTestId(DOCUMENT_UPLOADER_INPUT_TEST_ID), pngFile())

    await waitFor(() => {
      expect(screen.getByTestId(TOOLBAR_IMAGE_ERROR_TEST_ID)).toBeInTheDocument()
    })
    expect(runMock).not.toHaveBeenCalled()
    expect(closePopper).not.toHaveBeenCalled()
  })
})
