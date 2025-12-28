# ===============================
# Stage 1: Build assets
# ===============================
FROM frappe/bench:latest AS builder

USER frappe
WORKDIR /home/frappe

# Initialize bench
RUN bench init frappe-bench --skip-redis-config-generation

WORKDIR /home/frappe/frappe-bench

# Get LMS app
RUN bench get-app lms

# Copy fixed api.py to override the downloaded version
COPY lms/lms/api.py /home/frappe/frappe-bench/apps/lms/lms/lms/api.py

# Build assets without creating a site (using bench build --app)
# This builds the frontend assets without requiring a database
RUN bench build --app lms || bench build || true

# Also build frappe assets
RUN bench build --app frappe || true


# ===============================
# Stage 2: Runtime image
# ===============================
FROM frappe/bench:latest

USER frappe
WORKDIR /home/frappe

# Copy fully built bench from builder
COPY --from=builder /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

# Create sites directory (PVC mount point)
RUN mkdir -p sites

# Copy startup scripts
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*
USER frappe

# Expose ports
EXPOSE 8000

# Start with entrypoint script
CMD ["/usr/local/bin/entrypoint.sh"]