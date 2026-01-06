
# AWS Lambda Deployment Guide

## Cost: Nearly FREE (AWS Free Tier)
- 1M requests/month free
- 400,000 GB-seconds compute free
- Typical usage: <$1/month

## Step 1: Create Lambda Function

1. Go to AWS Lambda console
2. Click "Create function"
3. Choose "Author from scratch"
4. Function name: `eero-dashboard`
5. Runtime: Python 3.9
6. Click "Create function"

## Step 2: Deploy Code

1. Copy the code from `lambda_function.py`
2. Paste into the Lambda function editor
3. Click "Deploy"

## Step 3: Set Environment Variables

In Lambda configuration, add:
- `NETWORK_ID`: Your Eero network ID
- `API_TOKEN`: Your Eero API token
- `API_URL`: api-user.e2ro.com (or staging)

## Step 4: Create API Gateway

1. Go to API Gateway console
2. Create "HTTP API"
3. Add integration: Lambda function
4. Configure routes:
   - `GET /` → Lambda function
   - `GET /api/dashboard` → Lambda function
   - `ANY /{proxy+}` → Lambda function

## Step 5: Deploy API

1. Create stage (e.g., "prod")
2. Deploy API
3. Note the invoke URL

## Step 6: Access Dashboard

Visit your API Gateway URL to access the dashboard.

## Pros:
- Nearly free
- Serverless (no server management)
- Auto-scaling
- High availability

## Cons:
- Cold starts (1-2 second delay)
- 15-minute timeout limit
- More complex setup
- Limited real-time features

## Security:
- Add API key authentication
- Use custom domain with HTTPS
- Set up CloudFront for caching
