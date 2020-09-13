import html from '@rollup/plugin-html';
import buble from '@rollup/plugin-buble';
import strip from '@rollup/plugin-strip';
import replace from '@rollup/plugin-replace';
import commonjs from '@rollup/plugin-commonjs';
import resolve from '@rollup/plugin-node-resolve';
import { terser } from 'rollup-plugin-terser';

const production = process.env.NODE_ENV === 'production';

export default {
  input: 'src/js/main.js',
  output: {
    format: 'iife',
    name: 'app',
    dir: 'cms/web/assets/js',
    entryFileNames: `bundle${production ? '.[hash]' : ''}.js`,
    sourcemap: production ? false : 'inline'
  },
  plugins: [
    resolve({ browser: true }),
    commonjs(),
    buble({ include: ['src/js/*'] }),
    production && strip(),
    production && terser(),
    production &&
      html({
        fileName: 'manifest.json',
        template: ({ files, publicPath }) => {
          const json = {};
          (files.js || []).forEach(({ fileName, name }) => {
            json[name] = `${publicPath}${fileName}`;
          });
          return JSON.stringify(json);
        }
      })
  ]
};
