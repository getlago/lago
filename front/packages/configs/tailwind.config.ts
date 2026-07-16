import plugin from 'tailwindcss/plugin'
import { Config } from 'tailwindcss/types/config'

export const colors = {
  grey: {
    100: '#F3F4F6',
    200: '#E7EAEE',
    300: '#D9DEE7',
    400: '#C3C9D5',
    500: '#8C95A6',
    600: '#66758F',
    700: '#19212E',
  },
  blue: {
    100: '#DEECFF',
    200: '#B3D4FF',
    300: '#4C9AFF',
    400: '#2684FF',
    500: '#267DFF',
    600: '#006CFA',
    700: '#005FDB',
    800: '#0050B8',
  },
  yellow: {
    100: '#FFF7E6',
    200: '#FFF0B3',
    300: '#FFE380',
    400: '#FFC400',
    500: '#FFAB00',
    600: '#FF7E1D',
    700: '#F06700',
    800: '#CC5800',
  },
  purple: {
    100: '#EAE6FF',
    200: '#C9C1F5',
    300: '#AEA2F1',
    400: '#8272DF',
    500: '#5D48D5',
    600: '#422CC1',
    700: '#332296',
    800: '#2A1C7D',
  },
  green: {
    100: '#E3FCF4',
    200: '#ABF5DC',
    300: '#79F2CA',
    400: '#65DCB4',
    500: '#36B389',
    600: '#008559',
    700: '#006644',
    800: '#005236',
  },
  red: {
    100: '#FFEBE6',
    200: '#FFBDAD',
    300: '#FF8F73',
    400: '#FF7C5C',
    500: '#F6491E',
    600: '#DC3309',
    700: '#BA2B08',
    800: '#9D2507',
  },
  avatar: {
    orange: '#FF9351',
    brown: '#D59993',
    green: '#66DD93',
    turquoise: '#6FD8C1',
    blue: '#2FC1FE',
    indigo: '#5195FF',
    grey: '#889ABF',
    pink: '#FF9BE0',
  },
}

const config: Config = {
  content: ['./src/**/*.{ts,tsx,html}'],
  theme: {
    colors: {
      grey: {
        ...colors.grey,
        DEFAULT: colors.grey[700],
      },
      blue: {
        ...colors.blue,
        DEFAULT: colors.blue[600],
      },
      yellow: {
        ...colors.yellow,
        DEFAULT: colors.yellow[600],
      },
      purple: {
        ...colors.purple,
        DEFAULT: colors.purple[600],
      },
      green: {
        ...colors.green,
        DEFAULT: colors.green[600],
      },
      red: {
        ...colors.red,
        DEFAULT: colors.red[600],
      },
      avatar: colors.avatar,
      black: '#000000',
      white: '#FFFFFF',
      inherit: 'inherit',
    },
    boxShadow: {
      none: 'none',
      sm: '0px 2px 4px 0px rgba(25, 33, 46, 0.20)',
      md: '0px 6px 8px 0px rgba(25, 33, 46, 0.12)',
      lg: '0px 10px 16px 0px rgba(25, 33, 46, 0.10)',
      xl: '0px 16px 24px 0px rgba(25, 33, 46, 0.10)',
    },
    fontFamily: {
      sans: ['Inter', 'Arial', 'Verdana', 'Helvetica', 'sans-serif'],
      email: ['Helvetica', 'Arial', 'sans-serif'],
      code: ['IBM Plex Mono', 'Consolas', 'Monaco', 'Andale Mono', 'Ubuntu Mono', 'monospace'],
    },
    container: {
      center: false,
      padding: {
        DEFAULT: '1rem',
        md: '3rem',
      },
      screens: {
        md: '776px',
      },
    },

    extend: {
      fontSize: {
        '4xl': ['2rem', '2.5rem'],
      },
      screens: {
        md: '776px',
      },
      transitionDuration: {
        '250': '250ms',
      },
      spacing: {
        7: '1.75rem',
        13: '3.25rem',
        15: '3.75rem',
        17: '4.25rem',
        18: '4.5rem',
        22: '5.5rem',
        23: '5.75rem',
        25: '6.25rem',
        26: '6.5rem',
        29: '7.25rem',
        30: '7.5rem',
        31: '7.75rem',
        34: '8.5rem',
        35: '8.75rem',
        37: '9.25rem',
        38: '9.5rem',
        42: '10.5rem',
        45: '11.25rem',
        50: '12.5rem',
        55: '13.75rem',
        57: '14.25rem',
        58: '14.5rem',
        64: '16rem',
        66: '16.5rem',
        70: '17.5rem',
        74: '18.5rem',
        75: '18.75rem',
        76: '19rem',
        78: '19.5rem',
        89: '22.25rem',
        90: '22.5rem',
        98: '24.5rem',
        100: '25rem',
        104: '26rem',
        110: '27.5rem',
        120: '30rem',
        124: '31rem',
        144: '36rem',
        150: '37.5rem',
        164: '41rem',
        168: '42rem',
        170: '42.5rem',
        180: '45rem',
        192: '48rem',
        footer: '4rem',
        nav: '4rem',
        formMainPadding: '3rem',
      },
      zIndex: {
        tooltip: '2400',
        toast: '2200',
        dialog: '2000',
        console: '1900',
        popper: '1800',
        drawer: '1600',
        sideNav: '1500',
        navBar: '1200',
        sectionHead: '1000',
      },
      keyframes: {
        enter: {
          '0%': { transform: 'translateX(-120%)' },
          '100%': { transform: 'translateX(0)' },
        },

        pulseSpeed: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
      },
      animation: {
        enter: 'enter 250ms cubic-bezier(0.4, 0, 0.2, 1) 1',
        'pulse-speed': 'pulseSpeed 500ms ease-out infinite',
      },
    },
  },
  plugins: [
    plugin(function ({ addUtilities, addVariant, addComponents, theme }) {
      /**
       * Utilities
       */
      // Dividers
      addUtilities({
        '.shadow-t': {
          boxShadow: `0px 1px 0px 0px ${theme('colors.grey.300')} inset`,
        },

        '.shadow-r': {
          boxShadow: `-1px 0px 0px 0px ${theme('colors.grey.300')} inset`,
        },

        '.shadow-b': {
          boxShadow: `0px -1px 0px 0px ${theme('colors.grey.300')} inset`,
        },

        '.shadow-l': {
          boxShadow: `1px 0px 0px 0px ${theme('colors.grey.300')} inset`,
        },
        '.shadow-y': {
          boxShadow: `0px 1px 0px 0px ${theme('colors.grey.300')} inset, 0px -1px 0px 0px ${theme('colors.grey.300')} inset`,
        },
      })

      // Animation
      addUtilities({
        '.animate-shadow-left': {
          '@supports (animation-timeline: scroll(inline))': {
            animationName: 'shadowLeft',
            animationDuration: '1s',
            animationTimingFunction: 'ease-in-out',
            animationTimeline: 'scroll(inline)',
          },

          '@keyframes shadowLeft': {
            '0%': { boxShadow: `1px 0px 0px 0px ${theme('colors.grey.300')} inset` },
            '90%': { boxShadow: `1px 0px 0px 0px ${theme('colors.grey.300')} inset` },
            '99%': { boxShadow: 'none' },
          },
        },

        '.animate-shadow-top': {
          '@supports (animation-timeline: scroll(block))': {
            animationName: 'shadowTop',
            animationDuration: '1s',
            animationTimingFunction: 'ease-in-out',
            animationTimeline: 'scroll(block)',
          },

          '@keyframes shadowTop': {
            '0%': { boxShadow: `0px 1px 0px 0px ${theme('colors.grey.300')} inset` },
            '90%': { boxShadow: `0px 1px 0px 0px ${theme('colors.grey.300')} inset` },
            '99%': { boxShadow: 'none' },
          },
        },

        '.animate-shadow-bottom': {
          '@supports (animation-timeline: scroll(block))': {
            animationName: 'shadowBottom',
            animationDuration: '1s',
            animationTimingFunction: 'ease-in-out',
            animationTimeline: 'scroll(block)',
          },

          '@keyframes shadowBottom': {
            '1%': { boxShadow: 'none' },
            '10%': { boxShadow: `0px -1px 0px 0px ${theme('colors.grey.300')} inset` },
            '100%': { boxShadow: `0px -1px 0px 0px ${theme('colors.grey.300')} inset` },
          },
        },
      })

      // Outline ring
      addUtilities({
        '.ring': {
          outline: 'none',
          boxShadow: `0px 0px 0px 4px ${theme('colors.blue.200')} var(--tw-ring-inset)`,
        },
      })
      // Line break anywhere
      addUtilities({
        '.line-break-anywhere': {
          lineBreak: 'anywhere',
        },
        '.line-break-auto': {
          lineBreak: 'auto',
        },
      })

      // Remove scrollbar indicator
      addUtilities({
        '.no-scrollbar::-webkit-scrollbar': {
          display: 'none', // Chrome, Safari and Opera
        },
        '.no-scrollbar': {
          '-ms-overflow-style': 'none', // IE and Edge
          'scrollbar-width': 'none', // Firefox
        },
      })

      addUtilities({
        '.rotate-90-tl': {
          transform: 'rotate(90deg) translate(0%, -100%)',
          transformOrigin: 'top left',
        },
      })

      /**
       * Variants
       */
      // Focus not active
      addVariant('focus-not-active', '&:focus:not(:active)')
      // Hover not active
      addVariant('hover-not-active', '&:hover:not(:active)')
      // Not first child
      addVariant('not-first-child', '&>*:not(:first-child)')
      // Not first element
      addVariant('not-first', '&:not(:first-child)')
      // Not last child
      addVariant('not-last-child', '&>*:not(:last-child)')
      // Not last element
      addVariant('not-last', '&:not(:last-child)')
      // Children selector
      addVariant('first-child', '&>*:first-child')
      addVariant('last-child', '&>*:last-child')

      /**
       * Components
       */
      addComponents({
        '.height-minus-nav': {
          height: `calc(100vh - ${theme('spacing.nav')})`,
        },
        '.min-height-minus-nav': {
          minHeight: `calc(100vh - ${theme('spacing.nav')})`,
        },
        '.height-minus-nav-footer': {
          height: `calc(100vh - ${theme('spacing.nav')} - ${theme('spacing.footer')})`,
        },
        '.min-height-minus-nav-footer-formMainPadding': {
          minHeight: `calc(100vh - ${theme('spacing.nav')} - ${theme('spacing.footer')} - ${theme('spacing.formMainPadding')})`,
        },
        '.height-minus-footer': {
          height: `calc(100vh - ${theme('spacing.footer')})`,
        },
        '.remove-child-link-style': {
          a: {
            width: '100%',

            '&:focus, &:active, &:hover': {
              outline: 'none',
              textDecoration: 'none',
            },
          },
        },
        '.word-break-word': {
          wordBreak: 'break-word',
        },
        '.overflow-wrap-anywhere': {
          overflowWrap: 'anywhere',
        },
      })
    }),
  ],
}

export default config
