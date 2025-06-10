# Configuration des secrets GitHub Actions

## Secrets nécessaires

### 1. Déploiement
- **SSH_PRIVATE_KEY**: Clé SSH privée pour le déploiement
  - Générée avec `ssh-keygen -t ed25519 -C "lolzone@example.com"`
  - Format: Texte brut de la clé privée

- **SSH_KNOWN_HOSTS**: Hosts connus pour SSH
  - Généré avec `ssh-keyscan -t ed25519 <votre-serveur>`
  - Format: Texte brut des hosts connus

- **DEPLOY_HOST**: Adresse du serveur de production
  - Format: IP ou nom de domaine

- **DEPLOY_USER**: Utilisateur pour le déploiement
  - Format: Nom d'utilisateur

### 2. Notifications
- **SLACK_WEBHOOK_URL**: URL du webhook Slack
  - Créé depuis l'interface Slack
  - Format: URL complète du webhook

### 3. Clés API de test
- **ORANGE_MONEY_API_KEY**: Clé API Orange Money (mode test)
- **MTN_API_KEY**: Clé API MTN (mode test)
- **MOOV_API_KEY**: Clé API Moov (mode test)
- **WAVE_API_KEY**: Clé API Wave (mode test)
- **PAYPAL_CLIENT_ID**: Client ID PayPal (mode test)
- **PAYPAL_CLIENT_SECRET**: Client Secret PayPal (mode test)
- **PAYPAL_ACCESS_TOKEN**: Access Token PayPal (mode test)
- **BANK_TRANSFER_API_KEY**: Clé API Banque (mode test)
- **BANK_TRANSFER_SECRET**: Secret Banque (mode test)

## Configuration

1. Accédez à votre dépôt GitHub
2. Allez dans "Settings" > "Secrets and variables" > "Actions"
3. Cliquez sur "New repository secret"
4. Ajoutez chaque secret avec son nom et sa valeur

## Sécurité

- Ne partagez jamais les secrets en dehors de l'interface GitHub
- Utilisez uniquement des clés API de test
- Mettez à jour les clés régulièrement
- Assurez-vous que les permissions sont correctement configurées

## Vérification

Une fois les secrets configurés, vous pouvez vérifier que tout fonctionne en lançant un workflow de test :

```bash
git push origin main
```

Le workflow devrait s'exécuter avec succès et vous recevoir une notification Slack.
