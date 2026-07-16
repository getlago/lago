import { useMemo, useRef, useState } from 'react'

import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

type LogoPickerProps = {
  logoValue?: string | null
  logoUrl?: string | null
  name?: string
  className?: string
  onChange: (value?: string | null) => void
}

const FILE_MAX_SIZE = 800000

export const LogoPicker = ({ className, logoValue, onChange, logoUrl, name }: LogoPickerProps) => {
  const [logoUploadError, setLogoUploadError] = useState(false)
  const { translate } = useInternationalization()
  const hiddenFileInputRef = useRef<HTMLInputElement>(null)

  const getBase64 = (file: Blob) => {
    const reader = new FileReader()

    if (file.size > FILE_MAX_SIZE) {
      setLogoUploadError(true)
      return
    }

    reader.readAsDataURL(file)
    reader.onload = () => {
      onChange(reader?.result?.toString())
    }
    reader.onerror = (error) => {
      // eslint-disable-next-line no-console
      console.error('Error: ', error)
    }
  }

  const localLogoUrl = useMemo(() => {
    if (logoValue === null) {
      return null
    }
    return logoValue || logoUrl
  }, [logoValue, logoUrl])

  return (
    <div className={tw('flex gap-4', className)}>
      {!!localLogoUrl ? (
        <Avatar size="large" variant="connector">
          <img src={localLogoUrl} alt={`${name}'s logo`} />
        </Avatar>
      ) : (
        <Avatar
          size="large"
          variant="company"
          identifier={name || ''}
          initials={(name || '').split(' ').reduce((acc, n) => (acc = acc + n[0]), '')}
        />
      )}
      <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <Button
            className="w-fit"
            variant="secondary"
            onClick={() => hiddenFileInputRef?.current?.click()}
          >
            {translate('text_62ab2d0396dd6b0361614d18')}
          </Button>
          <Button
            danger
            icon="trash"
            variant="secondary"
            onClick={() => onChange(null)}
            disabled={!localLogoUrl}
          />
        </div>
        <Typography variant="caption" color={logoUploadError ? 'danger600' : undefined}>
          {translate('text_62ab2d0396dd6b0361614d20')}
        </Typography>
      </div>
      <input
        className="hidden"
        type="file"
        accept="image/png, image/jpeg"
        ref={hiddenFileInputRef}
        onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
          setLogoUploadError(false)
          const file = event?.target?.files?.[0]

          if (file) {
            getBase64(file)
          }
        }}
      />
    </div>
  )
}
