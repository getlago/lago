/** @type {import('postcss-load-config').Config} */
const config = {
  plugins: [
    require('postcss-preset-env'),
    require('tailwindcss'),
    require('autoprefixer'),
    process.env.APP_ENV === 'production' ? require('cssnano') : null,
  ],
}

module.exports = config
