FROM python:3.11-slim

# Configure Debian mirror for faster package downloads in China
RUN if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's|http://deb.debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources && \
        sed -i 's|http://security.debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources; \
    elif [ -f /etc/apt/sources.list ]; then \
        sed -i 's|http://deb.debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list && \
        sed -i 's|http://security.debian.org|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list; \
    fi

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Install system dependencies required by scientific Python stack, Playwright, Streamlit, and WeasyPrint PDF
RUN set -euo pipefail; \
    apt-get update; \
    if apt-cache show libgdk-pixbuf-2.0-0 > /dev/null 2>&1; then \
        GDK_PIXBUF_PKG=libgdk-pixbuf-2.0-0; \
    else \
        GDK_PIXBUF_PKG=libgdk-pixbuf2.0-0; \
    fi; \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        libgl1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libpangoft2-1.0-0 \
        "${GDK_PIXBUF_PKG}" \
        libffi-dev \
        libcairo2 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libxcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxtst6 \
        libnss3 \
        libxrandr2 \
        libxkbcommon0 \
        libasound2 \
        libx11-xcb1 \
        libxshmfence1 \
        libgbm1 \
        ffmpeg; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Install the latest uv release with Tsinghua mirror
RUN curl -LsSf --retry 3 --retry-delay 2 --proto '=https' --proto-redir '=https' --tlsv1.2 https://astral.sh/uv/install.sh | sh

WORKDIR /app

# Install Python dependencies first to leverage Docker layer caching
# Use Tsinghua PyPI mirror for faster downloads
COPY requirements.txt ./
RUN uv pip install --system --index-url https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt

# Install Playwright browser binaries (system deps already handled above)
RUN python -m playwright install chromium

# Copy .env
COPY .env.example .env

# Copy application source
COPY . .

# Ensure runtime directories exist even if ignored in build context
RUN mkdir -p /ms-playwright logs final_reports insight_engine_streamlit_reports media_engine_streamlit_reports query_engine_streamlit_reports

EXPOSE 5000 8501 8502 8503

# Default command launches the Flask orchestrator which starts Streamlit agents
CMD ["python", "app.py"]
