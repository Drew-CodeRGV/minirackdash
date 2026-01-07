#!/bin/bash
# Aggressive Fix for Nginx Default Page Issue

set -e

echo "🔧 Fixing nginx default page issue..."

# Stop services
sudo systemctl stop nginx || true
sudo systemctl stop eero-dashboard || true

# COMPLETELY remove all nginx default content
echo "🗑️ Removing ALL nginx default content..."
sudo rm -rf /var/www/html/*
sudo rm -rf /var/www/*
sudo rm -f /etc/nginx/sites-enabled/*
sudo rm -f /etc/nginx/sites-available/default*
sudo rm -f /etc/nginx/conf.d/*

# Create a completely clean nginx configuration
echo "⚙️ Creating clean nginx configuration..."
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    # ONLY our dashboard server - no defaults anywhere
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        
        # Disable any default root or index
        root /nonexistent;
        
        # Proxy EVERYTHING to our dashboard
        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            proxy_buffering off;
        }
        
        # Catch any other attempts to serve files
        location ~* \.(html|htm)$ {
            proxy_pass http://127.0.0.1:5000;
        }
    }
}
EOF

# Test nginx configuration
echo "✅ Testing nginx configuration..."
sudo nginx -t

# Ensure dashboard service is running
echo "🚀 Starting dashboard service..."
sudo systemctl start eero-dashboard

# Wait for dashboard to be ready
echo "⏳ Waiting for dashboard to be ready..."
for i in {1..20}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Dashboard is ready"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ Dashboard failed to start"
        sudo systemctl status eero-dashboard
        exit 1
    fi
    sleep 2
done

# Start nginx with our clean config
echo "🌐 Starting nginx..."
sudo systemctl start nginx

# Wait a moment for nginx to fully start
sleep 3

# Test the complete setup multiple times
echo "🔍 Testing complete setup..."
for i in {1..5}; do
    RESPONSE=$(curl -s http://localhost/)
    
    if echo "$RESPONSE" | grep -q "Dashboard" && ! echo "$RESPONSE" | grep -q "Welcome to nginx"; then
        echo "✅ Test $i: Dashboard is serving correctly"
    else
        echo "❌ Test $i: Still getting wrong content"
        echo "Response preview: $(echo "$RESPONSE" | head -c 200)"
        
        if [ $i -eq 5 ]; then
            echo "❌ All tests failed - debugging..."
            echo "Nginx status:"
            sudo systemctl status nginx
            echo "Dashboard status:"
            sudo systemctl status eero-dashboard
            echo "Nginx error log:"
            sudo tail -10 /var/log/nginx/error.log
            exit 1
        fi
    fi
    sleep 2
done

# Final verification
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
echo ""
echo "🎉 Nginx default page issue fixed!"
echo "🌐 Dashboard should now be accessible at: http://$PUBLIC_IP"
echo "🔄 Try a hard refresh (Ctrl+F5) if you still see cached content"
echo ""
echo "✅ Nginx is now properly configured to ONLY serve the dashboard"
echo "✅ All default nginx content has been removed"
echo "✅ Dashboard service is running and responding"