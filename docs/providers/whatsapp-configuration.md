# WhatsApp Configuration Guide

This guide explains how to configure WhatsApp integration with the Decidim Chatbot module using Meta's developer platform.

## Prerequisites

- A Meta/Facebook Business Account
- Access to [Meta for Developers](https://developers.facebook.com/)
- A phone number to use as your WhatsApp Business number
- Your Decidim instance domain name (including HTTPS)

## Step 1: Set Up Meta Business Manager

1. Visit [Meta for Developers](https://developers.facebook.com/) and log in with your Meta account.
2. If you don't have a Business Manager account, create one:
   - Go to **Business Manager** in the top menu
   - Click **Create Account**
   - Enter your business details
3. In Business Manager, navigate to **Settings** → **Users** to add team members if needed.

## Step 2: Create a WhatsApp Business Account

1. In Meta Business Manager, go to **Business Setup** → **All Tools**
2. Find and select **WhatsApp**
3. Click **Create or Connect Account**
4. Select **Create New Account** if you don't have one
5. Fill in the business information:
   - Business name
   - Industry category
   - Business website (optional but recommended)
6. Accept the WhatsApp Terms of Service

## Step 3: Register Your Phone Number

1. After creating your WhatsApp Business Account, go to **Phone Numbers**
2. Click **Add Phone Number**
3. Enter the phone number you want to use for WhatsApp:
   - Use the format with country code (e.g., +34 for Spain, +1 for USA)
   - This number will receive and send messages
4. Verify the phone number through SMS or voice call
5. Once verified, your number will appear as **Approved**

## Step 4: Create a WhatsApp API Application

1. Go to the **Meta Developers** portal ([developers.facebook.com](https://developers.facebook.com/))
2. Click **My Apps** and select **Create App**
3. Choose **Business** as the app type
4. Fill in the app details:
   - App Name: e.g., "Decidim Chatbot"
   - App Contact Email: your business email
   - Select use case: **Business**
5. Click **Create App**
6. Once created, go to **Settings** → **Basic** and save your:
   - **App ID**
   - **App Secret**

## Step 5: Add WhatsApp Product to Your App

1. In your app dashboard, click **+ Add Product**
2. Find **WhatsApp** and click **Set Up**
3. Select **WhatsApp Business API** (not WhatsApp Cloud API)
4. Complete the setup wizard

## Step 6: Obtain Credentials

In your WhatsApp app dashboard, navigate to **WhatsApp** → **Getting Started** to find:

### Phone Number ID
- Located in the **Getting Started** section
- Format: a numeric ID (e.g., `1234567890`)
- Copy and save this value

### Access Token
1. Go to **WhatsApp** → **API Setup**
2. Under **Temporary Access Token**, click **Generate Token**
3. Copy the token (starts with `EAAxx...`)
   - **Note**: This is a temporary token for testing
   - For production, create a permanent token in **Settings** → **System Users**

### Webhook Verify Token
- This is a custom value you create
- It's used to verify webhook requests from Meta
- Choose a secure random string (e.g., use an online generator or `openssl rand -hex 32`)
- You'll need this value for both Meta and Decidim configuration

## Step 7: Configure Webhooks in Meta

1. Go to **WhatsApp** → **Configuration**
2. In the **Webhooks** section, click **Edit**
3. Set the **Callback URL** to:
   ```
   https://your-decidim-domain.com/chatbot/webhooks/whatsapp
   ```
   - Replace `your-decidim-domain.com` with your actual domain
   - **Important**: Must use HTTPS
   - **Note**: If developing locally, use [ngrok](https://ngrok.com) to expose your local server

4. Set the **Verify Token** to the value you created in step 6
5. In **Subscribe to webhook fields**, select these events:
   - `messages` (required - for incoming messages)
   - `message_reactions` (optional - for message reactions)
   - `message_template_status_update` (optional - for template status)
   - `message_template_quality_update` (optional - for quality ratings)
6. Click **Verify and Save**

Meta will send a webhook verification request. If your Decidim instance is properly configured, it should respond with a success status.

## Step 8: Configure Decidim Chatbot

### Environment Variables

Add the following to your `.env` file or server environment:

```bash
# WhatsApp Provider Configuration
WHATSAPP_PROVIDER_NAME=whatsapp
WHATSAPP_VERIFY_TOKEN=<your-secure-token-from-step-6>
WHATSAPP_ACCESS_TOKEN=<your-access-token-from-step-6>
WHATSAPP_PHONE_NUMBER_ID=<your-phone-number-id-from-step-6>
```

### Decidim Admin Configuration

1. Log in to your Decidim instance as an administrator
2. Navigate to **Chatbot** in the admin menu
3. Enable the WhatsApp provider
4. Configure any additional settings (if applicable):
   - Conversation timeout
   - Message templates
   - Auto-response settings

## Step 9: Test the Integration

### Test Webhook Verification

Use this curl command to test webhook verification:

```bash
curl -G \
  --data-urlencode "hub.mode=subscribe" \
  --data-urlencode "hub.verify_token=$WHATSAPP_VERIFY_TOKEN" \
  --data-urlencode "hub.challenge=test_challenge_123" \
  https://your-decidim-domain.com/chatbot/webhooks/whatsapp
```

Expected response: `test_challenge_123` with HTTP 200

### Send a Test Message

1. From your verified WhatsApp Business Account, send a test message to your number
2. Check your Decidim logs to see if the message was received
3. If configured, an automated response should be sent back

## Troubleshooting

### Webhook Verification Fails

- **Check HTTPS**: Your webhook URL must use HTTPS
- **Verify Token Mismatch**: Ensure the token in Meta and Decidim are identical
- **Network Connectivity**: If using ngrok, ensure it's running and the domain hasn't changed
- **Logs**: Check your Decidim application logs for specific error messages

### Messages Not Received

- **Phone Number Status**: Verify your WhatsApp Business phone number is **Approved**
- **Access Token**: Ensure the token is valid and hasn't expired
- **Webhook Configuration**: Confirm the webhook URL is correct in Meta's settings
- **Rate Limiting**: Meta has rate limits; check if you're hitting quotas

### Access Token Expired

- Regular tokens expire after a period of time
- Create a permanent token using **Settings** → **System Users** in Meta for Developers
- Follow Meta's documentation on managing system user access tokens

## Important Notes

### 24-Hour Messaging Window

Meta's WhatsApp Business API has a 24-hour messaging window:
- Users must initiate the conversation first
- After a user sends you a message, you have 24 hours to respond freely
- After 24 hours, you can only send template-based messages

### Message Limitations

- Messages are limited to 4,096 characters
- Media messages (images, videos, documents) are supported with size limits
- Message templates should be pre-approved by Meta

### Production Considerations

- Use permanent access tokens (via System Users) instead of temporary tokens
- Implement proper error handling and retry logic
- Monitor webhook delivery status
- Regularly review Meta's documentation for API updates
- Set up alerting for webhook failures

## Additional Resources

- [Meta WhatsApp Business API Documentation](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started)
- [WhatsApp Business Platform Overview](https://www.whatsapp.com/business/api/)
- [Meta Developer Documentation](https://developers.facebook.com/docs/)
- [Decidim Chatbot Module Repository](https://github.com/openpoke/decidim-module-chatbot)

## Support

For issues specific to the Decidim Chatbot module, please open an issue on the [GitHub repository](https://github.com/openpoke/decidim-module-chatbot).

For WhatsApp API issues, consult the [Meta Developer Community](https://developers.facebook.com/community) or contact Meta Support.
