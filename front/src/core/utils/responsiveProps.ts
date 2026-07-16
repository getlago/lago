import { theme } from '~/styles'

type Breakpoint = keyof typeof theme.breakpoints.values
type BreakpointWithDefault = Breakpoint | 'default'

export type ResponsiveStyleValue<T extends string | number> =
  T | Partial<Record<BreakpointWithDefault, T | undefined>>

export const setResponsiveProperty = <T extends string | number>(
  cssProperty: keyof CSSStyleDeclaration,
  value: ResponsiveStyleValue<T>,
) => {
  if (typeof value === 'object') {
    const defaultValue = value.default
    const breakpoints = Object.keys(value) as BreakpointWithDefault[]

    const responsiveCssProperties = breakpoints.reduce((curr, breakpoint) => {
      if (breakpoint === 'default') return curr

      return {
        ...curr,

        [theme.breakpoints.up(breakpoint)]: {
          [cssProperty]: !!value[breakpoint] ? `${value[breakpoint]}px` : `${defaultValue}px`,
        },
      }
    }, {})

    return {
      ...responsiveCssProperties,
      [cssProperty]: `${defaultValue}px`,
    }
  }

  return {
    [cssProperty]: `${value}px`,
  }
}
