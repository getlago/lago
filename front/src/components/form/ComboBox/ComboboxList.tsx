import _groupBy from 'lodash/groupBy'
import {
  Children,
  ForwardedRef,
  forwardRef,
  PropsWithChildren,
  ReactElement,
  ReactNode,
  useMemo,
} from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { tw } from '~/styles/utils'

import { ComboBoxVirtualizedList, GROUP_ITEM_KEY } from './ComboBoxVirtualizedList'
import { ComboBoxData, ComboBoxProps } from './types'

const randomKey = Math.round(Math.random() * 100000)

interface ComboBoxVirtualizedListProps extends Pick<
  ComboBoxProps,
  'value' | 'renderGroupHeader' | 'virtualized'
> {
  children: ReactNode
}

// ItemGroup wraps consecutive items with 8px margins and 4px gap between items
export const ItemGroup = ({ children }: { children: ReactNode }) => (
  <div className="my-2 flex flex-col gap-1">{children}</div>
)

// Individual items have no margins when in ItemGroup
// When virtualized and flattened, items need margins for proper spacing
export const ComboboxListItem = ({
  children,
  virtualized,
  className,
  ...propsToForward
}: { className?: string } & PropsWithChildren & ComboBoxVirtualizedListProps) => (
  <div
    className={tw(
      {
        'not-last:mx-2': virtualized,
        'not-last:mx-0': !virtualized,
      },
      className,
    )}
    {...propsToForward}
  >
    {children}
  </div>
)

export const ComboboxList = forwardRef(
  (
    {
      value,
      children,
      virtualized,
      renderGroupHeader,
      ...propsToForward
    }: ComboBoxVirtualizedListProps,
    ref: ForwardedRef<HTMLDivElement>,
  ) => {
    const isGrouped = !!(children as { props: { option: ComboBoxData } }[])[0]?.props?.option?.group

    const htmlItems = useMemo(() => {
      if (!isGrouped) {
        const items = (children as ReactElement[]).map((item, i) => (
          <ComboboxListItem key={`combobox-list-item-${randomKey}-${i}`} {...propsToForward}>
            {item}
          </ComboboxListItem>
        ))

        // For virtualized lists, we need to flatten the structure
        if (virtualized) {
          return items
        }

        // For non-virtualized, wrap in ItemGroup
        return [<ItemGroup key={`item-group-${randomKey}`}>{items}</ItemGroup>]
      }

      /**
       * If items are grouped (ie !!item.group)
       * Construct an array with headers followed by their respective items
       */
      const groupedBy = _groupBy(
        children as { props: { option: ComboBoxData } }[],
        (child) => child.props.option.group,
      )

      return Children.toArray(
        Object.keys(groupedBy)
          .sort((a, b) => a.localeCompare(b))
          .reduce<ReactNode[]>((acc, key, i) => {
            const items = (groupedBy[key] as ReactElement[]).map((item, j) => (
              <ComboboxListItem
                key={`combobox-list-item-${randomKey}-${i}-${j}`}
                {...propsToForward}
              >
                {item}
              </ComboboxListItem>
            ))

            return [
              ...acc,
              // Headers have no margins
              <div
                key={`${GROUP_ITEM_KEY}-${key}`}
                data-type={GROUP_ITEM_KEY}
                className={tw(
                  'mx-0 flex h-11 w-[inherit] items-center bg-grey-100 px-6 py-0 shadow-[0px_-1px_0px_0px_#D9DEE7_inset,0px_-1px_0px_0px_#D9DEE7]',
                  {
                    'sticky top-0 z-toast': !virtualized,
                  },
                )}
              >
                {(!!renderGroupHeader && (renderGroupHeader[key] as ReactNode)) || (
                  <Typography noWrap>{key}</Typography>
                )}
              </div>,
              // For virtualized lists, flatten items; for non-virtualized, wrap in ItemGroup
              ...(virtualized
                ? items
                : [<ItemGroup key={`item-group-${randomKey}-${i}`}>{items}</ItemGroup>]),
            ]
          }, []),
      )
    }, [isGrouped, renderGroupHeader, children, propsToForward, virtualized])

    return (
      <div
        className={tw('relative max-h-[inherit] pb-0', {
          'overflow-auto': !virtualized,
          'overflow-visible': virtualized,
        })}
        ref={ref}
        role="listbox"
      >
        {virtualized ? (
          <ComboBoxVirtualizedList value={value} elements={htmlItems as ReactElement[]} />
        ) : (
          htmlItems
        )}
      </div>
    )
  },
)

ComboboxList.displayName = 'ComboboxList'
