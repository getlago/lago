/* eslint-disable react/prop-types */
import {
  type CodeToHtmlOptions,
  loadHighlighter,
  parseCompleteMarkdownCodeBlock,
} from '@llm-ui/code'
import { type LLMOutputComponent } from '@llm-ui/react'
import parseHtml from 'html-react-parser'
import { useEffect, useReducer, useState } from 'react'
import { bundledLanguages, createHighlighter } from 'shiki/bundle/web'
import type { HighlighterCore } from 'shiki/core'
import catppuccinLatte from 'shiki/themes/catppuccin-latte.mjs'

import './codeblock.css'

// Eagerly load only the common web-bundle languages (78) for fast startup.
// When a code block uses a language outside this set, we dynamically import
// shiki/bundle/full (code-split by Vite) and lazy-load the grammar on demand.
const highlighterHandle = loadHighlighter(
  createHighlighter({
    langs: Object.keys(bundledLanguages),
    themes: [catppuccinLatte],
  }),
)

const codeToHtmlOptions: CodeToHtmlOptions = {
  theme: 'catppuccin-latte',
}

// Track languages already requested for lazy-loading so we don't re-trigger
// loadLanguage on every re-render while the promise settles.
const lazyLoadRequested = new Set<string>()

async function lazyLoadLanguage(shiki: HighlighterCore, lang: string): Promise<boolean> {
  const { bundledLanguages: fullLanguages } = await import('shiki/bundle/full')

  if (!(lang in fullLanguages)) return false

  const key = lang as keyof typeof fullLanguages

  await shiki.loadLanguage(fullLanguages[key])
  return true
}

export const Codeblock: LLMOutputComponent = ({ blockMatch }) => {
  const [shiki, setShiki] = useState(highlighterHandle.getHighlighter())
  const [, forceRender] = useReducer((x: number) => x + 1, 0)

  useEffect(() => {
    if (!shiki) {
      highlighterHandle.highlighterPromise.then((h) => setShiki(h))
    }
  }, [shiki])

  const { code = '\n', language } = parseCompleteMarkdownCodeBlock(blockMatch.output)
  const lang = language ?? 'text'

  if (!shiki) {
    return (
      <pre className="shiki">
        <code>{code}</code>
      </pre>
    )
  }

  let html: string

  try {
    html = shiki.codeToHtml(code, { ...codeToHtmlOptions, lang })
  } catch {
    // Language not in the web bundle — lazy-load it from the full bundle
    // (code-split by Vite), then re-render. Show plaintext in the meantime.
    if (!lazyLoadRequested.has(lang)) {
      lazyLoadRequested.add(lang)
      lazyLoadLanguage(shiki, lang)
        .then((loaded) => {
          if (loaded) forceRender()
        })
        .catch(() => {
          // Chunk load or grammar registration failed — remove from the set
          // so a subsequent render can retry (e.g. after a transient network error).
          lazyLoadRequested.delete(lang)
        })
    }

    html = shiki.codeToHtml(code, { ...codeToHtmlOptions, lang: 'text' })
  }

  return <>{parseHtml(html)}</>
}
