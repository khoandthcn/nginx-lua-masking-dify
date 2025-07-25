-- pattern_matcher.lua - Pattern matching engine for nginx-lua-masking plugin
-- Author: Manus AI
-- Version: 1.0.0

local utils = require("lib.utils")

local _M = {}

-- Default patterns
local DEFAULT_PATTERNS = {
    email = {
        enabled = true,
        regex = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+",
        placeholder_prefix = "EMAIL"
    },
    ipv4_private = {
        enabled = true,
        regex = "(%d+%.%d+%.%d+%.%d+)",
        placeholder_prefix = "IP_PRIVATE",
        validator = "is_private_ipv4"
    },
    ipv4_public = {
        enabled = true,
        regex = "(%d+%.%d+%.%d+%.%d+)",
        placeholder_prefix = "IP_PUBLIC",
        validator = "is_public_ipv4"
    },
    ipv6 = {
        enabled = true,
        regex = "([0-9a-fA-F]*:+[0-9a-fA-F:]*)",
        placeholder_prefix = "IPV6",
        validator = "is_valid_ipv6"
    },
    domains = {
        enabled = true,
        static_list = {
            "google.com", "microsoft.com", "amazon.com", "facebook.com", "apple.com",
            "netflix.com", "tesla.com", "twitter.com", "linkedin.com", "instagram.com",
            "youtube.com", "github.com", "oracle.com", "ibm.com", "intel.com",
            "amd.com", "nvidia.com", "samsung.com", "sony.com", "lg.com",
            "openai.com", "anthropic.com", "cohere.ai", "huggingface.co",
            "stackoverflow.com", "reddit.com", "discord.com", "slack.com",
            "zoom.us", "teams.microsoft.com", "meet.google.com", "webex.com"
        },
        placeholder_prefix = "DOMAIN",
        case_sensitive = false,
        whole_words_only = true
    },
    hostnames = {
        enabled = true,
        static_list = {
            "localhost", "www", "api", "app", "web", "mail", "ftp", "ssh",
            "db", "database", "cache", "redis", "mongo", "mysql", "postgres",
            "server", "host", "node", "worker", "master", "slave", "primary",
            "secondary", "backup", "staging", "prod", "production", "dev",
            "development", "test", "testing", "qa", "uat", "demo",
            "admin", "dashboard", "portal", "gateway", "proxy", "load-balancer",
            "cdn", "static", "media", "assets", "files", "storage",
            "auth", "login", "oauth", "sso", "ldap", "ad",
            "monitor", "metrics", "logs", "analytics", "tracking"
        },
        placeholder_prefix = "HOSTNAME",
        case_sensitive = false,
        whole_words_only = true
    },
    organizations = {
        enabled = true,
        static_list = {
            "Google", "Microsoft", "Amazon", "Facebook", "Apple", "Netflix", 
            "Tesla", "Twitter", "LinkedIn", "Instagram", "YouTube", "GitHub",
            "Oracle", "IBM", "Intel", "AMD", "NVIDIA", "Samsung", "Sony", "LG",
            "OpenAI", "Anthropic", "Cohere", "Hugging Face", "DeepMind",
            "Salesforce", "ServiceNow", "Snowflake", "Databricks", "Palantir",
            "Uber", "Airbnb", "Spotify", "Dropbox", "Slack", "Zoom", "Discord"
        },
        placeholder_prefix = "ORG",
        case_sensitive = false,
        whole_words_only = true
    }
}

-- Pattern matcher instance
local PatternMatcher = {}
PatternMatcher.__index = PatternMatcher

-- Create new pattern matcher instance
function _M.new(config)
    local self = setmetatable({}, PatternMatcher)
    
    -- Use provided config or default
    self.config = config or DEFAULT_PATTERNS
    
    -- Value to placeholder mapping (for consistency)
    self.value_to_placeholder = {}
    
    -- Placeholder to value mapping (for reverse mapping)
    self.placeholder_to_value = {}
    
    -- Placeholder counters
    self.placeholder_counters = {}
    
    -- Compiled regex patterns (cache)
    self.compiled_patterns = {}
    
    -- Initialize patterns
    self:_initialize_patterns()
    
    utils.log("INFO", "Pattern matcher initialized with " .. utils.table_size(self.config) .. " patterns")
    
    return self
end

-- Initialize and compile patterns
function PatternMatcher:_initialize_patterns()
    for name, pattern_config in pairs(self.config) do
        if pattern_config.enabled then
            if pattern_config.regex then
                -- Compile regex pattern
                self.compiled_patterns[name] = {
                    type = "regex",
                    pattern = pattern_config.regex,
                    prefix = pattern_config.placeholder_prefix or string.upper(name)
                }
                utils.log("DEBUG", "Compiled regex pattern for: " .. name)
            elseif pattern_config.static_list then
                -- Prepare static list pattern
                self.compiled_patterns[name] = {
                    type = "static",
                    list = pattern_config.static_list,
                    prefix = pattern_config.placeholder_prefix or string.upper(name)
                }
                utils.log("DEBUG", "Prepared static list pattern for: " .. name .. " with " .. #pattern_config.static_list .. " items")
            end
            
            -- Initialize counter
            self.placeholder_counters[name] = 0
        end
    end
end

-- IP validation functions
function PatternMatcher:is_private_ipv4(ip)
    -- Parse IP octets
    local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return false end
    
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not a or not b or not c or not d then return false end
    if a > 255 or b > 255 or c > 255 or d > 255 then return false end
    
    -- Check private IP ranges
    -- 10.0.0.0/8
    if a == 10 then return true end
    
    -- 172.16.0.0/12
    if a == 172 and b >= 16 and b <= 31 then return true end
    
    -- 192.168.0.0/16
    if a == 192 and b == 168 then return true end
    
    -- 127.0.0.0/8 (localhost)
    if a == 127 then return true end
    
    -- 169.254.0.0/16 (link-local)
    if a == 169 and b == 254 then return true end
    
    return false
end

function PatternMatcher:is_public_ipv4(ip)
    -- Parse IP octets
    local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return false end
    
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not a or not b or not c or not d then return false end
    if a > 255 or b > 255 or c > 255 or d > 255 then return false end
    
    -- Exclude reserved ranges
    if a == 0 then return false end -- 0.0.0.0/8
    if a >= 224 then return false end -- Multicast and reserved
    
    -- Return true if not private
    return not self:is_private_ipv4(ip)
end

function PatternMatcher:is_valid_ipv6(ip)
    -- Basic IPv6 validation
    if not ip or ip == "" then return false end
    
    -- Remove leading/trailing whitespace
    ip = ip:match("^%s*(.-)%s*$")
    
    -- Check for valid IPv6 characters
    if not ip:match("^[0-9a-fA-F:]+$") then return false end
    
    -- Must contain at least one colon
    if not ip:match(":") then return false end
    
    -- Cannot start or end with single colon (except ::)
    if ip:match("^:[^:]") or ip:match("[^:]:$") then return false end
    
    -- Cannot have more than one double colon
    local _, double_colon_count = ip:gsub("::", "")
    if double_colon_count > 1 then return false end
    
    -- Split by colons and check each part
    local parts = {}
    for part in ip:gmatch("[^:]+") do
        table.insert(parts, part)
    end
    
    -- Each part should be 1-4 hex digits
    for _, part in ipairs(parts) do
        if #part > 4 or not part:match("^[0-9a-fA-F]+$") then
            return false
        end
    end
    
    -- If no double colon, should have exactly 8 parts
    -- If double colon exists, should have fewer than 8 parts
    if double_colon_count == 0 and #parts ~= 8 then
        return false
    elseif double_colon_count == 1 and #parts >= 8 then
        return false
    end
    
    return true
end

-- Generate unique placeholder for a value
function PatternMatcher:_generate_placeholder(pattern_name, value)
    -- Check if we already have a placeholder for this value
    local key = pattern_name .. ":" .. value
    if self.value_to_placeholder[key] then
        return self.value_to_placeholder[key]
    end
    
    -- Generate new placeholder
    local pattern_info = self.compiled_patterns[pattern_name]
    if not pattern_info then
        utils.log("WARN", "Pattern not found: " .. pattern_name)
        return value
    end
    
    self.placeholder_counters[pattern_name] = self.placeholder_counters[pattern_name] + 1
    local placeholder = pattern_info.prefix .. "_" .. self.placeholder_counters[pattern_name]
    
    -- Store mappings
    self.value_to_placeholder[key] = placeholder
    self.placeholder_to_value[placeholder] = value
    
    utils.log("DEBUG", "Generated placeholder: " .. value .. " -> " .. placeholder)
    
    return placeholder
end

-- Match and replace patterns in text
function PatternMatcher:mask_text(text)
    if not text or text == "" then
        return text
    end
    
    local result = text
    local matches_found = 0
    
    -- Process each enabled pattern
    for name, pattern_info in pairs(self.compiled_patterns) do
        if pattern_info.type == "regex" then
            -- Handle regex patterns
            local pattern = pattern_info.pattern
            
            -- Find all matches
            local matches = {}
            for match in result:gmatch(pattern) do
                -- Validate the match (additional checks for specific patterns)
                if self:_validate_match(name, match) then
                    table.insert(matches, match)
                end
            end
            
            -- Replace matches with placeholders
            for _, match in ipairs(matches) do
                local placeholder = self:_generate_placeholder(name, match)
                result = result:gsub(utils.escape_regex(match), placeholder)
                matches_found = matches_found + 1
            end
            
        elseif pattern_info.type == "static" then
            -- Handle static list patterns
            local pattern_config = self.config[name]
            local case_sensitive = pattern_config.case_sensitive ~= false -- default true
            local whole_words_only = pattern_config.whole_words_only ~= false -- default true
            
            for _, item in ipairs(pattern_info.list) do
                local escaped_item = utils.escape_regex(item)
                local search_pattern
                
                if whole_words_only then
                    -- Use word boundaries
                    search_pattern = "(%f[%w]" .. escaped_item .. "%f[%W])"
                else
                    -- Simple substring match
                    search_pattern = "(" .. escaped_item .. ")"
                end
                
                local found = false
                if case_sensitive then
                    -- Case-sensitive matching
                    result = result:gsub(search_pattern, function(match)
                        found = true
                        matches_found = matches_found + 1
                        return self:_generate_placeholder(name, match)
                    end)
                else
                    -- Case-insensitive matching
                    local lower_result = result:lower()
                    local lower_item = item:lower()
                    local lower_escaped = utils.escape_regex(lower_item)
                    local lower_pattern
                    
                    if whole_words_only then
                        lower_pattern = "(%f[%w]" .. lower_escaped .. "%f[%W])"
                    else
                        lower_pattern = "(" .. lower_escaped .. ")"
                    end
                    
                    -- Find matches in lowercase version
                    for match in lower_result:gmatch(lower_pattern) do
                        -- Find the original case version in the original text
                        local start_pos = 1
                        while true do
                            local match_start, match_end = result:find(utils.escape_regex(match), start_pos, false)
                            if not match_start then
                                -- Try case-insensitive search
                                for i = start_pos, #result - #match + 1 do
                                    local substr = result:sub(i, i + #match - 1)
                                    if substr:lower() == match then
                                        local placeholder = self:_generate_placeholder(name, substr)
                                        result = result:sub(1, i-1) .. placeholder .. result:sub(i + #match)
                                        matches_found = matches_found + 1
                                        start_pos = i + #placeholder
                                        found = true
                                        break
                                    end
                                end
                                break
                            else
                                local original_match = result:sub(match_start, match_end)
                                local placeholder = self:_generate_placeholder(name, original_match)
                                result = result:sub(1, match_start-1) .. placeholder .. result:sub(match_end+1)
                                matches_found = matches_found + 1
                                start_pos = match_start + #placeholder
                                found = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    if matches_found > 0 then
        utils.log("INFO", "Masked " .. matches_found .. " sensitive values in text")
    end
    
    return result
end

-- Validate specific pattern matches
function PatternMatcher:_validate_match(pattern_name, match)
    -- Get pattern config to check if it has a validator
    local pattern_config = self.config[pattern_name]
    if pattern_config and pattern_config.validator then
        local validator_func = self[pattern_config.validator]
        if validator_func then
            return validator_func(self, match)
        end
    end
    
    -- Default validation for specific patterns
    if pattern_name == "email" then
        return self:_validate_email(match)
    elseif pattern_name == "ipv4" then
        -- Legacy IPv4 validation (if still used)
        return self:_validate_ipv4(match)
    end
    
    return true
end

-- Validate email format
function PatternMatcher:_validate_email(email)
    if not email then return false end
    
    -- Check basic structure
    local at_count = 0
    for _ in email:gmatch("@") do
        at_count = at_count + 1
    end
    
    if at_count ~= 1 then return false end
    
    local local_part, domain = email:match("([^@]+)@([^@]+)")
    if not local_part or not domain then return false end
    
    -- Check local part length
    if #local_part > 64 then return false end
    
    -- Check domain has at least one dot
    if not domain:match("%.") then return false end
    
    -- Check domain parts
    local domain_parts = utils.split(domain, ".")
    if #domain_parts < 2 then return false end
    
    -- Check TLD length
    local tld = domain_parts[#domain_parts]
    if #tld < 2 or #tld > 6 then return false end
    
    return true
end

-- Validate IPv4 format
function PatternMatcher:_validate_ipv4(ip)
    if not ip then return false end
    
    local parts = utils.split(ip, ".")
    if #parts ~= 4 then return false end
    
    for _, part in ipairs(parts) do
        local num = tonumber(part)
        if not num or num < 0 or num > 255 then
            return false
        end
        
        -- Check for leading zeros (except for "0")
        if part ~= "0" and part:match("^0") then
            return false
        end
    end
    
    return true
end

-- Reverse mapping - replace placeholders with original values
function PatternMatcher:unmask_text(text)
    if not text or text == "" then
        return text
    end
    
    local result = text
    local replacements_made = 0
    
    -- Replace all placeholders with original values
    for placeholder, original_value in pairs(self.placeholder_to_value) do
        local escaped_placeholder = utils.escape_regex(placeholder)
        local count
        result, count = result:gsub(escaped_placeholder, original_value)
        replacements_made = replacements_made + count
    end
    
    if replacements_made > 0 then
        utils.log("INFO", "Unmasked " .. replacements_made .. " placeholders in text")
    end
    
    return result
end

-- Get mapping statistics
function PatternMatcher:get_stats()
    local stats = {
        total_mappings = utils.table_size(self.placeholder_to_value),
        patterns = {}
    }
    
    for name, count in pairs(self.placeholder_counters) do
        stats.patterns[name] = count
    end
    
    return stats
end

-- Clear all mappings (for cleanup)
function PatternMatcher:clear_mappings()
    self.value_to_placeholder = {}
    self.placeholder_to_value = {}
    
    -- Reset counters
    for name in pairs(self.placeholder_counters) do
        self.placeholder_counters[name] = 0
    end
    
    utils.log("INFO", "Cleared all pattern mappings")
end

-- Export mappings (for persistence if needed)
function PatternMatcher:export_mappings()
    return {
        value_to_placeholder = utils.deep_copy(self.value_to_placeholder),
        placeholder_to_value = utils.deep_copy(self.placeholder_to_value),
        counters = utils.deep_copy(self.placeholder_counters)
    }
end

-- Import mappings (for restoration if needed)
function PatternMatcher:import_mappings(mappings)
    if mappings.value_to_placeholder then
        self.value_to_placeholder = utils.deep_copy(mappings.value_to_placeholder)
    end
    
    if mappings.placeholder_to_value then
        self.placeholder_to_value = utils.deep_copy(mappings.placeholder_to_value)
    end
    
    if mappings.counters then
        self.placeholder_counters = utils.deep_copy(mappings.counters)
    end
    
    utils.log("INFO", "Imported pattern mappings")
end

-- Test pattern matching (for debugging)
function PatternMatcher:test_pattern(pattern_name, test_string)
    local pattern_info = self.compiled_patterns[pattern_name]
    if not pattern_info then
        return false, "Pattern not found: " .. pattern_name
    end
    
    local matches = {}
    
    if pattern_info.type == "regex" then
        for match in test_string:gmatch(pattern_info.pattern) do
            if self:_validate_match(pattern_name, match) then
                table.insert(matches, match)
            end
        end
    elseif pattern_info.type == "static" then
        for _, item in ipairs(pattern_info.list) do
            if test_string:find(item, 1, true) then
                table.insert(matches, item)
            end
        end
    end
    
    return true, matches
end

return _M

