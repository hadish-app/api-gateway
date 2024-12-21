# API Gateway Test Plan

## 1. Basic HTTP Functionality

### 1.1 Health Check

- [ ] GET /health returns 200
- [ ] Response is valid JSON
- [ ] Contains all required metrics
  - [ ] Memory usage stats
  - [ ] Rate limit configuration
  - [ ] Active bans count
  - [ ] Uptime information
- [ ] Version information present
- [ ] Response time < 50ms

### 1.2 HTTP Methods

- [ ] GET requests work properly
- [ ] POST requests work properly
- [ ] PUT requests work properly
- [ ] DELETE requests work properly
- [ ] OPTIONS returns proper CORS headers
- [ ] Invalid methods return appropriate error
- [ ] Method restrictions properly enforced

## 2. Error Handling

### 2.1 404 Handling

- [ ] Normal path returns proper 404 JSON response
- [ ] Response includes request_id
- [ ] No sensitive information in response
- [ ] Properly logged in access log
- [ ] Not logged in error log
- [ ] Response time < 50ms

### 2.2 Suspicious Paths

- [ ] Returns same 404 response as normal paths
- [ ] Properly logged in security log
- [ ] Includes violation_type and details
- [ ] Each suspicious pattern is detected:
  - [ ] .php files
  - [ ] .asp files
  - [ ] wp-admin
  - [ ] phpmyadmin
  - [ ] .git
  - [ ] SQL injection attempts

### 2.3 Forbidden Access

- [ ] Dot files return 403 JSON response
- [ ] Response format matches other errors
- [ ] Properly logged in security log
- [ ] No server information leaked
- [ ] Response time < 50ms

## 3. Rate Limiting

### 3.1 Basic Rate Limiting

- [ ] Respects requests per second limit
- [ ] Handles burst properly
- [ ] Returns 429 when limit exceeded
- [ ] Includes proper rate limit headers:
  - [ ] X-RateLimit-Limit
  - [ ] X-RateLimit-Remaining
  - [ ] X-RateLimit-Reset
- [ ] Counter resets after window expires

### 3.2 Rate Limit Violations

- [ ] Tracks violations properly
- [ ] Resets violations after expiry
- [ ] Triggers ban after max violations
- [ ] Properly logged in security log
- [ ] Violation count persists across requests

## 4. IP Banning

### 4.1 Ban Management

- [ ] IPs are banned after threshold
- [ ] Bans expire after duration
- [ ] Banned IPs receive 403
- [ ] Ban events properly logged
- [ ] Ban reason included in logs

### 4.2 Ban Persistence

- [ ] Bans survive nginx reload
- [ ] Banned IPs list is updated
- [ ] Expired bans are cleaned up
- [ ] Ban information accessible via API
- [ ] Proper cleanup of expired bans

## 5. Logging

### 5.1 Access Log

- [ ] Standard requests logged
- [ ] Includes request_id
- [ ] Includes timing information
- [ ] Includes client information
- [ ] JSON format is valid
- [ ] Contains all required fields:
  - [ ] Timestamp
  - [ ] Client IP
  - [ ] Request method and path
  - [ ] Status code
  - [ ] Response size
  - [ ] User agent
  - [ ] Request ID

### 5.2 Security Log

- [ ] 4xx/5xx errors logged
- [ ] Security violations logged
- [ ] Rate limit violations logged
- [ ] Ban events logged
- [ ] JSON format is valid
- [ ] Contains all required fields:
  - [ ] Timestamp
  - [ ] Violation type
  - [ ] Details
  - [ ] Client information
  - [ ] Request ID

### 5.3 Error Log

- [ ] No normal operations logged
- [ ] Only actual errors logged
- [ ] Proper log levels used
- [ ] Contains stack traces when needed
- [ ] No sensitive information logged

## 6. Admin Service

### 6.1 Routing

- [ ] /admin/ prefix properly stripped
- [ ] Requests properly forwarded
- [ ] Headers properly passed
- [ ] Response properly returned
- [ ] Proper handling of upstream errors

### 6.2 Security

- [ ] Rate limiting applied
- [ ] Security headers present
- [ ] No internal information leaked
- [ ] Proper error handling
- [ ] CORS properly configured

## 7. Performance

### 7.1 Response Times

- [ ] Health check < 50ms
- [ ] Normal requests < 100ms
- [ ] Rate limited requests < 50ms
- [ ] Error responses < 50ms
- [ ] Admin proxied requests < 200ms

### 7.2 Resource Usage

- [ ] Memory usage stable
- [ ] No memory leaks in shared dicts
- [ ] CPU usage reasonable
- [ ] Connection handling proper
- [ ] Log rotation working

## Test Framework Implementation

- [ ] Common test utilities
  - [ ] HTTP request handling
  - [ ] JSON validation and parsing
  - [ ] Test assertions and reporting
  - [ ] Color output and formatting
- [ ] Environment configuration
  - [ ] Loading from .env
  - [ ] Configurable timeouts
  - [ ] Port and host settings
- [ ] Test result tracking
  - [ ] Pass/Fail counting
  - [ ] Detailed error reporting
  - [ ] Test summary generation
- [ ] Error handling
  - [ ] HTTP request failures
  - [ ] JSON parsing errors
  - [ ] Missing dependencies

## Test Execution Checklist

### Pre-test Setup

1. [ ] Clean environment (docker-compose down)
2. [ ] Rebuild containers (docker-compose build)
3. [ ] Start services (docker-compose up -d)
4. [ ] Wait for services to be ready
5. [ ] Clear all logs
6. [ ] Verify initial state

### Test Execution

1. [ ] Run basic HTTP tests
   - [ ] Health check tests
   - [ ] HTTP methods tests
   - [ ] CORS validation
2. [ ] Run error handling tests
3. [ ] Run rate limiting tests
4. [ ] Run IP banning tests
5. [ ] Run logging tests
6. [ ] Run admin service tests
7. [ ] Run performance tests

### Post-test Cleanup

1. [ ] Collect all logs
2. [ ] Save test results
3. [ ] Clean up containers
4. [ ] Archive test artifacts

## Test Environment Requirements

### Software Requirements

- [ ] Docker version 20.10 or higher
- [ ] docker-compose version 2.0 or higher
- [ ] curl 7.0 or higher
- [ ] jq 1.6 or higher
- [ ] bash 5.0 or higher

### Hardware Requirements

- [ ] Minimum 2 CPU cores
- [ ] Minimum 4GB RAM
- [ ] 20GB free disk space

### Network Requirements

- [ ] Port 8080 available
- [ ] Internet access for admin service
- [ ] No firewall blocking Docker bridge network
