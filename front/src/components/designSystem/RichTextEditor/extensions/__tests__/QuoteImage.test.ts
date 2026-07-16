import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'

import { QuoteImageSchema } from '../QuoteImage'

const makeEditor = (images: Record<string, string>) =>
  new Editor({
    extensions: [StarterKit, QuoteImageSchema.configure({ images })],
    content: '',
  })

describe('QuoteImageSchema renderHTML', () => {
  it('renders the signed URL for a blob id present in the images map', () => {
    const editor = makeEditor({ 'blob-1': 'https://signed/blob-1' })

    editor.commands.setContent({
      type: 'doc',
      content: [{ type: 'image', attrs: { src: 'blob-1' } }],
    })

    expect(editor.getHTML()).toContain('src="https://signed/blob-1"')
    editor.destroy()
  })

  it('renders a legacy http URL verbatim', () => {
    const editor = makeEditor({})

    editor.commands.setContent({
      type: 'doc',
      content: [{ type: 'image', attrs: { src: 'https://cdn.example.com/a.png' } }],
    })

    expect(editor.getHTML()).toContain('src="https://cdn.example.com/a.png"')
    editor.destroy()
  })

  it('renders no <img> for an unknown id', () => {
    const editor = makeEditor({ 'blob-1': 'https://signed/blob-1' })

    editor.commands.setContent({
      type: 'doc',
      content: [{ type: 'image', attrs: { src: 'blob-unknown' } }],
    })

    expect(editor.getHTML()).not.toContain('<img')
    expect(editor.getHTML()).not.toContain('blob-unknown')
    editor.destroy()
  })

  it('keeps the standard block-wrapper structure', () => {
    const editor = makeEditor({ 'blob-1': 'https://signed/blob-1' })

    editor.commands.setContent({
      type: 'doc',
      content: [{ type: 'image', attrs: { src: 'blob-1' } }],
    })

    expect(editor.getHTML()).toContain('data-type="image"')
    editor.destroy()
  })
})
