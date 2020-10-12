<?php

/**
 * General Configuration
 *
 * All of your system's general configuration settings go in here. You can see a
 * list of the available settings in vendor/craftcms/cms/src/config/GeneralConfig.php.
 *
 * @see \craft\config\GeneralConfig
 */

use craft\helpers\App;

return [
    // Craft config settings from .env variables
    'aliases' => [
        '@assetsUrl' => App::env('ASSETS_URL'),
        '@cloudfrontUrl' => App::env('CLOUDFRONT_URL'),
        '@web' => App::env('SITE_URL'),
    ],
    'allowAdminChanges' => (bool)App::env('ALLOW_ADMIN_CHANGES'),
    'allowUpdates' => (bool)App::env('ALLOW_UPDATES'),
    'backupOnUpdate' => (bool)App::env('BACKUP_ON_UPDATE'),
    'devMode' => (bool)App::env('DEV_MODE'),
    'disallowRobots' => (bool)App::env('DISALLOW_ROBOTS'),
    'enableTemplateCaching' => (bool)App::env('ENABLE_TEMPLATE_CACHING'),
    'maxUploadFileSize' => App::env('MAX_UPLOAD_FILE_SIZE'),
    'runQueueAutomatically' => (bool)App::env('RUN_QUEUE_AUTOMATICALLY'),
    'securityKey' => App::env('SECURITY_KEY'),
    'userSessionDuration' => App::env('USER_SESSION_DURATION'),

    // Craft config settings from constants
    'cacheDuration' => 0,
    'defaultWeekStartDay' => 0,
    'errorTemplatePrefix' => 'errors/',
    'generateTransformsBeforePageLoad' => true,
    'maxCachedCloudImageSize' => 3840,
    'omitScriptNameInUrls' => true,
    'timezone' => 'Asia/Riyadh',
    'useEmailAsUsername' => true,
    'usePathInfo' => true,
];
