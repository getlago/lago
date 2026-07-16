import { defineConfig } from 'eslint/config'
import config from 'lago-configs/eslint'

export default defineConfig([
  {
    files: [
      'src/**/*.{js,ts,jsx,tsx}',
      'scripts/**/*.{js,ts,jsx,tsx}',
      'cypress/**/*.{js,ts,jsx,tsx}',
    ],
    extends: [config],
  },
])
