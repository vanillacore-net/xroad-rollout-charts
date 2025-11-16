# Certificates
## Instructions

- run `generate_certs_testca_eab.sh` to renew certificates
- NOTE: certs are symlinked, this will only work on Linux or MacOS

### ACME specifics

You will need external account binding (EAB) credentials:
Access the running test-ca pod (if you have kubectl access):
  `kubectl exec -it -n im-ns <test-ca-pod-name> -- cat /var/www/acme2certifier/examples/eab_handler/kid_profiles.json`

**Note:** The test-ca pod is in the `im-ns` namespace (not `test-ca`).

Default values:
`
{
  "keyid_1": {
    "hmac": "78a6d08bb1d1b91ab116790e1ab59517352fa5e0c8ac360c3a80255d80de2259"
  },
  "keyid_2": {
    "hmac": "addfdbb19965e85623c124a88d085eae50a7f7f4f570989e3a320a81c3119625",
    "cahandler": {
      "profile_id": "auth"
    }
  },
  "keyid_3": {
    "hmac": "96d7380f5ea8de06912a4520d0adca616848b5e70cb3d0bd748af5b33507ddde",
    "cahandler": {
      "profile_id": "sign"
    }
  }
}
`

## Docs
Read more about certs here
- https://nordic-institute.atlassian.net/wiki/spaces/XRDKB/pages/4916191/What+Kind+of+Keys+and+Certificates+the+Security+Server+Has
- https://nordic-institute.atlassian.net/wiki/spaces/XRDKB/pages/4915640/How%2Bto%2BChange%2Bthe%2BSecurity%2BServer%2BUI%2BAPI%2BTLS%2BCertificate