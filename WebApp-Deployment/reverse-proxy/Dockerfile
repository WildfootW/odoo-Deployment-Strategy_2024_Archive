# Use the official Nginx image as the base image
FROM nginx:1.27-alpine

# Copy custom entrypoint script
COPY custom-entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

# Copy Nginx configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d /etc/nginx/conf.d
COPY html /usr/share/nginx/html

# Expose ports
EXPOSE 80 443

# Set the custom entrypoint
ENTRYPOINT ["/custom-entrypoint.sh"]

# Keep the original CMD
CMD ["nginx", "-g", "daemon off;"]

