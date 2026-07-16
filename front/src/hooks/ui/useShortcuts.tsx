import { KeyboardEvent, useCallback, useEffect, useMemo, useRef } from 'react'

export interface Shortcut {
  keys: string[]
  windowsKeys?: string[] // if set, this will be used only for Windows and "keys" will be used only for Mac
  disabled?: boolean
  action: () => void
}

type CleanedShortcut = {
  keys: string[]
  action: () => void
}

type ReducedShortcut = Record<string, CleanedShortcut>

export const getCleanKey = (key: string) => {
  switch (key) {
    case 'MetaLeft':
    case 'OSLeft':
    case 'MetaRight':
    case 'Meta':
    case 'OSRight':
      return 'Cmd'
    case 'AltLeft':
    case 'AltRight':
      return 'Alt'
    case 'ControlLeft':
    case 'ControlRight':
      return 'Ctrl'
    default:
      return key
  }
}

const getShortcutId = (keys: string[]): string => {
  return keys
    .join('')
    .split('')
    .sort((a, b) => a.localeCompare(b))
    .join('')
    .toLowerCase()
}

type UseShortcutReturn = (shortcuts: Shortcut[]) => { isMac: boolean }
/**
 * --------- USE
 * const { isMac } = useShortcuts([
 *  {
 *    keys: ['Ctrl' + 'Enter'],
 *    disabled: true,
 *    action: () => console.log('This will work both for Mac and Windows')
 *  },
 *  {
 *    keys: ['Cmd' + 'L'],
 *    windowsKeys: ['Ctrl' + 'L'],
 *    action: () => console.log('Cmd + L will work on Mac | Ctrl + L will work on windows')
 *  }
 *
 * --------- NOTE
 * The keys must be the code of each key (got from event.code) except for :
 *  - ⌘ Command for Mac should be written `Cmd`
 *  - Control should always be `Ctrl`
 *  This is to avoid confusion between left and right keys (ie MetaLeft / MetaRight for Cmd)
 *
 * You can check the code here : https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/code/code_values#code_values_on_linux_x11
 */
export const useShortcuts: UseShortcutReturn = (shortcuts) => {
  const isMac = navigator.platform.toUpperCase().includes('MAC')
  const keyPressedRef = useRef<Record<string, boolean>>({})
  const usableShortcuts = useMemo(
    () =>
      shortcuts.reduce<ReducedShortcut>((acc, shortcut) => {
        if (shortcut.disabled) return acc
        // Get keys according to OS
        const keys = (!!shortcut?.windowsKeys && !isMac ? shortcut.windowsKeys : shortcut.keys).map(
          (key) => getCleanKey(key),
        )
        const shortcutId = getShortcutId(keys)

        acc[shortcutId] = { keys, action: shortcut.action }

        return acc
      }, {}),
    [shortcuts, isMac],
  )

  const onKeyDown: (e: Event) => void = useCallback(
    (e) => {
      const cleanKey = getCleanKey((e as unknown as KeyboardEvent).code)

      keyPressedRef.current[cleanKey] = true

      const pressKeysID = getShortcutId(
        Object.keys(keyPressedRef.current).filter((key) => !!keyPressedRef.current[key]),
      )

      if (!!usableShortcuts[pressKeysID]) {
        usableShortcuts[pressKeysID].action()

        // Clean after use of one shortcut to it to be recalled right away
        keyPressedRef.current = {}
      }
    },
    [usableShortcuts],
  )

  const onKeyUp: (e: Event) => void = useCallback((e) => {
    const cleanKey = getCleanKey((e as unknown as KeyboardEvent).code)

    if (keyPressedRef.current[cleanKey]) {
      keyPressedRef.current[cleanKey] = false
    }
  }, [])

  useEffect(() => {
    if (shortcuts.length < 1) return

    document.addEventListener('keydown', onKeyDown)
    document.addEventListener('keyup', onKeyUp)

    return () => {
      if (shortcuts.length < 1) return
      document.removeEventListener('keydown', onKeyDown)
      document.removeEventListener('keyup', onKeyUp)
    }
  }, [onKeyDown, onKeyUp, shortcuts])

  return {
    isMac,
  }
}
