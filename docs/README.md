# API Gateway Documentation

## Overview

The API Gateway is built on OpenResty/Lua, providing a flexible and performant solution for API management. This documentation covers all aspects of the gateway's implementation, configuration, and usage.

## Contents

- [Core Architecture](./core/ARCHITECTURE.md) - System design and components
- [Configuration Guide](./config/GUIDE.md) - Setup and configuration details
- [Middleware Implementation](./middleware/IMPLEMENTATION.md) - Guide to implementing middleware
- [Testing Guide](./testing/GUIDE.md) - Testing framework and utilities
- [Examples](./examples/) - Implementation examples:
  - [Request ID Middleware](./examples/request_id.md)
  - [Health Check Service](./examples/health.md)

## Quick Start

1. **Installation**:

   ```bash
   git clone <repository-url>
   cd api-gateway
   ```

2. **Configuration**:

   - Copy `.env.example` to `.env`
   - Modify settings as needed
   - Review `configs/nginx.conf`

3. **Running**:

   ```bash
   docker-compose up
   ```

4. **Testing**:
   ```bash
   curl http://localhost:8080/tests/run_all
   ```

## Contributing

Please read our [Contributing Guide](./CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
