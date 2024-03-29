<?php

/**
 * Authenticate using HTTP login.
 *
 * @author Yorn de Jong
 * @author Oystein Kristoffer Tveit
 * @package simpleSAMLphp
 */

namespace SimpleSAML\Module\authpwauth\Auth\Source;

class PwAuth extends \SimpleSAML\Module\core\Auth\UserPassBase
{
    protected $pwauth_bin_path;
    protected $mail_domain;

    public function __construct(array $info, array &$config) {
            assert('is_array($info)');
            assert('is_array($config)');

            /* Call the parent constructor first, as required by the interface. */
            parent::__construct($info, $config);

            $this->pwauth_bin_path = $config['pwauth_bin_path'];
            if (array_key_exists('mail_domain', $config)) {
                    $this->mail_domain = '@' . ltrim($config['mail_domain'], '@');
            }
    }

    public function login(string $username, string $password): array {
            $username = strtolower( $username );

	    if (!file_exists($this->pwauth_bin_path)) {
                    die("Could not find pwauth binary");
                    return false;
	    }

	    if (!is_executable($this->pwauth_bin_path)) {
                    die("pwauth binary is not executable");
                    return false;
	    }

            $handle = popen($this->pwauth_bin_path, 'w');
            if ($handle === FALSE) {
                    die("Error opening pipe to pwauth");
                    return false;
            }

            $data = "$username\n$password\n";
            if (fwrite($handle, $data) !== strlen($data)) {
                    die("Error writing to pwauth pipe");
                    return false;
            }

            # Is the password valid?
            $result = pclose( $handle );
            if ($result !== 0) {
                    if (!in_array($result, [1, 2, 3, 4, 5, 6, 7], true)) {
                            die("pwauth returned $result for username $username");
                    }
                    throw new \SimpleSAML\Error\Error('WRONGUSERPASS');
            }
            /*
            $ldap = ldap_connect('129.241.210.159', 389);
            ldap_set_option($ldap, LDAP_OPT_PROTOCOL_VERSION, 3);
            ldap_start_tls($ldap);
            ldap_bind($ldap, 'passordendrer@pvv.ntnu.no', 'Oi7aekoh');
            $search = ldap_search($ldap, 'DC=pvv,DC=ntnu,DC=no', '(sAMAccountName='.ldap_escape($username, '', LDAP_ESCAPE_FILTER).')');
            $entry = ldap_first_entry($ldap, $search);
            $dn = ldap_get_dn($ldap, $entry);
            $newpassword = mb_convert_encoding("\"$password\"", 'UTF-16LE', 'UTF-8');
            ldap_modify_batch($ldap, $dn, [
                    #[
                    #       'modtype' => LDAP_MODIFY_BATCH_REMOVE,
                    #       'attrib' => 'unicodePwd',
                    #       'values' => [$password],
                    #],
                    [
                            #'modtype' => LDAP_MODIFY_BATCH_ADD,
                            'modtype' => LDAP_MODIFY_BATCH_REPLACE,
                            'attrib' => 'unicodePwd',
                            'values' => [$newpassword],
                    ],
            ]);
            */

            #0  -  Login OK.
            #1  -  Nonexistant login or (for some configurations) incorrect password.
            #2  -  Incorrect password (for some configurations).
            #3  -  Uid number is below MIN_UNIX_UID value configured in config.h.
            #4  -  Login ID has expired.
            #5  -  Login's password has expired.
            #6  -  Logins to system have been turned off (usually by /etc/nologin file).
            #7  -  Limit on number of bad logins exceeded.
            #50 -  pwauth was not run with real uid SERVER_UID.  If you get this
            #      this error code, you probably have SERVER_UID set incorrectly
            #      in pwauth's config.h file.
            #51 -  pwauth was not given a login & password to check.  The means
            #      the passing of data from mod_auth_external to pwauth is messed
            #      up.  Most likely one is trying to pass data via environment
            #      variables, while the other is trying to pass data via a pipe.
            #52 -  one of several possible internal errors occured.


            $uid = $username;
	    # TODO: Reinstate this code once passwd is working...
	    /*
            $cn = trim(shell_exec('getent passwd '.escapeshellarg($uid).' | cut -d: -f5 | cut -d, -f1'));

            $groups = preg_split('_\\s_', shell_exec('groups '.escapeshellarg($uid)));
            array_shift($groups);
            array_shift($groups);
            array_pop($groups);
	    
            $info = posix_getpwnam($uid);
            $group = $info['gid'];
            if (!in_array($group, $groups)) {
                    $groups[] = $group;
            }
	    */
	    $cn = "Unknown McUnknown";
	    $groups = array();

            $result = array(
                    'uid' => array($uid),
                    'cn' => array($cn),
                    'group' => $groups,
            );
            if (isset($this->mail_domain)) {
                    $result['mail'] = array($uid.$this->mail_domain);
            }
            return $result;
    }
}
