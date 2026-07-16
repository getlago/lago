import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'

import { configureMention, mentionBaseConfig, MentionSchema } from '../Mention.schema'

describe('MentionSchema', () => {
  describe('GIVEN the addStorage markdown config', () => {
    const storage = (
      MentionSchema.storage as {
        markdown: {
          serialize: (
            state: { write: (text: string) => void },
            node: { attrs: { id: string; label?: string } },
          ) => void
          parse: { updateDOM: (element: HTMLElement) => void }
        }
      }
    ).markdown

    describe('WHEN serialize is called with a mention node that has a label', () => {
      it('THEN should write the mention in {id|label} format', () => {
        const mockWrite = jest.fn()

        storage.serialize(
          { write: mockWrite },
          { attrs: { id: 'customerName', label: 'Customer Name' } },
        )

        expect(mockWrite).toHaveBeenCalledWith('{customerName|Customer Name}')
      })
    })

    describe('WHEN serialize is called with a mention node that has no label', () => {
      it('THEN should fallback to using id as the label', () => {
        const mockWrite = jest.fn()

        storage.serialize({ write: mockWrite }, { attrs: { id: 'planName' } })

        expect(mockWrite).toHaveBeenCalledWith('{planName|planName}')
      })
    })

    describe('WHEN parse.updateDOM is called', () => {
      it('THEN should replace mention placeholders with span elements', () => {
        const mockElement = {
          innerHTML: 'Hello {customerName|Customer Name}, your plan is {planName|Pro Plan}.',
        } as HTMLElement

        storage.parse.updateDOM(mockElement)

        expect(mockElement.innerHTML).toContain('data-type="mention"')
        expect(mockElement.innerHTML).toContain('data-id="customerName"')
        expect(mockElement.innerHTML).toContain('data-label="Customer Name"')
        expect(mockElement.innerHTML).toContain('@Customer Name')
        expect(mockElement.innerHTML).toContain('data-id="planName"')
        expect(mockElement.innerHTML).toContain('@Pro Plan')
      })

      it('THEN should not modify content without mention placeholders', () => {
        const mockElement = { innerHTML: 'No mentions here.' } as HTMLElement

        storage.parse.updateDOM(mockElement)

        expect(mockElement.innerHTML).toBe('No mentions here.')
      })
    })
  })

  describe('GIVEN the mentionBaseConfig', () => {
    it('THEN should set the variable-mention CSS class', () => {
      expect(mentionBaseConfig.HTMLAttributes).toEqual({ class: 'variable-mention' })
    })
  })

  describe('GIVEN the renderHTML method', () => {
    const getHtmlForMention = (
      attrs: { id: string; label?: string },
      mentionValues?: Record<string, string>,
    ) => {
      const editor = new Editor({
        extensions: [StarterKit, configureMention({ ...mentionBaseConfig, mentionValues })],
        content: {
          type: 'doc',
          content: [
            {
              type: 'paragraph',
              content: [{ type: 'mention', attrs }],
            },
          ],
        },
      })
      const html = editor.getHTML()

      editor.destroy()

      return html
    }

    describe('WHEN no mentionValues are provided', () => {
      it('THEN should render an unresolved mention with @label', () => {
        const html = getHtmlForMention({ id: 'customerName', label: 'Customer Name' })

        expect(html).toContain('class="variable-mention"')
        expect(html).toContain('@Customer Name')
        expect(html).not.toContain('variable-mention--resolved')
      })

      it('THEN should fallback to @id when no label', () => {
        const html = getHtmlForMention({ id: 'customerName' })

        expect(html).toContain('@customerName')
      })
    })

    describe('WHEN mentionValues are provided', () => {
      it('THEN should render a resolved mention with the value', () => {
        const html = getHtmlForMention(
          { id: 'customerName', label: 'Customer Name' },
          { customerName: 'Acme Corp' },
        )

        expect(html).toContain('variable-mention--resolved')
        expect(html).toContain('Acme Corp')
        expect(html).not.toContain('@Customer Name')
      })

      it('THEN should keep unresolved mentions when id has no value', () => {
        const html = getHtmlForMention(
          { id: 'customerName', label: 'Customer Name' },
          { otherVar: 'value' },
        )

        expect(html).not.toContain('variable-mention--resolved')
        expect(html).toContain('@Customer Name')
      })

      it('THEN should render nothing (not @label) when the value is an empty string', () => {
        const html = getHtmlForMention(
          { id: 'customerName', label: 'Customer Name' },
          { customerName: '' },
        )

        expect(html).not.toContain('@Customer Name')
      })

      it('THEN should render nothing (not @label) when the value is null', () => {
        const html = getHtmlForMention(
          { id: 'customerName', label: 'Customer Name' },
          { customerName: null as unknown as string },
        )

        expect(html).not.toContain('@Customer Name')
      })
    })
  })
})
