import { useEffect, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'

export type SetDisabledRef = React.MutableRefObject<(disabled: boolean) => void>

export const useSetDisabledRef = (): SetDisabledRef => useRef<(disabled: boolean) => void>(() => {})

export const DialogActionButton = ({
  label,
  setDisabledRef,
  'data-test': dataTest,
}: {
  label: string
  setDisabledRef: SetDisabledRef
  'data-test'?: string
}) => {
  const [disabled, setDisabled] = useState(true)

  useEffect(() => {
    setDisabledRef.current = setDisabled
  }, [setDisabledRef])

  return (
    <Button disabled={disabled} type="submit" data-test={dataTest}>
      {label}
    </Button>
  )
}
