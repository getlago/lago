import { setResponsiveProperty } from '~/core/utils/responsiveProps'

describe('setResponsiveProperty', () => {
  it('should return a responsive style object', () => {
    expect(setResponsiveProperty('margin', 0)).toEqual({
      margin: '0px',
    })

    expect(setResponsiveProperty('margin', { default: 4 })).toEqual({
      margin: '4px',
    })

    expect(
      setResponsiveProperty('margin', {
        default: 4,
        md: 48,
      }),
    ).toEqual({
      margin: '4px',
      '@media (min-width:776px)': {
        margin: '48px',
      },
    })

    expect(
      setResponsiveProperty('margin', {
        default: 20,
        md: 30,
        lg: 10,
      }),
    ).toEqual({
      margin: '20px',
      '@media (min-width:776px)': {
        margin: '30px',
      },
      '@media (min-width:1024px)': {
        margin: '10px',
      },
    })
  })
})
