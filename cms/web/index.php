<?php
/**
 * Craft web bootstrap file
 */

// Set path constants
define('CRAFT_BASE_PATH', dirname(__DIR__));
define('CRAFT_VENDOR_PATH', '/usr/local/lib/craft');

// Load Composer's autoloader
require_once CRAFT_VENDOR_PATH.'/autoload.php';

// Load dotenv?
if (class_exists('Dotenv\Dotenv') && file_exists(CRAFT_BASE_PATH.'/.env')) {
    Dotenv\Dotenv::create(CRAFT_BASE_PATH)->load();
}

// Load and run Craft
define('CRAFT_ENVIRONMENT', getenv('ENVIRONMENT') ?: 'production');
/** @var craft\web\Application $app */
$app = require CRAFT_VENDOR_PATH.'/craftcms/cms/bootstrap/web.php';
$app->run();
