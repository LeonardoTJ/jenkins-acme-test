## Requirements on agent
- acme.sh
- openssl
- ansible
- jq

### Jenkins
- `ENC_PASS` stored as Jenkins secret text credential id `enc-pass`.
- The Jenkins service account credential for Ansible is a stored SSH key credential named `ansible-ssh-key` (type: *SSH Username with private key*).

### Ansible
For sudo elevation by Ansible, ensure that account is allowed to sudo on targets (`NOPASSWD` or with password; if password, use Jenkins credential).

#### `provision-challenge.yml`
- backs up the nginx site file
- inserts an ACME location block above the `return 301` redirect line (using `insertbefore`),
- creates the challenge webroot (`/var/www/html/acme-challenge`)
- reloads nginx

### `deploy-certs.yml`
- copies the encrypted cert and key from the control machine to the remote host
- decrypts them on the remote host using `openssl enc -aes-128-cbc -pbkdf2 -salt` with a password read from an **environment variable** (so the password is NOT passed on the ansible command line)
- moves the decrypted cert/key to their final locations with secure modes
- reloads nginx to pick up the new certificate
- removes the ACME challenge directory
- restores the nginx config backup, and reloads nginx again
Sensitive tasks that use the decryption password are marked `no_log`: true to prevent leakage in Ansible logs.

## Jenkinsfile: Issue/Create
This pipeline reads `servers.json`, for each server uses pre-existing CSR stored at `/mnt/project/csrs/<primary>.csr.enc` (encrypted), decrypts CSR, runs `acme.sh --signcsr --csr <csr>` and receives certificate, encrypts artifacts and writes them to NFS, then runs Ansible to deploy.

## Jenkinsfile: Renew
Renew pipeline is similar. It will:
- read `servers.json`
- for each primary, decrypt local CSR/key if needed, call `acme.sh --renew -d <primary> --server <ACME_SERVER> --debug 2` (for `--signcsr` you call `--signcsr` again with the same CSR if required by your ACME front end), or use `--renew` if acme.sh manages cert.
- encrypt artifacts and deploy via Ansible.

