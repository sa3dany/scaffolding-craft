# scaffolding-craft

Scaffolding for a Craft CMS project

## Based on

- [craftcms/craft v1.0.59](https://github.com/craftcms/craft)
- [nystudio107/craft v2.3.9](https://github.com/nystudio107/craft)

## Notes

I've ovverdden `CRAFT_VENDOR_PATH` in `craft` and `web/index.php` to
`/usr/local/lib/craft` plus, the associated `vendor-dir` config options
in `composer.json`. This is to avoid all issues a `compose install`
causes from within a Windows-hosted VM.
