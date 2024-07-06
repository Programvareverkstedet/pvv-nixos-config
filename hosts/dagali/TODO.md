# Tracking document for new PVV kerberos auth stack

![Bensinstasjon på heimdal](https://bydelsnytt.no/wp-content/uploads/2022/08/esso_heimdal003.jpg)

<div align="center">
  Bensinstasjon på heimdal
</div>

### TODO:

- [ ] setup heimdal
  - [x] ensure running with systemd
  - [x] compile smbk5pwd (part of openldap)
  - [ ] set `modify -a -disallow-all-tix,requires-pre-auth default` declaratively
  - [ ] fully initialize PVV.NTNU.NO
    - [x] `kadmin -l init PVV.NTNU.NO`
    - [x] add oysteikt/admin@PVV.NTNU.NO principal
    - [x] add oysteikt@PVV.NTNU.NO principal
    - [x] add krbtgt/PVV.NTNU.NO@PVV.NTNU.NO principal?
      - why is this needed, and where is it documented?
      - `kadmin check` seems to work under sudo?
      - (it is included by default, just included as error message
         in a weird state)

    - [x] Ensure client is working correctly
      - [x] Ensure kinit works on darbu
      - [x] Ensure kpasswd works on darbu
      - [x] Ensure kadmin get <user> (and other restricted commands) works on darbu

    - [ ] Ensure kdc is working correctly
      - [x] Ensure kinit works on dagali
      - [x] Ensure kpasswd works on dagali
      - [ ] Ensure kadmin get <user> (and other restricte commands) works on dagali

    - [x] Fix FQDN
      - https://github.com/NixOS/nixpkgs/issues/94011
      - https://github.com/NixOS/nixpkgs/issues/261269
      - Possibly fixed by disabling systemd-resolved

- [ ] setup cyrus sasl
  - [x] ensure running with systemd 
  - [x] verify GSSAPI support plugin is installed
    - `nix-shell -p cyrus_sasl --command pluginviewer`
  - [x] create "host/localhost@PVV.NTNU.NO" and export to keytab
  - [x] verify cyrus sasl is able to talk to heimdal
    - `sudo testsaslauthd -u oysteikt -p <password>`
  - [ ] provide ldap principal to cyrus sasl through keytab

- [ ] setup openldap
  - [x] ensure running with systemd
  - [ ] verify openldap is able to talk to cyrus sasl
  - [ ] create user for oysteikt in openldap
  - [ ] authenticate openldap login through sasl
    - does this require creating an ldap user?

- [ ] fix smbk5pwd integration
  - [x] add smbk5pwd schemas to openldap
  - [x] create openldap db for smbk5pwd with overlays
  - [ ] test to ensure that user sync is working
  - [ ] test as user source (replace passwd)
  - [ ] test as PAM auth source
  - [ ] test as auth source for 3rd party appliation

- [ ] Set up ldap administration panel
  - Doesn't seem like there are many good ones out there. Maybe phpLDAPAdmin?

- [ ] Set up kerberos SRV DNS entry

### Information and URLS

- OpenLDAP SASL: https://www.openldap.org/doc/admin24/sasl.html
- Use a keytab: https://kb.iu.edu/d/aumh
- 2 ways for openldap to auth: https://security.stackexchange.com/questions/65093/how-to-test-ldap-that-authenticates-with-kerberos
- Cyrus guide OpenLDAP + SASL + GSSAPI: https://www.cyrusimap.org/sasl/sasl/faqs/openldap-sasl-gssapi.html
- Configuring GSSAPI and Cyrus SASL: https://web.mit.edu/darwin/src/modules/passwordserver_sasl/cyrus_sasl/doc/gssapi.html
- PVV Kerberos docs: https://wiki.pvv.ntnu.no/wiki/Drift/Kerberos
- OpenLDAP smbk5pwd source: https://git.openldap.org/nivanova/openldap/-/tree/master/contrib/slapd-modules/smbk5pwd
- saslauthd(8): https://linux.die.net/man/8/saslauthd
