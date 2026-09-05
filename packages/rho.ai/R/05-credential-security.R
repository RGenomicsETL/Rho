RhoCredentialEncryptionSecret <- S7::new_class(
  "RhoCredentialEncryptionSecret",
  abstract = TRUE
)

RhoCredentialPassphrase <- S7::new_class(
  "RhoCredentialPassphrase",
  parent = RhoCredentialEncryptionSecret,
  properties = list(passphrase = rho_non_empty_string)
)

RhoCredentialEncryptionKey <- S7::new_class(
  "RhoCredentialEncryptionKey",
  parent = RhoCredentialEncryptionSecret,
  properties = list(key = S7::class_raw),
  validator = function(self) {
    if (length(self@key) != 32L) "@key must contain exactly 32 bytes"
  }
)

RhoEncryptedFileCredentialStore <- S7::new_class(
  "RhoEncryptedFileCredentialStore",
  parent = RhoFileCredentialStore,
  properties = list(secret = RhoCredentialEncryptionSecret)
)

RhoKeychainCredentialStore <- S7::new_class(
  "RhoKeychainCredentialStore",
  parent = RhoPersistentCredentialStore,
  properties = list(
    service = rho_non_empty_string,
    backend = S7::class_any
  ),
  validator = function(self) {
    if (!inherits(self@backend, "backend_keyrings")) {
      return("@backend must be a keyring backend with native keychain support")
    }
    if (inherits(self@backend, "backend_env") || inherits(self@backend, "backend_file")) {
      "@backend must not store credentials in environment variables or a keyring file"
    }
  }
)

rho_credential_passphrase <- function(passphrase) {
  RhoCredentialPassphrase(passphrase = passphrase)
}

rho_credential_encryption_key <- function(key) {
  RhoCredentialEncryptionKey(key = key)
}

rho_encrypted_file_credential_store <- function(path, providers, secret) {
  if (length(providers)) {
    names(providers) <- vapply(providers, function(provider) provider@id, character(1))
  }
  state <- new.env(parent = emptyenv())
  state$queue <- rho.async::rho_serial_queue()
  RhoEncryptedFileCredentialStore(
    path = path,
    providers = providers,
    secret = secret,
    state = state
  )
}

rho_native_keychain_backend <- function() {
  if (identical(.Platform$OS.type, "windows")) {
    return(keyring::backend_wincred$new())
  }
  if (identical(Sys.info()[["sysname"]], "Darwin")) {
    return(keyring::backend_macos$new())
  }
  keyring::backend_secret_service$new()
}

rho_keychain_credential_store <- function(providers, service = "Rho", backend = NULL) {
  if (is.null(backend)) {
    backend <- rho_native_keychain_backend()
  }
  if (length(providers)) {
    names(providers) <- vapply(providers, function(provider) provider@id, character(1))
  }
  state <- new.env(parent = emptyenv())
  state$queue <- rho.async::rho_serial_queue()
  RhoKeychainCredentialStore(
    service = service,
    backend = backend,
    providers = providers,
    state = state
  )
}

rho_credential_encryption_descriptor <- S7::new_generic(
  "rho_credential_encryption_descriptor",
  "secret",
  function(secret, ...) S7::S7_dispatch()
)

rho_credential_encryption_key_material <- S7::new_generic(
  "rho_credential_encryption_key_material",
  "secret",
  function(secret, descriptor, store, ...) S7::S7_dispatch()
)

S7::method(
  rho_credential_encryption_descriptor,
  RhoCredentialPassphrase
) <- function(secret, ...) {
  salt <- tryCatch(
    nanonext::random(16L, convert = FALSE),
    error = function(error) error
  )
  if (inherits(salt, "error") || !is.raw(salt) || length(salt) != 16L) {
    return(rho_auth_error(
      "Could not generate a credential-encryption salt",
      code = "credential_store_encryption"
    ))
  }
  list(name = "argon2id", salt = base64enc::base64encode(salt))
}

S7::method(
  rho_credential_encryption_descriptor,
  RhoCredentialEncryptionKey
) <- function(secret, ...) {
  list(name = "direct-32byte")
}

rho_encrypted_credential_salt <- function(descriptor, store) {
  valid <- is.list(descriptor) &&
    identical(descriptor$name, "argon2id") &&
    is.character(descriptor$salt) &&
    length(descriptor$salt) == 1L &&
    !is.na(descriptor$salt) &&
    nzchar(descriptor$salt)
  if (!valid) {
    return(rho_credential_document_error(
      "Encrypted credential store has no valid Argon2id salt",
      store@path,
      "credential_store_format"
    ))
  }
  salt <- tryCatch(base64enc::base64decode(descriptor$salt), error = function(error) error)
  if (inherits(salt, "error") || !is.raw(salt) || length(salt) != 16L) {
    return(rho_credential_document_error(
      "Encrypted credential store has an invalid Argon2id salt",
      store@path,
      "credential_store_format"
    ))
  }
  salt
}

S7::method(
  rho_credential_encryption_key_material,
  RhoCredentialPassphrase
) <- function(secret, descriptor, store, ...) {
  salt <- rho_encrypted_credential_salt(descriptor, store)
  if (S7::S7_inherits(salt, ProviderErrorValue)) {
    return(salt)
  }
  key <- tryCatch(
    rmonocypher::argon2(secret@passphrase, salt = salt, type = "raw"),
    error = function(error) error
  )
  if (inherits(key, "error") || !is.raw(key) || length(key) != 32L) {
    return(rho_credential_document_error(
      "Could not derive an encrypted credential-store key",
      store@path,
      "credential_store_encryption"
    ))
  }
  key
}

S7::method(
  rho_credential_encryption_key_material,
  RhoCredentialEncryptionKey
) <- function(secret, descriptor, store, ...) {
  if (!is.list(descriptor) || !identical(descriptor$name, "direct-32byte")) {
    return(rho_credential_document_error(
      "Encrypted credential store requires a passphrase or matching 32-byte key",
      store@path,
      "credential_store_key"
    ))
  }
  secret@key
}

rho_encrypted_credential_metadata <- function(document) {
  provider_ids <- sort(names(document$credentials))
  metadata <- list()
  for (provider_id in provider_ids) {
    credential <- document$credentials[[provider_id]]
    metadata[[provider_id]] <- list(
      provider = credential$provider,
      kind = credential$kind
    )
  }
  metadata
}

rho_encrypted_credential_aad <- function(envelope, store) {
  authenticated <- list(
    format = envelope$format,
    version = envelope$version,
    cipher = envelope$cipher,
    kdf = envelope$kdf,
    metadata = envelope$metadata
  )
  encoded <- tryCatch(
    yyjsonr::write_json_str(authenticated, auto_unbox = TRUE, null = "null"),
    error = function(error) error
  )
  if (inherits(encoded, "error")) {
    return(rho_credential_document_error(
      "Could not encode encrypted credential-store metadata",
      store@path,
      "credential_store_encryption"
    ))
  }
  encoded
}

rho_encrypted_credential_envelope <- function(store, document) {
  descriptor <- rho_credential_encryption_descriptor(store@secret)
  if (S7::S7_inherits(descriptor, ProviderErrorValue)) {
    return(descriptor)
  }
  envelope <- list(
    format = "rho.ai.encrypted-credential-store",
    version = 1L,
    cipher = "xchacha20poly1305",
    kdf = descriptor,
    metadata = rho_encrypted_credential_metadata(document)
  )
  additional_data <- rho_encrypted_credential_aad(envelope, store)
  if (S7::S7_inherits(additional_data, ProviderErrorValue)) {
    return(additional_data)
  }
  key <- rho_credential_encryption_key_material(store@secret, descriptor, store)
  if (S7::S7_inherits(key, ProviderErrorValue)) {
    return(key)
  }
  plaintext <- tryCatch(
    yyjsonr::write_json_str(document, auto_unbox = TRUE, null = "null"),
    error = function(error) error
  )
  if (inherits(plaintext, "error")) {
    return(rho_credential_document_error(
      "Could not encode encrypted credential-store payload",
      store@path,
      "credential_store_encryption"
    ))
  }
  ciphertext <- tryCatch(
    rmonocypher::encrypt_raw(charToRaw(plaintext), key, additional_data = additional_data),
    error = function(error) error
  )
  if (inherits(ciphertext, "error")) {
    return(rho_credential_document_error(
      "Could not encrypt credential-store payload",
      store@path,
      "credential_store_encryption"
    ))
  }
  envelope$ciphertext <- base64enc::base64encode(ciphertext)
  envelope
}

rho_valid_encrypted_credential_envelope <- function(envelope, store) {
  valid <- is.list(envelope) &&
    all(
      identical(envelope$format, "rho.ai.encrypted-credential-store"),
      identical(envelope$version, 1L),
      identical(envelope$cipher, "xchacha20poly1305"),
      is.list(envelope$kdf),
      is.list(envelope$metadata),
      rho_non_empty_scalar_string(envelope$ciphertext)
    )
  if (!valid) {
    return(rho_credential_document_error(
      "Credential store is not a supported encrypted credential envelope",
      store@path,
      "credential_store_format"
    ))
  }
  envelope
}

rho_decrypt_credential_document <- function(store, envelope) {
  verified <- rho_valid_encrypted_credential_envelope(envelope, store)
  if (S7::S7_inherits(verified, ProviderErrorValue)) {
    return(verified)
  }
  additional_data <- rho_encrypted_credential_aad(envelope, store)
  if (S7::S7_inherits(additional_data, ProviderErrorValue)) {
    return(additional_data)
  }
  key <- rho_credential_encryption_key_material(store@secret, envelope$kdf, store)
  if (S7::S7_inherits(key, ProviderErrorValue)) {
    return(key)
  }
  ciphertext <- tryCatch(base64enc::base64decode(envelope$ciphertext), error = function(error) {
    error
  })
  if (inherits(ciphertext, "error") || !is.raw(ciphertext) || !length(ciphertext)) {
    return(rho_credential_document_error(
      "Encrypted credential store has invalid ciphertext",
      store@path,
      "credential_store_format"
    ))
  }
  plaintext <- tryCatch(
    rmonocypher::decrypt_raw(ciphertext, key, additional_data = additional_data),
    error = function(error) error
  )
  if (inherits(plaintext, "error")) {
    return(rho_credential_document_error(
      "Could not decrypt credential store with the supplied secret",
      store@path,
      "credential_store_decrypt"
    ))
  }
  document <- tryCatch(
    yyjsonr::read_json_str(
      rawToChar(plaintext),
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(document, "error") || !is.list(document)) {
    return(rho_credential_document_error(
      "Decrypted credential store has an invalid document",
      store@path,
      "credential_store_format"
    ))
  }
  valid_document <- rho_scalar_number(document$version) &&
    document$version == 1 &&
    is.list(document$credentials)
  if (!valid_document) {
    return(rho_credential_document_error(
      "Decrypted credential store must contain version 1 and a credentials object",
      store@path,
      "credential_store_format"
    ))
  }
  document
}

S7::method(
  rho_read_credential_document,
  RhoEncryptedFileCredentialStore
) <- function(store, ...) {
  rho.async::rho_task_from_function(
    function() {
      if (!file.exists(store@path)) {
        return(rho_empty_credential_document())
      }
      envelope <- tryCatch(
        yyjsonr::read_json_file(
          store@path,
          arr_of_objs_to_df = FALSE,
          obj_of_arrs_to_df = FALSE
        ),
        error = function(error) error
      )
      if (inherits(envelope, "error")) {
        return(rho_credential_document_error(
          "Could not read encrypted credential store",
          store@path,
          "credential_store_read"
        ))
      }
      rho_decrypt_credential_document(store, envelope)
    },
    label = "encrypted-credential-store-read"
  )
}

S7::method(
  rho_write_credential_document,
  RhoEncryptedFileCredentialStore
) <- function(store, document, ...) {
  rho.async::rho_task_from_function(
    function() {
      envelope <- rho_encrypted_credential_envelope(store, document)
      if (S7::S7_inherits(envelope, ProviderErrorValue)) {
        return(envelope)
      }
      encoded <- tryCatch(
        yyjsonr::write_json_str(envelope, auto_unbox = TRUE, null = "null"),
        error = function(error) error
      )
      if (inherits(encoded, "error")) {
        return(rho_credential_document_error(
          "Could not encode encrypted credential-store envelope",
          store@path,
          "credential_store_encryption"
        ))
      }
      rho_write_credential_file_text(store, encoded)
    },
    label = "encrypted-credential-store-write"
  )
}

rho_keychain_store_error <- function(store, provider_id, message, code) {
  rho_auth_error(
    message,
    code = code,
    details = list(service = store@service, provider = provider_id)
  )
}

rho_keychain_entries <- function(store, provider_id) {
  entries <- tryCatch(
    store@backend$list(service = store@service),
    error = function(error) error
  )
  if (inherits(entries, "error")) {
    return(rho_keychain_store_error(
      store,
      provider_id,
      "Could not list credentials in the operating-system keychain",
      "credential_store_keychain"
    ))
  }
  valid <- is.data.frame(entries) &&
    all(c("service", "username") %in% names(entries))
  if (!valid) {
    return(rho_keychain_store_error(
      store,
      provider_id,
      "Operating-system keychain returned an invalid credential listing",
      "credential_store_keychain"
    ))
  }
  entries
}

rho_keychain_has_credential <- function(store, provider_id) {
  entries <- rho_keychain_entries(store, provider_id)
  if (S7::S7_inherits(entries, ProviderErrorValue)) {
    return(entries)
  }
  any(entries$service == store@service & entries$username == provider_id)
}

rho_decode_keychain_credential <- function(store, provider_id, document) {
  valid <- is.list(document) && identical(document$provider, provider_id)
  if (!valid) {
    return(rho_keychain_store_error(
      store,
      provider_id,
      "Keychain credential has an invalid document",
      "credential_store_format"
    ))
  }
  provider <- store@providers[[provider_id]]
  if (is.null(provider)) {
    return(rho_keychain_store_error(
      store,
      provider_id,
      "Keychain credential has no matching provider definition",
      "provider"
    ))
  }
  strategy <- rho_credential_strategy(provider, document, store@service)
  if (S7::S7_inherits(strategy, ProviderErrorValue)) {
    return(strategy)
  }
  rho_credential_decode(
    strategy,
    document,
    provider_id,
    source = sprintf("keychain:%s/%s", store@service, provider_id)
  )
}

rho_keychain_read_credential <- function(store, provider_id) {
  rho.async::rho_task_from_function(
    function() {
      exists <- rho_keychain_has_credential(store, provider_id)
      if (S7::S7_inherits(exists, ProviderErrorValue)) {
        return(exists)
      }
      if (!exists) {
        return(NULL)
      }
      encoded <- tryCatch(
        store@backend$get(service = store@service, username = provider_id),
        error = function(error) error
      )
      if (inherits(encoded, "error")) {
        return(rho_keychain_store_error(
          store,
          provider_id,
          "Could not read a credential from the operating-system keychain",
          "credential_store_keychain"
        ))
      }
      document <- tryCatch(
        yyjsonr::read_json_str(
          encoded,
          arr_of_objs_to_df = FALSE,
          obj_of_arrs_to_df = FALSE
        ),
        error = function(error) error
      )
      if (inherits(document, "error")) {
        return(rho_keychain_store_error(
          store,
          provider_id,
          "Keychain credential has an invalid document",
          "credential_store_format"
        ))
      }
      rho_decode_keychain_credential(store, provider_id, document)
    },
    label = "keychain-credential-read"
  )
}

rho_keychain_write_credential <- function(store, provider_id, credential) {
  encoded <- rho_credential_encode(credential)
  if (S7::S7_inherits(encoded, ProviderErrorValue)) {
    return(rho.async::rho_task(encoded))
  }
  rho.async::rho_task_from_function(
    function() {
      document <- tryCatch(
        yyjsonr::write_json_str(encoded, auto_unbox = TRUE, null = "null"),
        error = function(error) error
      )
      if (inherits(document, "error")) {
        return(rho_keychain_store_error(
          store,
          provider_id,
          "Could not encode a keychain credential",
          "credential_store_write"
        ))
      }
      written <- tryCatch(
        {
          store@backend$set_with_value(
            service = store@service,
            username = provider_id,
            password = document
          )
          TRUE
        },
        error = function(error) error
      )
      if (inherits(written, "error")) {
        return(rho_keychain_store_error(
          store,
          provider_id,
          "Could not write a credential to the operating-system keychain",
          "credential_store_keychain"
        ))
      }
      TRUE
    },
    label = "keychain-credential-write"
  )
}

rho_keychain_delete_credential <- function(store, provider_id) {
  rho.async::rho_task_from_function(
    function() {
      exists <- rho_keychain_has_credential(store, provider_id)
      if (S7::S7_inherits(exists, ProviderErrorValue)) {
        return(exists)
      }
      if (!exists) {
        return(NULL)
      }
      deleted <- tryCatch(
        {
          store@backend$delete(service = store@service, username = provider_id)
          TRUE
        },
        error = function(error) error
      )
      if (inherits(deleted, "error")) {
        return(rho_keychain_store_error(
          store,
          provider_id,
          "Could not delete a credential from the operating-system keychain",
          "credential_store_keychain"
        ))
      }
      NULL
    },
    label = "keychain-credential-delete"
  )
}

S7::method(rho_credential_read, RhoKeychainCredentialStore) <- function(
  store,
  provider_id,
  ...
) {
  rho.async::rho_enqueue(
    store@state$queue,
    function() rho_keychain_read_credential(store, provider_id),
    label = sprintf("credential-read:%s", provider_id)
  )
}

S7::method(rho_credential_modify, RhoKeychainCredentialStore) <- function(
  store,
  provider_id,
  update,
  ...
) {
  if (!is.function(update)) {
    rho.async::rho_signal_contract_violation("`update` must be a function")
  }
  rho.async::rho_enqueue(
    store@state$queue,
    function() {
      rho.async::rho_then(rho_keychain_read_credential(store, provider_id), function(current) {
        if (S7::S7_inherits(current, ProviderErrorValue)) {
          return(current)
        }
        rho.async::rho_then(rho.async::rho_as_task(update(current)), function(next_value) {
          if (S7::S7_inherits(next_value, ProviderErrorValue)) {
            return(next_value)
          }
          if (is.null(next_value)) {
            return(current)
          }
          valid <- S7::S7_inherits(next_value, RhoCredential) &&
            identical(next_value@provider, provider_id)
          if (!valid) {
            return(rho_keychain_store_error(
              store,
              provider_id,
              "Credential update must return a matching RhoCredential, NULL, or a typed provider error",
              "credential_type"
            ))
          }
          rho.async::rho_then(
            rho_keychain_write_credential(store, provider_id, next_value),
            function(written) {
              if (S7::S7_inherits(written, ProviderErrorValue)) {
                return(written)
              }
              next_value
            }
          )
        })
      })
    },
    label = sprintf("credential-modify:%s", provider_id)
  )
}

S7::method(rho_credential_delete, RhoKeychainCredentialStore) <- function(
  store,
  provider_id,
  ...
) {
  rho.async::rho_enqueue(
    store@state$queue,
    function() rho_keychain_delete_credential(store, provider_id),
    label = sprintf("credential-delete:%s", provider_id)
  )
}
