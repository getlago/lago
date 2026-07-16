/**
 * Shared types for overlay components (dialogs and drawers).
 */

export type OverlayResult =
  { reason: 'close' } | { reason: 'success'; params?: unknown } | { reason: 'error'; error: Error }

export type HookOverlayReturnType<Props> = {
  open: (props: Props) => Promise<OverlayResult>
  close: () => void
}

export type OverlayFormProps = {
  id: string
  submit: () => void | Promise<void> | OverlayResult | Promise<OverlayResult>
}
