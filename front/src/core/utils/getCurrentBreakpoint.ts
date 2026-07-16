import tailwindConfig from 'lago-configs/tailwind'
import resolveConfig from 'tailwindcss/resolveConfig'

const fullConfig = resolveConfig(tailwindConfig)

type BreakpointKey = keyof typeof fullConfig.theme.screens

const getBreakpointValue = (value: BreakpointKey): number => {
  const breakpointString = fullConfig.theme.screens[value]
  const pxIndex = breakpointString.indexOf('px')
  const numericValue = breakpointString.slice(0, pxIndex)

  return Number(numericValue)
}

export const getCurrentBreakpoint = (): BreakpointKey => {
  let currentBreakpoint: BreakpointKey = 'sm'
  let biggestBreakpointValue = 0

  for (const breakpoint of Object.keys(fullConfig.theme.screens) as BreakpointKey[]) {
    const breakpointValue = getBreakpointValue(breakpoint)

    if (breakpointValue > biggestBreakpointValue && window.innerWidth >= breakpointValue) {
      biggestBreakpointValue = breakpointValue
      currentBreakpoint = breakpoint
    }
  }

  return currentBreakpoint
}
