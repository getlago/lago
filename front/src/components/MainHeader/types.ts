import { IconName } from 'lago-design-system'
import { ReactNode } from 'react'

import { ButtonVariant } from '~/components/designSystem/Button'
import { StatusProps, StatusType } from '~/components/designSystem/Status'

import { NavigationTabBarItem } from './NavigationTabBar'

// ─── Tab with content ────────────────────────────────────────────

/**
 * Unified tab definition: bar metadata + content in a single object.
 * Pages define one array, MainHeader picks the bar metadata,
 * and the page resolves the active content — single source of truth.
 */
export type MainHeaderTab = NavigationTabBarItem & {
  content: ReactNode
  /**
   * Serializable value included in the config snapshot. `content` (ReactNode) is
   * stripped from the snapshot, so a tab whose content reflects reactive state
   * (e.g. a toggle the user flips while staying on the page) must encode that
   * state here, otherwise the stale content stays in context until a full reload.
   */
  snapshotKey?: string | number | boolean
}

// ─── Action types ───────────────────────────────────────────────

/** Primary button with chevron-down that opens a dropdown menu */
export interface MainHeaderDropdownAction {
  type: 'dropdown'
  label: string
  items: MainHeaderDropdownItem[]
  dataTest?: string
}

interface MainHeaderDropdownItem {
  label: string
  onClick: (closePopper: () => void) => void | Promise<void>
  disabled?: boolean
  hidden?: boolean
  danger?: boolean
  dataTest?: string
  startIcon?: IconName
  endIcon?: IconName
  tooltip?: string
}

/** Grey/inline button that performs an action in the current view */
export interface MainHeaderInPageAction {
  type: 'action'
  label: string
  onClick: () => void | Promise<void>
  variant?: ButtonVariant
  startIcon?: IconName
  endIcon?: IconName
  hidden?: boolean
  disabled?: boolean
  dataTest?: string
}

/** Arbitrary ReactNode rendered as-is in the actions area */
interface MainHeaderCustomAction {
  type: 'custom'
  label: string
  content: ReactNode
  hidden?: boolean
  /** Serializable value included in the config snapshot to trigger re-renders when the content changes (e.g. a toggle state). */
  snapshotKey?: string | number | boolean
}

export type MainHeaderAction =
  MainHeaderDropdownAction | MainHeaderInPageAction | MainHeaderCustomAction

// ─── Actions config ─────────────────────────────────────────────

export interface MainHeaderActionsConfig {
  /** Action button definitions */
  items: MainHeaderAction[]
  /** Show a skeleton instead of the actions block */
  loading?: boolean
}

// ─── Entity config ──────────────────────────────────────────────

type MainHeaderBadge = Pick<StatusProps, 'label' | 'labelVariables' | 'endIcon'> & {
  /** Accepts both the StatusType enum and string literals like 'default', 'success', etc. */
  type: `${StatusType}`
}

export interface MainHeaderEntityConfig {
  /** Display name — rendered as headline Typography */
  viewName: string
  /** Show a skeleton instead of the title + badges row */
  viewNameLoading?: boolean
  /**
   * Secondary line below the name (e.g. externalId, amount). A plain string is
   * wrapped in a Typography; pass a ReactNode to render custom content as-is
   * (e.g. a TypographyWithCopy, or copy button composed next to text).
   */
  metadata?: ReactNode
  /** Show a skeleton instead of the metadata line */
  metadataLoading?: boolean
  /** Status badges displayed next to the entity name */
  badges?: MainHeaderBadge[]
  /** Arbitrary icon rendered in a connector Avatar (e.g. integrations). Can be an IconName string or a ReactNode (e.g. SVG component) */
  icon?: IconName | ReactNode
}

// ─── Breadcrumb ──────────────────────────────────────────────────

export interface BreadcrumbItem {
  /** Human-readable label shown in the breadcrumb trail */
  label: string
  /** Route path — the item is rendered as a clickable link */
  path: string
  /** Show a skeleton instead of the label (e.g. while an async label loads) */
  loading?: boolean
}

// ─── Main config ────────────────────────────────────────────────

export interface MainHeaderConfig {
  /** Breadcrumb trail rendered above the entity name */
  breadcrumb?: BreadcrumbItem[]

  /** Actions section — items + optional loading skeleton */
  actions?: MainHeaderActionsConfig

  /** Entity section — viewName is the page/entity heading. Optional during loading. */
  entity?: MainHeaderEntityConfig

  /** Tab definitions — each tab declares bar metadata AND content in a single object */
  tabs?: MainHeaderTab[]

  /** Filter — pages include their own providers */
  filtersSection?: ReactNode

  /**
   * Serializable value included in the config snapshot. The snapshot strips the tabs'
   * `content` ReactNode (to avoid re-render loops), so pages whose content reflects
   * mutable data must bump this key when that data changes, otherwise the header keeps
   * showing stale content (e.g. a wallet balance after a top-up/void).
   */
  snapshotKey?: string | number | boolean
}
