/* eslint-disable react/prop-types */
import { type LLMOutputComponent } from '@llm-ui/react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

import './markdown.css'

export const Markdown: LLMOutputComponent = ({ blockMatch }) => {
  const markdown = blockMatch.output

  return (
    <div className="markdown">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{markdown}</ReactMarkdown>
    </div>
  )
}
