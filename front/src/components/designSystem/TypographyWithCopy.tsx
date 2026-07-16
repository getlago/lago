import { FC } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography, TypographyProps } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { MaskOptions, maskValue } from '~/core/formats/maskValue'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

export const TYPOGRAPHY_WITH_COPY_BUTTON_TEST_ID = 'typography-with-copy-button'

interface TypographyWithCopyProps extends TypographyProps {
  masked?: boolean
  maskOptions?: MaskOptions
  onCopy?: () => void
  /**
   * Shrinks the copy button so it hugs its content height and uses a smaller
   * icon, to sit inline with caption/body text in dense lists. Defaults to
   * `false`, preserving the original `size="small"` button look.
   */
  compact?: boolean
}

export const TypographyWithCopy: FC<TypographyWithCopyProps> = ({
  children,
  className,
  masked,
  maskOptions,
  onCopy,
  compact,
  ...typographyProps
}) => {
  const { translate } = useInternationalization()

  const displayValue = masked && maskOptions ? maskValue(children as string, maskOptions) : children

  return (
    <Tooltip placement="top" title={translate('text_623b42ff8ee4e000ba87d0c6')} className="w-fit">
      <Button
        data-test={TYPOGRAPHY_WITH_COPY_BUTTON_TEST_ID}
        endIcon="duplicate"
        variant="quaternary"
        size="small"
        className={tw(
          '-ml-1 px-1 py-0',
          {
            '!h-auto !min-h-0 !min-w-0 !items-baseline !py-0 [&_.MuiButton-endIcon>svg]:!size-3 [&_.MuiButton-endIcon]:!ml-1':
              compact,
          },
          className,
        )}
        onClick={(e) => {
          e.stopPropagation()
          if (onCopy) {
            onCopy()
          } else {
            copyToClipboard(children as string)
            addToast({
              severity: 'info',
              translateKey: 'text_1775559630554ourrtpgddty',
            })
          }
        }}
      >
        <Typography
          className={tw({
            // Caption is 14px/24px; the copy button nudges the text baseline ~1px
            // high, so the code in a `code • text` line misaligns with its plain
            // sibling. +2px line-height drops the baseline back onto the sibling's.
            '!leading-[26px]': compact,
          })}
          {...typographyProps}
        >
          {displayValue}
        </Typography>
      </Button>
    </Tooltip>
  )
}
