import NiceModal, { unregister, useModal } from '@ebay/nice-modal-react'
import { useEffect, useId } from 'react'

import CentralizedDrawer, { CentralizedDrawerProps } from './CentralizedDrawer'
import { CLOSE_DRAWER_PARAMS } from './const'
import FormDrawer, { FormDrawerProps } from './FormDrawer'
import { DrawerResult, HookDrawerReturnType } from './types'

export const useDrawer = (): HookDrawerReturnType<CentralizedDrawerProps> => {
  const id = useId()

  useEffect(() => {
    NiceModal.register(id, CentralizedDrawer)

    return () => unregister(id)
  }, [id])

  const modal = useModal(id)

  return {
    open: (props: CentralizedDrawerProps) => modal.show(props) as Promise<DrawerResult>,
    close: () => {
      modal.resolve(CLOSE_DRAWER_PARAMS)
      modal.hide()
    },
  }
}

export const useFormDrawer = (): HookDrawerReturnType<FormDrawerProps> => {
  const id = useId()

  useEffect(() => {
    NiceModal.register(id, FormDrawer)

    return () => unregister(id)
  }, [id])

  const modal = useModal(id)

  return {
    open: (props: FormDrawerProps) => modal.show(props) as Promise<DrawerResult>,
    close: () => {
      modal.resolve(CLOSE_DRAWER_PARAMS)
      modal.hide()
    },
  }
}
