import autoprefixer from 'autoprefixer'
import cssnano from 'cssnano'
import postcssPresetEnv from 'postcss-preset-env'
import tailwindcss from 'tailwindcss'

/** @type {import('postcss-load-config').Config} */
const config = {
  plugins: [
    postcssPresetEnv,
    tailwindcss,
    autoprefixer,
    process.env.APP_ENV === 'production' ? cssnano : null,
  ].filter(Boolean),
}

export default config
