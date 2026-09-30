Locales = Locales or {}

function _L(key, ...)
    local lang = (Config and Config.Language) or 'en'
    local langTable = Locales[lang] or Locales['en'] or Locales['tr'] or {}
    local str = langTable[key] or (Locales['en'] and Locales['en'][key]) or (Locales['tr'] and Locales['tr'][key]) or key
    if select('#', ...) > 0 then
        local success, result = pcall(string.format, str, ...)
        if success then
            return result
        end
        return str
    end
    return str
end
