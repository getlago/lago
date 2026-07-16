import { alpha, createTheme } from '@mui/material/styles'
import type {} from '@mui/x-date-pickers/themeAugmentation'

import { palette } from './colorsPalette'

const ITEM_HEIGHT = 56

export const NAV_HEIGHT = 64
const BREAKPOINT_LG = 1024

const typographyBody = {
  fontSize: '16px',
  lineHeight: '24px',
  letterSpacing: '-0.16px',
  fontWeight: 400,
}

const typographyCaption = {
  fontSize: '14px',
  lineHeight: '24px',
  letterSpacing: '-0.16px',
  fontWeight: 400,
}

export const theme = createTheme({
  spacing: 4, // Base 4 --> [0, 4, 8, 12, 16...], only following indexes are authorized: 1,2,3,4,5,6,8,10,12
  palette,
  breakpoints: {
    // There's only one real breakpoint, so only use md
    values: {
      xs: 0,
      sm: 0,
      md: 776,
      lg: BREAKPOINT_LG,
      xl: 1600,
    },
  },
  shape: {
    borderRadius: 12, // Default is 4 but can be 12px
  },
  components: {
    MuiButtonBase: {
      defaultProps: {
        disableRipple: true,
        disableTouchRipple: true,
      },
    },
    MuiPickersArrowSwitcher: {
      styleOverrides: {
        spacer: {
          width: '24px',
        },
        button: {
          width: '40px',
          height: '40px',
          borderRadius: '8px',
        },
      },
    },
    MuiPopper: {
      styleOverrides: {
        root: {
          // Make sure if a date picker is displayed in a popper that it is above all content
          '&.MuiPickersPopper-root': {
            zIndex: 2000,
          },
          '.MuiDateCalendar-viewTransitionContainer': {
            minHeight: '304px',

            '> *:first-of-type': {
              overflow: 'hidden',
            },
          },
          '.MuiDateCalendar-root,.PrivatePickersSlideTransition-root,.MuiPaper-root > div > div:first-of-type':
            {
              overflowX: 'visible',
            },
          '.MuiPickersCalendarHeader-root': {
            margin: '6px 0 16px 0',
            padding: '0 6px 0',
            minHeight: 'unset',
            maxHeight: 'fit-content',
          },
          '.MuiPickersCalendarHeader-label': {
            color: palette.grey[700],
            fontSize: '16px',
            lineHeight: '24px',
            letterSpacing: '-0.16px',
            fontWeight: 400,
          },
          '.custom-date-picker-header': {
            marginTop: '6px',
            marginBottom: '16px',
            padding: '0px 6px 0px',
          },

          '.custom-date-picker-day': {
            borderRadius: '12px',
            color: palette.grey[600],
            height: '40px',
            width: '40px',
            margin: '0px',
            fontSize: '16px',
            lineHeight: '24px',
            letterSpacing: '-0.16px',
            fontWeight: 400,

            '&:focus': {
              backgroundColor: 'white',
              boxShadow: 'rgb(179, 212, 255) 0px 0px 0px 4px',

              '&.Mui-selected': {
                backgroundColor: `${palette.primary[600]} !important`,
              },
            },
            '&.Mui-disabled': {
              color: `${palette.grey[400]} !important`,
            },
          },
          '.MuiDayCalendar-header': {
            justifyContent: 'space-between',
          },
          '.MuiDayCalendar-monthContainer': {
            padding: '4px',
          },
          '.MuiDayCalendar-slideTransition': {
            minHeight: '248px',
          },
          '.MuiDayCalendar-weekContainer': {
            justifyContent: 'space-between',
            padding: 0,
            margin: 0,
          },
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          height: 'fit-content',
          width: 'fit-content',
          borderRadius: '8px',
          minHeight: '32px',
          padding: '0px 8px',
          fontSize: '14px',
          lineHeight: '24px',
          letterSpacing: '-0.16px',
          fontWeight: 500,
          outline: `1px solid ${palette.grey[300]}`,
          outlineOffset: '-1px',
          '&.chip-size--small': {
            minHeight: '20px',
            padding: '0px 4px',
          },
          '&.chip-size--big': {
            minHeight: '40px',
            padding: '0px 12px',
          },
          '&.chip--error': {
            backgroundColor: palette.error[100],
            outline: `1px solid ${palette.error[300]}`,
            color: palette.error[600],
            path: {
              fill: palette.error[600],
            },
          },
        },
        filled: {
          backgroundColor: palette.grey[100],
        },
        outlined: {
          backgroundColor: palette.common.white,
        },
        label: {
          padding: '0px',
          margin: '0px',
        },
        deleteIcon: {
          width: '20px',
          height: '20px',
          margin: '6px 0 6px 8px',
        },
      },
    },
    MuiLink: {
      defaultProps: {
        color: 'primary',
      },
      styleOverrides: {
        root: {
          '&.Mui-focusVisible': {
            boxShadow: `0px 0px 0px 4px ${palette.primary[200]}`,
            borderRadius: 4,
            outline: 'none',
          },
          '&:visited': {
            color: palette.info.main,
          },
        },
      },
    },
    MuiInputBase: {
      styleOverrides: {
        input: {
          textOverflow: 'ellipsis',
          overflow: 'hidden',
          whiteSpace: 'nowrap',
        },
      },
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: {
          transition:
            'background-color 250ms cubic-bezier(0.4, 0, 0.2, 1) 0ms,border 250ms cubic-bezier(0.4, 0, 0.2, 1) 0ms',
          '&:hover:not(.Mui-focused)': {
            backgroundColor: palette.grey[100],
          },
          '&.Mui-focused': {
            outline: 'none',
            boxShadow: `0px 0px 0px 4px ${palette.primary[200]} !important`,
          },
          '&.Mui-disabled': {
            backgroundColor: palette.grey[100],
            '& .MuiOutlinedInput-notchedOutline': {
              borderColor: palette.grey[300],
            },
            '& input': {
              color: palette.grey[600],
              WebkitTextFillColor: 'inherit',
            },
            '.MuiInputAdornment-root, .MuiInputAdornment-root > *': {
              color: palette.grey[400],
            },
          },
          '& .MuiInputAdornment-positionStart': {
            paddingLeft: '16px',
          },
          '& .MuiInputBase-inputAdornedStart': {
            paddingLeft: '8px',
            borderRadius: '0 12px 12px 0',
          },
          '& .MuiInputBase-inputAdornedEnd': {
            paddingRight: '0px !important',
            borderRadius: '12px 0 0 12px !important',
          },
          '.MuiInputAdornment-positionEnd': {
            marginRight: '16px',
          },
        },
        adornedEnd: {
          paddingRight: 0,
          '& .MuiButton-root': {
            '& svg': {
              padding: '0',
            },
          },
          '& .MuiInputAdornment-positionEnd': {
            '& svg': {
              padding: '0 0 0 0',
            },
          },
        },
        adornedStart: {
          paddingLeft: '0',
          '& .MuiInputAdornment-positionStart': {
            marginRight: '0',
          },
          '& .MuiButton-root': {
            marginLeft: '4px',
            '& svg': {
              padding: '0',
            },
          },
          '& .MuiInputAdornment-positionStart svg': {
            padding: '0 12px 0 16px',
          },
        },
        input: {
          ...typographyBody,
          height: '48px',
          boxSizing: 'border-box',
          padding: '10px 16px !important',
          color: palette.grey[700],
          borderRadius: '12px',
          '&::placeholder': {
            color: palette.grey[500],
            opacity: 1,
          },
          '&.Mui-disabled': {
            backgroundColor: palette.grey[100],
            borderRadius: 12,
            color: palette.grey[600],
            '&::placeholder': {
              color: palette.grey[400],
            },
          },
        },
        multiline: {
          padding: '5px',
          textarea: {
            padding: '5px 11px',
            minHeight: '38px',
            resize: 'vertical',
            whiteSpace: 'pre-wrap',
          },
          '&.Mui-disabled': {
            backgroundColor: palette.grey[100],
            borderRadius: 12,
            '&::placeholder': {
              color: palette.grey[400],
            },
          },
        },
        notchedOutline: {
          borderColor: palette.grey[500],
          borderWidth: '1px !important',
          '&:hover': {
            borderColor: palette.grey[600],
          },
          '&:focus, &:active': {
            borderColor: palette.primary.main,
          },
        },
      },
    },
    MuiTabs: {
      styleOverrides: {
        indicator: {
          /* We hide the default MUI selected tab indicator. It's manually handled by us bellow */
          display: 'none',
        },
        flexContainer: {
          overflow: 'visible',
          gap: '8px',
        },
        scroller: {
          overflowY: 'auto',
          height: 'min-content',
          paddingLeft: '16px',
          paddingRight: '16px',
          marginLeft: '-16px',
          marginRight: '-16px',
        },
      },
    },
    MuiTab: {
      styleOverrides: {
        root: {
          '&.Mui-focusVisible': {
            outline: `4px solid ${palette.primary[100]}`,
          },
          '&.Mui-selected': {
            // Color have to be important to override the TW color definition in the component
            color: `${palette.primary.main} !important`,

            '&::after': {
              content: '""',
              display: 'block',
              height: '2px',
              backgroundColor: palette.primary.main,
              width: 'calc(100% - 16px)',
              position: 'absolute',
              bottom: '-8px',
            },
          },
          '&.Mui-disabled': {
            color: palette.grey[400],
          },
        },
      },
    },
    MuiTooltip: {
      styleOverrides: {
        tooltip: {
          ...typographyCaption,
          backgroundColor: palette.grey[700],
          padding: '12px 16px',
        },
        // MUI positions poppers using CSS, per position
        // !important is ugly, but required
        tooltipPlacementBottom: {
          marginTop: '8px !important',
        },
        tooltipPlacementTop: {
          marginBottom: '8px !important',
        },
        tooltipPlacementLeft: {
          marginRight: '8px !important',
        },
        tooltipPlacementRight: {
          marginLeft: '8px !important',
        },
      },
    },
    MuiAccordion: {
      styleOverrides: {
        root: {
          '&::before': {
            height: 0,
          },
          '&.MuiPaper-root': {
            backgroundColor: 'transparent',
            borderRadius: '12px',
          },
          '&.Mui-expanded': {
            margin: '0',
            minHeight: 'auto',
          },
          '&.MuiPaper-elevation1': {
            boxShadow: 'none',
          },
        },
      },
    },
    MuiAccordionSummary: {
      styleOverrides: {
        root: {
          overflow: 'inherit',
          minHeight: 'auto',
          padding: '0',

          '&.Mui-expanded': {
            minHeight: 'auto',
          },
        },
        content: {
          width: '100%',
          margin: '0 !important',
          display: 'flex',
          alignItems: 'center',
        },
      },
    },
    MuiAccordionDetails: {
      styleOverrides: {
        root: {
          padding: '0',
        },
      },
    },
    MuiAutocomplete: {
      styleOverrides: {
        paper: {
          padding: '8px important',
          overflow: 'auto',
          maxHeight: 320,
          scrollBehavior: 'smooth',
        },
        loading: { padding: 0 },
        listbox: {
          display: 'flex',
          flexDirection: 'column',
          maxHeight: 'inherit',
          padding: 0,
          gap: '4px',
        },
        root: {
          '.MuiOutlinedInput-root': {
            padding: '0 0 0 0 !important',
            '&.Mui-disabled': {
              backgroundColor: palette.grey[100],

              '.MuiInputAdornment-root': {
                color: palette.grey[400],
              },
            },
          },
          '.MuiAutocomplete-paper': {
            border: `1px solid ${palette.grey[200]}`,
            boxSizing: 'content-box',
          },
        },
        popupIndicator: {
          backgroundColor: 'transparent',
          cursor: 'pointer',
        },
        clearIndicator: {
          backgroundColor: 'transparent',
          cursor: 'pointer',
        },
        option: {
          borderRadius: '12px',
          height: 'auto',
          minHeight: `${ITEM_HEIGHT}px !important`,
          width: '100% !important',
          margin: '0 8px',
          '&.Mui-focused': {
            backgroundColor: `${palette.grey[100]} !important`,
          },
          '&[aria-selected="true"]': {
            backgroundColor: `${palette.primary[100]} !important`,
            '&[aria-disabled="true"]': {
              opacity: '1 !important',
            },
            '&.Mui-focused': {
              backgroundColor: `${palette.primary[200]} !important`,
            },
          },
        },
        noOptions: {
          color: palette.grey[500],
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          height: '40px',
          minWidth: '80px',
          padding: '6px 12px',
          fontSize: '16px',
          '&.button-icon-only': {
            padding: '12px',
            minWidth: 'unset',
            width: '40px',
          },
          '&:active': {
            transform: 'scale(0.99)',
          },
          '&.button-inline': {
            height: 'auto',
            minWidth: 'unset',
            padding: '0px',
          },
          '&.Mui-disabled': {
            backgroundColor: palette.grey[100],
            color: palette.grey[400],
          },
        },
        endIcon: {
          marginLeft: '8px',
          marginRight: 0,
        },
        startIcon: {
          marginLeft: 0,
          marginRight: '8px',
        },
        sizeSmall: {
          height: '32px',
          padding: '10px 12px',
          borderRadius: '8px',
          // Caption
          fontSize: '14px',
          fontWeight: 400,
          lineHeight: '24px',
          letterSpacing: '-0.16px',
          '&.button-icon-only': {
            width: '24px',
            height: '24px',
          },
          '.MuiButton-endIcon': {
            marginLeft: '8px',
          },
          '.MuiButton-startIcon': {
            marginRight: '8px',
          },
        },
        sizeLarge: {
          height: '48px',
          padding: '10px 12px',
          '&.button-icon-only': {
            padding: '12px',
            minWidth: 'unset',
            width: '48px',
          },
        },
        fullWidth: {
          '&:active': {
            transform: 'scale(0.999)',
          },
        },
        text: {
          padding: '6px 12px',
          '&.MuiButton-root.Mui-focusVisible': {
            boxShadow: `0px 0px 0px 4px ${palette.primary[200]}`,
            outline: 'none',
          },
          color: palette.grey[600],
          '&:hover': {
            backgroundColor: palette.grey[200],
          },
          '&:active': {
            backgroundColor: palette.grey[300],
          },
          '&.button-danger': {
            '&:hover': {
              backgroundColor: palette.error[100],
            },
            '&:active': {
              backgroundColor: palette.error[200],
            },
            '&$disabled': {
              color: palette.grey[400],
            },
            color: palette.error.main,
          },
          '&.button-quaternary-light': {
            color: palette.common.white,
            '&:hover': {
              backgroundColor: alpha(palette.grey[100], 0.1),
            },
            '&:active': {
              backgroundColor: alpha(palette.grey[100], 0.2),
            },
          },
          '&.button-quaternary-dark': {
            color: palette.grey[700],
            '&:hover': {
              backgroundColor: alpha(palette.grey[700], 0.1),
            },
            '&:active': {
              backgroundColor: alpha(palette.grey[700], 0.2),
            },
          },
          '&.button-inline': {
            position: 'relative',
            color: palette.primary.main,
            backgroundColor: 'transparent',
            '&:hover': {
              color: palette.primary[700],
            },

            '&:active': {
              color: palette.primary[800],
            },

            '&:focus-visible': {
              boxShadow: 'none',

              '&::before': {
                content: '""',
                display: 'block',
                width: '100%',
                height: '4px',
                backgroundColor: palette.primary[200],
                position: 'absolute',
                left: 0,
                bottom: '-4px',
              },
            },

            '&.button-danger': {
              backgroundColor: 'transparent',
              color: palette.error.main,

              '&:hover': {
                color: palette.error[700],
              },

              '&:active': {
                color: palette.error[700],
              },
            },
          },
          '&.Mui-disabled': {
            backgroundColor: 'transparent',
            color: palette.grey[400],
          },
          '&$disabled': {
            color: palette.grey[400],
            backgroundColor: 'transparent',
          },
        },
        outlined: {
          padding: '5px 11px',
          color: palette.grey[600],
          '&.MuiButton-root.Mui-focusVisible': {
            boxShadow: `0px 0px 0px 4px ${palette.primary[200]}`,
            outline: 'none',
          },
          border: `1px solid ${palette.grey[500]}`,
          '&:hover': {
            backgroundColor: palette.grey[200],
          },
          '&:active': {
            backgroundColor: palette.grey[300],
          },
          '&$disabled': {
            color: palette.grey[400],
            backgroundColor: palette.grey[100],
            border: 'none',
            padding: '6px 12px',
          },
          '&.button-danger': {
            '&:hover': {
              backgroundColor: palette.error[100],
            },
            '&:active': {
              backgroundColor: palette.error[200],
            },
            '&$disabled': {
              color: palette.grey[400],
              backgroundColor: palette.grey[100],
              border: 'none',
            },
            color: palette.error.main,
            border: `1px solid ${palette.error[500]}`,
          },
        },
        contained: {
          '&.MuiButton-root.Mui-focusVisible': {
            boxShadow: `0px 0px 0px 4px ${palette.primary[200]}`,
            outline: 'none',
          },
          color: palette.primary.main,
          backgroundColor: palette.grey[200],
          '&:hover': {
            backgroundColor: palette.grey[300],
          },
          '&:active': {
            backgroundColor: palette.grey[400],
          },
          '&.button-danger': {
            color: palette.error.main,
            backgroundColor: palette.error[100],
            '&:hover': {
              backgroundColor: palette.error[200],
            },
            '&:active': {
              backgroundColor: palette.error[300],
            },
            '&.Mui-disabled': {
              color: palette.grey[400],
              backgroundColor: palette.grey[100],
            },
          },
          '&$disabled &.Mui-disabled': {
            color: palette.grey[400],
            backgroundColor: palette.grey[100],
          },
        },
        containedPrimary: {
          color: palette.common.white,
          backgroundColor: palette.primary.main,
          '&:hover': {
            backgroundColor: palette.primary[700],
          },
          '&:active': {
            backgroundColor: palette.primary[800],
          },
          '&.button-danger': {
            '&:hover': {
              backgroundColor: palette.error[700],
            },
            '&:active': {
              backgroundColor: palette.error[800],
            },
            '&$disabled': {
              color: palette.grey[400],
              backgroundColor: palette.grey[100],
            },
            color: palette.common.white,
            backgroundColor: palette.error.main,
          },
          '&$disabled': {
            color: palette.grey[400],
            backgroundColor: palette.grey[100],
          },
        },
      },
    },
  },
  typography: {
    fontFamily: 'Inter, Arial , Verdana , Helvetica , sans-serif',
    headline: {
      fontSize: '24px',
      lineHeight: '32px',
      letterSpacing: '-0.40px',
      fontWeight: 600,
    },
    h1: undefined,
    subhead1: {
      fontSize: '18px',
      lineHeight: '24px',
      letterSpacing: '-0.40px',
      fontWeight: 600,
    },
    subhead2: {
      fontSize: '16px',
      lineHeight: '24px',
      letterSpacing: '-0.40px',
      fontWeight: 600,
    },
    captionCode: {
      fontFamily: 'IBM Plex Mono, monospace',
      fontWeight: 400,
      fontSize: '14px',
      lineHeight: '24px',
    },
    h2: undefined,
    bodyHl: {
      fontSize: '16px',
      lineHeight: '24px',
      letterSpacing: '-0.16px',
      fontWeight: 500,
    },
    body2: undefined,
    body: {
      ...typographyBody,
    },
    body1: undefined,
    captionHl: {
      fontSize: '14px',
      lineHeight: '24px',
      letterSpacing: '-0.16px',
      fontWeight: 500,
    },
    subtitle1: undefined,
    caption: {
      ...typographyCaption,
    },
    note: {
      fontSize: '12px',
      lineHeight: '16px',
      fontWeight: 400,
      letterSpacing: '-0.16px',
      textTransform: 'none',
    },
    noteHl: {
      fontSize: '12px',
      lineHeight: '16px',
      letterSpacing: '-0.16px',
      fontWeight: 500,
      textTransform: 'none',
    },
    overline: undefined,
    button: {
      fontSize: '16px',
      lineHeight: '24px',
      letterSpacing: '-0.16px',
      fontWeight: 400,
      textTransform: 'none',
    },
  },
  zIndex: {
    tooltip: 2400,
    toast: 2200,
    dialog: 2000,
    popper: 1800,
    drawer: 1600,
    navBar: 1200,
    sectionHead: 1000,
  },
  shadows: [
    'none',
    '0px 2px 4px 0px rgba(25, 33, 46, 0.2)',
    '0px 6px 8px 0px rgba(25, 33, 46, 0.12)',
    '0px 10px 16px 0px rgba(25, 33, 46, 0.1)',
    '0px 16px 24px 0px rgba(25, 33, 46, 0.1)',
    // Next one (shadows[5]) is only used as top divider
    `0px 1px 0px 0px ${palette.divider} inset`,
    // Next one (shadows[6]) is only used as right divider
    `-1px 0px 0px 0px ${palette.divider} inset`,
    // Next one (shadows[7]) is only used as bottom divider
    `0px -1px 0px 0px ${palette.divider} inset`,
    // Next one (shadows[8]) is only used as left divider
    `1px 0px 0px 0px ${palette.divider} inset`,
    // The following are not used but needs to be set for MUI - Those are the default values
    '0px 3px 5px -1px rgba(0,0,0,0.2),0px 6px 10px 0px rgba(0,0,0,0.14),0px 1px 18px 0px rgba(0,0,0,0.12)',
    '0px 4px 5px -2px rgba(0,0,0,0.2),0px 7px 10px 1px rgba(0,0,0,0.14),0px 2px 16px 1px rgba(0,0,0,0.12)',
    '0px 5px 5px -3px rgba(0,0,0,0.2),0px 8px 10px 1px rgba(0,0,0,0.14),0px 3px 14px 2px rgba(0,0,0,0.12)',
    '0px 5px 6px -3px rgba(0,0,0,0.2),0px 9px 12px 1px rgba(0,0,0,0.14),0px 3px 16px 2px rgba(0,0,0,0.12)',
    '0px 6px 6px -3px rgba(0,0,0,0.2),0px 10px 14px 1px rgba(0,0,0,0.14),0px 4px 18px 3px rgba(0,0,0,0.12)',
    '0px 6px 7px -4px rgba(0,0,0,0.2),0px 11px 15px 1px rgba(0,0,0,0.14),0px 4px 20px 3px rgba(0,0,0,0.12)',
    '0px 7px 8px -4px rgba(0,0,0,0.2),0px 12px 17px 2px rgba(0,0,0,0.14),0px 5px 22px 4px rgba(0,0,0,0.12)',
    '0px 7px 8px -4px rgba(0,0,0,0.2),0px 13px 19px 2px rgba(0,0,0,0.14),0px 5px 24px 4px rgba(0,0,0,0.12)',
    '0px 7px 9px -4px rgba(0,0,0,0.2),0px 14px 21px 2px rgba(0,0,0,0.14),0px 5px 26px 4px rgba(0,0,0,0.12)',
    '0px 8px 9px -5px rgba(0,0,0,0.2),0px 15px 22px 2px rgba(0,0,0,0.14),0px 6px 28px 5px rgba(0,0,0,0.12)',
    '0px 8px 10px -5px rgba(0,0,0,0.2),0px 16px 24px 2px rgba(0,0,0,0.14),0px 6px 30px 5px rgba(0,0,0,0.12)',
    '0px 8px 11px -5px rgba(0,0,0,0.2),0px 17px 26px 2px rgba(0,0,0,0.14),0px 6px 32px 5px rgba(0,0,0,0.12)',
    '0px 9px 11px -5px rgba(0,0,0,0.2),0px 18px 28px 2px rgba(0,0,0,0.14),0px 7px 34px 6px rgba(0,0,0,0.12)',
    '0px 9px 12px -6px rgba(0,0,0,0.2),0px 19px 29px 2px rgba(0,0,0,0.14),0px 7px 36px 6px rgba(0,0,0,0.12)',
    '0px 10px 13px -6px rgba(0,0,0,0.2),0px 20px 31px 3px rgba(0,0,0,0.14),0px 8px 38px 7px rgba(0,0,0,0.12)',
    '0px 10px 13px -6px rgba(0,0,0,0.2),0px 21px 33px 3px rgba(0,0,0,0.14),0px 8px 40px 7px rgba(0,0,0,0.12)',
  ],
})
