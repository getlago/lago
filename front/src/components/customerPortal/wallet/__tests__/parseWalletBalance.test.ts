import {
  CurrencyEnum,
  type CustomerPortalWalletInfoFragment,
  WalletStatusEnum,
} from '~/generated/graphql'

import { parseWalletBalance } from '../WalletSection'

function prepareWallet({
  creditsBalance = 0,
  creditsOngoingBalance = 0,
  balanceCents = 0,
  ongoingBalanceCents = 0,
}: {
  creditsBalance?: number
  creditsOngoingBalance?: number
  balanceCents?: number
  ongoingBalanceCents?: number
}): CustomerPortalWalletInfoFragment {
  return {
    id: 'wallet-id',
    currency: CurrencyEnum.Usd,
    balanceCents,
    creditsBalance,
    consumedCredits: 25,
    consumedAmountCents: 2500,
    status: WalletStatusEnum.Active,
    creditsOngoingBalance,
    ongoingBalanceCents,
    rateAmount: 1,
  }
}

describe('parseWalletBalance', () => {
  describe('when isPremium is false (non-premium user)', () => {
    it('should return parsed creditsBalance values', () => {
      const wallet = prepareWallet({
        creditsBalance: 123.45,
        balanceCents: 12345,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '123',
        cents: '45',
        balance: 12345,
      })
    })

    it('should handle whole number creditsBalance', () => {
      const wallet = prepareWallet({
        creditsBalance: 100,
        balanceCents: 10000,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '100',
        cents: '00',
        balance: 10000,
      })
    })

    it('should handle zero creditsBalance', () => {
      const wallet = prepareWallet({
        creditsBalance: 0,
        balanceCents: 0,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '0',
        cents: '00',
        balance: 0,
      })
    })

    it('should handle creditsBalance with single decimal place', () => {
      const wallet = prepareWallet({
        creditsBalance: 50.5,
        balanceCents: 5050,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '50',
        cents: '5',
        balance: 5050,
      })
    })
  })

  describe('when isPremium is true (premium user)', () => {
    it('should return parsed creditsOngoingBalance values', () => {
      const wallet = prepareWallet({
        creditsOngoingBalance: 87.65,
        ongoingBalanceCents: 8765,
      })

      const result = parseWalletBalance(wallet, true)

      expect(result).toEqual({
        unit: '87',
        cents: '65',
        balance: 8765,
      })
    })

    it('should handle whole number creditsOngoingBalance', () => {
      const wallet = prepareWallet({
        creditsOngoingBalance: 200,
        ongoingBalanceCents: 20000,
      })

      const result = parseWalletBalance(wallet, true)

      expect(result).toEqual({
        unit: '200',
        cents: '00',
        balance: 20000,
      })
    })

    it('should handle zero creditsOngoingBalance', () => {
      const wallet = prepareWallet({
        creditsOngoingBalance: 0,
        ongoingBalanceCents: 0,
      })

      const result = parseWalletBalance(wallet, true)

      expect(result).toEqual({
        unit: '0',
        cents: '00',
        balance: 0,
      })
    })

    it('should handle creditsOngoingBalance with single decimal place', () => {
      const wallet = prepareWallet({
        creditsOngoingBalance: 99.9,
        ongoingBalanceCents: 9990,
      })

      const result = parseWalletBalance(wallet, true)

      expect(result).toEqual({
        unit: '99',
        cents: '9',
        balance: 9990,
      })
    })
  })

  describe('edge cases', () => {
    it('should handle very large numbers', () => {
      const wallet = prepareWallet({
        creditsBalance: 999999.99,
        balanceCents: 99999999,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '999999',
        cents: '99',
        balance: 99999999,
      })
    })

    it('should handle negative numbers (if they occur)', () => {
      const wallet = prepareWallet({
        creditsBalance: -50.25,
        balanceCents: -5025,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '-50',
        cents: '25',
        balance: -5025,
      })
    })

    it('should handle numbers with more than 2 decimal places', () => {
      const wallet = prepareWallet({
        creditsBalance: 123.456789,
        balanceCents: 12345,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '123',
        cents: '456789',
        balance: 12345,
      })
    })

    it('should handle string numbers (if they occur)', () => {
      const wallet = prepareWallet({
        creditsBalance: '75.50' as unknown as number,
        balanceCents: 7550,
      })

      const result = parseWalletBalance(wallet, false)

      expect(result).toEqual({
        unit: '75',
        cents: '50',
        balance: 7550,
      })
    })
  })

  describe('premium vs non-premium comparison', () => {
    it('should return different values for the same wallet based on premium status', () => {
      const wallet = prepareWallet({
        creditsBalance: 100.5,
        balanceCents: 10050,
        creditsOngoingBalance: 75.25,
        ongoingBalanceCents: 7525,
      })

      const nonPremiumResult = parseWalletBalance(wallet, false)
      const premiumResult = parseWalletBalance(wallet, true)

      expect(nonPremiumResult).toEqual({
        unit: '100',
        cents: '5',
        balance: 10050,
      })

      expect(premiumResult).toEqual({
        unit: '75',
        cents: '25',
        balance: 7525,
      })

      expect(nonPremiumResult).not.toEqual(premiumResult)
    })
  })
})
