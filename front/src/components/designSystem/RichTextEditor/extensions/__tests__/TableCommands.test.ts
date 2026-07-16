import { Editor } from '@tiptap/core'
import { Table } from '@tiptap/extension-table'
import TableCell from '@tiptap/extension-table-cell'
import TableHeader from '@tiptap/extension-table-header'
import TableRow from '@tiptap/extension-table-row'
import StarterKit from '@tiptap/starter-kit'
import { act } from 'react'

import { TableCommands } from '../TableCommands'

const TABLE_2x3 = `
<table>
  <tbody>
    <tr><td>A1</td><td>B1</td><td>C1</td></tr>
    <tr><td>A2</td><td>B2</td><td>C2</td></tr>
  </tbody>
</table>
`

const createEditor = (content = TABLE_2x3) => {
  let editor!: Editor

  act(() => {
    editor = new Editor({
      extensions: [StarterKit, Table, TableRow, TableCell, TableHeader, TableCommands],
      content,
    })
  })

  return editor
}

/** Helper to get all cell texts as a 2D array */
const getTableCells = (editor: Editor): string[][] => {
  const rows: string[][] = []

  editor.state.doc.descendants((node) => {
    if (node.type.name === 'tableRow') {
      const cells: string[] = []

      node.forEach((cell) => {
        cells.push(cell.textContent)
      })
      rows.push(cells)
    }
  })

  return rows
}

/** Place cursor in a specific cell by row/col index */
const setCursorInCell = (editor: Editor, rowIndex: number, colIndex: number) => {
  let currentRow = 0

  editor.state.doc.descendants((node, pos) => {
    if (node.type.name === 'tableRow') {
      if (currentRow === rowIndex) {
        let currentCol = 0

        node.forEach((cell, offset) => {
          if (currentCol === colIndex) {
            // Position inside the cell's first text content
            editor.commands.setTextSelection(pos + offset + 2)
          }
          currentCol++
        })
      }
      currentRow++
    }
  })
}

describe('TableCommands', () => {
  describe('GIVEN the TableCommands extension', () => {
    it('THEN should have the correct name', () => {
      expect(TableCommands.name).toBe('tableCommands')
    })
  })

  describe('GIVEN a 2x3 table', () => {
    describe('WHEN moveRowDown is called on the first row', () => {
      it('THEN should swap rows 0 and 1', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        editor.commands.moveRowDown()

        const cells = getTableCells(editor)

        expect(cells[0]).toEqual(['A2', 'B2', 'C2'])
        expect(cells[1]).toEqual(['A1', 'B1', 'C1'])

        editor.destroy()
      })
    })

    describe('WHEN moveRowUp is called on the second row', () => {
      it('THEN should swap rows 0 and 1', () => {
        const editor = createEditor()

        setCursorInCell(editor, 1, 0)
        editor.commands.moveRowUp()

        const cells = getTableCells(editor)

        expect(cells[0]).toEqual(['A2', 'B2', 'C2'])
        expect(cells[1]).toEqual(['A1', 'B1', 'C1'])

        editor.destroy()
      })
    })

    describe('WHEN moveRowUp is called on the first row', () => {
      it('THEN should return false (no-op)', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        const result = editor.commands.moveRowUp()

        expect(result).toBe(false)

        const cells = getTableCells(editor)

        expect(cells[0]).toEqual(['A1', 'B1', 'C1'])

        editor.destroy()
      })
    })

    describe('WHEN moveRowDown is called on the last row', () => {
      it('THEN should return false (no-op)', () => {
        const editor = createEditor()

        setCursorInCell(editor, 1, 0)
        const result = editor.commands.moveRowDown()

        expect(result).toBe(false)

        const cells = getTableCells(editor)

        expect(cells[1]).toEqual(['A2', 'B2', 'C2'])

        editor.destroy()
      })
    })

    describe('WHEN moveColumnRight is called on the first column', () => {
      it('THEN should swap columns 0 and 1', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        editor.commands.moveColumnRight()

        const cells = getTableCells(editor)

        expect(cells[0]).toEqual(['B1', 'A1', 'C1'])
        expect(cells[1]).toEqual(['B2', 'A2', 'C2'])

        editor.destroy()
      })
    })

    describe('WHEN moveColumnLeft is called on the second column', () => {
      it('THEN should swap columns 0 and 1', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 1)
        editor.commands.moveColumnLeft()

        const cells = getTableCells(editor)

        expect(cells[0]).toEqual(['B1', 'A1', 'C1'])
        expect(cells[1]).toEqual(['B2', 'A2', 'C2'])

        editor.destroy()
      })
    })

    describe('WHEN moveColumnLeft is called on the first column', () => {
      it('THEN should return false (no-op)', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        const result = editor.commands.moveColumnLeft()

        expect(result).toBe(false)

        editor.destroy()
      })
    })

    describe('WHEN moveColumnRight is called on the last column', () => {
      it('THEN should return false (no-op)', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 2)
        const result = editor.commands.moveColumnRight()

        expect(result).toBe(false)

        editor.destroy()
      })
    })
  })

  describe('GIVEN row color commands', () => {
    describe('WHEN setRowBackgroundColor is called', () => {
      it('THEN should set backgroundColor on all cells in that row', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        editor.commands.setRowBackgroundColor('#fee2e2')

        // All cells in row 0 should have the color
        const cellColors: string[] = []
        let currentRow = 0

        editor.state.doc.descendants((node) => {
          if (node.type.name === 'tableRow') {
            currentRow++
          }
          if (
            currentRow === 1 &&
            (node.type.name === 'tableCell' || node.type.name === 'tableHeader')
          ) {
            cellColors.push(node.attrs.backgroundColor)
          }
        })

        expect(cellColors).toEqual(['#fee2e2', '#fee2e2', '#fee2e2'])

        editor.destroy()
      })
    })

    describe('WHEN setRowTextColor is called', () => {
      it('THEN should set textColor on all cells in that row', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        editor.commands.setRowTextColor('#dc2626')

        const cellColors: string[] = []
        let currentRow = 0

        editor.state.doc.descendants((node) => {
          if (node.type.name === 'tableRow') {
            currentRow++
          }
          if (
            currentRow === 1 &&
            (node.type.name === 'tableCell' || node.type.name === 'tableHeader')
          ) {
            cellColors.push(node.attrs.textColor)
          }
        })

        expect(cellColors).toEqual(['#dc2626', '#dc2626', '#dc2626'])

        editor.destroy()
      })
    })

    describe('WHEN setRowBackgroundColor is called with null', () => {
      it('THEN should clear backgroundColor on all cells in that row', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 0)
        editor.commands.setRowBackgroundColor('#fee2e2')
        editor.commands.setRowBackgroundColor(null)

        const cellColors: (string | null)[] = []
        let currentRow = 0

        editor.state.doc.descendants((node) => {
          if (node.type.name === 'tableRow') {
            currentRow++
          }
          if (
            currentRow === 1 &&
            (node.type.name === 'tableCell' || node.type.name === 'tableHeader')
          ) {
            cellColors.push(node.attrs.backgroundColor)
          }
        })

        expect(cellColors).toEqual([null, null, null])

        editor.destroy()
      })
    })
  })

  describe('GIVEN column color commands', () => {
    describe('WHEN setColumnBackgroundColor is called', () => {
      it('THEN should set backgroundColor on all cells in that column', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 1) // column 1
        editor.commands.setColumnBackgroundColor('#dbeafe')

        // Check column 1 cells across both rows
        const colColors: string[] = []

        editor.state.doc.descendants((node) => {
          if (node.type.name === 'tableRow') {
            let colIdx = 0

            node.forEach((cell) => {
              if (colIdx === 1 && cell.attrs.backgroundColor) {
                colColors.push(cell.attrs.backgroundColor)
              }
              colIdx++
            })
          }
        })

        expect(colColors).toEqual(['#dbeafe', '#dbeafe'])

        editor.destroy()
      })
    })
  })

  describe('GIVEN column text color commands', () => {
    describe('WHEN setColumnTextColor is called', () => {
      it('THEN should set textColor on all cells in that column', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 1) // column 1
        editor.commands.setColumnTextColor('#dc2626')

        const colColors: string[] = []

        editor.state.doc.descendants((node) => {
          if (node.type.name === 'tableRow') {
            let colIdx = 0

            node.forEach((cell) => {
              if (colIdx === 1 && cell.attrs.textColor) {
                colColors.push(cell.attrs.textColor)
              }
              colIdx++
            })
          }
        })

        expect(colColors).toEqual(['#dc2626', '#dc2626'])

        editor.destroy()
      })
    })

    describe('WHEN setColumnTextColor is called with null', () => {
      it('THEN should clear textColor on all cells in that column', () => {
        const editor = createEditor()

        setCursorInCell(editor, 0, 1)
        editor.commands.setColumnTextColor('#dc2626')
        editor.commands.setColumnTextColor(null)

        const colColors: (string | null)[] = []

        editor.state.doc.descendants((node) => {
          if (node.type.name === 'tableRow') {
            let colIdx = 0

            node.forEach((cell) => {
              if (colIdx === 1) {
                colColors.push(cell.attrs.textColor)
              }
              colIdx++
            })
          }
        })

        expect(colColors).toEqual([null, null])

        editor.destroy()
      })
    })
  })

  describe('GIVEN the cursor is not in a table', () => {
    describe('WHEN any table command is called', () => {
      it('THEN should return false', () => {
        const editor = createEditor('<p>Hello</p>')

        editor.commands.setTextSelection(1)

        expect(editor.commands.moveRowUp()).toBe(false)
        expect(editor.commands.moveRowDown()).toBe(false)
        expect(editor.commands.moveColumnLeft()).toBe(false)
        expect(editor.commands.moveColumnRight()).toBe(false)
        expect(editor.commands.setRowBackgroundColor('#fee2e2')).toBe(false)
        expect(editor.commands.setRowTextColor('#dc2626')).toBe(false)
        expect(editor.commands.setColumnBackgroundColor('#dbeafe')).toBe(false)
        expect(editor.commands.setColumnTextColor('#dc2626')).toBe(false)

        editor.destroy()
      })
    })
  })
})
