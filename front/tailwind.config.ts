import sharedConfig from 'lago-configs/tailwind'
import { Config } from 'prettier'

const config: Pick<Config, 'presets' | 'content'> = {
  content: ['src/**/*.{js,ts,jsx,tsx}'],
  presets: [sharedConfig],
}

export default config
