import { gql } from '@apollo/client'
import { Icon, IconName } from 'lago-design-system'
import { useLayoutEffect, useMemo, useRef, useState } from 'react'

import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { findNearestScrollableAncestor } from '~/components/designSystem/VirtualList/findNearestScrollableAncestor'
import { VirtualFilterList } from '~/components/designSystem/VirtualList/VirtualFilterList'
import {
  EntitlementForPlanDetailsSidebarFragment,
  FixedChargeForPlanDetailsSidebarFragment,
  UsageChargeForPlanDetailsSidebarFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import { getEntitlementSectionId, PlanDetailsV2SectionId } from './sidebarSections'

gql`
  fragment FixedChargeForPlanDetailsSidebar on FixedCharge {
    id
    invoiceDisplayName
    code
    addOn {
      id
      name
    }
  }

  fragment UsageChargeForPlanDetailsSidebar on Charge {
    id
    invoiceDisplayName
    code
    billableMetric {
      id
      name
    }
  }

  fragment EntitlementForPlanDetailsSidebar on PlanEntitlement {
    code
    name
  }
`

// `labelKey` is translated; `label` is a ready-to-render string (charge names,
// which aren't translation keys). Sections use `labelKey`, charge children use
// `label`.
type SidebarItem = {
  id: string
  labelKey?: string
  label?: string
  children?: SidebarItem[]
  addLabelKey?: string
}

// Every row is full-width so the hover background is identical across groups and
// leaves; depth is expressed purely as left padding on the row content, and the tree
// guide line is an absolute overlay (it must sit ON TOP of the hover background, like
// GitHub's PR file tree), never a container that insets the row.
const SIDEBAR_INDENT_STEP = 20
const SIDEBAR_LEAF_BASE_PADDING = 24
const SIDEBAR_GUIDE_LINE_BASE_LEFT = 10

const getLeafPaddingLeft = (depth: number): number =>
  SIDEBAR_LEAF_BASE_PADDING + depth * SIDEBAR_INDENT_STEP

// x of the vertical guide line for a children block whose items sit at `childDepth`.
const getGuideLineLeft = (childDepth: number): number =>
  SIDEBAR_GUIDE_LINE_BASE_LEFT + (childDepth - 1) * SIDEBAR_INDENT_STEP

const getIconName = (isGroup: boolean, isExpanded: boolean): IconName => {
  if (!isGroup) return 'file'

  return isExpanded ? 'folder-open' : 'folder-close'
}

const buildSections = (
  isInSubscriptionForm: boolean,
  fixedCharges: FixedChargeForPlanDetailsSidebarFragment[],
  usageCharges: UsageChargeForPlanDetailsSidebarFragment[],
  entitlements: EntitlementForPlanDetailsSidebarFragment[],
): SidebarItem[] => {
  const sections: SidebarItem[] = [
    { id: PlanDetailsV2SectionId.PlanSettings, labelKey: 'text_177928991586601f21f0x87c' },
    { id: PlanDetailsV2SectionId.SubscriptionFee, labelKey: 'text_1779289915866etwoweh1syv' },
    {
      id: PlanDetailsV2SectionId.FixedCharges,
      labelKey: 'text_1779289915866aj39dyv1wps',
      addLabelKey: 'text_176072970726882uau5y69f1',
      children: fixedCharges.map((charge) => ({
        id: charge.id,
        label: charge.invoiceDisplayName || charge.addOn.name || charge.code || '',
      })),
    },
    {
      id: PlanDetailsV2SectionId.UsageCharges,
      labelKey: 'text_1779289915866ngi8sv5t9lg',
      addLabelKey: 'text_1772133285142oouequiz2t2',
      children: usageCharges.map((charge) => ({
        id: charge.id,
        label: charge.invoiceDisplayName || charge.billableMetric.name || charge.code || '',
      })),
    },
    // Minimum commitment lives at the root level now (no "Advanced settings" folder).
    { id: PlanDetailsV2SectionId.MinimumCommitment, labelKey: 'text_17792899158664ii2pmrd2le' },
  ]

  if (!isInSubscriptionForm) {
    sections.push(
      { id: PlanDetailsV2SectionId.ProgressiveBilling, labelKey: 'text_1779289915866vguw0lfmz06' },
      {
        id: PlanDetailsV2SectionId.Entitlements,
        labelKey: 'text_1779289915866mr56w61hhi5',
        addLabelKey: 'text_1753864223060devvklm7vk0',
        children: entitlements.map((entitlement) => ({
          id: getEntitlementSectionId(entitlement.code),
          label: entitlement.name || entitlement.code,
        })),
      },
    )
  }

  return sections
}

type PlanDetailsV2LeftSidebarProps = {
  isInSubscriptionForm?: boolean
  fixedCharges?: FixedChargeForPlanDetailsSidebarFragment[]
  usageCharges?: UsageChargeForPlanDetailsSidebarFragment[]
  entitlements?: EntitlementForPlanDetailsSidebarFragment[]
  onItemClick: (id: string) => void
  onAddClick?: (id: string) => void
  className?: string
}

export const PlanDetailsV2LeftSidebar = ({
  isInSubscriptionForm = false,
  fixedCharges = [],
  usageCharges = [],
  entitlements = [],
  onItemClick,
  onAddClick,
  className,
}: PlanDetailsV2LeftSidebarProps) => {
  const { translate } = useInternationalization()
  const sections = useMemo(
    () => buildSections(isInSubscriptionForm, fixedCharges, usageCharges, entitlements),
    [isInSubscriptionForm, fixedCharges, usageCharges, entitlements],
  )
  // Folders start collapsed; the user expands what they need.
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())
  // The sidebar is its own scroll container (overflow-y-auto below) so the
  // virtualizer tracks the nav's scroll, not the page's. We own the element, so
  // we hand VirtualFilterList the ref directly rather than walking ancestors.
  const navRef = useRef<HTMLElement>(null)

  // The nav is `sticky top-0`, but at the top of the page it sits BELOW the page
  // header/tabs, so a fixed `h-screen` would overflow the viewport by that offset
  // and hide the bottom of an expanded folder. Size it to "viewport bottom minus
  // current top" instead; the offset shrinks from header-height to 0 as the page
  // scrolls and the header scrolls away. Written imperatively (no re-render on
  // scroll); VirtualFilterList's own ResizeObserver picks up the height change.
  useLayoutEffect(() => {
    const element = navRef.current

    if (!element) return

    const pageScrollElement = findNearestScrollableAncestor(element)

    const resizeToViewport = () => {
      element.style.maxHeight = `${window.innerHeight - element.getBoundingClientRect().top}px`
    }

    resizeToViewport()
    window.addEventListener('resize', resizeToViewport)
    pageScrollElement?.addEventListener('scroll', resizeToViewport, { passive: true })

    // Content above the nav (page header, async data) can reflow with no scroll/resize
    // event, shifting the nav's top. Observe the body so the height re-converges whenever
    // layout settles - however long that takes - instead of guessing a fixed frame budget.
    const bodyObserver = new ResizeObserver(resizeToViewport)

    bodyObserver.observe(document.body)

    return () => {
      window.removeEventListener('resize', resizeToViewport)
      pageScrollElement?.removeEventListener('scroll', resizeToViewport)
      bodyObserver.disconnect()
    }
  }, [])

  const toggleExpanded = (id: string) => {
    setExpanded((prev) => {
      const next = new Set(prev)

      if (next.has(id)) {
        next.delete(id)
      } else {
        next.add(id)
      }

      return next
    })
  }

  // The visible tree flattened to a linear row list: folders contribute their
  // children only when expanded. Virtualization needs a flat array, so recursion
  // is re-expressed as a per-row `depth`. Recomputed on expand/collapse.
  const flatRows = useMemo(() => {
    const rows: Array<{ item: SidebarItem; depth: number }> = []

    const walk = (items: SidebarItem[], depth: number) => {
      for (const item of items) {
        rows.push({ item, depth })

        if (item.children !== undefined && expanded.has(item.id) && item.children.length > 0) {
          walk(item.children, depth + 1)
        }
      }
    }

    walk(sections, 0)

    return rows
  }, [sections, expanded])

  // The interactive row bar (toggle + label + optional add button). Shared by
  // every row; depth only drives the label's left padding.
  const renderRowBar = (item: SidebarItem, depth: number) => {
    const isGroup = item.children !== undefined
    const isExpanded = isGroup && expanded.has(item.id)
    const showAddButton = !!item.addLabelKey && !isInSubscriptionForm
    const addLabel = item.addLabelKey ? translate(item.addLabelKey) : undefined
    const iconName = getIconName(isGroup, isExpanded)

    return (
      <div className="group/bar flex h-8 w-full items-stretch rounded-lg hover:bg-grey-200">
        {isGroup && (
          <Tooltip
            title={translate(
              isExpanded ? 'text_624aa732d6af4e0103d40e61' : 'text_624aa79870f60300a3c4d074',
            )}
            placement="top"
          >
            <button
              type="button"
              data-test={`sidebar-toggle-${item.id}`}
              className="flex items-center justify-center rounded-l-lg px-1 py-2.5 hover:bg-grey-300 focus-visible:ring focus-visible:ring-inset"
              onClick={() => toggleExpanded(item.id)}
            >
              <Icon
                name={isExpanded ? 'chevron-down-filled' : 'chevron-right-filled'}
                size="small"
                color="dark"
              />
            </button>
          </Tooltip>
        )}
        <button
          type="button"
          className={tw(
            'flex min-w-0 flex-1 items-center gap-2 px-2 py-1 text-left focus-visible:ring focus-visible:ring-inset',
            // Round the outer-facing corners so the focus ring isn't shaved off where
            // the button meets the row's edge: left when no toggle precedes, right when
            // no add button follows.
            !isGroup && 'rounded-l-lg',
            !showAddButton && 'rounded-r-lg',
          )}
          // Leaves pad left to clear the chevron column and step in per depth; groups
          // rely on the chevron for their left slot. The row itself stays full-width.
          style={!isGroup ? { paddingLeft: getLeafPaddingLeft(depth) } : undefined}
          // BIL-159: clicking a folder row expands/collapses it (no scroll). Only leaf
          // items navigate to (open + scroll to) their section.
          onClick={() => (isGroup ? toggleExpanded(item.id) : onItemClick(item.id))}
        >
          <Icon name={iconName} size="small" color="dark" />
          <Typography className="min-w-0" variant="caption" color="grey600" noWrap>
            {item.label ?? (item.labelKey ? translate(item.labelKey) : '')}
          </Typography>
        </button>
        {showAddButton && addLabel && (
          <Tooltip title={addLabel} placement="top">
            <button
              type="button"
              data-test={`sidebar-add-${item.id}`}
              className="flex items-center justify-center rounded-r-lg px-1 py-2.5 hover:bg-grey-300 focus-visible:ring focus-visible:ring-inset"
              onClick={() => onAddClick?.(item.id)}
            >
              <Icon name="plus" size="small" color="dark" />
            </button>
          </Tooltip>
        )}
      </div>
    )
  }

  // One flattened row: a fixed-height slot (consecutive slots leave no gap, so the
  // guide line never breaks) carrying the row bar plus one vertical guide segment
  // per ancestor depth. Stacking the per-row segments reproduces the continuous
  // tree line that a single cross-block overlay can't draw once rows are
  // absolutely positioned by the virtualizer. Segments render after the bar so
  // they paint on top of its hover background.
  const renderFlatRow = (item: SidebarItem, depth: number) => (
    <div className="relative h-9">
      {renderRowBar(item, depth)}
      {Array.from({ length: depth }, (_, level) => (
        <span
          key={level}
          aria-hidden
          className="pointer-events-none absolute inset-y-0 w-px bg-grey-300"
          style={{ left: getGuideLineLeft(level + 1) }}
        />
      ))}
    </div>
  )

  return (
    <nav
      ref={navRef}
      className={tw(
        // Height is set imperatively (see useLayoutEffect) to "viewport - nav top",
        // so an expanded folder never extends past the viewport bottom.
        'sticky top-0 flex min-h-0 w-64 flex-shrink-0 flex-col overflow-y-auto border-r border-grey-300 pr-4 pt-4',
        className,
      )}
      aria-label="Plan sections"
    >
      <VirtualFilterList
        className="flex flex-col"
        gap={0}
        items={flatRows}
        estimateItemHeight={36}
        getItemKey={(row) => row.item.id}
        renderItem={(row) => renderFlatRow(row.item, row.depth)}
        getScrollElement={() => navRef.current}
      />
    </nav>
  )
}
