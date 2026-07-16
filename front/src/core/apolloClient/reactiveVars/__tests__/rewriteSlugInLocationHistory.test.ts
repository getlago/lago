import type { Location } from 'react-router-dom'

import { locationHistoryVar, rewriteSlugInLocationHistory } from '../locationHistoryVar'

const createLocation = (pathname: string): Location => ({
  pathname,
  search: '',
  hash: '',
  state: null,
  key: 'test-key',
})

describe('rewriteSlugInLocationHistory', () => {
  beforeEach(() => {
    locationHistoryVar([])
  })

  describe('GIVEN early-return conditions', () => {
    describe('WHEN oldSlug is empty', () => {
      it('THEN should not modify history', () => {
        const history = [createLocation('/acme/settings')]

        locationHistoryVar(history)
        rewriteSlugInLocationHistory('', 'new-slug')

        expect(locationHistoryVar()).toEqual(history)
      })
    })

    describe('WHEN oldSlug equals newSlug', () => {
      it('THEN should not modify history', () => {
        const history = [createLocation('/acme/settings')]

        locationHistoryVar(history)
        rewriteSlugInLocationHistory('acme', 'acme')

        expect(locationHistoryVar()).toEqual(history)
      })
    })
  })

  describe('GIVEN history entries with matching slug prefix', () => {
    describe('WHEN pathname starts with /${oldSlug}/', () => {
      it('THEN should rewrite the slug segment', () => {
        locationHistoryVar([
          createLocation('/acme/settings/general'),
          createLocation('/acme/customers'),
        ])

        rewriteSlugInLocationHistory('acme', 'new-org')

        const result = locationHistoryVar()

        expect(result[0].pathname).toBe('/new-org/settings/general')
        expect(result[1].pathname).toBe('/new-org/customers')
      })
    })

    describe('WHEN pathname equals exactly /${oldSlug}', () => {
      it('THEN should rewrite to /${newSlug}', () => {
        locationHistoryVar([createLocation('/acme')])

        rewriteSlugInLocationHistory('acme', 'new-org')

        expect(locationHistoryVar()[0].pathname).toBe('/new-org')
      })
    })
  })

  describe('GIVEN history entries that do NOT match the slug', () => {
    describe('WHEN pathname has a different prefix', () => {
      it('THEN should leave them unchanged', () => {
        locationHistoryVar([createLocation('/other-org/settings'), createLocation('/login')])

        rewriteSlugInLocationHistory('acme', 'new-org')

        const result = locationHistoryVar()

        expect(result[0].pathname).toBe('/other-org/settings')
        expect(result[1].pathname).toBe('/login')
      })
    })
  })

  describe('GIVEN a mix of matching and non-matching entries', () => {
    describe('WHEN rewriting', () => {
      it('THEN should only rewrite matching entries and preserve non-matching ones', () => {
        locationHistoryVar([
          createLocation('/acme/customers'),
          createLocation('/login'),
          createLocation('/acme/settings/taxes'),
          createLocation('/other/dashboard'),
        ])

        rewriteSlugInLocationHistory('acme', 'new-org')

        const result = locationHistoryVar()

        expect(result.map((l) => l.pathname)).toEqual([
          '/new-org/customers',
          '/login',
          '/new-org/settings/taxes',
          '/other/dashboard',
        ])
      })
    })
  })

  describe('GIVEN entries with extra properties', () => {
    describe('WHEN rewriting', () => {
      it('THEN should preserve search, hash, state, and key', () => {
        const entry: Location = {
          pathname: '/acme/customers',
          search: '?page=2',
          hash: '#section',
          state: { from: 'test' },
          key: 'abc123',
        }

        locationHistoryVar([entry])
        rewriteSlugInLocationHistory('acme', 'new-org')

        const result = locationHistoryVar()[0]

        expect(result.pathname).toBe('/new-org/customers')
        expect(result.search).toBe('?page=2')
        expect(result.hash).toBe('#section')
        expect(result.state).toEqual({ from: 'test' })
        expect(result.key).toBe('abc123')
      })
    })
  })
})
