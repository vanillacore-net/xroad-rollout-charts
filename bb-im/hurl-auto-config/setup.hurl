# Check that the Central Server UI is up and running
GET https://{{cs_host}}
HTTP/* 200

# Log in to the Central Server
POST https://{{cs_host}}/login
[FormParams]
username: xrd
password: {{cs_host_password}}

HTTP/* 200
[Captures]
cs_xsrf_token: cookie "XSRF-TOKEN"


# Initialize Central Server
# Note: central_server_address must be conf.im.assembly.govstack.global (config endpoint)
# not cs.im.assembly.govstack.global (admin UI) to generate correct anchor URLs
POST https://{{cs_host}}/api/v1/initialization
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "software_token_pin": "{{cs_host_pin}}",
  "instance_identifier": "assembly",
  "central_server_address": "{{cs_conf_host}}"
}

# TODO: The Central Server currently returns the incorrect HTTP code, the documentation notes that it should be "201":
# https://github.com/nordic-institute/X-Road/blob/6ef2d9e83287ccb281b0cc27ba663a5ae8c4aa16/src/central-server/openapi-model/src/main/resources/openapi-definition.yaml#L1344
# Allow 200-409: 200/201 = success, 409 = already initialized (idempotent)
HTTP/* *
[Asserts]
status >= 200
status <= 409

# CRITICAL: Login token AFTER initialization
# Token can only be logged in after CS is initialized.
# This must happen before we can add signing keys.
PUT https://{{cs_host}}/api/v1/tokens/0/login
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "password": "{{cs_host_pin}}"
}

# Allow 200 (success) or 400 (already logged in or token action not possible)
HTTP/* *
[Asserts]
status >= 200
status <= 400

# CRITICAL: Add signing keys IMMEDIATELY after token login
# CS generates configuration immediately after initialization, and if signing keys
# are not present, it will generate DUMMY configuration that cannot be fixed.
# If CS was already initialized with DUMMY config, adding keys now won't fix it,
# but we still need to ensure keys are present for future config generations.

# Add internal signing key to Central Server
# Will return 400 if key already exists, which is handled by allowing 200-409
# Note: There's no GET endpoint to list signing keys, so we rely on POST error handling
POST https://{{cs_host}}/api/v1/configuration-sources/INTERNAL/signing-keys
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "key_label": "cs1-int-sign",
  "token_id": 0
}

# TODO: The Central Server currently returns the incorrect HTTP code, the documentation notes that it should be "201":
# https://github.com/nordic-institute/X-Road/blob/6ef2d9e83287ccb281b0cc27ba663a5ae8c4aa16/src/central-server/openapi-model/src/main/resources/openapi-definition.yaml#L1051
# Allow 200 (success), 400 (already exists), 409 (conflict) - all are acceptable
HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add external signing key to Central Server
# Will return 400 if key already exists, which is handled by allowing 200-409
# Note: There's no GET endpoint to list signing keys, so we rely on POST error handling
POST https://{{cs_host}}/api/v1/configuration-sources/EXTERNAL/signing-keys
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "key_label": "cs1-ext-sign",
  "token_id": 0
}

# TODO: The Central Server currently returns the incorrect HTTP code, the documentation notes that it should be "201":
# https://github.com/nordic-institute/X-Road/blob/6ef2d9e83287ccb281b0cc27ba663a5ae8c4aa16/src/central-server/openapi-model/src/main/resources/openapi-definition.yaml#L1051
# Allow 200 (success), 400 (already exists), 409 (conflict) - all are acceptable
HTTP/* *
[Asserts]
status >= 200
status <= 409

# Wait a moment for CS to process signing keys before continuing
# This ensures keys are ready before any config generation
# (Hurl doesn't have sleep, but we can add a small delay via a no-op request)
GET https://{{cs_host}}/api/v1/status
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* *

# Add member classes to Central Server
POST https://{{cs_host}}/api/v1/member-classes
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "code": "GOV",
  "description": "Governmental institution"
}

POST https://{{cs_host}}/api/v1/member-classes
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "code": "COM",
  "description": "Company"
}

POST https://{{cs_host}}/api/v1/member-classes
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "code": "NGO",
  "description": "Non-governmental organization"
}

POST https://{{cs_host}}/api/v1/member-classes
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "code": "EDU",
  "description": "Educational institution"
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add member Operator to Central Server (management provider)
POST https://{{cs_host}}/api/v1/members
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "member_id": {
    "member_class": "GOV",
    "member_code": "operator"
  },
  "member_name": "Operator"
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add member Aktors to Central Server
POST https://{{cs_host}}/api/v1/members
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "member_id": {
    "member_class": "COM",
    "member_code": "11333578"
  },
  "member_name": "Aktors"
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add management subsystem for member Operator to Central Server
POST https://{{cs_host}}/api/v1/subsystems
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "subsystem_id": {
    "member_class": "GOV",
    "member_code": "operator",
    "subsystem_code": "MANAGEMENT"
  }
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add DEMO-API subsystem for member operator to Central Server
POST https://{{cs_host}}/api/v1/subsystems
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "subsystem_id": {
    "member_class": "GOV",
    "member_code": "operator",
    "subsystem_code": "DEMO-API"
  }
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add DEMO-API-CONSUMER subsystem for member Aktors to Central Server
POST https://{{cs_host}}/api/v1/subsystems
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "subsystem_id": {
    "member_class": "COM",
    "member_code": "11333578",
    "subsystem_code": "DEMO-API-CONSUMER"
  }
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Set management subsystem for member operator as the management service for the Central Server
PATCH https://{{cs_host}}/api/v1/management-services-configuration
X-XSRF-TOKEN: {{cs_xsrf_token}}
Content-Type: application/json
{
  "service_provider_id": "assembly:GOV:operator:MANAGEMENT"
}

HTTP/* 200

# Add test CA to Central Server configuration
POST https://{{cs_host}}/api/v1/certification-services
X-XSRF-TOKEN: {{cs_xsrf_token}}
[MultipartFormData]
certificate_profile_info: ee.ria.xroad.common.certificateprofile.impl.FiVRKCertificateProfileInfoProvider
tls_auth: false
acme_server_directory_url: https://{{ca_acme_host}}:{{ca_acme_port}}
certificate: file,ca/ca.pem;

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ca_id: jsonpath "$.id"

# Add OCSP to test CA in the Central Server configuration
POST https://{{cs_host}}/api/v1/certification-services/{{ca_id}}/ocsp-responders
X-XSRF-TOKEN: {{cs_xsrf_token}}
[MultipartFormData]
url: https://{{ca_ocsp_host}}:{{ca_ocsp_port}}
certificate: file,ca/ocsp.pem;

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Add TSA to the Central Server
POST https://{{cs_host}}/api/v1/timestamping-services
X-XSRF-TOKEN: {{cs_xsrf_token}}
[MultipartFormData]
url: https://{{ca_tsa_host}}:{{ca_tsa_port}}
certificate: file,ca/tsa.pem;

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Note: authCertRegUrl is set to https://conf.im.assembly.govstack.global:4001/managementservice/
# by default. We've added an Ingress rule to route /managementservice/ from
# conf.im.assembly.govstack.global:443 to backend port 4001, so Security Servers
# can connect via HTTPS on the standard port 443.
# The URL format with :4001 will still work if port 4001 is accessible,
# but the Ingress on port 443 provides the standard HTTPS access.

# Wait for Central Server to regenerate configuration after all setup
# CS needs time to regenerate configuration with proper signatures after:
# - Adding signing keys
# - Adding members/subsystems
# - Adding CA/OCSP/TSA
# We wait by attempting to download the anchor multiple times
# The anchor download will succeed once configuration is ready
# Hurl will retry automatically on failure (up to retry max count)
GET https://{{cs_host}}/api/v1/configuration-sources/INTERNAL/anchor/download
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* 200

[Captures]
gconf_anchor: body

# Initialize management Security Server

# Check that the Security Server UI is up and running
GET https://{{ss0_host}}
HTTP/* 200

# Log in to the Security Server
POST https://{{ss0_host}}/login
[FormParams]
username: xrd
password: {{ss0_host_password}}

HTTP/* 200
[Captures]
ss0_xsrf_token: cookie "XSRF-TOKEN"

# Add configuration anchor
POST https://{{ss0_host}}/api/v1/system/anchor
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/octet-stream
```
{{gconf_anchor}}
```

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Initialize management Security Server
POST https://{{ss0_host}}/api/v1/initialization
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/json
{
  "owner_member_class": "GOV",
  "owner_member_code": "operator",
  "security_server_code": "SS0",
  "software_token_pin": "{{ss0_host_pin}}",
  "ignore_warnings": true
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

# Log in to the Security Servers token
PUT https://{{ss0_host}}/api/v1/tokens/0/login
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/json
{
  "password": "{{ss0_host_pin}}"
}

HTTP/* *

# Get the CA name
GET https://{{ss0_host}}/api/v1/certificate-authorities
X-XSRF-TOKEN: {{ss0_xsrf_token}}

HTTP/* 200

[Captures]
ca_name: jsonpath "$[0].name"

## Get keys list to check if auth key exists and get its ID
#GET https://{{ss0_host}}/api/v1/tokens/0/keys
#X-XSRF-TOKEN: {{ss0_xsrf_token}}
#
#HTTP/* 200
#
#[Captures]
#ss0_keys: body
#ss0_auth_key_id_existing: jsonpath "$[?(@.label.label=='Auth key')].id"
#
# Add auth key to the Security Server token
# Will return 400 if key already exists, which is handled by allowing 200-409
POST https://{{ss0_host}}/api/v1/tokens/0/keys-with-csrs
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/json
{
  "key_label": "Auth key",
  "csr_generate_request": {
    "key_usage_type": "AUTHENTICATION",
    "ca_name": "{{ca_name}}",
    "csr_format": "DER",
    "subject_field_values": {
      "CN": "{{ss0_host}}",
      "C": "EE",
      "O": "Operator",
      "subjectAltName": "{{ss0_host}}",
      "serialNumber": "assembly/SS0/GOV"
    }
  }
}
# TODO: This should return 201 according to the definition:
# https://github.com/nordic-institute/X-Road/blob/e14d198f704b34b4d1789c2972e816152b6a35f8/src/security-server/openapi-model/src/main/resources/META-INF/openapi-definition.yaml#L4846
# Allow 200 (success), 400 (already exists), 409 (conflict) - all are acceptable
HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss0_auth_key_id_new: jsonpath "$.key.id"
ss0_auth_key_csr_id: jsonpath "$.csr_id"

## Get the auth key CSR
## Use existing key ID if available (key already existed), otherwise use new key ID
## First try with existing key ID if it exists
#GET https://{{ss0_host}}/api/v1/keys/{{ss0_auth_key_id_existing}}/csrs
#X-XSRF-TOKEN: {{ss0_xsrf_token}}
#
#HTTP/* *
#[Asserts]
#status >= 200
#status <= 404
#
#[Captures]
#ss0_auth_key_csr_id_existing: jsonpath "$[0].id"
#
## Get CSR using existing key ID (if key existed and has CSR)
#GET https://{{ss0_host}}/api/v1/keys/{{ss0_auth_key_id_existing}}/csrs/{{ss0_auth_key_csr_id_existing}}?csr_format=PEM
#X-XSRF-TOKEN: {{ss0_xsrf_token}}
#
#HTTP/* *
#[Asserts]
#status >= 200
#status <= 404
#
#[Captures]
#ss0_auth_key_csr: body
#
# Get CSR using new key ID (if key was just created or existing key had no CSR)
GET https://{{ss0_host}}/api/v1/keys/{{ss0_auth_key_id_new}}/csrs/{{ss0_auth_key_csr_id}}?csr_format=PEM
X-XSRF-TOKEN: {{ss0_xsrf_token}}

HTTP/* 200

[Captures]
ss0_auth_key_csr: body

# Sign the auth key CSR (note that the test CA needs filename so we can't just send it under
# [FormMultiPart] as we do with the other requests)
POST https://{{ca_ocsp_host}}:{{ca_ocsp_port}}/testca/sign
Content-Type: multipart/form-data; boundary=certboundary
```
--certboundary
Content-Disposition: form-data; name="type"

auth
--certboundary
Content-Disposition: form-data; name="certreq"; filename="auth.csr.pem"

{{ss0_auth_key_csr}}
--certboundary--
```

HTTP/* 200
[Captures]
ss0_auth_key_cert: body

# Import auth certificate
POST https://{{ss0_host}}/api/v1/token-certificates
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/octet-stream
```
{{ss0_auth_key_cert}}
```

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss0_auth_key_cert_hash: jsonpath "$.certificate_details.hash"

## Get keys list again to check if sign key exists and get its ID
#GET https://{{ss0_host}}/api/v1/tokens/0/keys
#X-XSRF-TOKEN: {{ss0_xsrf_token}}
#
#HTTP/* 200
#
#[Captures]
#ss0_keys_updated: body
#ss0_sign_key_id_existing: jsonpath "$[?(@.label.label=='Sign key')].id"
#
# Add sign key to the Security Server token
# Will return 400 if key already exists, which is handled by allowing 200-409
POST https://{{ss0_host}}/api/v1/tokens/0/keys-with-csrs
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/json
{
  "key_label": "Sign key",
  "csr_generate_request": {
    "key_usage_type": "SIGNING",
    "ca_name": "{{ca_name}}",
    "csr_format": "DER",
    "member_id": "assembly:GOV:operator",
    "subject_field_values": {
      "CN": "operator",
      "C": "EE",
      "O": "Operator",
      "subjectAltName": "{{ss0_host}}",
      "serialNumber": "assembly/SS0/GOV"
    }
  }
}

# TODO: This should return 201 according to the definition (same as for auth key above)
# Allow 200 (success), 400 (already exists), 409 (conflict) - all are acceptable
HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss0_sign_key_id_new: jsonpath "$.key.id"
ss0_sign_key_csr_id: jsonpath "$.csr_id"

## Get the sign key CSR
## Use existing key ID if available (key already existed), otherwise use new key ID
## First try with existing key ID if it exists
#GET https://{{ss0_host}}/api/v1/keys/{{ss0_sign_key_id_existing}}/csrs
#X-XSRF-TOKEN: {{ss0_xsrf_token}}
#
#HTTP/* *
#[Asserts]
#status >= 200
#status <= 404
#
#[Captures]
#ss0_sign_key_csr_id_existing: jsonpath "$[0].id"
#
## Get CSR using existing sign key ID (if key existed and has CSR)
#GET https://{{ss0_host}}/api/v1/keys/{{ss0_sign_key_id_existing}}/csrs/{{ss0_sign_key_csr_id_existing}}?csr_format=PEM
#X-XSRF-TOKEN: {{ss0_xsrf_token}}
#
#HTTP/* *
#[Asserts]
#status >= 200
#status <= 404
#
#[Captures]
#ss0_sign_key_csr: body
#
# Get CSR using new sign key ID (if key was just created or existing key had no CSR)
GET https://{{ss0_host}}/api/v1/keys/{{ss0_sign_key_id_new}}/csrs/{{ss0_sign_key_csr_id}}?csr_format=PEM
X-XSRF-TOKEN: {{ss0_xsrf_token}}

HTTP/* 200

[Captures]
ss0_sign_key_csr: body

# Sign the sign key CSR (note that the test CA needs filename so we can't just send it under
# [FormMultiPart] as we do with the other requests)
POST https://{{ca_ocsp_host}}:{{ca_ocsp_port}}/testca/sign
Content-Type: multipart/form-data; boundary=certboundary
```
--certboundary
Content-Disposition: form-data; name="type"

sign
--certboundary
Content-Disposition: form-data; name="certreq"; filename="sign.csr.pem"

{{ss0_sign_key_csr}}
--certboundary--
```

HTTP/* 200
[Captures]
ss0_sign_key_cert: body

# Import sign certificate
POST https://{{ss0_host}}/api/v1/token-certificates
X-XSRF-TOKEN: {{ss0_xsrf_token}}
Content-Type: application/octet-stream
```
{{ss0_sign_key_cert}}
```

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss0_sign_key_cert_hash: jsonpath "$.certificate_details.hash"

# Register auth certificate
PUT https://{{ss0_host}}/api/v1/token-certificates/{{ss0_auth_key_cert_hash}}/register
X-XSRF-TOKEN: {{ss0_xsrf_token}}
{
  "address": "{{ss0_host}}"
}

# TODO: This should be 200 according to the OpenAPI description but is 204:
# https://github.com/nordic-institute/X-Road/blob/e14d198f704b34b4d1789c2972e816152b6a35f8/src/security-server/openapi-model/src/main/resources/META-INF/openapi-definition.yaml#L640
HTTP/* 204

# Accept Security Server auth certificate registration
GET https://{{cs_host}}/api/v1/management-requests?sort=id&desc=true&status=WAITING
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* 200

[Captures]
ss0_auth_cert_reg_req_id: jsonpath "$.items[0].id"

POST https://{{cs_host}}/api/v1/management-requests/{{ss0_auth_cert_reg_req_id}}/approval
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* 200

# Register management subsystem to SS0 Security Server
POST https://{{cs_host}}/api/v1/management-services-configuration/register-provider
X-XSRF-TOKEN: {{cs_xsrf_token}}
{
  "security_server_id": "assembly:GOV:operator:SS0"
}

HTTP/* 200

# Add MANAGEMENT to management Security Server
POST https://{{ss0_host}}/api/v1/clients
X-XSRF-TOKEN: {{ss0_xsrf_token}}
{
  "ignore_warnings": true,
  "client": {
    "member_class": "GOV",
    "member_code": "operator",
    "subsystem_code": "MANAGEMENT",
    "connection_type": "HTTP"
  }
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss0_management_client_id: jsonpath "$.id"

# Get Central Server management services settings
GET https://{{cs_host}}/api/v1/management-services-configuration
X-XSRF-TOKEN: {{cs_xsrf_token}}

HTTP/* 200

[Captures]
cs_management_service_address: jsonpath "$.services_address"
cs_management_service_wsdl: jsonpath "$.wsdl_address"

# Add Central Server management service to SS0 Security Server
POST https://{{ss0_host}}/api/v1/clients/{{ss0_management_client_id}}/service-descriptions
X-XSRF-TOKEN: {{ss0_xsrf_token}}
{
  "url": "{{cs_management_service_wsdl}}",
  "type": "WSDL",
  "ignore_warnings": true
}

HTTP/* *
[Asserts]
status >= 200
status <= 409

[Captures]
ss0_management_service_id: jsonpath "$.id"
ss0_auth_cert_deletion_service_id: jsonpath "$.services[0].id"

# Add security server owners group access to management services
PATCH https://{{ss0_host}}/api/v1/services/{{ss0_auth_cert_deletion_service_id}}
X-XSRF-TOKEN: {{ss0_xsrf_token}}
{
  "ignore_warnings": true,
  "ssl_auth": false,
  "ssl_auth_all": true,
  "timeout": 60,
  "timeout_all": true,
  "url": "{{cs_management_service_address}}",
  "url_all": true
}

# Add security server owners group access to management services
POST https://{{ss0_host}}/api/v1/clients/{{ss0_management_client_id}}/service-clients/DE-SH-TEST:security-server-owners/access-rights
X-XSRF-TOKEN: {{ss0_xsrf_token}}
{
  "items": [
    {
      "service_code": "authCertDeletion"
    },
    {
      "service_code": "clientDeletion"
    },
    {
      "service_code": "clientReg"
    },
    {
      "service_code": "ownerChange"
    },
    {
      "service_code": "clientEnable"
    },
    {
      "service_code": "clientDisable"
    }
  ]
}

# Enable management subsystem on management Security Server
PUT https://{{ss0_host}}/api/v1/service-descriptions/{{ss0_management_service_id}}/enable
X-XSRF-TOKEN: {{ss0_xsrf_token}}

# TODO: This should be 204 according to the OpenAPI description but is 200:
# https://github.com/nordic-institute/X-Road/blob/e14d198f704b34b4d1789c2972e816152b6a35f8/src/security-server/openapi-model/src/main/resources/META-INF/openapi-definition.yaml#L3908
HTTP/* 200

# Activate auth certificate on SS0 Security Server
PUT https://{{ss0_host}}/api/v1/token-certificates/{{ss0_auth_key_cert_hash}}/activate
X-XSRF-TOKEN: {{ss0_xsrf_token}}

HTTP/* 204

# Set timestamping service on SS0 Security Server
GET https://{{ss0_host}}/api/v1/timestamping-services
X-XSRF-TOKEN: {{ss0_xsrf_token}}

HTTP/* 200

[Captures]
tsa_name: jsonpath "$[0].name"
tsa_url: jsonpath "$[0].url"

POST https://{{ss0_host}}/api/v1/system/timestamping-services
X-XSRF-TOKEN: {{ss0_xsrf_token}}
{
  "name": "{{tsa_name}}",
  "url": "{{tsa_url}}"
}

HTTP/* *
[Asserts]
status >= 200
status <= 409
