import { z } from 'zod'

import {
  PropertiesZodInput,
  validateChargeProperties,
} from '~/formValidation/chargePropertiesSchema'
import { ChargeModelEnum } from '~/generated/graphql'

// Collect the issues emitted on the `presentationGroupKeys` path only, so the
// per-charge-model validators (which run first) don't pollute the assertions.
function validatePresentationGroupKeys(props: Partial<PropertiesZodInput>) {
  const issues: any[] = []

  const ctx = { addIssue: (issue: any) => issues.push(issue), path: [] } as any as z.RefinementCtx

  // Standard + a valid `amount` keeps the model validator silent, isolating the
  // presentationGroupKeys validation under test.
  validateChargeProperties(
    ChargeModelEnum.Standard,
    { amount: '1', ...props } as PropertiesZodInput,
    ctx,
    ['properties'],
  )

  const pgkIssues = issues.filter((i) => i.path?.includes('presentationGroupKeys'))

  return { issues: pgkIssues, isValid: pgkIssues.length === 0 }
}

const valueIssuesAt = (issues: { path: string[] }[], index: number) =>
  issues.filter((i) => i.path.join('.') === `properties.presentationGroupKeys.${index}.value`)

const displayInInvoiceIssuesAt = (issues: { path: string[] }[], index: number) =>
  issues.filter(
    (i) =>
      i.path.join('.') === `properties.presentationGroupKeys.${index}.options.displayInInvoice`,
  )

describe('validateChargeProperties — presentationGroupKeys', () => {
  describe('GIVEN no presentationGroupKeys', () => {
    it('THEN emits no presentationGroupKeys issues', () => {
      expect(validatePresentationGroupKeys({}).isValid).toBe(true)
    })
  })

  describe('GIVEN a valid presentationGroupKey', () => {
    it('THEN emits no issues', () => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice: 'true' } }],
      } as Partial<PropertiesZodInput>)

      expect(result.isValid).toBe(true)
    })

    it.each(['true', 'false'])('THEN accepts displayInInvoice="%s"', (displayInInvoice) => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice } }],
      } as Partial<PropertiesZodInput>)

      expect(displayInInvoiceIssuesAt(result.issues, 0)).toHaveLength(0)
    })
  })

  describe('GIVEN an empty value', () => {
    it('THEN flags the row with a "value required" issue', () => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [{ value: '', options: { displayInInvoice: 'true' } }],
      } as Partial<PropertiesZodInput>)

      expect(valueIssuesAt(result.issues, 0)).toHaveLength(1)
    })
  })

  describe('GIVEN a missing/invalid displayInInvoice', () => {
    it.each([
      ['undefined', undefined],
      ['empty string', ''],
      ['garbage', 'maybe'],
    ])('THEN flags the row when displayInInvoice is %s', (_, displayInInvoice) => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [{ value: 'region', options: { displayInInvoice } }],
      } as Partial<PropertiesZodInput>)

      expect(displayInInvoiceIssuesAt(result.issues, 0)).toHaveLength(1)
    })
  })

  describe('GIVEN duplicate values (trimmed)', () => {
    it('THEN flags BOTH the first and the duplicate row', () => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [
          { value: 'region', options: { displayInInvoice: 'true' } },
          { value: ' region ', options: { displayInInvoice: 'true' } },
        ],
      } as Partial<PropertiesZodInput>)

      expect(valueIssuesAt(result.issues, 0)).toHaveLength(1)
      expect(valueIssuesAt(result.issues, 1)).toHaveLength(1)
    })

    it('THEN does NOT treat empty rows as duplicates of each other', () => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [
          { value: '', options: { displayInInvoice: 'true' } },
          { value: '', options: { displayInInvoice: 'true' } },
        ],
      } as Partial<PropertiesZodInput>)

      // Each empty row gets a "value required" issue, never a "duplicate" one.
      expect(valueIssuesAt(result.issues, 0)).toHaveLength(1)
      expect(valueIssuesAt(result.issues, 1)).toHaveLength(1)
    })

    it('THEN treats case differences as distinct values', () => {
      const result = validatePresentationGroupKeys({
        presentationGroupKeys: [
          { value: 'Region', options: { displayInInvoice: 'true' } },
          { value: 'region', options: { displayInInvoice: 'true' } },
        ],
      } as Partial<PropertiesZodInput>)

      expect(valueIssuesAt(result.issues, 0)).toHaveLength(0)
      expect(valueIssuesAt(result.issues, 1)).toHaveLength(0)
    })
  })
})
