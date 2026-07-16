import lagoPrettierConfig from 'lago-configs/prettier'

/**
 * @type {import("prettier").Config}
 */
const config = {
  ...lagoPrettierConfig,
  tailwindConfig: './tailwind.config.ts',
}

export default config
