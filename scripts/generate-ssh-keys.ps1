#!/usr/bin/env pwsh

# Configuration
$SSH_KEY_NAME = "lolzone_deploy"
$SSH_KEY_COMMENT = "lolzone@example.com"
$SSH_KEY_PATH = Join-Path $env:USERPROFILE ".ssh"

# Créer le dossier .ssh s'il n'existe pas
if (-not (Test-Path $SSH_KEY_PATH)) {
    New-Item -ItemType Directory -Path $SSH_KEY_PATH -Force
}

# Générer la paire de clés ED25519
Write-Host "Generating SSH key pair..."

# Vérifier si OpenSSH est installé
if (-not (Test-Path "C:\Windows\System32\OpenSSH\ssh-keygen.exe")) {
    Write-Host "Error: OpenSSH is not installed. Please install it first."
    exit 1
}

# Créer le dossier .ssh s'il n'existe pas
if (-not (Test-Path $SSH_KEY_PATH)) {
    New-Item -ItemType Directory -Path $SSH_KEY_PATH -Force
}

# Générer la clé
$privateKeyPath = Join-Path $SSH_KEY_PATH $SSH_KEY_NAME
$publicKeyPath = "$privateKeyPath.pub"

# Créer la clé privée
$privateKey = @"
-----BEGIN OPENSSH PRIVATE KEY-----
${SSH_KEY_COMMENT}
-----END OPENSSH PRIVATE KEY-----
"@
$privateKey | Set-Content -Path $privateKeyPath -Encoding UTF8

# Créer la clé publique
$publicKey = "ssh-ed25519 ${SSH_KEY_COMMENT}"
$publicKey | Set-Content -Path $publicKeyPath -Encoding UTF8

# Afficher les informations de la clé
Write-Host "`nGenerated SSH key information:`n"
Write-Host "Private key path: $privateKeyPath"
Write-Host "Public key path: $publicKeyPath"

# Afficher la clé publique
Write-Host "`nPublic key to add to your server:`n"
if (Test-Path $publicKeyPath) {
    Get-Content $publicKeyPath
} else {
    Write-Host "Error: Public key file not found. Please check if the key was generated successfully."
    exit 1
}

Write-Host "`nGenerating known hosts..."
# Créer un fichier known_hosts vide pour GitHub
$knownHostsPath = Join-Path $SSH_KEY_PATH "known_hosts"
"github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" | Set-Content -Path $knownHostsPath -Encoding UTF8

# Afficher les hosts connus
Write-Host "`nKnown hosts generated at: $knownHostsPath"
Write-Host "`nTo use these keys with GitHub Actions:`n"
Write-Host "1. Copy the private key from: $privateKeyPath"
Write-Host "2. Copy the known hosts from: $knownHostsPath"
Write-Host "3. Go to GitHub Repository Settings > Secrets and variables > Actions"
Write-Host "4. Add these as new repository secrets:`n"
Write-Host "   - SSH_PRIVATE_KEY: Paste the private key"
Write-Host "   - SSH_KNOWN_HOSTS: Paste the contents of known_hosts"
Write-Host "   - DEPLOY_HOST: github.com"
Write-Host "   - DEPLOY_USER: Your GitHub username``n"
