import MuiTypography, { type TypographyProps as MuiTypographyProps } from '@mui/material/Typography'
import _isEqual from 'lodash/isEqual'
import { ElementType, memo } from 'react'
import sanitizeHtml from 'sanitize-html'

import { Link } from '~/core/router'
import { tw } from '~/styles/utils'

/**
 * Validates that a URL is safe to use as an internal link href.
 * Only allows relative paths (no protocol schemes, no protocol-relative URLs).
 */
const isSafeHref = (href: string): boolean => {
  if (!href) return false

  // Reject protocol-relative URLs (//evil.com → open redirect)
  if (href.startsWith('//')) return false

  // Allow absolute paths within the app (/customers/123)
  if (href.startsWith('/')) return true

  // Reject anything with a protocol scheme (javascript:, data:, http:, etc.)
  if (/^[a-zA-Z][a-zA-Z0-9+\-.]*:/.test(href)) return false

  // Allow relative paths (customers/123) - safe for React Router
  return true
}

const INTERNAL_LINK_PLACEHOLDER = '{{link}}'
const INTERNAL_LINK_PLACEHOLDER_HTML = `<span class="internal-link-placeholder">${INTERNAL_LINK_PLACEHOLDER}</span>`

const defaultSanitizerOptions = {
  allowedTags: ['b', 'i', 'em', 'strong', 'a', 'sup', 'span'],
  allowedAttributes: {
    a: ['href', 'target', 'rel', 'data-*'],
    '*': ['class'],
  },
  selfClosing: ['br', 'hr'],
}

const sanitize = (dirty: string, options: sanitizeHtml.IOptions | undefined) => ({
  __html: sanitizeHtml(dirty, { ...defaultSanitizerOptions, ...options }),
})

enum ColorTypeEnum {
  grey700 = 'grey.700',
  grey600 = 'grey.600',
  grey500 = 'grey.500',
  grey400 = 'grey.400',
  info600 = 'info.600',
  infoMain = 'info.main',
  purple600 = 'purple.600',
  primary600 = 'primary.600',
  danger600 = 'error.600',
  warning700 = 'warning.700',
  success600 = 'success.600',
  inherit = 'inherit',
  white = 'common.white',
  disabled = 'text.disabled', // This is to maintain the existing code
  textPrimary = 'text.primary', // This is to maintain the existing code
  textSecondary = 'text.secondary', // This is to maintain the existing code
}

export type TypographyColor = keyof typeof ColorTypeEnum
export interface TypographyProps extends Pick<
  MuiTypographyProps,
  'variant' | 'children' | 'noWrap' | 'align' | 'sx' | 'onClick'
> {
  className?: string
  component?: ElementType
  color?: TypographyColor
  html?: string
  forceBreak?: boolean
  blur?: boolean
}

const mapColor = (variant: TypographyProps['variant'], color?: TypographyColor): ColorTypeEnum => {
  if (color) return ColorTypeEnum[color]

  switch (variant) {
    case 'headline':
    case 'subhead1':
    case 'subhead2':
      return ColorTypeEnum.textSecondary
    case 'bodyHl':
    case 'body':
    case 'captionHl':
    case 'note':
    case 'noteHl':
    case 'caption':
    default:
      return ColorTypeEnum.textPrimary
  }
}

export const Typography = memo(
  ({
    variant = 'body',
    className,
    color,
    children,
    html,
    component = 'div',
    noWrap,
    forceBreak = false,
    blur = false,
    ...props
  }: TypographyProps) => {
    const getSanitizedHtml = (htmlString: string) => {
      const internalLinks: sanitizeHtml.Attributes[] = []
      const sanitizeOptions: sanitizeHtml.IOptions = {
        transformTags: {
          a: (tagName, attribs) => {
            /**
             * If there is a `data-text` attribute, we consider the link as internal
             * We have to use `data-text` in this case as we can't get the original `text` from transformTags
             */
            if (!!attribs['data-text']) {
              internalLinks.push(attribs)

              // Return a proper tagName to prevent sanitize-html from truncating
              // content after the closing tag (known bug when tagName is omitted)
              return {
                tagName: 'span',
                attribs: { class: 'internal-link-placeholder' },
                text: INTERNAL_LINK_PLACEHOLDER,
              }
            }
            // For external links, don't change anything
            return { tagName, attribs }
          },
        },
      }
      const sanitized = sanitize(htmlString, sanitizeOptions)

      // If there's no internal link, simply return the sanitized string
      if (!internalLinks.length) return <span dangerouslySetInnerHTML={sanitized} />

      // Otherwise, replace all the {{link}} by the <Link /> component
      const splitted = sanitized.__html.split(INTERNAL_LINK_PLACEHOLDER_HTML)
      const sanitizedWithInternalLinks: JSX.Element[] = []

      // Add each string + the links in between
      splitted.forEach((string, i) => {
        const internalLink = i > 0 ? internalLinks[i - 1] : null

        if (internalLink) {
          if (isSafeHref(internalLink.href)) {
            sanitizedWithInternalLinks.push(
              <Link key={`link-${i}`} to={internalLink.href}>
                {internalLink['data-text']}
              </Link>,
            )
          } else {
            sanitizedWithInternalLinks.push(
              <span key={`link-${i}`}>{internalLink['data-text']}</span>,
            )
          }
        }

        sanitizedWithInternalLinks.push(
          <span key={i} dangerouslySetInnerHTML={{ __html: string }} />,
        )
      })

      return sanitizedWithInternalLinks.map((child) => child)
    }

    return (
      <MuiTypography
        variant={variant}
        className={tw(
          {
            'whitespace-pre-line': !noWrap && variant !== 'captionCode',
            'whitespace-pre': !noWrap && variant === 'captionCode',
            'pointer-events-none select-none blur-sm': blur,
            'line-break-anywhere': forceBreak,
          },
          className,
        )}
        color={mapColor(variant, color)}
        data-test={variant}
        variantMapping={{
          subhead1: 'div',
          subhead2: 'div',
          caption: 'div',
          note: 'div',
          noteHl: 'div',
          captionCode: 'code',
        }}
        noWrap={noWrap}
        component={component}
        {...props}
      >
        {html ? getSanitizedHtml(html) : children}
      </MuiTypography>
    )
  },
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  ({ component, ...prevProps }, { component: nextComponent, ...nextProps }) =>
    _isEqual(prevProps, nextProps),
)

Typography.displayName = 'Typography'
