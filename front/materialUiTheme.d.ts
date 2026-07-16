/* eslint-disable */
import { Theme } from '@material-ui/core/styles/createMuiTheme'

declare module '@mui/material/styles' {
  interface PaletteColor {
    100: string
    200: string
    300: string
    400: string
    500: string
    600: string
    700: string
    800: string
  }

  interface SimplePaletteColorOptions {
    100: string
    200: string
    300: string
    400: string
    500: string
    600: string
    700: string
    800: string
  }

  interface ZIndex {
    toast: number
    tooltip: number
    dialog: number
    navBar: number
    popper: number
    drawer: number
    sectionHead: number
  }

  interface ZIndexOptions {
    toast: number
    tooltip: number
    dialog: number
    navBar: number
    popper: number
    drawer: number
    sectionHead: number
  }

  interface TypographyVariants {
    headline: React.CSSProperties
    subhead1: React.CSSProperties
    subhead2: React.CSSProperties
    bodyHl: React.CSSProperties
    body: React.CSSProperties
    captionHl: React.CSSProperties
    captionCode: React.CSSProperties
    button: React.CSSProperties
    note: React.CSSProperties
    noteHl: React.CSSProperties
    button: React.CSSProperties
    caption: React.CSSProperties
  }

  // allow configuration using `createTheme`
  interface TypographyVariantsOptions {
    headline: React.CSSProperties
    subhead1: React.CSSProperties
    subhead2: React.CSSProperties
    bodyHl: React.CSSProperties
    body: React.CSSProperties
    captionHl: React.CSSProperties
    captionCode: React.CSSProperties
    button: React.CSSProperties
    note: React.CSSProperties
    noteHl: React.CSSProperties
    button: React.CSSProperties
    caption: React.CSSProperties
  }
}

declare module '@mui/material/styles/zIndex' {
  interface ZIndex {
    toast: number
    tooltip: number
    dialog: number
    navBar: number
    popper: number
    drawer: number
    sectionHead: number
  }

  interface ZIndexOptions {
    toast: number
    tooltip: number
    dialog: number
    navBar: number
    popper: number
    drawer: number
    sectionHead: number
  }
}

declare module '@mui/material/Typography' {
  interface TypographyPropsVariantOverrides {
    headline: true
    subhead1: true
    subhead2: true
    bodyHl: true
    body: true
    captionHl: true
    captionCode: true
    button: true
    note: true
    noteHl: true
    button: true
    h1: false
    h2: false
    h3: false
    h4: false
    h5: false
    h6: false
    subtitle1: false
    subtitle2: false
    body1: false
    body2: false
    caption: true
    overline: false
  }
}
