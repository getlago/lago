import { PropsWithChildren } from 'react'

import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

export const SettingsPaddedContainer = ({
  children,
  className,
}: PropsWithChildren & { className?: string }) => (
  <div className={tw('flex flex-col gap-12 px-4 pb-20 pt-4 md:px-12', className)}>{children}</div>
)

export const SettingsWithTabsPaddedContainer = ({
  children,
  className,
}: PropsWithChildren & { className?: string }) => (
  <div className={tw('flex flex-col gap-12 px-4 pb-20 pt-10 md:px-12', className)}>{children}</div>
)

export const SettingsPageHeaderContainer = ({ children }: PropsWithChildren) => (
  <div className="flex flex-col gap-1">{children}</div>
)

export const SettingsListWrapper = ({ children }: PropsWithChildren) => (
  <div className="flex flex-col gap-12">{children}</div>
)

export const SettingsListItem = ({
  children,
  className,
}: PropsWithChildren & { className?: string }) => (
  <div
    className={tw('flex flex-col gap-4 pb-12 shadow-b last:pb-0 last:[box-shadow:none]', className)}
  >
    {children}
  </div>
)

export const SettingsListItemLoadingSkeleton = ({ count = 1 }: { count?: number }) =>
  Array.from({ length: count }).map((_, index) => (
    <div
      key={`settings-list-item-skeleton-${index}`}
      className="flex w-full flex-col justify-between pb-12 shadow-b last:pb-0 last:[box-shadow:none]"
    >
      <Skeleton variant="text" className="mb-6 w-40" />
      <Skeleton variant="text" className="mb-7 w-80" />
      <Skeleton variant="text" className="mb-2 w-60" />
    </div>
  ))

export const SettingsListItemHeader = ({
  label,
  sublabel,
  action,
}: {
  label: string
  sublabel?: string
  action?: JSX.Element
}) => (
  <div className="flex min-h-12 flex-row items-baseline justify-between gap-4">
    <div className="flex flex-col gap-2">
      <Typography variant="subhead1" color="grey700">
        {label}
      </Typography>

      {sublabel && <Typography variant="caption">{sublabel}</Typography>}
    </div>

    {!!action && <>{action}</>}
  </div>
)
