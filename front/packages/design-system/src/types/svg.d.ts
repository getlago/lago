/* eslint-disable @typescript-eslint/no-explicit-any */
declare module '*.svg' {
  import { FC, SVGProps } from 'react'
  const content: FC<SVGProps<SVGElement> & { title?: string; 'data-test'?: string }>

  export default content
}

declare module '*.png' {
  const value: any

  export default value
}

declare module '*.jpg' {
  const value: any

  export default value
}

declare module '*.jpeg' {
  const value: any

  export default value
}

declare module '*.css'
