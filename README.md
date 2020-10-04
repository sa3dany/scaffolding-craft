# scaffolding-craft

Scaffolding for a Craft CMS project

## Based on

- [craftcms/craft v1.0.61](https://github.com/craftcms/craft)
- [nystudio107/craft v2.3.9](https://github.com/nystudio107/craft)

## Notes

To avoid all issues a `compose install` causes if running within a
Windows-hosted VM.  I changed the `vendor` directory path to somewhere
outside the shared folder between the vm and the host. I've chosen
`/usr/local/lib/craft`.

> Make sure the directory you chose exists and has the [necessary
> permissions](https://craftcms.com/docs/3.x/installation.html#step-2-set-the-file-permissions).

- I've overridden the
  [`CRAFT_VENDOR_PATH`](https://craftcms.com/docs/3.x/config/#craft-vendor-path)
  PHP constant in `craft` (CLI) and `web/index.php` to  point to the new
  location
- Added the
  [`vendor-dir`](https://getcomposer.org/doc/06-config.md#vendor-dir)
  config options in composer.json, also pointing to the new location

## Instructions

1. Edit vm name in `Vagrantfile`. Additionally, choose bridged IP
2. Run `npm install && npm outdated`
3. Install git-lfs and track common static file types

    ```shell
    git lfs install
    git lfs track "*.jpg"
    git lfs track "*.otf"
    git lfs track "*.png"
    git lfs track "*.svg"
    git lfs track "*.ttf"
    git lfs track "*.woff"
    git lfs track "*.woff2"
    ```

4. **TODO:**
