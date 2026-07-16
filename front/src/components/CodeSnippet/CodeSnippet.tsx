import Prism from 'prismjs'
import 'prismjs/components/prism-bash'
import 'prismjs/components/prism-javascript'
import 'prismjs/components/prism-json'
import 'prismjs/components/prism-ruby'
import 'prismjs/plugins/line-numbers/prism-line-numbers'
import { memo, useEffect, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

import './codeSnippet.css'

Prism.manual = true

interface CodeSnippetProps {
  className?: string
  loading?: boolean
  code: string
  language?: 'bash' | 'javascript' | 'json'
  canCopy?: boolean
  displayHead?: boolean
  variant?: 'minimal' | 'default'
}

export const CodeSnippet = memo(
  ({
    className,
    loading,
    code,
    language = 'javascript',
    canCopy = true,
    displayHead = true,
    variant = 'default',
  }: CodeSnippetProps) => {
    const codeRef = useRef(null)
    const { translate } = useInternationalization()

    useEffect(() => {
      if (codeRef?.current) {
        Prism.highlightElement(codeRef.current)
      }
    })

    const handleCopy = () => {
      copyToClipboard(code, { ignoreComment: true })

      addToast({
        severity: 'info',
        translateKey: 'text_6241ce41ae814301478358a2',
      })
    }

    return (
      <div
        className={tw(
          'code-snippet',
          'relative h-full',
          variant === 'minimal' && 'overflow-hidden rounded-lg bg-grey-100',
          className,
        )}
      >
        {canCopy && variant === 'minimal' && (
          <div className="flex items-center justify-end bg-grey-200 p-2">
            <Tooltip title={translate('text_623b42ff8ee4e000ba87d0c6')} placement="top-end">
              <Button variant="quaternary" icon="duplicate" size="small" onClick={handleCopy} />
            </Tooltip>
          </div>
        )}

        {!loading && (
          <>
            {displayHead && (
              <div className="flex h-nav items-center px-8 shadow-b">
                <Typography variant="bodyHl">
                  {translate('text_623b42ff8ee4e000ba87d0b2')}
                </Typography>
              </div>
            )}
            <pre
              className={tw(
                // Line-numbers is a Prism className and is required
                // https://prismjs.com/plugins/line-numbers/
                'line-numbers',
                'pb-30',
                displayHead ? 'h-[calc(100%-theme(space.nav))]' : 'h-full',
                variant === 'minimal' && '!m-0',
              )}
            >
              <code
                ref={codeRef}
                className={tw(`language-${language}`, 'font-code text-sm/6 font-normal')}
              >
                {code}
              </code>
            </pre>
            {canCopy && variant === 'default' && (
              <Button
                className="absolute inset-x-0 bottom-12 mx-auto w-fit"
                variant="secondary"
                startIcon="duplicate"
                onClick={handleCopy}
              >
                {translate('text_623b42ff8ee4e000ba87d0c6')}
              </Button>
            )}
          </>
        )}
      </div>
    )
  },
)

CodeSnippet.displayName = 'CodeSnippet'
