import {
  editOrganizationSlugDefaultValues,
  editOrganizationSlugValidationSchema,
} from '../validationSchema'

describe('editOrganizationSlugValidationSchema', () => {
  describe('GIVEN valid slugs', () => {
    it.each([
      ['minimum length (3 chars)', 'abc'],
      ['maximum length (40 chars)', 'a'.repeat(40)],
      ['lowercase letters only', 'myorganization'],
      ['numbers only', '123'],
      ['letters and numbers', 'org123'],
      ['with hyphens', 'my-org-name'],
      ['starts with number', '1st-org'],
      ['ends with number', 'org-1'],
    ])('THEN should pass for %s', (_, slug) => {
      const result = editOrganizationSlugValidationSchema.safeParse({ slug })

      expect(result.success).toBe(true)
    })
  })

  describe('GIVEN invalid slugs', () => {
    it.each([
      ['too short (2 chars)', 'ab'],
      ['too short (1 char)', 'a'],
      ['empty string', ''],
      ['too long (41 chars)', 'a'.repeat(41)],
      ['starts with hyphen', '-my-org'],
      ['ends with hyphen', 'my-org-'],
      ['uppercase letters', 'MyOrg'],
      ['contains spaces', 'my org'],
      ['contains underscores', 'my_org'],
      ['contains dots', 'my.org'],
      ['contains special chars', 'my@org!'],
      ['single hyphen only', '-'],
    ])('THEN should fail for %s', (_, slug) => {
      const result = editOrganizationSlugValidationSchema.safeParse({ slug })

      expect(result.success).toBe(false)
    })
  })

  describe('GIVEN default values', () => {
    describe('WHEN checking defaults', () => {
      it('THEN should have empty slug', () => {
        expect(editOrganizationSlugDefaultValues).toEqual({ slug: '' })
      })
    })
  })
})
