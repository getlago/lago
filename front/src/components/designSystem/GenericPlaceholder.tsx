import { ReactNode } from 'react'

import { Button, ButtonVariant } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

// Test ID constants
export const GENERIC_PLACEHOLDER_TEST_ID = 'empty-state'
export const GENERIC_PLACEHOLDER_TITLE_TEST_ID = 'generic-placeholder-title'
export const GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID = 'generic-placeholder-subtitle'
export const GENERIC_PLACEHOLDER_IMAGE_TEST_ID = 'generic-placeholder-image'
export const GENERIC_PLACEHOLDER_BUTTON_TEST_ID = 'generic-placeholder-button'

export interface GenericPlaceholderProps {
  className?: string
  title?: string
  subtitle: string | ReactNode
  image: ReactNode
  buttonTitle?: string
  buttonVariant?: ButtonVariant
  buttonAction?: (() => Promise<void>) | (() => void)
  noMargins?: boolean
}

export const GenericPlaceholder = ({
  className,
  title,
  subtitle,
  image,
  buttonTitle,
  noMargins = false,
  buttonVariant,
  buttonAction,
  ...props
}: GenericPlaceholderProps) => {
  const hasButton = !!buttonTitle && !!buttonAction

  return (
    <div
      className={tw(
        'mx-auto my-0 max-w-124 px-4 pb-4 pt-12 first:mb-3',
        {
          'm-0': noMargins,
          'p-0': noMargins,
        },
        className,
      )}
      data-test={GENERIC_PLACEHOLDER_TEST_ID}
      {...props}
    >
      <div
        className="mb-1 [&>img]:size-35 [&>svg]:size-35"
        data-test={GENERIC_PLACEHOLDER_IMAGE_TEST_ID}
      >
        {image}
      </div>

      {title && (
        <Typography
          className="mb-3"
          variant="subhead1"
          data-test={GENERIC_PLACEHOLDER_TITLE_TEST_ID}
        >
          {title}
        </Typography>
      )}
      <Typography
        className={tw({
          'mb-5': hasButton,
        })}
        html={typeof subtitle === 'string' ? subtitle : undefined}
        data-test={GENERIC_PLACEHOLDER_SUBTITLE_TEST_ID}
      >
        {typeof subtitle === 'string' ? undefined : subtitle}
      </Typography>

      {hasButton && (
        <Button
          variant={buttonVariant}
          onClick={buttonAction}
          data-test={GENERIC_PLACEHOLDER_BUTTON_TEST_ID}
        >
          {buttonTitle}
        </Button>
      )}
    </div>
  )
}

GenericPlaceholder.displayName = 'GenericPlaceholder'
