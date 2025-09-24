# WordPress OpenLiteSpeed Super Optimized Docker Image

> ⚠️ **TESTING/BETA**: This image is currently in testing phase. Use in production at your own risk.

## Overview

This Docker image provides a highly optimized WordPress environment based on OpenLiteSpeed, specifically designed for use with Coolify 4 and other systems using Traefik/Caddy as reverse proxies.

### Tech Stack

- **OpenLiteSpeed** (1.8.2): High-performance web server, optimized alternative to Apache
- **PHP 8.2**: Latest stable version with WordPress optimizations
- **WordPress** (6.4.3+): Latest stable version
- **MariaDB** (11.4): Database optimized for WordPress
- **Relay**: In-memory cache optimized for PHP 8.2
- **WP-CLI**: Command-line tool for managing WordPress

### Key Features

- 🚀 Optimized performance for WordPress with builders (Elementor, etc.)
- 🔒 Hardened security configurations
- 💾 Advanced caching with Relay
- ⚡ OpenLiteSpeed pre-configured for WordPress
- 🛠️ PHP configuration optimized for modern CMS
- 🔄 Guaranteed compatibility with Traefik/Caddy

## Usage with Coolify 4

1. In Coolify dashboard, create a new application
2. Select "Docker Image" as deployment type
3. Use image: `anideaforbusiness/wordpress-ols-super-optimized-eg:latest`
4. Configure required environment variables (see Environment Variables section)
