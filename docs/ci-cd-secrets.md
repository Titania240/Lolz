# Configuration des secrets GitHub pour CI/CD

## Secrets nécessaires

### 1. Déploiement
- **SSH_PRIVATE_KEY**: Clé SSH privée pour le déploiement
- **SSH_KNOWN_HOSTS**: Hosts connus pour la connexion SSH
- **DEPLOY_HOST**: Hôte de production
- **DEPLOY_USER**: Utilisateur pour le déploiement

### 2. Notifications
- **SLACK_WEBHOOK_URL**: URL du webhook Slack pour les notifications

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

## Configuration des secrets

1. Accédez aux paramètres de votre dépôt GitHub
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
