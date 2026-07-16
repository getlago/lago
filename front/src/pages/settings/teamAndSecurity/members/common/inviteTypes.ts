/**
 * Those are temporary types until we can use the graphQL generated types
 * We don't have the design for multiple roles yet
 */

export type CreateInviteSingleRole = {
  role: string
  email: string
}

export type UpdateInviteSingleRole = {
  role: string
}
