import { Icon, IconName } from 'lago-design-system'
import { FC, PropsWithChildren, ReactNode } from 'react'

import { Avatar } from '~/components/designSystem/Avatar'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography, TypographyProps } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

const DetailsPageContainer: FC<PropsWithChildren<{ className?: string }>> = ({
  className,
  children,
}) => {
  return <div className={tw('flex flex-col gap-12 px-4 pb-20 md:px-12', className)}>{children}</div>
}

const DetailsPageHeader: FC<{
  isLoading: boolean
  icon: IconName
  title: string | JSX.Element
  description: string
  className?: string
}> = ({ isLoading, icon, title, description, className }) => {
  if (isLoading) {
    return (
      <div className={tw('flex items-center gap-4 px-4 py-8 md:px-12', className)}>
        <Skeleton variant="connectorAvatar" size="large" />
        <div className="flex flex-col gap-1">
          <Skeleton variant="text" className="mb-1 w-40" />
          <Skeleton variant="text" className="w-50" />
        </div>
      </div>
    )
  }

  return (
    <div className={tw('flex items-center gap-4 px-4 py-8 md:px-12', className)}>
      <Avatar variant="connector" size="large">
        <Icon name={icon} color="dark" size="large" />
      </Avatar>

      <div className="flex flex-col gap-1">
        {typeof title === 'string' ? (
          <Typography variant="headline" color="grey700">
            {title}
          </Typography>
        ) : (
          title
        )}
        <Typography variant="body" color="grey600">
          {description}
        </Typography>
      </div>
    </div>
  )
}

const DetailsPageOverviewLine: FC<{
  title: string
  value: string | JSX.Element
  className?: string
}> = ({ title, value, className }) => {
  return (
    <div className={tw('flex items-start gap-2', className)}>
      <Typography variant="caption" color="grey600" noWrap className="min-w-35">
        {title}
      </Typography>
      {typeof value === 'string' ? (
        <Typography variant="body" color="grey700">
          {value}
        </Typography>
      ) : (
        value
      )}
    </div>
  )
}

const DetailsPageOverview: FC<
  PropsWithChildren<{
    className?: string
    leftColumn: JSX.Element
    rightColumn: JSX.Element
    isLoading?: boolean
  }>
> = ({ className, leftColumn, rightColumn, isLoading }) => {
  if (isLoading) {
    return (
      <div className="flex flex-row gap-8 py-6">
        <div className={tw('flex flex-1 flex-col gap-2', className)}>
          {[...Array(3)].map((_, index) => (
            <div key={`leftColumn-skeleton-${index}`} className="flex flex-row gap-8">
              <Skeleton variant="text" className="w-28" />
              <Skeleton variant="text" className="w-50" />
            </div>
          ))}
        </div>
        <div className={tw('flex flex-1 flex-col gap-2', className)}>
          {[...Array(2)].map((_, index) => (
            <div key={`rightColumn-skeleton-${index}`} className="flex flex-row gap-8">
              <Skeleton variant="text" className="w-28" />
              <Skeleton variant="text" className="w-50" />
            </div>
          ))}
        </div>
      </div>
    )
  }
  return (
    <div className={tw('flex flex-row gap-8 py-6', className)}>
      <div className={tw('flex flex-1 flex-col gap-2', className)}>{leftColumn}</div>
      <div className={tw('flex flex-1 flex-col gap-2', className)}>{rightColumn}</div>
    </div>
  )
}

const DetailsPageSectionTitle: FC<PropsWithChildren<TypographyProps>> = ({
  children,
  className,
  ...props
}) => (
  <Typography className={tw('flex h-18 items-center', className)} {...props}>
    {children}
  </Typography>
)

interface DetailsInfoItemProps {
  label: string
  value: ReactNode | string
  className?: string
  valueClassName?: string
}

const DetailsPageInfoGridItem: FC<DetailsInfoItemProps> = ({
  label,
  value,
  className,
  valueClassName,
}) => {
  return (
    <div className={tw(className)}>
      <Typography variant="caption">{label}</Typography>
      <Typography className={valueClassName} variant="body" color="grey700">
        {value}
      </Typography>
    </div>
  )
}

const DetailsPageInfoGrid: FC<{ grid: Array<DetailsInfoItemProps | false> }> = ({ grid }) => {
  return (
    <div className="grid grid-cols-[repeat(2,minmax(auto,1fr))] gap-[16px_32px]">
      {grid.map((item, index) => {
        if (item) {
          return (
            <DetailsPageInfoGridItem
              key={`details-info-grid-${item.label}-${index}`}
              label={item.label}
              value={item.value}
              valueClassName={item.valueClassName}
            />
          )
        }
      })}
    </div>
  )
}

const DetailsPageTableDisplay: FC<{
  name: string
  header?: Array<string | ReactNode>
  body?: Array<Array<string | number | ReactNode>>
  className?: string
}> = ({ name, header, body, className }) => {
  const ID = `details-table-display-${name}`

  return (
    <table
      className={tw(
        'w-full border-separate border-spacing-0 overflow-hidden rounded-xl border border-grey-300',
        (header?.length || 0) > 3 ? 'table-auto' : 'table-fixed',
        className,
      )}
    >
      {!!header?.length && header && (
        <thead className={tw('h-12 bg-grey-100 text-left', !!body?.length && 'shadow-b')}>
          <tr>
            {header
              .filter((headerItem) => headerItem !== false && headerItem !== undefined)
              .map((headerItem, index) => (
                <th
                  className="border-grey-300 px-4 not-last:border-r"
                  key={`${ID}-header-${index}`}
                >
                  {typeof headerItem === 'object' ? (
                    headerItem
                  ) : (
                    <Typography variant="captionHl">{headerItem}</Typography>
                  )}
                </th>
              ))}
          </tr>
        </thead>
      )}
      {!!body?.length && body && (
        <tbody className="text-left">
          {body.map((bodyItem, i) => (
            <tr key={`${ID}-body-row-${i}`} className="not-last:shadow-b">
              {bodyItem.map((bodyCell, j) => (
                <td
                  key={`${ID}-row-${i}-cell-${j}`}
                  className="h-12 min-h-11 border-r-grey-300 px-4 not-last:border-r"
                >
                  {typeof bodyCell === 'object' ? (
                    bodyCell
                  ) : (
                    <Typography variant="body" color="grey700">
                      {bodyCell}
                    </Typography>
                  )}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      )}
    </table>
  )
}

const DetailsPageSkeleton: FC = () => {
  return (
    <div>
      <div className="flex h-18 items-center">
        <Skeleton className="w-78" variant="text" />
      </div>
      <div className="grid grid-cols-2 gap-6">
        {[0, 1, 2, 3].map((i) => (
          <div className="flex flex-col gap-3 pb-3 pt-1" key={`skeleton-details-page-${i}`}>
            {i !== 1 && (
              <>
                <Skeleton className="w-20" variant="text" />
                <Skeleton className="w-50" variant="text" />
              </>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

export const DetailsPage = {
  Container: DetailsPageContainer,
  Header: DetailsPageHeader,
  Overview: DetailsPageOverview,
  OverviewLine: DetailsPageOverviewLine,
  SectionTitle: DetailsPageSectionTitle,
  InfoGrid: DetailsPageInfoGrid,
  InfoGridItem: DetailsPageInfoGridItem,
  TableDisplay: DetailsPageTableDisplay,
  Skeleton: DetailsPageSkeleton,
}
