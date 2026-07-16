import { Editor } from '@tiptap/react'
import { useState } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { DocumentUploader } from '~/components/form/DocumentUploader/DocumentUploader'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useRichTextEditorContext } from '../common/RichTextEditorContext'

export const TOOLBAR_IMAGE_ERROR_TEST_ID = 'toolbar-image-error'

const IMAGE_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif']
const IMAGE_ACCEPT = IMAGE_MIME_TYPES.join(',')
const IMAGE_MAX_SIZE = 5 * 1024 * 1024

type ImagePopperFormProps = {
  editor: Editor
  closePopper: () => void
}

const ImagePopperForm = ({ editor, closePopper }: ImagePopperFormProps) => {
  const { translate } = useInternationalization()
  const { onImageUpload } = useRichTextEditorContext()
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleChange = async (base64: string | null) => {
    if (!base64 || !onImageUpload) return

    setError(null)
    setUploading(true)

    try {
      const id = await onImageUpload(base64)

      editor.chain().focus().setImage({ src: id }).run()
      closePopper()
    } catch {
      setError(translate('text_1782918544840f0jput31j5k'))
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="flex w-90 flex-col gap-2 p-3">
      <DocumentUploader
        value={null}
        onChange={handleChange}
        accept={IMAGE_ACCEPT}
        acceptedMimeTypes={IMAGE_MIME_TYPES}
        maxSize={IMAGE_MAX_SIZE}
        description={translate('text_1782997762645ugjob60lzff')}
      />
      {uploading && (
        <Typography variant="caption" color="grey600">
          {translate('text_1779268404389431dgsiiysk')}
        </Typography>
      )}
      {error && (
        <Typography variant="caption" color="danger600" data-test={TOOLBAR_IMAGE_ERROR_TEST_ID}>
          {error}
        </Typography>
      )}
    </div>
  )
}

export default ImagePopperForm
