<?php

// https://simplesamlphp.org/docs/contrib_modules/oidc/3-oidc-configuration.html
// https://github.com/simplesamlphp/simplesamlphp-module-oidc/blob/master/config/module_oidc.php.dist

declare(strict_types=1);

use SimpleSAML\Module\oidc\ModuleConfig;

$config = [
    ModuleConfig::OPTION_ISSUER => 'https://idp.pvv.ntnu.no/',

    ModuleConfig::OPTION_PKI_PRIVATE_KEY_FILENAME => $OIDC_PRIVATE_KEY_PATH,
    ModuleConfig::OPTION_PKI_CERTIFICATE_FILENAME => $OIDC_CERTIFICATE_PATH,

    ModuleConfig::OPTION_TOKEN_AUTHORIZATION_CODE_TTL => 'PT10M',
    ModuleConfig::OPTION_TOKEN_REFRESH_TOKEN_TTL => 'P1M',
    ModuleConfig::OPTION_TOKEN_ACCESS_TOKEN_TTL => 'PT1H',
    ModuleConfig::OPTION_TOKEN_SIGNER => \Lcobucci\JWT\Signer\Rsa\Sha256::class,

    ModuleConfig::OPTION_AUTH_SOURCE => 'pwauth',
    ModuleConfig::OPTION_AUTH_USER_IDENTIFIER_ATTRIBUTE => 'uid',

    ModuleConfig::OPTION_CRON_TAG => 'hourly',

    ModuleConfig::OPTION_ADMIN_UI_PERMISSIONS => [
        'attribute' => 'uid',
        'client' => [],
    ],
];
