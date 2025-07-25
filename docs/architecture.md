# Nginx Lua Masking Plugin - Architecture Design

## Tổng quan

Plugin này được thiết kế để thực hiện masking dữ liệu nhạy cảm trong request và response của Nginx sử dụng Lua. Plugin sẽ xử lý dữ liệu JSON, thực hiện masking các pattern định nghĩa trước và tạo mapping để reverse lại trong response.

## Kiến trúc tổng thể

```
nginx-lua-masking/
├── lib/                    # Core library files
│   ├── masking_plugin.lua  # Main plugin module
│   ├── pattern_matcher.lua # Pattern matching engine
│   ├── json_processor.lua  # JSON processing utilities
│   ├── stream_handler.lua  # Stream data handling
│   ├── mapping_store.lua   # Mapping storage and retrieval
│   └── utils.lua          # Common utilities
├── config/                # Configuration files
│   ├── default.json       # Default configuration
│   └── patterns.json      # Pattern definitions
├── test/                  # Unit tests
│   ├── test_runner.lua    # Test framework
│   ├── test_patterns.lua  # Pattern matching tests
│   ├── test_json.lua      # JSON processing tests
│   └── test_integration.lua # Integration tests
├── examples/              # Usage examples
│   ├── nginx.conf         # Sample Nginx configuration
│   └── sample_requests.json # Sample test requests
└── docs/                  # Documentation
    ├── architecture.md    # This file
    ├── api.md            # API documentation
    └── installation.md   # Installation guide
```

## Các thành phần chính

### 1. masking_plugin.lua (Main Module)
- Entry point của plugin
- Xử lý request và response hooks
- Quản lý lifecycle của masking process
- Tích hợp với các module khác

### 2. pattern_matcher.lua (Pattern Matching Engine)
- Định nghĩa và xử lý các pattern:
  - Email: `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`
  - IPv4: `\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b`
  - Organization names: Danh sách tĩnh có thể cấu hình
- Tạo placeholder cho các match
- Đảm bảo consistency (cùng value → cùng placeholder)

### 3. json_processor.lua (JSON Processing)
- Parse và validate JSON request
- Xử lý selective masking theo path configuration
- Rebuild JSON với masked data
- Error handling cho invalid JSON

### 4. stream_handler.lua (Stream Data Handling)
- Xử lý response stream data
- Buffer management cho large responses
- Chunked processing
- Reverse mapping trong stream

### 5. mapping_store.lua (Mapping Storage)
- Lưu trữ mapping giữa original value và placeholder
- Thread-safe storage mechanism
- Cleanup và memory management
- Persistence options

### 6. utils.lua (Common Utilities)
- Logging utilities
- Configuration loading
- Error handling helpers
- String manipulation functions

## Data Flow

### Request Processing Flow
1. **Request Interception**: Plugin intercepts incoming request
2. **Content Type Check**: Verify request is JSON
3. **JSON Parsing**: Parse request body to JSON
4. **Path Filtering**: Apply masking only to configured paths
5. **Pattern Matching**: Find sensitive data using patterns
6. **Placeholder Generation**: Create unique placeholders
7. **Mapping Storage**: Store original→placeholder mapping
8. **JSON Reconstruction**: Rebuild JSON with placeholders
9. **Forward Request**: Send masked request to upstream

### Response Processing Flow
1. **Response Interception**: Plugin intercepts upstream response
2. **Stream Processing**: Handle response as stream data
3. **Mapping Retrieval**: Get stored mappings for this request
4. **Reverse Mapping**: Replace placeholders with original values
5. **Stream Output**: Send unmasked response to client
6. **Cleanup**: Clear mappings for this request

## Configuration Schema

```json
{
  "enabled": true,
  "patterns": {
    "email": {
      "enabled": true,
      "regex": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
      "placeholder_prefix": "EMAIL_"
    },
    "ipv4": {
      "enabled": true,
      "regex": "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
      "placeholder_prefix": "IP_"
    },
    "organizations": {
      "enabled": true,
      "static_list": ["Google", "Microsoft", "Amazon", "Facebook"],
      "placeholder_prefix": "ORG_"
    }
  },
  "json_paths": [
    "$.user.email",
    "$.server.ip",
    "$.company.name"
  ],
  "logging": {
    "enabled": true,
    "level": "INFO"
  },
  "performance": {
    "max_buffer_size": 1048576,
    "chunk_size": 8192
  }
}
```

## Error Handling Strategy

### Graceful Degradation
- Nếu JSON parsing fails → pass through request unchanged
- Nếu pattern matching fails → log error, continue without masking
- Nếu stream processing fails → fallback to simple string replacement

### Error Categories
1. **Configuration Errors**: Invalid config, missing patterns
2. **Processing Errors**: JSON parsing, regex compilation
3. **Runtime Errors**: Memory issues, stream handling
4. **Network Errors**: Upstream connection issues

### Recovery Mechanisms
- Automatic fallback to passthrough mode
- Error logging với detailed context
- Graceful cleanup of resources
- Request isolation (1 request error không affect others)

## Performance Considerations

### Memory Management
- Efficient buffer allocation for stream processing
- Automatic cleanup of mappings after request completion
- Configurable limits for maximum buffer sizes

### Processing Efficiency
- Lazy loading of patterns and configurations
- Optimized regex compilation and caching
- Minimal JSON parsing overhead
- Stream processing để avoid loading entire response vào memory

### Scalability
- Thread-safe operations
- Minimal shared state
- Efficient pattern matching algorithms
- Configurable performance tuning parameters

## Security Considerations

### Data Protection
- Mappings chỉ tồn tại trong memory, không persist to disk
- Secure cleanup of sensitive data
- No logging of actual sensitive values

### Access Control
- Configuration file permissions
- Plugin loading restrictions
- Audit logging capabilities

## Testing Strategy

### Unit Tests
- Pattern matching accuracy
- JSON processing edge cases
- Stream handling với various data sizes
- Error handling scenarios

### Integration Tests
- End-to-end request/response flow
- Performance under load
- Memory usage patterns
- Error recovery mechanisms

### Load Testing
- High concurrency scenarios
- Large payload handling
- Memory leak detection
- Performance benchmarking

