import { OverlayResult } from '~/core/overlays/types'

export type DialogResult =
  | OverlayResult
  | {
      reason: 'open-other-dialog'
      otherDialog: Promise<DialogResult>
    }

export type HookDialogReturnType<Props> = {
  open: (props: Props) => Promise<DialogResult>
  close: () => void
}

export type PremiumWarningHookDialogReturnType<Props> = {
  open: (props?: Props) => Promise<DialogResult>
  close: () => void
}

export type FormProps = {
  id: string
  submit: () => void | Promise<void> | DialogResult | Promise<DialogResult>
}
