import { AnyObject, Flags, Maybe, Schema } from 'yup'

declare module 'yup' {
  interface StringSchema<
    TType extends Maybe<string> = string | undefined,
    TContext extends AnyObject = AnyObject,
    TDefault = undefined,
    TFlags extends Flags = '',
  > extends Schema<TType, TContext, TDefault, TFlags> {
    domain(message: string): this
    emails(message: string): this
    host(message: string): this
  }
}

export {}
