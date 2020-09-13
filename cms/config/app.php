<?php

/**
 * Yii Application Config
 *
 * Edit this file at your own risk!
 *
 * The array returned by this file will get merged with
 * vendor/craftcms/cms/src/config/app.php and app.[web|console].php, when
 * Craft's bootstrap script is defining the configuration for the entire
 * application.
 *
 * You can define custom modules and system components, and even override the
 * built-in system components.
 *
 * If you want to modify the application config for *only* web requests or
 * *only* console requests, create an app.web.php or app.console.php file in
 * your config/ folder, alongside this one.
 */

use Craft;
use craft\helpers\App;

return [
    'id' => App::env('APP_ID') ?: 'CraftCMS',
    'components' => [
        'deprecator' => [
            'throwExceptions' => App::env('DEV_MODE'),
        ],
        // Mutex fix for Windows VM hosts
        /*'mutex' => function () {
            $config = App::mutexConfig();
            $config['isWindows'] = (bool)getenv('WINDOWS_FS') ?: null;
            return Craft::createObject($config);
        },*/
    ],
];
