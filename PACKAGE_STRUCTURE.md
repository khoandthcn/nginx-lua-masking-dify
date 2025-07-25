# Package Structure

```
nginx-lua-masking-dify-v1.0/
├── README.md                           # 📖 Hướng dẫn tổng quan và quick start
├── QUICKSTART.md                       # 🚀 Hướng dẫn cài đặt nhanh 5 phút
├── CHANGELOG.md                        # 📋 Lịch sử thay đổi và tính năng
├── LICENSE                             # 📄 Giấy phép MIT
├── VERSION                             # 🏷️ Version hiện tại (1.0.0)
├── PACKAGE_STRUCTURE.md                # 📁 Cấu trúc package này
│
├── 🔧 Core Library Files
├── lib/
│   ├── utils.lua                       # Utility functions và JSON handling
│   ├── pattern_matcher.lua             # Pattern matching engine
│   ├── json_processor.lua              # JSON processing với JSONPath
│   ├── stream_handler.lua              # Stream data processing
│   ├── mapping_store.lua               # Mapping storage và retrieval
│   ├── masking_plugin.lua              # Main masking plugin
│   ├── dify_adapter.lua                # Dify integration adapter
│   └── dify_message_api.lua            # Dify message API handler
│
├── ⚙️ Configuration Files
├── config/
│   ├── default.json                    # Default plugin configuration
│   ├── dify_config.json                # Dify-specific configuration
│   └── patterns.json                   # Pattern definitions
│
├── 📝 Examples & Templates
├── examples/
│   ├── nginx.conf                      # General Nginx configuration
│   ├── dify_nginx.conf                 # Dify-specific Nginx config
│   └── sample_requests.json            # Sample API requests
│
├── 🚀 Deployment & Scripts
├── scripts/
│   └── deploy_dify.sh                  # Automated deployment script
│
├── 🧪 Testing Framework
├── test/
│   ├── test_runner.lua                 # Test framework
│   ├── test_patterns.lua               # Pattern matching tests
│   ├── test_json.lua                   # JSON processing tests
│   ├── test_integration.lua            # Integration tests
│   ├── run_tests.lua                   # Test suite runner
│   ├── simple_test.lua                 # Simple debug test
│   └── test_report.json               # Test results
│
├── 📚 Documentation
├── docs/
│   ├── DIFY_INTEGRATION_GUIDE.md       # Chi tiết tích hợp Dify v0.15.8
│   ├── API.md                          # API documentation
│   ├── INSTALLATION.md                 # Hướng dẫn cài đặt manual
│   └── architecture.md                 # Thiết kế kiến trúc
│
├── 🧪 Quick Test Files
├── fixed_test.lua                      # Test core functions
├── test_dify_integration.lua           # Test Dify integration
│
└── 📊 Test Reports
    ├── core_functions_test_report.md   # Báo cáo test core functions
    └── dify_integration_test_report.md # Báo cáo test tích hợp Dify
```

## 📋 File Descriptions

### 🔧 Core Library (lib/)
- **utils.lua**: JSON encoding/decoding, logging, utility functions
- **pattern_matcher.lua**: Email, IP, Organization pattern detection
- **json_processor.lua**: JSONPath-based selective field processing
- **stream_handler.lua**: Streaming response processing (SSE)
- **mapping_store.lua**: Placeholder mapping storage và retrieval
- **masking_plugin.lua**: Main plugin orchestrating all components
- **dify_adapter.lua**: Dify-specific integration layer
- **dify_message_api.lua**: Specialized Dify message API handling

### ⚙️ Configuration (config/)
- **default.json**: Default patterns và settings
- **dify_config.json**: Dify v0.15.8 specific configuration
- **patterns.json**: Pattern definitions cho masking

### 📝 Examples (examples/)
- **nginx.conf**: General Nginx configuration template
- **dify_nginx.conf**: Production-ready Dify configuration
- **sample_requests.json**: Example API requests for testing

### 🚀 Scripts (scripts/)
- **deploy_dify.sh**: One-click deployment script với options

### 🧪 Testing (test/)
- **test_runner.lua**: Custom test framework
- **test_*.lua**: Comprehensive test suites
- **run_tests.lua**: Execute all tests

### 📚 Documentation (docs/)
- **DIFY_INTEGRATION_GUIDE.md**: Complete integration guide
- **API.md**: API reference documentation
- **INSTALLATION.md**: Manual installation steps
- **architecture.md**: System architecture design

## 🎯 Usage Priorities

### 1. Quick Start (5 minutes)
```bash
# Read: QUICKSTART.md
# Run: ./scripts/deploy_dify.sh
```

### 2. Production Deployment
```bash
# Read: docs/DIFY_INTEGRATION_GUIDE.md
# Configure: examples/dify_nginx.conf
```

### 3. Development & Customization
```bash
# Study: lib/ modules
# Test: fixed_test.lua, test_dify_integration.lua
# Configure: config/ files
```

### 4. Troubleshooting
```bash
# Reference: docs/DIFY_INTEGRATION_GUIDE.md (Troubleshooting section)
# Debug: test/ files
```

## 📊 File Sizes & Complexity

| Category | Files | Total Lines | Complexity |
|----------|-------|-------------|------------|
| **Core Library** | 8 files | ~2,000 lines | High |
| **Configuration** | 3 files | ~200 lines | Medium |
| **Documentation** | 8 files | ~1,500 lines | Low |
| **Testing** | 8 files | ~1,200 lines | Medium |
| **Scripts** | 1 file | ~300 lines | Medium |
| **Examples** | 3 files | ~400 lines | Low |

## 🔍 Key Entry Points

1. **README.md** - Start here for overview
2. **QUICKSTART.md** - For immediate deployment
3. **scripts/deploy_dify.sh** - For automated setup
4. **lib/masking_plugin.lua** - Main plugin logic
5. **config/dify_config.json** - Dify configuration
6. **docs/DIFY_INTEGRATION_GUIDE.md** - Complete guide

## ✅ Quality Assurance

- ✅ All core functions tested và working
- ✅ Dify v0.15.8 integration verified
- ✅ Performance benchmarked (0.183ms avg)
- ✅ Error handling implemented
- ✅ Documentation complete
- ✅ Deployment automated
- ✅ Production ready

