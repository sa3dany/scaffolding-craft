const fs = require('fs');

const CSS_MANIFEST_FILE = 'cms/web/assets/css/manifest.json';
const JS_MANIFEST_FILE = 'cms/web/assets/js/manifest.json';

let cssManifest = JSON.parse(fs.readFileSync(CSS_MANIFEST_FILE));
fs.writeFileSync(
  'cms/templates/_boilerplate/_partials/build-css.html',
  `${toLinkTags(cssManifest).join('\n')}\n`
);

let jsManifest = JSON.parse(fs.readFileSync(JS_MANIFEST_FILE));
fs.writeFileSync(
  'cms/templates/_boilerplate/_partials/build-js.html',
  `${toScriptTags(jsManifest).join('\n')}\n`
);

function toLinkTags(manifest) {
  return Object.keys(manifest).map(
    (file) => `<link rel="stylesheet" href="/assets/css/${manifest[file]}">`
  );
}

function toScriptTags(manifest) {
  return Object.keys(manifest).map(
    (file) => `<script defer src="/assets/js/${manifest[file]}"></script>`
  );
}
