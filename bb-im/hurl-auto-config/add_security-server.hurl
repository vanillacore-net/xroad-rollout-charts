# Add a new Security Server to the existing cs1/ss0 setup
# This script reuses ss1 variables (ss1_host, ss1_host_password, ss1_host_pin)
# to configure a new security server (ss2, ss3, etc.)
#
# Variables expected:
#   - ss1_host: hostname of the new security server to add
#   - ss1_host_password: password for the security server UI
#   - ss1_host_pin: PIN for the security server token
#   - ss_number: the security server number (e.g., "2" for SS2, "3" for SS3)
#   - owner_member_code: member code for the owner (e.g., "SH", "SH-ZIT")
#   - owner_org_name: organization name for certificates (e.g., "SH", "ZIT")
#   - cs_host: hostname of the central server (should already be logged in)
#   - cs_xsrf_token: XSRF token from previous CS login
#   - gconf_anchor: global configuration anchor from CS
#   - ca_name: CA name from previous setup
#   - tsa_name: TSA name from previous setup
#   - tsa_url: TSA URL from previous setup
#   - ca_ocsp_host: OCSP host
#   - ca_ocsp_port: OCSP port

# Initialize new Security Server

# Check that the Security Server UI is up and running
GET https://{{ss1_host}}:4000
HTTP/* 200

# Log in to the Security Server
POST https://{{ss1_host}}:4000/login
[FormParams]
username: xrd
password: {{ss1_host_password}}

HTTP/* 200
[Captures]
ss1_xsrf_token: cookie "XSRF-TOKEN"

# Add configuration anchor
POST https://{{ss1_host}}:4000/api/v1/system/anchor
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/octet-stream
```
{{gconf_anchor}}
```

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Initialize Security Server
POST https://{{ss1_host}}:4000/api/v1/initialization
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/json
{
  "owner_member_class": "GOV",
  "owner_member_code": "{{owner_member_code}}",
  "security_server_code": "SS{{ss_number}}",
  "software_token_pin": "{{ss1_host_pin}}",
  "ignore_warnings": true
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Log in to the Security Server token
PUT https://{{ss1_host}}:4000/api/v1/tokens/0/login
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/json
{
  "password": "{{ss1_host_pin}}"
}

HTTP/* *

# Add auth key to the Security Server token
POST https://{{ss1_host}}:4000/api/v1/tokens/0/keys-with-csrs
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/json
{
  "key_label": "Auth key",
  "csr_generate_request": {
    "key_usage_type": "AUTHENTICATION",
    "ca_name": "{{ca_name}}",
    "csr_format": "DER",
    "subject_field_values": {
      "CN": "{{ss1_host}}",
      "C": "DE",
      "O": "{{owner_org_name}}",
      "subjectAltName": "{{ss1_host}}",
      "serialNumber": "DE-SH-TEST/SS{{ss_number}}/GOV"
    }
  }
}
# TODO: This should return 201 according to the definition:
# https://github.com/nordic-institute/X-Road/blob/e14d198f704b34b4d1789c2972e816152b6a35f8/src/security-server/openapi-model/src/main/resources/META-INF/openapi-definition.yaml#L4846
HTTP/* 200

[Captures]
ss1_auth_key_id: jsonpath "$.key.id"
ss1_auth_key_csr_id: jsonpath "$.csr_id"

# Get the auth key CSR
GET https://{{ss1_host}}:4000/api/v1/keys/{{ss1_auth_key_id}}/csrs/{{ss1_auth_key_csr_id}}?csr_format=PEM
X-XSRF-TOKEN: {{ss1_xsrf_token}}

HTTP/* 200

[Captures]
ss1_auth_key_csr: body

# Sign the auth key CSR (note that the test CA needs filename so we can't just send it under
# [FormMultiPart] as we do with the other requests)
POST http://{{ca_ocsp_host}}:{{ca_ocsp_port}}/testca/sign
Content-Type: multipart/form-data; boundary=certboundary
```
--certboundary
Content-Disposition: form-data; name="type"

auth
--certboundary
Content-Disposition: form-data; name="certreq"; filename="auth.csr.pem"

{{ss1_auth_key_csr}}
--certboundary--
```

HTTP/* 200
[Captures]
ss1_auth_key_cert: body

# Import auth certificate
POST https://{{ss1_host}}:4000/api/v1/token-certificates
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/octet-stream
```
{{ss1_auth_key_cert}}
```

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss1_auth_key_cert_hash: jsonpath "$.certificate_details.hash"

# Add sign key to the Security Server token
POST https://{{ss1_host}}:4000/api/v1/tokens/0/keys-with-csrs
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/json
{
  "key_label": "Sign key",
  "csr_generate_request": {
    "key_usage_type": "SIGNING",
    "ca_name": "{{ca_name}}",
    "csr_format": "DER",
    "member_id": "DE-SH-TEST:GOV:{{owner_member_code}}",
    "subject_field_values": {
      "CN": "{{owner_org_name}}",
      "C": "DE",
      "O": "{{owner_org_name}}",
      "subjectAltName": "{{ss1_host}}",
      "serialNumber": "DE-SH-TEST/SS{{ss_number}}/GOV"
    }
  }
}

# TODO: This should return 201 according to the definition (same as for auth key above)
HTTP/* 200

[Captures]
ss1_sign_key_id: jsonpath "$.key.id"
ss1_sign_key_csr_id: jsonpath "$.csr_id"

# Get the sign key CSR
GET https://{{ss1_host}}:4000/api/v1/keys/{{ss1_sign_key_id}}/csrs/{{ss1_sign_key_csr_id}}?csr_format=PEM
X-XSRF-TOKEN: {{ss1_xsrf_token}}

HTTP/* 200

[Captures]
ss1_sign_key_csr: body

# Sign the sign key CSR (note that the test CA needs filename so we can't just send it under
# [FormMultiPart] as we do with the other requests)
POST http://{{ca_ocsp_host}}:{{ca_ocsp_port}}/testca/sign
Content-Type: multipart/form-data; boundary=certboundary
```
--certboundary
Content-Disposition: form-data; name="type"

sign
--certboundary
Content-Disposition: form-data; name="certreq"; filename="sign.csr.pem"

{{ss1_sign_key_csr}}
--certboundary--
```

HTTP/* 200
[Captures]
ss1_sign_key_cert: body

# Import sign certificate
POST https://{{ss1_host}}:4000/api/v1/token-certificates
X-XSRF-TOKEN: {{ss1_xsrf_token}}
Content-Type: application/octet-stream
```
{{ss1_sign_key_cert}}
```

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss1_sign_key_cert_hash: jsonpath "$.certificate_details.hash"


# Register auth certificate
PUT https://{{ss1_host}}:4000/api/v1/token-certificates/{{ss1_auth_key_cert_hash}}/register
X-XSRF-TOKEN: {{ss1_xsrf_token}}
{
  "address": "{{ss1_host}}"
}

# TODO: This should be 200 according to the OpenAPI description but is 204:
# https://github.com/nordic-institute/X-Road/blob/e14d198f704b34b4d1789c2972e816152b6a35f8/src/security-server/openapi-model/src/main/resources/META-INF/openapi-definition.yaml#L640
HTTP/* 204

# Accept Security Server auth certificate registration
GET https://{{cs_host}}{{cs_host_port}}/api/v1/management-requests?sort=id&desc=true&status=WAITING
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* 200

[Captures]
ss1_auth_cert_reg_req_id: jsonpath "$.items[0].id"

POST https://{{cs_host}}{{cs_host_port}}/api/v1/management-requests/{{ss1_auth_cert_reg_req_id}}/approval
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* 200

# Activate auth certificate on Security Server
PUT https://{{ss1_host}}:4000/api/v1/token-certificates/{{ss1_auth_key_cert_hash}}/activate
X-XSRF-TOKEN: {{ss1_xsrf_token}}

HTTP/* 204

# Set timestamping service on Security Server
POST https://{{ss1_host}}:4000/api/v1/system/timestamping-services
X-XSRF-TOKEN: {{ss1_xsrf_token}}
{
  "name": "{{tsa_name}}",
  "url": "{{tsa_url}}"
}

HTTP/* *
[Asserts]
status >= 200
status <= 409
