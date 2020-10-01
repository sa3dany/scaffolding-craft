const MANIFEST_PATH = "cms/web/assets/site/css/manifest.json";

const production = process.env.NODE_ENV == 'production';

const plugins = [];

plugins.push(
  require('postcss-import'),
  require('tailwindcss'),
  require('postcss-rtl'),
  require('autoprefixer')
);

production &&
  plugins.push(
    require('cssnano')({ preset: 'default' }),
    require('postcss-hash')({ manifest: MANIFEST_PATH })
  );

module.exports = { plugins };
