-- Optimized Pattern Matcher for OpenResty
-- Version: 2.1.0

local utils = require("utils")
local _M = {}

local PatternMatcher = {}
PatternMatcher.__index = PatternMatcher

-- Optimized patterns with compiled regex for better performance
local DEFAULT_PATTERNS = {
    {
        name = "email",
        pattern = "[%w%._%+-]+@[%w%._%+-]+%.%w+",
        prefix = "EMAIL",
        validator = utils.is_valid_email,
        priority = 1
    },
    {
        name = "ip_private",
        pattern = "192%.168%.[0-9]+%.[0-9]+",
        prefix = "IP_PRIVATE",
        validator = function(ip) 
            return utils.is_valid_ipv4(ip) and (
                ip:match("^192%.168%.") or 
                ip:match("^10%.") or 
                ip:match("^172%.1[6-9]%.") or 
                ip:match("^172%.2[0-9]%.") or 
                ip:match("^172%.3[0-1]%.") or
                ip:match("^127%.")
            )
        end,
        priority = 2
    },
    {
        name = "ip_public",
        pattern = "[0-9]+%.[0-9]+%.[0-9]+%.[0-9]+",
        prefix = "IP_PUBLIC",
        validator = function(ip)
            return utils.is_valid_ipv4(ip) and not (
                ip:match("^192%.168%.") or 
                ip:match("^10%.") or 
                ip:match("^172%.1[6-9]%.") or 
                ip:match("^172%.2[0-9]%.") or 
                ip:match("^172%.3[0-1]%.") or
                ip:match("^127%.")
            )
        end,
        priority = 3
    },
    {
        name = "ipv6",
        pattern = "[0-9a-fA-F:]+::[0-9a-fA-F:]*",
        prefix = "IPV6",
        validator = utils.is_valid_ipv6,
        priority = 4
    },
    {
        name = "organization",
        pattern = nil, -- Will use static list
        prefix = "ORG",
        static_list = {
            "Google", "Microsoft", "Apple", "Amazon", "Facebook", "Meta",
            "OpenAI", "GitHub", "GitLab", "Atlassian", "Slack", "Discord",
            "Netflix", "Spotify", "Adobe", "Oracle", "IBM", "Intel",
            "NVIDIA", "AMD", "Tesla", "SpaceX", "Uber", "Airbnb",
            "Dropbox", "Zoom", "Salesforce", "ServiceNow", "Workday"
        },
        priority = 5
    },
    {
        name = "domain",
        pattern = nil, -- Will use static list
        prefix = "DOMAIN",
        static_list = {
            "google.com", "microsoft.com", "apple.com", "amazon.com",
            "facebook.com", "meta.com", "openai.com", "github.com",
            "gitlab.com", "atlassian.com", "slack.com", "discord.com",
            "netflix.com", "spotify.com", "adobe.com", "oracle.com",
            "ibm.com", "intel.com", "nvidia.com", "amd.com",
            "tesla.com", "spacex.com", "uber.com", "airbnb.com",
            "dropbox.com", "zoom.us", "salesforce.com", "servicenow.com"
        },
        priority = 6
    },
    {
        name = "hostname",
        pattern = nil, -- Will use static list
        prefix = "HOSTNAME",
        static_list = {
            "localhost", "www", "api", "app", "server", "database", "db",
            "staging", "prod", "production", "dev", "development", "test",
            "qa", "admin", "dashboard", "gateway", "proxy", "load-balancer",
            "cdn", "static", "media", "cache", "redis", "memcached",
            "login", "auth", "oauth", "sso", "ldap", "mail", "smtp",
            "ftp", "sftp", "ssh", "vpn", "dns", "ntp", "monitoring"
        },
        priority = 7
    }
}

function _M.new(config)
    local self = setmetatable({}, PatternMatcher)
    
    self.patterns = config and config.patterns or DEFAULT_PATTERNS
    self.mappings = {}
    self.reverse_mappings = {}
    self.stats = {
        total_processed = 0,
        total_masked = 0,
        pattern_hits = {}
    }
    
    -- Initialize pattern hit counters
    for _, pattern in ipairs(self.patterns) do
        self.stats.pattern_hits[pattern.name] = 0
    end
    
    -- Sort patterns by priority for optimal matching order
    table.sort(self.patterns, function(a, b) return a.priority < b.priority end)
    
    utils.log("INFO", "Pattern matcher initialized with " .. #self.patterns .. " patterns")
    
    return self
end

function PatternMatcher:mask_text(text)
    if not text or text == "" then
        return text
    end
    
    local start_time = utils.get_time_ms()
    local result = text
    local masked_count = 0
    
    self.stats.total_processed = self.stats.total_processed + 1
    
    -- Process each pattern
    for _, pattern in ipairs(self.patterns) do
        if pattern.static_list then
            -- Handle static list patterns
            for _, item in ipairs(pattern.static_list) do
                local escaped_item = utils.escape_pattern(item)
                local matches = {}
                
                -- Find all matches (case insensitive)
                for match in result:lower():gmatch(escaped_item:lower()) do
                    local original_match = result:match("(" .. escaped_item .. ")")
                    if original_match and not matches[original_match] then
                        if not pattern.validator or pattern.validator(original_match) then
                            masked_count = masked_count + 1
                            local placeholder = self:_get_or_create_placeholder(original_match, pattern.prefix)
                            matches[original_match] = placeholder
                            result = result:gsub(utils.escape_pattern(original_match), placeholder)
                            self.stats.pattern_hits[pattern.name] = self.stats.pattern_hits[pattern.name] + 1
                        end
                    end
                end
            end
        else
            -- Handle regex patterns
            local matches = {}
            for match in result:gmatch(pattern.pattern) do
                if not matches[match] then
                    if not pattern.validator or pattern.validator(match) then
                        masked_count = masked_count + 1
                        local placeholder = self:_get_or_create_placeholder(match, pattern.prefix)
                        matches[match] = placeholder
                        result = result:gsub(utils.escape_pattern(match), placeholder)
                        self.stats.pattern_hits[pattern.name] = self.stats.pattern_hits[pattern.name] + 1
                    end
                end
            end
        end
    end
    
    local end_time = utils.get_time_ms()
    local processing_time = end_time - start_time
    
    if masked_count > 0 then
        self.stats.total_masked = self.stats.total_masked + masked_count
        utils.log("INFO", string.format("Masked %d sensitive values in %.3fms", masked_count, processing_time))
    end
    
    return result
end

function PatternMatcher:unmask_text(text)
    if not text or text == "" then
        return text
    end
    
    local result = text
    
    -- Replace placeholders with original values
    for placeholder, original in pairs(self.reverse_mappings) do
        result = result:gsub(utils.escape_pattern(placeholder), original)
    end
    
    return result
end

function PatternMatcher:_get_or_create_placeholder(original_value, prefix)
    -- Check if we already have a mapping for this value
    if self.mappings[original_value] then
        return self.mappings[original_value]
    end
    
    -- Create new placeholder
    local count = 1
    for existing_original, existing_placeholder in pairs(self.mappings) do
        if existing_placeholder:match("^" .. prefix .. "_(%d+)$") then
            local num = tonumber(existing_placeholder:match("^" .. prefix .. "_(%d+)$"))
            if num and num >= count then
                count = num + 1
            end
        end
    end
    
    local placeholder = prefix .. "_" .. count
    self.mappings[original_value] = placeholder
    self.reverse_mappings[placeholder] = original_value
    
    return placeholder
end

function PatternMatcher:get_mappings()
    return self.mappings
end

function PatternMatcher:get_reverse_mappings()
    return self.reverse_mappings
end

function PatternMatcher:get_stats()
    return self.stats
end

function PatternMatcher:clear_mappings()
    utils.clear_table(self.mappings)
    utils.clear_table(self.reverse_mappings)
end

function PatternMatcher:add_pattern(pattern)
    table.insert(self.patterns, pattern)
    self.stats.pattern_hits[pattern.name] = 0
    
    -- Re-sort patterns by priority
    table.sort(self.patterns, function(a, b) return a.priority < b.priority end)
    
    utils.log("INFO", "Added new pattern: " .. pattern.name)
end

function PatternMatcher:remove_pattern(pattern_name)
    for i, pattern in ipairs(self.patterns) do
        if pattern.name == pattern_name then
            table.remove(self.patterns, i)
            self.stats.pattern_hits[pattern_name] = nil
            utils.log("INFO", "Removed pattern: " .. pattern_name)
            return true
        end
    end
    return false
end

return _M
