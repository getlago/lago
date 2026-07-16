import { cx, CxOptions } from 'class-variance-authority'
import { twMerge } from 'tailwind-merge'

export const tw = (...inputs: CxOptions) => {
  return twMerge(cx(inputs))
}
