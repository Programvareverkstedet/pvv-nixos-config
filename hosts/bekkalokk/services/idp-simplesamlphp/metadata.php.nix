''
  <?php
  $metadata['https://idp2.pvv.ntnu.no/'] = [
      'metadata-set' => 'saml20-idp-hosted',
      'entityid' => 'https://idp2.pvv.ntnu.no/',
      'SingleSignOnService' => [
          [
              'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
              'Location' => 'https://idp2.pvv.ntnu.no/module.php/saml/idp/singleSignOnService',
          ],
      ],
      'SingleLogoutService' => [
          [
              'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
              'Location' => 'https://idp2.pvv.ntnu.no/module.php/saml/idp/singleLogout',
          ],
      ],
      'NameIDFormat' => [ 'urn:oasis:names:tc:SAML:2.0:nameid-format:transient' ],
      'certificate' => '${./idp.crt}',
  ];
  ?>
''
