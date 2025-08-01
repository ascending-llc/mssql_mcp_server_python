FROM python:3.12-slim

# Set basic environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Microsoft ODBC Driver for SQL Server
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        unixodbc \
        unixodbc-dev \
        libpq-dev \
        libgl1 \
        libglib2.0-0 \
        curl \
        gnupg \
        netcat-traditional \
        wget \
        ca-certificates \
    # Install Microsoft ODBC driver using modern GPG key method
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg \
    && echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Verify ODBC driver installation
RUN odbcinst -q -d -n "ODBC Driver 18 for SQL Server"


# Set working directory
WORKDIR /app

# Copy dependency files and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .


# FastMCP server configuration
ENV FASTMCP_TRANSPORT=http \
    FASTMCP_HOST=0.0.0.0 \
    FASTMCP_PORT=3333 \
    FASTMCP_LOG_LEVEL=INFO

# Cache configuration
ENV CACHE_ENABLED=true \
    CACHE_TABLE_NAMES_TTL=600 \
    CACHE_TABLE_DATA_TTL=120 \
    CACHE_TABLE_SCHEMA_TTL=600

# Connection pool configuration
ENV DB_POOL_MIN_SIZE=2 \
    DB_POOL_MAX_SIZE=10 \
    ASYNC_DB_TIMEOUT=120

# Server feature configuration
ENV ENABLE_ASYNC=true \
    ENABLE_DYNAMIC_RESOURCES=true \
    MAX_ROWS_LIMIT=500 \
    BATCH_ROWS_SIZE=200

HEALTHCHECK --interval=60s --timeout=30s --start-period=120s --retries=5 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:3333', timeout=20)" || exit 1

# Expose port
EXPOSE 3333

# Start the server
CMD ["python", "-m", "mssql_mcp_server.main"]
