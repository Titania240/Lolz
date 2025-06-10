#Requires -Version 5.1

# Configuration
$SLACK_APP_NAME = "LOLZone CI/CD"
$SLACK_CHANNEL = "#ci-cd-notifications"

# Instructions
Write-Host "`nSetting up Slack webhook...`n"
Write-Host "To set up the Slack webhook:`n"
Write-Host "1. Go to https://api.slack.com/apps"
Write-Host "2. Click 'Create New App'"
Write-Host "3. Name your app: $SLACK_APP_NAME"
Write-Host "4. Select your workspace"
Write-Host "5. Click 'Incoming Webhooks'"
Write-Host "6. Click 'Activate Incoming Webhooks'"
Write-Host "7. Click 'Add New Webhook to Workspace'"
Write-Host "8. Select channel: $SLACK_CHANNEL"
Write-Host "9. Click 'Allow'"
Write-Host "10. Copy the webhook URL`n"

# Ajouter le secret GitHub
Write-Host "To add the webhook to GitHub:`n"
Write-Host "1. Go to your repository Settings > Secrets and variables > Actions"
Write-Host "2. Click 'New repository secret'"
Write-Host "3. Name: SLACK_WEBHOOK_URL"
Write-Host "4. Value: Paste the webhook URL you copied`n"

# Tester le webhook
Write-Host "To test the webhook:`n"
Write-Host "1. Create a test workflow file: .github/workflows/test-slack.yml`n"
Write-Host "```yaml`n"
Write-Host "on:`n"
Write-Host "  workflow_dispatch:`n"
Write-Host "`n"
Write-Host "jobs:`n"
Write-Host "  test:`n"
Write-Host "    runs-on: ubuntu-latest`n"
Write-Host "    steps:`n"
Write-Host "    - name: Test Slack Webhook`n"
Write-Host "      uses: 8398a7/action-slack@v3`n"
Write-Host "      env:`n"
Write-Host "        SLACK_WEBHOOK_URL: `{{ secrets.SLACK_WEBHOOK_URL }}`n"
Write-Host "        STATUS: success`n"
Write-Host "        TEXT: 'Slack webhook test successful'`n"
Write-Host "````n"

Write-Host "2. Push the changes to trigger the test"`n
Write-Host "3. Check the Slack channel for the test message"`n
