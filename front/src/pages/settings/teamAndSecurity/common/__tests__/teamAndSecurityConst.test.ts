import { teamAndSecurityGroupOptions, teamAndSecurityTabOptions } from '../teamAndSecurityConst'

describe('teamAndSecurityConst', () => {
  describe('teamAndSecurityGroupOptions', () => {
    it('has the correct group values', () => {
      expect(teamAndSecurityGroupOptions).toEqual({
        members: 'members',
        roles: 'roles',
        authentication: 'authentication',
        logs: 'logs',
      })
    })

    it('has exactly 4 group options', () => {
      expect(Object.keys(teamAndSecurityGroupOptions)).toHaveLength(4)
    })

    it('contains a members group', () => {
      expect(teamAndSecurityGroupOptions.members).toBe('members')
    })

    it('contains a roles group', () => {
      expect(teamAndSecurityGroupOptions.roles).toBe('roles')
    })

    it('contains an authentication group', () => {
      expect(teamAndSecurityGroupOptions.authentication).toBe('authentication')
    })

    it('contains a logs group', () => {
      expect(teamAndSecurityGroupOptions.logs).toBe('logs')
    })
  })

  describe('teamAndSecurityTabOptions', () => {
    it('has the correct tab values', () => {
      expect(teamAndSecurityTabOptions).toEqual({
        members: 'members',
        invitations: 'invitations',
      })
    })

    it('has exactly 2 tab options', () => {
      expect(Object.keys(teamAndSecurityTabOptions)).toHaveLength(2)
    })

    it('contains a members tab', () => {
      expect(teamAndSecurityTabOptions.members).toBe('members')
    })

    it('contains an invitations tab', () => {
      expect(teamAndSecurityTabOptions.invitations).toBe('invitations')
    })
  })
})
