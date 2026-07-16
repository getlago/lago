import { Icon } from 'lago-design-system'
import { FC, ReactNode, useEffect, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

export const DOCUMENT_UPLOADER_INPUT_TEST_ID = 'document-uploader-input'

const DEFAULT_ACCEPT = 'application/pdf,image/jpeg,image/png'
const DEFAULT_MIME_TYPES = ['application/pdf', 'image/jpeg', 'image/png']
const DEFAULT_MAX_SIZE = 10 * 1024 * 1024

export interface DocumentUploaderProps {
  value: string | null
  onChange: (value: string | null) => void
  accept?: string
  acceptedMimeTypes?: string[]
  maxSize?: number
  description?: ReactNode
  invalidTypeError?: string
  tooLargeError?: string
  className?: string
}

export const DocumentUploader: FC<DocumentUploaderProps> = ({
  value,
  onChange,
  accept = DEFAULT_ACCEPT,
  acceptedMimeTypes = DEFAULT_MIME_TYPES,
  maxSize = DEFAULT_MAX_SIZE,
  description,
  invalidTypeError,
  tooLargeError,
  className,
}) => {
  const inputRef = useRef<HTMLInputElement>(null)
  const [fileName, setFileName] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isDragging, setIsDragging] = useState(false)

  const { translate } = useInternationalization()

  useEffect(() => {
    if (!value) {
      setFileName(null)
      setError(null)
    }
  }, [value])

  const handleFile = (file: File | undefined) => {
    if (!file) return

    if (!acceptedMimeTypes.includes(file.type)) {
      setError(invalidTypeError ?? translate('text_1781686594125m4b2ej18zyb'))
      return
    }

    if (file.size > maxSize) {
      setError(tooLargeError ?? translate('text_1781686594125tj83pbtkkad'))
      return
    }

    const reader = new FileReader()

    reader.onload = () => {
      setError(null)
      setFileName(file.name)
      onChange(reader.result?.toString() ?? null)
    }
    reader.readAsDataURL(file)
  }

  const onRemove = () => {
    setFileName(null)
    setError(null)
    onChange(null)

    if (inputRef.current) {
      inputRef.current.value = ''
    }
  }

  return (
    <div className={tw('flex flex-col gap-2', className)}>
      <button
        type="button"
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => {
          e.preventDefault()
          setIsDragging(true)
        }}
        onDragLeave={() => setIsDragging(false)}
        onDrop={(e) => {
          e.preventDefault()
          setIsDragging(false)
          handleFile(e.dataTransfer.files?.[0])
        }}
        className={tw(
          'flex flex-col items-center justify-center gap-4 rounded-xl border-2 border-dashed border-grey-400 bg-grey-100 px-6 py-10',
          isDragging && 'border-blue-600',
        )}
      >
        <div className="flex size-10 items-center justify-center">
          <Icon name="upload" />
        </div>
        <div className="flex flex-col items-center text-center">
          <Typography className="text-center" variant="bodyHl" color="grey700">
            <Typography component="span" variant="bodyHl" color="primary600">
              {translate('text_178168659412569kiwbxedzw')}
            </Typography>{' '}
            {translate('text_1781709211816eyrk9jcabsg')}
          </Typography>
          {description && (
            <Typography variant="caption" color="grey600">
              {description}
            </Typography>
          )}
          <Typography variant="caption" color="grey600">
            {translate('text_1781707828627t3f7vohqvq8')}
          </Typography>
        </div>
      </button>

      <input
        ref={inputRef}
        data-test={DOCUMENT_UPLOADER_INPUT_TEST_ID}
        type="file"
        accept={accept}
        className="hidden"
        onChange={(e) => handleFile(e.target.files?.[0])}
      />

      {value && fileName && !error && (
        <div className="flex items-center justify-between rounded-xl border border-grey-300 px-4 py-2">
          <Typography variant="body" color="grey700">
            {fileName}
          </Typography>
          <Button variant="quaternary" icon="trash" onClick={onRemove} />
        </div>
      )}

      {error && (
        <Typography variant="caption" color="danger600">
          {error}
        </Typography>
      )}
    </div>
  )
}
