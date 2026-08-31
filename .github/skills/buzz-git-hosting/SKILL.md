---
name: buzz-git-hosting
description: "Create, import, diagnose, and verify Buzz-hosted Git repositories and projects. Use for repository unavailable, repository not found, Git username/password prompts, NIP-98 credential-helper failures, private GitHub imports, tenant FQDN mismatches, Schannel revocation errors, or branch parity checks."
user-invocable: true
---

# Buzz Git Hosting

Buzz repository metadata is a NIP-34 kind `30617` event. A multi-repository project is a kind
`30621` event. Git data is served separately over authenticated Smart HTTP at
`https://<relay>/git/<owner-hex>/<repo-id>`. Prove each layer independently.

## Safety

- Never ask for or print an nsec, `NOSTR_PRIVATE_KEY`, `BUZZ_PRIVATE_KEY`, auth tag, Authorization
  header, credential-helper response, or complete process environment.
- Never embed a token or key in a Git URL or command line. If a key is needed, have the user type it
  directly into a terminal with `read -rsp`, or consume an existing mode-`0600` key file without
  displaying it.
- Before `push --all`, verify the current repository, worktree, source remote, local/remote branch
  list, and destination URL. Map explicit refs when importing remote-tracking branches.
- Do not force-push merely to resolve a stale local branch. Compare ancestry first and fast-forward
  an inactive local ref only when it is a strict ancestor.
- Database host repairs require evidence from routing, deployment configuration, and the
  `communities` table. Use a guarded transaction and preserve the community ID and all tenant data.

## Create Repository Metadata

1. Determine the relay HTTPS/WSS FQDN from the live HTTPProxy/Ingress and deployment `RELAY_URL`.
2. Determine the owner public key from the active Buzz identity. The owner path segment is a
   64-character lowercase hex pubkey, never a username or literal `PUBKEY` placeholder.
3. Select an access channel and obtain its UUID. The owner must have an active recognized role in
   that channel; the relay deliberately has no owner bypass.
4. Create the NIP-34 announcement:

   ```bash
   buzz repos create \
     --id <repo-id> \
     --name <name> \
     --clone https://<relay>/git/<owner-hex>/<repo-id> \
     --web https://github.com/<owner>/<repo> \
     --channel <channel-uuid>
   ```

5. Query `buzz repos get --id <repo-id> --owner <owner-hex>` and require one live kind `30617`
   with matching `d`, `clone`, and `buzz-channel` tags.
6. Run authenticated `git ls-remote` before pushing. An empty successful response means the
   announcement and empty manifest exist; `repository not found` means resolution or access failed.
7. Create the project grouping after the repository exists:

   ```bash
   buzz projects create <slug> --repo <repo-id> --name <name> \
     --channel <channel-uuid> --visibility listed
   ```

## NIP-98 Git Authentication

Buzz has no Git username/password. A username prompt means Git did not use the Nostr credential
response.

1. Require Git `2.46+`; older Git does not advertise the credential protocol `authtype`
   capability. Git `2.43` falls back to a username prompt even when the helper executable exists.
2. Require `git-credential-nostr` and `credential.useHttpPath=true`.
3. Scope the helper to the Buzz host when a checkout also uses private GitHub credentials:

   ```bash
   git config --local --unset-all credential.helper || true
   git config --local --add credential.https://<relay>.helper ''
   git config --local --add credential.https://<relay>.helper /path/to/git-credential-nostr
   git config --local credential.useHttpPath true
   git config --local nostr.keyfile ~/.nostr/key
   ```

4. The key file must be a regular file, at most 256 bytes, and mode `0600` on Unix.
5. Trace safely with `GIT_TRACE=1 GIT_CURL_VERBOSE=1`, redacting Authorization and credential
   values. The expected sequence is unauthenticated `401` with
   `WWW-Authenticate: Nostr ...`, helper invocation, then an authenticated response.
6. `401 -> 404` proves helper authentication occurred; continue with repository/tenant/access
   diagnosis rather than changing credentials.

## Import GitHub History

For private GitHub repositories, Desktop cannot inject GitHub credentials. Fetch GitHub with the
user's existing GitHub credential path, then push to Buzz with the Nostr helper.

1. Work in the actual source checkout, never the vm-buzz checkout by accident.
2. Fetch the source remote with prune/tags and enumerate `refs/remotes/origin/*` excluding
   `origin/HEAD`.
3. Inspect local-only branches and tags. Do not assume `push --all` includes remote-tracking refs.
4. For an empty Buzz repository, push explicit mappings:

   ```bash
   git push buzz \
     refs/remotes/origin/main:refs/heads/main \
     refs/remotes/origin/dev:refs/heads/dev
   git push --tags buzz
   ```

   Generate the complete refspec list from the inspected origin branches; do not hardcode only the
   two examples above.
5. Compare every source and Buzz branch commit ID. Verify `git ls-remote --symref buzz HEAD` points
   to the intended default branch.
6. If later `push --all` rejects local `main` as non-fast-forward while `origin/main == buzz/main`,
   and local `main` is an ancestor, fast-forward the inactive local ref with
   `git branch -f main origin/main`; then retry without force.

## Repository Not Found

The relay intentionally collapses many Git read denials to `404 repository not found`.

Check in order:

1. Kind `30617` exists for exact `(community, owner pubkey, d-tag)` and is not deleted/replaced.
2. The event has exactly one valid `buzz-channel` UUID binding.
3. The authenticated caller has an active channel membership row with a recognized role. `bot` is
   valid for reads; push policy promotes it to member where supported.
4. `git_repo_names` has the reserved `(community, owner, repo-id)` row and the manifest pointer was
   initialized by the announcement side effect.
5. The request Host resolves to the same durable community that stores the event. Git binds the
   tenant from Host before NIP-98 URL verification and never falls back to a default tenant.

### Tenant FQDN Drift

Compare all three authorities:

- Contour HTTPProxy/Ingress FQDN.
- Deployment `RELAY_URL` and public/media URLs.
- Active `communities.host` values in PostgreSQL.

If routing and deployment use `buzz.example` but the only active row is stale `example`, authenticated
Git returns 404 even though HTTP event queries may have populated cached UI state. Before repair,
prove the target hostname has no existing community row and the source row is active. Rename only
the host in one guarded transaction, preserving the community ID. Re-run `/health`, NIP-11,
`repos get`, authenticated `ls-remote`, and branch parity afterward. Keep this deployment repair in
the vm-clone-owned deployment/database surface, not duplicated manifests in vm-buzz.

## Repository Unavailable in Desktop

The UI's generic `Repository unavailable` state can hide a native Git error. Prove the relay first
with an authenticated command-line clone, then inspect the exact Desktop boundary.

1. Record Desktop executable path/version/hash and active identity pubkey.
2. Reproduce the same clone URL and selected branch with Windows Git plus the installed adjacent
   `git-credential-nostr.exe`, using a temporary directory that is removed afterward.
3. If command-line clone succeeds, invoke Tauri `get_project_repo_snapshot` directly through a
   temporary local WebView2 debug port, returning only relay URLs, public identity, snapshot counts,
   and the sanitized error. Stop stale single-instance processes before launching one debug-enabled
   instance; Windows loopback CDP must be accessed with Windows Node/curl, not WSL loopback.
4. On Windows private CAs with no CRL/OCSP endpoint, Git may fail with:

   ```text
   CRYPT_E_NO_REVOCATION_CHECK (0x80092012)
   ```

   Desktop clears global and system Git config. For authenticated Buzz Git subprocesses, inject both:

   ```text
   http.sslBackend=schannel
   http.schannelCheckRevoke=false
   ```

   The pair matters: the revocation setting alone was experimentally ignored under isolated config.
   Scope it to Windows and authenticated, already-validated Buzz repository operations. Schannel
   still validates the certificate chain against Windows roots; this disables only unavailable
   revocation checking.
5. Validate with an A/B clone under Desktop's isolated config: baseline must reproduce the revocation
   error and the paired settings must clone successfully. Then rebuild/install Desktop and invoke the
   snapshot again; require a latest commit and nonzero files.

## Verification Evidence

Report:

- Relay FQDN and host-to-community match.
- Repository/project event IDs or existence, owner, repo ID, and channel binding.
- Credential flow (`401 -> authenticated result`) without credential values.
- Exact imported branch count and commit parity.
- Buzz symbolic HEAD/default branch.
- Desktop snapshot latest commit, file/commit/contributor counts.
- Installed Desktop path, version, hash equality with the build artifact, closed debug port, and
   preserved rollback backups. A successful snapshot from a different installation directory does
   not validate the shortcut the user actually runs.
- Worktree status for both source repositories and any unrelated changes left untouched.