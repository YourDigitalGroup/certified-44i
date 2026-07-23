<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * Localized language
 * * ABSPATH
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'certified44i_wp_6ogwt' );

/** Database username */
define( 'DB_USER', 'certified44i_wp_6jwmj' );

/** Database password */
define( 'DB_PASSWORD', 'dnp#5WM1EvFB6xL~' );

/** Database hostname */
define( 'DB_HOST', 'localhost:3306' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         'ei]u5NFj!L=I7fUVm`L8?oa-u{I*}c5Ui}?z{ATq7I%Y]utOe+YVm[>9eKG8?Dk|');
define('SECURE_AUTH_KEY',  'DS7qGzk/@wEfC=qNMAuj@h:fI]fXKjzJRg~C^x f102!u%WDm0u7BL&j7J1]p^(v');
define('LOGGED_IN_KEY',    '(AIDjLeUFJLk8jo8+d:n/5yk[lM_$8*S6>p)HX.gR$LT;!E5eAQc4Ph^S-9=0DDb');
define('NONCE_KEY',        'sFJ&/?(}Uji.q=W1(263rZQE?C#eb;kHZ!~u[~F;7^Op$9!w(cZbDzFU;|(.JK[>');
define('AUTH_SALT',        'o=C#ysC D<1W}t:&,<-+Et;uOMCSy>z4IZ~oZAn<+h5$53sSo-bB##|n.;P6JcNT');
define('SECURE_AUTH_SALT', '[#|(7Z_QOHYZj|iW,&%b2^B2ZOW+{5+m%@B)+amtBt.R hxOoC4S):o`Foc!poF$');
define('LOGGED_IN_SALT',   'Jy{d9S<fD3nxL5;2m`-P~Jm_Y|YH< NlG{FRA@d$03yC@E_w%C2Pp-;mzvwPt:oG');
define('NONCE_SALT',       ']3I3O-m%US!hjAAiuE..g:VJF---~am-v25vlU8(wA4T:N_<7BR?Zo,i>0*^D2tU');


/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'r4qZUM_';


/* Add any custom values between this line and the "stop editing" line. */

define('WP_ALLOW_MULTISITE', true);
/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
if ( ! defined( 'WP_DEBUG' ) ) {
	define( 'WP_DEBUG', true );
  define('WP_DEBUG_LOG', true);
  define('WP_DEBUG_DISPLAY', false);

}

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
