/**
 * This file defines every types and utils related to the toastsVar (reactive variable)
 * It deals with all the toasts of the app
 */
import { makeVar } from '@apollo/client'

/** ----------------- TYPES ----------------- */
export enum ToastSeverityEnum {
  info = 'info',
  success = 'success',
  danger = 'danger',
}
type TSeverity = keyof typeof ToastSeverityEnum

interface IToastWithMessage {
  id: string
  severity?: TSeverity
  autoDismiss?: boolean
  message: string
  translateKey?: never
}

interface IToastWithTransKey {
  id: string
  severity?: TSeverity
  autoDismiss?: boolean
  translateKey: string
  message?: never
}

export type TToast = IToastWithMessage | IToastWithTransKey

/** ----------------- VAR ----------------- */
export const toastsVar = makeVar<TToast[]>([])

/** ----------------- UTILS ----------------- */
export const addToast = (toast: Omit<IToastWithMessage, 'id'> | Omit<IToastWithTransKey, 'id'>) => {
  const previousToasts = toastsVar()
  const existingToast = previousToasts.find((t) => {
    return (
      (!!toast.translateKey && t.translateKey === toast.translateKey) ||
      (!!toast.message && t.message === toast.message)
    )
  })

  if (!existingToast) {
    toastsVar([{ id: Math.ceil(Math.random() * 100000000) + '', ...toast }, ...previousToasts])
  }
}

export const removeToast = (id: string) => {
  const previousToasts = toastsVar()

  toastsVar([...previousToasts.filter((t) => t.id !== id)])
}

export const removeAllToasts = () => {
  toastsVar([])
}
