import { colors } from 'lago-configs/tailwind'

/**
 * In primary, secondary, info, success, warning and error color set
 * Colors '600 === main' and '800 === dark' as well
 * MUI needs to know the main and dark
 * But to avoid any confusion we also kept 600 & 800 as it is used in Figma
 */
export const palette = {
  common: {
    black: '#000',
    white: '#fff',
  },
  primary: {
    ...colors.blue,
    main: colors.blue[600],
    dark: colors.blue[800],
  },
  secondary: {
    ...colors.yellow,
    main: colors.yellow[600],
    dark: colors.yellow[800],
  },
  info: {
    ...colors.purple,
    main: colors.purple[600],
    dark: colors.purple[800],
  },
  success: {
    ...colors.green,
    main: colors.green[600],
    dark: colors.green[800],
  },
  warning: {
    ...colors.yellow,
    main: colors.yellow[600],
    dark: colors.yellow[800],
  },
  error: {
    ...colors.red,
    main: colors.red[600],
    dark: colors.red[800],
  },
  grey: colors.grey,
  background: {
    default: '#fff',
    paper: '#fff',
  },
  text: {
    primary: colors.grey[600],
    secondary: colors.grey[700],
    disabled: colors.grey[500],
  },
  divider: colors.grey[300],
}
